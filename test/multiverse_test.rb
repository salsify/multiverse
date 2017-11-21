require_relative "test_helper"

class MultiverseTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Multiverse::VERSION
  end

  def test_all
    gem_path = File.dirname(__dir__)
    clean = ENV["CLEAN"]

    Bundler.with_clean_env do
      FileUtils.rm_rf("/tmp/multiverse_app")
      Dir.mkdir("/tmp/multiverse_app")
      Dir.chdir("/tmp/multiverse_app") do
        # create Rails app
        open("Gemfile", "w") do |f|
          f.puts "source 'https://rubygems.org'"
          f.puts "gem 'rails', '#{rails_version}'"
        end
        cmd "bundle"
        cmd "bundle exec rails new . --force --skip-bundle"

        unless clean
          # add multiverse
          open("Gemfile", "a") do |f|
            f.puts "gem 'multiverse', path: '#{gem_path}'"
          end
        end

        # Must run `bundle update` to regenerate Gemfile.lock
        # after the rails dependencies were added
        cmd "bundle update"
        cmd "bundle"

        unless clean
          # generate new database
          cmd "bin/rails generate multiverse:db catalog"
        end

        # test create
        cmd "bin/rake db:create"
        assert database_exist?("development")
        assert database_exist?("test")
        assert !database_exist?("catalog_development")
        assert !database_exist?("catalog_test")

        unless clean
          cmd "DB=catalog bin/rake db:create"
          assert database_exist?("catalog_development")
          assert database_exist?("catalog_test")
        end

        # test rails generatde model
        cmd "bin/rails generate model User"
        assert_includes File.read("app/models/user.rb"), (rails5? ? "ApplicationRecord" : "ActiveRecord::Base")
        # TODO assert migration file in right directory

        unless clean
          cmd "DB=catalog bin/rails generate model Product"
          assert_includes File.read("app/models/product.rb"), "CatalogRecord"
        end
        # TODO assert migration file in right directory

        # test rails generate migration
        cmd "bin/rails generate migration create_posts"
        # TODO assert migration file in right directory, run on right DB

        unless clean
          cmd "DB=catalog bin/rails generate migration create_items"
          # TODO assert migration file in right directory, run on right DB
        end

        # test db:migrate
        cmd "bin/rake db:migrate"
        assert_tables("development", ["users", "posts"])

        unless clean
          cmd "DB=catalog bin/rake db:migrate"
          assert_tables("catalog_development", ["products", "items"])
        end

        # test db:migrate:status
        cmd "bin/rake db:migrate:status"

        unless clean
          cmd "DB=catalog bin/rake db:migrate:status"
        end

        # test db:rollback
        cmd "bin/rake db:rollback"
        assert_tables("development", ["users"])

        unless clean
          assert_tables("catalog_development", ["products", "items"])
          cmd "DB=catalog bin/rake db:rollback"
          assert_tables("catalog_development", ["products"])
        end

        # test db:drop
        cmd "bin/rake db:drop"
        assert !database_exist?("development")
        assert !database_exist?("test")

        unless clean
          cmd "DB=catalog bin/rake db:drop"
          assert !database_exist?("catalog_development")
          assert !database_exist?("catalog_test")
        end

        # test db:schema:load
        cmd "bin/rake db:create db:schema:load"
        assert_tables("development", ["users"])
        assert_tables("test", ["users"])

        unless clean
          cmd "DB=catalog bin/rake db:create db:schema:load"
          assert_tables("catalog_development", ["products"])
          assert_tables("catalog_test", ["products"])
        end

        # test db:test:prepare
        cmd "bin/rake db:drop db:create db:test:prepare"
        assert_tables("test", ["users"])

        unless clean
          cmd "DB=catalog bin/rake db:drop db:create db:test:prepare"
          assert_tables("catalog_test", ["products"])
        end
      end
    end
  end

  private

  def cmd(command)
    puts "> #{command}"
    assert system(command)
    puts
  end

  def rails_version
    ENV["RAILS_VERSION"] || "5.1.4"
  end

  def database_exist?(dbname)
    File.exist?("db/#{dbname}.sqlite3")
  end

  def assert_tables(dbname, tables)
    default_tables = rails5? ? ["ar_internal_metadata"] : []
    expected_tables = tables + default_tables + ["schema_migrations"]
    assert_equal expected_tables.sort, actual_tables(dbname).sort
  end

  def actual_tables(dbname)
    db = SQLite3::Database.new("db/#{dbname}.sqlite3")
    db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name != 'sqlite_sequence'").map(&:first)
  end

  def rails5?
    # should work until Rails 10 :)
    rails_version >= "5"
  end
end
