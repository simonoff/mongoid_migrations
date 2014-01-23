# encoding: utf-8
module Mongoid
  # Specify whether or not to use timestamps for migration versions
  Config.module_eval do
    option :timestamped_migrations, default: true
    option :migrations_path, default: 'db/migrate'
  end
end