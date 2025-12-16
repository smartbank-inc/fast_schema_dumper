require "erb"
require "active_record"
require "active_record/database_configurations"

require_relative "fast_dumper"

module FastSchemaDumper
  class CLI
    def self.run(...)
      new.run(...)
    end

    def run(argv)
      env = ENV["RAILS_ENV"] || "development"

      database_yml_path = File.join(Dir.pwd, "config", "database.yml")
      database_yml = Psych.safe_load(ERB.new(File.read(database_yml_path)).result, aliases: true)
      config = database_yml[env]
      # Override pool size to 1 for faster startup
      config["pool"] = 1

      # Prepare the ActiveRecord connection configuration
      hash_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(env, "primary", config)
      ActiveRecord::Base.establish_connection(hash_config)

      SchemaDumper.dump

      0
    end
  end
end
