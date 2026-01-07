require_relative 'fast_dumper'

# Loading this file will overwrite `Ridgepole::Dumper.dump`.

# This file must be loaded after the ridgepole gem is loaded.
raise "Ridgepole is not defined. Require ridgepole before loading this file." if !defined?(Ridgepole)

module Ridgepole
  class Dumper
    alias_method :original_dump, :dump

    def dump
      case ENV['FAST_SCHEMA_DUMPER_MODE']
      in 'disabled'
        original_dump
      in 'verify'
        puts "Warning: fast_schema_dumper is enabled in verify mode" unless ENV['FAST_SCHEMA_DUMPER_SUPPRESS_MESSAGE'] == '1'
        original_results = original_dump
        fast_results = fast_dump
        File.write("orig.txt", original_results)
        File.write("fast.txt", fast_results)
        if original_results != fast_results
          raise "Dumped schema do not match between ActiveRecord::SchemaDumper and fast_schema_dumper. This is a fast_schema_dumper bug."
        end
        fast_results
      else
        puts "Warning: fast_schema_dumper is enabled" unless ENV['FAST_SCHEMA_DUMPER_SUPPRESS_MESSAGE'] == '1'
        fast_dump
      end
    end

    def fast_dump
      s = StringIO.new
      FastSchemaDumper::SchemaDumper.dump(ActiveRecord::Base.connection_pool, s)
      s.rewind
      s.read
    end
  end
end
