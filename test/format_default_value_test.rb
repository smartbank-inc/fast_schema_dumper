# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class FormatDefaultValueTest < Minitest::Test
  def setup
    @dumper = FastSchemaDumper::SchemaDumper.new
  end

  def test_nil_input_returns_nil
    actual = @dumper.send(:format_default_value, nil, "varchar")
    assert_nil(actual)
  end

  def test_null_string_returns_nil
    actual = @dumper.send(:format_default_value, "NULL", "varchar")
    assert_nil(actual)
  end

  def test_boolean_true_for_tinyint_1
    actual = @dumper.send(:format_default_value, "1", "tinyint", "tinyint(1)")
    assert_equal("true", actual)
  end

  def test_boolean_false_for_tinyint_1
    actual = @dumper.send(:format_default_value, "0", "tinyint", "tinyint(1)")
    assert_equal("false", actual)
  end

  def test_string_default_for_varchar
    actual = @dumper.send(:format_default_value, "hello", "varchar")
    assert_equal('"hello"', actual)
  end

  def test_integer_default_for_int
    actual = @dumper.send(:format_default_value, "42", "int")
    assert_equal("42", actual)
  end

  def test_current_timestamp_for_datetime
    actual = @dumper.send(:format_default_value, "CURRENT_TIMESTAMP", "datetime")
    assert_equal('-> { "CURRENT_TIMESTAMP" }', actual)
  end

  def test_datetime_string_default
    actual = @dumper.send(:format_default_value, "2024-01-01 00:00:00", "datetime")
    assert_equal('"2024-01-01 00:00:00"', actual)
  end

  def test_decimal_default
    actual = @dumper.send(:format_default_value, "3.14", "decimal")
    assert_equal(BigDecimal("3.14").to_s.inspect, actual)
  end

  def test_float_default
    actual = @dumper.send(:format_default_value, "1.5", "float")
    assert_equal("1.5", actual)
  end

  def test_json_empty_array_default
    actual = @dumper.send(:format_default_value, "'[]'", "json")
    assert_equal("[]", actual)
  end

  def test_json_non_array_default_returns_empty_hash
    actual = @dumper.send(:format_default_value, "'{}' ", "json")
    assert_equal("{}", actual)
  end
end
