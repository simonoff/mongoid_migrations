module Mongoid
  module Migrations
    class DataMigration
      include ::Mongoid::Document
      field :version
    end
  end
end
