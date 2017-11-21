require "multiverse/generators"
require "multiverse/patches"
require "multiverse/railtie"
require "multiverse/version"

module Multiverse
  class << self
    attr_writer :db

    def db
      @db ||= ENV["DB"].presence
    end

    def db_dir
      db_dir = db ? "db/#{db}" : "db"
      abort "Unknown DB: #{db}" if db && !Dir.exist?(db_dir)
      db_dir
    end

    def parent_class_name
      if db
        "#{db.camelize}Record"
      elsif ActiveRecord::VERSION::MAJOR >= 5
        "ApplicationRecord"
      else
        "ActiveRecord::Base"
      end
    end

    def record_class
      if db
        record_class = parent_class_name.safe_constantize
        abort "Missing model: #{parent_class_name}" unless record_class
        record_class
      else
        ActiveRecord::Base
      end
    end

    def migrate_path
      "#{db_dir}/migrate"
    end

    def env(environment)
      db ? "#{db}_#{environment}" : environment
    end

    def db_configuration(environment = Rails.env)
      ActiveRecord::Base.configurations[env(environment)]
    end

    def db_overriden?
      db.present?
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend Multiverse::DatabaseTasks
  ActiveRecord::Migration.prepend Multiverse::Migration
  ActiveRecord::Migrator.prepend Multiverse::Migrator
  ActiveRecord::SchemaDumper.singleton_class.prepend Multiverse::SchemaDumper
end
