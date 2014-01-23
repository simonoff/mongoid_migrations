module Mongoid #:nodoc
  class Migrator #:nodoc:
    class << self
      def migrate(migrations_path, target_version = nil)
        case
        when target_version.nil? then
          up(migrations_path, target_version)
        when current_version > target_version then
          down(migrations_path, target_version)
        else
          up(migrations_path, target_version)
        end
      end

      def rollback(migrations_path, steps=1)
        move(:down, migrations_path, steps)
      end

      def forward(migrations_path, steps=1)
        move(:up, migrations_path, steps)
      end

      def up(migrations_path, target_version = nil)
        self.new(:up, migrations_path, target_version).migrate
      end

      def down(migrations_path, target_version = nil)
        self.new(:down, migrations_path, target_version).migrate
      end

      def run(direction, migrations_path, target_version)
        self.new(direction, migrations_path, target_version).run
      end

      def migrations_path
        ::Mongoid.migrations_path
      end

      def get_all_versions
        ::Mongoid::Migrations::DataMigration.all.map { |dm| dm.version.to_i }.sort
      end

      def current_version
        get_all_versions.max || 0
      end

      def proper_table_name(name)
        # Use the Active Record objects own table_name, or pre/suffix from ActiveRecord::Base if name is a symbol/string
        # name.table_name rescue "#{ActiveRecord::Base.table_name_prefix}#{name}#{ActiveRecord::Base.table_name_suffix}"
        name
      end

      private

      def move(direction, migrations_path, steps)
        migrator = self.new(direction, migrations_path)
        start_index = migrator.migrations.index(migrator.current_migration)

        if start_index
          finish = migrator.migrations[start_index + steps]
          version = finish ? finish.version : 0
          send(direction, migrations_path, version)
        end
      end
    end

    def initialize(direction, migrations_path, target_version = nil)
      # raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?
      # Base.connection.initialize_schema_migrations_table
      @direction, @migrations_path, @target_version = direction, migrations_path, target_version
    end

    def current_version
      migrated.last || 0
    end

    def current_migration
      migrations.detect { |m| m.version == current_version }
    end

    def run
      target = migrations.detect { |m| m.version == @target_version }
      raise ::Mongoid::UnknownMigrationVersionError.new(@target_version) if target.nil?
      unless (up? && migrated.include?(target.version.to_i)) || (down? && !migrated.include?(target.version.to_i))
        target.migrate(@direction)
        record_version_state_after_migrating(target.version)
      end
    end

    def migrate
      current = migrations.detect { |m| m.version == current_version }
      target = migrations.detect { |m| m.version == @target_version }

      if target.nil? && !@target_version.nil? && @target_version > 0
        raise ::Mongoid::UnknownMigrationVersionError.new(@target_version)
      end

      start = up? ? 0 : (migrations.index(current) || 0)
      finish = migrations.index(target) || migrations.size - 1
      runnable = migrations[start..finish]

      # skip the last migration if we're headed down, but not ALL the way down
      runnable.pop if down? && !target.nil?

      runnable.each do |migration|
        #if defined?(::Rails)
        #  ::Rails.logger.info "Migrating to #{migration.name} (#{migration.version})" if ::Rails.logger
        #end

        # On our way up, we skip migrating the ones we've already migrated
        next if up? && migrated.include?(migration.version.to_i)

        # On our way down, we skip reverting the ones we've never migrated
        if down? && !migrated.include?(migration.version.to_i)
          migration.announce 'never migrated, skipping'; migration.write
          next
        end

        # begin
        #   ddl_transaction do
        #     migration.migrate(@direction)
        #     record_version_state_after_migrating(migration.version)
        #   end
        # rescue => e
        #   canceled_msg = Base.connection.supports_ddl_transactions? ? "this and " : ""
        #   raise StandardError, "An error has occurred, #{canceled_msg}all later migrations canceled:\n\n#{e}", e.backtrace
        # end
        begin
          migration.migrate(@direction)
          record_version_state_after_migrating(migration.version)
        rescue => e
          raise StandardError, "An error has occurred, #{migration.version} and all later migrations canceled:\n\n#{e}", e.backtrace
        end
      end
    end

    def migrations
      @migrations ||= begin
        files = Dir["#{@migrations_path}/[0-9]*_*.rb"]

        migrations = files.inject([]) do |klasses, file|
          version, name = file.scan(/([0-9]+)_([_a-z0-9]*).rb/).first

          raise ::Mongoid::IllegalMigrationNameError.new(file) unless version
          version = version.to_i

          if klasses.detect { |m| m.version == version }
            raise ::Mongoid::DuplicateMigrationVersionError.new(version)
          end

          if klasses.detect { |m| m.name == name.camelize }
            raise ::Mongoid::DuplicateMigrationNameError.new(name.camelize)
          end

          migration = ::Mongoid::MigrationProxy.new
          migration.name = name.camelize
          migration.version = version
          migration.filename = file
          klasses << migration
        end

        migrations = migrations.sort_by(&:version)
        down? ? migrations.reverse : migrations
      end
    end

    def pending_migrations
      already_migrated = migrated
      migrations.reject { |m| already_migrated.include?(m.version.to_i) }
    end

    def migrated
      @migrated_versions ||= self.class.get_all_versions
    end

    private
    def record_version_state_after_migrating(version)
      # table = Arel::Table.new(self.class.schema_migrations_table_name)

      @migrated_versions ||= []
      # if down?
      #   @migrated_versions.delete(version)
      #   table.where(table["version"].eq(version.to_s)).delete
      # else
      #   @migrated_versions.push(version).sort!
      #   table.insert table["version"] => version.to_s
      # end
      if down?
        @migrated_versions.delete(version)
        ::Mongoid::Migrations::DataMigration.where(:version => version.to_s).first.destroy
      else
        @migrated_versions.push(version).sort!
        ::Mongoid::Migrations::DataMigration.create(:version => version.to_s)
      end
    end

    def up?
      @direction == :up
    end

    def down?
      @direction == :down
    end

    # Wrap the migration in a transaction only if supported by the adapter.
    def ddl_transaction(&block)
      # if Base.connection.supports_ddl_transactions?
      #   Base.transaction { block.call }
      # else
      #   block.call
      # end
      block.call
    end
  end
end
