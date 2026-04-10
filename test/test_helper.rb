# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "fast_schema_dumper"
require "active_record"

require "minitest/autorun"

def mysql_available?
  ENV.key?("MYSQL_HOST")
end

def setup_database_connection!
  ActiveRecord::Base.establish_connection(
    adapter: "mysql2",
    host: ENV.fetch("MYSQL_HOST", "127.0.0.1"),
    port: ENV.fetch("MYSQL_PORT", 3306).to_i,
    username: ENV.fetch("MYSQL_USER", "root"),
    password: ENV.fetch("MYSQL_PASSWORD", ""),
    database: ENV.fetch("MYSQL_DATABASE", "fast_schema_dumper_test")
  )
end
