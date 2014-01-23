module Mongoid
  # Data migrations can manage the modification of data. It's a solution to the common problem of modifying
  # data between code revisions within a document oriented database.
  #
  # Example of simple migration for a system dependency:
  #
  #   class AddBaselineSurveySchema < Mongoid::Migration
  #     def self.up
  #       SurveySchema.create(:label => 'Baseline Survey')
  #     end
  #
  #     def self.down
  #       SurveySchema.where(:label => 'Baseline Survey').first.destroy
  #     end
  #   end
  #
  # == Timestamped Migrations
  #
  # By default, Rails generates migrations that look like:
  #
  #    20080717013526_your_migration_name.rb
  #
  # The prefix is a generation timestamp (in UTC).
  #
  # If you'd prefer to use numeric prefixes, you can turn timestamped migrations
  # off by setting:
  #
  #    Mongoid.config.timestamped_migrations = false
  #
  # In environment.rb.
  #
  class Migration
    @@verbose = true
    cattr_accessor :verbose

    class << self
      def up_with_benchmarks #:nodoc:
        migrate(:up)
      end

      def down_with_benchmarks #:nodoc:
        migrate(:down)
      end

      # Execute this migration in the named direction
      def migrate(direction)
        return unless respond_to?(direction)

        case direction
        when :up then
          announce "migrating"
        when :down then
          announce "reverting"
        end

        result = nil
        time = ::Benchmark.measure { result = send("#{direction}_without_benchmarks") }

        case direction
        when :up then
          announce "migrated (%.4fs)" % time.real; write
        when :down then
          announce "reverted (%.4fs)" % time.real; write
        end

        result
      end

      # Because the method added may do an alias_method, it can be invoked
      # recursively. We use @ignore_new_methods as a guard to indicate whether
      # it is safe for the call to proceed.
      def singleton_method_added(sym) #:nodoc:
        return if defined?(@ignore_new_methods) && @ignore_new_methods

        begin
          @ignore_new_methods = true

          case sym
          when :up, :down
            singleton_class.send(:alias_method_chain, sym, "benchmarks")
          end
        ensure
          @ignore_new_methods = false
        end
      end

      def write(text = '')
        puts(text) if verbose
      end

      def announce(message)
        version = defined?(@version) ? @version : nil

        text = "#{version} #{name}: #{message}"
        length = [0, 75 - text.length].max
        write "== %s %s" % [text, "=" * length]
      end

      def say(message, subitem=false)
        write "#{subitem ? "   ->" : "--"} #{message}"
      end

      def say_with_time(message)
        say(message)
        result = nil
        time = ::Benchmark.measure { result = yield }
        say "%.4fs" % time.real, :subitem
        say("#{result} rows", :subitem) if result.is_a?(::Integer)
        result
      end

      def suppress_messages
        save, self.verbose = verbose, false
        yield
      ensure
        self.verbose = save
      end

      def connection
        ::Mongoid.default_session
      end

      def method_missing(method, *arguments, &block)
        arg_list = arguments.map(&:inspect) * ', '

        say_with_time "#{method}(#{arg_list})" do
          # unless arguments.empty? || method == :execute
          #   arguments[0] = Migrator.proper_table_name(arguments.first)
          # end
          connection.send(method, *arguments, &block)
        end
      end
    end
  end

end