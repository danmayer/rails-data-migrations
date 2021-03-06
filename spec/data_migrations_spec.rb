require 'spec_helper'

describe RailsDataMigrations do
  it 'checks for migration log table existence' do
    expect(ActiveRecord::Base.connection.data_source_exists?(RailsDataMigrations::LogEntry.table_name)).to be_truthy
    expect(RailsDataMigrations::Migrator.get_all_versions).to be_blank
  end

  it 'has no migrations at the start' do
    expect(RailsDataMigrations::Migrator.current_version).to eq(0)
    expect(RailsDataMigrations::LogEntry.count).to eq(0)
  end

  context 'generator' do
    let (:migration_name) { 'test_migration' }

    let (:file_name) { 'spec/db/data-migrations/20161031000000_test_migration.rb' }

    before(:each) do
      allow(Time).to receive(:now).and_return(Time.utc(2016, 10, 31))
      Rails::Generators.invoke('data_migration', [migration_name])
    end

    it 'creates non-empty migration file' do
      expect(File.exist?(file_name)).to be_truthy
      expect(File.size(file_name)).to be > 0
    end

    it 'creates valid migration class' do
      eval(File.open(file_name).read)
      klass = migration_name.classify.constantize
      expect(klass.superclass).to eq(ActiveRecord::DataMigration)
      expect(klass.instance_methods(false)).to eq([:up])
    end
  end

  context 'migrator' do
    before(:each) do
      allow(Time).to receive(:now).and_return(Time.utc(2016, 11, 01, 02, 03, 04))

      Rails::Generators.invoke('data_migration', ['test'])
    end

    def load_rake_rasks
      load File.expand_path('../../lib/tasks/data_migrations.rake', __FILE__)
      Rake::Task.define_task(:environment)
    end

    it 'list pending migrations' do
      expect(RailsDataMigrations::Migrator.migrations(RailsDataMigrations::Migrator.migrations_path).size).to eq(1)
    end

    it 'applies pending migrations only once' do
      expect(RailsDataMigrations::LogEntry.count).to eq(0)

      load_rake_rasks

      2.times do
        Rake::Task['data:migrate'].execute
        expect(RailsDataMigrations::Migrator.current_version).to eq(20161101020304)
        expect(RailsDataMigrations::LogEntry.count).to eq(1)
      end
    end

    it 'requires VERSION to run a single migration' do
      ENV['VERSION'] = nil

      load_rake_rasks

      expect { Rake::Task['data:migrate:up'].execute}.to raise_error(RuntimeError, 'VERSION is required')
      expect { Rake::Task['data:migrate:down'].execute}.to raise_error(RuntimeError, 'VERSION is required')
    end

    it 'applies single migration by its VERSION' do
      expect(RailsDataMigrations::LogEntry.count).to eq(0)

      ENV['VERSION'] = '20161101020304'
      load_rake_rasks

      2.times do
        Rake::Task['data:migrate:up'].execute
        expect(RailsDataMigrations::Migrator.current_version).to eq(ENV['VERSION'].to_i)
        expect(RailsDataMigrations::LogEntry.count).to eq(1)
      end
    end
  end
end
