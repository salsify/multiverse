require "rails/railtie"

module Multiverse
  class Railtie < Rails::Railtie
    generators do
      require "rails/generators/active_record/migration"
      ActiveRecord::Generators::Migration.prepend(Multiverse::Generators::Migration)

      require "rails/generators/active_record/model/model_generator"
      ActiveRecord::Generators::ModelGenerator.prepend(Multiverse::Generators::ModelGenerator)
    end

    rake_tasks do
      namespace :db do
        task :load_config do
          ActiveRecord::Tasks::DatabaseTasks.migrations_paths = [Multiverse.migrate_path]
          ActiveRecord::Tasks::DatabaseTasks.db_dir = [Multiverse.db_dir]
        end
      end
    end
  end
end