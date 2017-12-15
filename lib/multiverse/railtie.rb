require "rails/railtie"

module Multiverse
  class Railtie < Rails::Railtie
    generators do
      if ActiveRecord::VERSION::MAJOR >= 5
        require "rails/generators/active_record/migration"
        ActiveRecord::Generators::Migration.prepend(Multiverse::Generators::Migration)
      else
        require "rails/generators/migration"
        Rails::Generators::Migration.prepend(Multiverse::Generators::MigrationTemplate)
      end

      require "rails/generators/active_record/model/model_generator"
      ActiveRecord::Generators::ModelGenerator.prepend(Multiverse::Generators::ModelGenerator)
    end

    rake_tasks do
      namespace :db do
        task :load_config do
          ActiveRecord::Tasks::DatabaseTasks.migrations_paths = [Multiverse.migrate_path]
          ActiveRecord::Tasks::DatabaseTasks.db_dir = [Multiverse.db_dir]
          ActiveRecord::Tasks::DatabaseTasks.current_config = Multiverse.db_configuration
          ActiveRecord::Migrator.migrations_paths = [Multiverse.migrate_path] if ActiveRecord::VERSION::MAJOR < 5

          if Multiverse.db_overriden?
            # A lot of rails code explicitly uses ActiveRecord::Base.connection, so
            # we'll have to override it manually for the duration of this task.
            ActiveRecord::Base.establish_connection(Multiverse.db_configuration)
          end
        end

        namespace :test do
          task load_schema: %w(db:test:purge) do
            begin
              should_reconnect = ActiveRecord::Base.connection_pool.active_connection?
              ActiveRecord::Schema.verbose = false
              load_schema(ActiveRecord::Base.configurations[Multiverse.env("test")], :ruby, ENV["SCHEMA"])
            ensure
              if should_reconnect
                ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Multiverse.env(ActiveRecord::Tasks::DatabaseTasks.env)])
              end
            end
          end

          task load_structure: %w(db:test:purge) do
            load_schema(ActiveRecord::Base.configurations[Multiverse.env("test")], :sql, ENV["SCHEMA"])
          end

          task purge: %w(environment load_config) do
            Rake::Task['db:check_protected_environments'].invoke if ActiveRecord::VERSION::MAJOR >= 5
            ActiveRecord::Tasks::DatabaseTasks.purge ActiveRecord::Base.configurations[Multiverse.env("test")]
          end
        end
      end
    end

    def load_schema(config, format, file)
      if ActiveRecord::VERSION::MAJOR >= 5
        ActiveRecord::Tasks::DatabaseTasks.load_schema(config, format, file)
      else
        ActiveRecord::Tasks::DatabaseTasks.load_schema_for(config, format, file)
      end
    end
  end
end
