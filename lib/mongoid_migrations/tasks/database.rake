namespace :mongodb do
  unless Rake::Task.task_defined?("mongodb:drop")
    desc 'Drops all the collections for the database for the current Rails.env'
    task :drop => :environment do
      Mongoid.master.collections.each {|col| col.drop_indexes && col.drop unless ['system.indexes', 'system.users'].include?(col.name) }
    end
  end

  unless Rake::Task.task_defined?("mongodb:seed")
    # if another ORM has defined mongodb:seed, don't run it twice.
    desc 'Load the seed data from db/seeds.rb'
    task :seed => :environment do
      seed_file = File.join(Rails.application.root, 'db', 'seeds.rb')
      load(seed_file) if File.exist?(seed_file)
    end
  end

  unless Rake::Task.task_defined?("mongodb:setup")
    desc 'Create the database, and initialize with the seed data'
    task :setup => [ 'mongodb:create', 'mongodb:seed' ]
  end

  unless Rake::Task.task_defined?("mongodb:reseed")
    desc 'Delete data and seed'
    task :reseed => [ 'mongodb:drop', 'mongodb:seed' ]
  end

  unless Rake::Task.task_defined?("mongodb:create")
    task :create => :environment do
      # noop
    end
  end

  desc 'Current database version'
  task :version => :environment do
    puts Mongoid::Migrator.current_version.to_s
  end

  desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x. Turn off output with VERBOSE=false."
  task :migrate => :environment do
    ::Mongoid::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
    ::Mongoid::Migrator.migrate("db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end

  namespace :migrate do
    desc  'Rollback the database one migration and re migrate up. If you want to rollback more than one step, define STEP=x. Target specific version with VERSION=x.'
    task :redo => :environment do
      if ENV["VERSION"]
        Rake::Task["mongodb:migrate:down"].invoke
        Rake::Task["mongodb:migrate:up"].invoke
      else
        Rake::Task["mongodb:rollback"].invoke
        Rake::Task["mongodb:migrate"].invoke
      end
    end

    desc 'Resets your database using your migrations for the current environment'
    # should mongodb:create be changed to mongodb:setup? It makes more sense wanting to seed
    task :reset => ["mongodb:drop", "mongodb:create", "mongodb:migrate"]

    desc 'Runs the "up" for a given migration VERSION.'
    task :up => :environment do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version
      Mongoid::Migrator.run(:up, "db/migrate/", version)
    end

    desc 'Runs the "down" for a given migration VERSION.'
    task :down => :environment do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version
      Mongoid::Migrator.run(:down, "db/migrate/", version)
    end
  end

  desc 'Rolls the database back to the previous migration. Specify the number of steps with STEP=n'
  task :rollback => :environment do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    Mongoid::Migrator.rollback('db/migrate/', step)
  end

  namespace :schema do
    task :load do
      # noop
    end
  end

  namespace :test do
    task :prepare do
      # Stub out for MongoDB
    end
  end
end