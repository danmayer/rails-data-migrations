require 'rake'

namespace :data do
  def migrations_path
    RailsDataMigrations::Migrator.migrations_path
  end

  def apply_single_migration(direction, version)
    raise 'VERSION is required' unless version
    RailsDataMigrations::Migrator.run(direction, migrations_path, version.to_i)
  end

  task init_migration: :environment do
    RailsDataMigrations::LogEntry.create_table
  end

  desc 'Apply pending data migrations'
  task migrate: :init_migration do
    filter = RailsDataMigrations::Migrator.current_version
    versions = RailsDataMigrations::Migrator.migrations(migrations_path)
                 .select { |migration| migration.version > filter }
                 .map(&:version)
    versions.sort.each do |version|
      apply_single_migration(:up, version)
    end
  end

  namespace :migrate do
    desc 'Apply single data migration using VERSION'
    task up: :init_migration do
      apply_single_migration(:up, ENV['VERSION'])
    end

    desc 'Revert single data migration using VERSION'
    task down: :init_migration do
      apply_single_migration(:down, ENV['VERSION'])
    end

    desc 'Skip single data migration using VERSION'
    task skip: :init_migration do
      version = ENV['VERSION'].to_i
      raise 'VERSION is required' unless version > 0
      if RailsDataMigrations::LogEntry.where(version: version).any?
        puts "data migration #{version} was already applied."
      else
        RailsDataMigrations::LogEntry.create!(version: version)
        puts "data migration #{version} was skipped."
      end
    end
  end
end