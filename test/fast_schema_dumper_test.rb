# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class FastSchemaDumperTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::FastSchemaDumper::VERSION
  end
end
