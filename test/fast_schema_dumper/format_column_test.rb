# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class FormatColumnTest < Minitest::Test
  def setup
    @dumper = FastSchemaDumper::SchemaDumper.new
  end

  def base_column(overrides = {})
    {
      "COLUMN_NAME" => "name",
      "DATA_TYPE" => "varchar",
      "COLUMN_TYPE" => "varchar(255)",
      "EXTRA" => "",
      "COLUMN_DEFAULT" => nil,
      "COLUMN_COMMENT" => "",
      "IS_NULLABLE" => "YES",
      "CHARACTER_MAXIMUM_LENGTH" => 255,
      "NUMERIC_PRECISION" => nil,
      "NUMERIC_SCALE" => nil,
      "DATETIME_PRECISION" => nil,
      "COLLATION_NAME" => nil
    }.merge(overrides)
  end

  def test_varchar_255_produces_string_without_limit
    column = base_column
    actual = @dumper.send(:format_column, column)
    assert_equal('t.string "name"', actual)
  end

  def test_varchar_with_custom_limit
    column = base_column(
      "COLUMN_TYPE" => "varchar(100)",
      "CHARACTER_MAXIMUM_LENGTH" => 100
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.string "name", limit: 100', actual)
  end

  def test_tinyint_1_produces_boolean
    column = base_column(
      "COLUMN_NAME" => "active",
      "DATA_TYPE" => "tinyint",
      "COLUMN_TYPE" => "tinyint(1)",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.boolean "active"', actual)
  end

  def test_tinyint_non_boolean_produces_integer_with_limit_1
    column = base_column(
      "COLUMN_NAME" => "status",
      "DATA_TYPE" => "tinyint",
      "COLUMN_TYPE" => "tinyint(4)",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.integer "status", limit: 1', actual)
  end

  def test_smallint_produces_integer_with_limit_2
    column = base_column(
      "COLUMN_NAME" => "count",
      "DATA_TYPE" => "smallint",
      "COLUMN_TYPE" => "smallint",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.integer "count", limit: 2', actual)
  end

  def test_mediumint_produces_integer_with_limit_3
    column = base_column(
      "COLUMN_NAME" => "count",
      "DATA_TYPE" => "mediumint",
      "COLUMN_TYPE" => "mediumint",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.integer "count", limit: 3', actual)
  end

  def test_bigint_not_null_with_integer_default
    column = base_column(
      "COLUMN_NAME" => "user_id",
      "DATA_TYPE" => "bigint",
      "COLUMN_TYPE" => "bigint",
      "COLUMN_DEFAULT" => "0",
      "IS_NULLABLE" => "NO",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.bigint "user_id", default: 0, null: false', actual)
  end

  def test_decimal_with_precision_and_scale
    column = base_column(
      "COLUMN_NAME" => "price",
      "DATA_TYPE" => "decimal",
      "COLUMN_TYPE" => "decimal(10,2)",
      "NUMERIC_PRECISION" => 10,
      "NUMERIC_SCALE" => 2,
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.decimal "price", precision: 10, scale: 2', actual)
  end

  def test_datetime_with_precision_zero_includes_precision_nil
    column = base_column(
      "COLUMN_NAME" => "created_at",
      "DATA_TYPE" => "datetime",
      "COLUMN_TYPE" => "datetime",
      "DATETIME_PRECISION" => 0,
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_includes(actual, "precision: nil")
    assert_equal('t.datetime "created_at", precision: nil', actual)
  end

  def test_mediumtext_includes_size_medium
    column = base_column(
      "COLUMN_NAME" => "body",
      "DATA_TYPE" => "mediumtext",
      "COLUMN_TYPE" => "mediumtext",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.text "body", size: :medium', actual)
  end

  def test_longtext_includes_size_long
    column = base_column(
      "COLUMN_NAME" => "body",
      "DATA_TYPE" => "longtext",
      "COLUMN_TYPE" => "longtext",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.text "body", size: :long', actual)
  end

  def test_unsigned_column_includes_unsigned_true
    column = base_column(
      "COLUMN_NAME" => "count",
      "DATA_TYPE" => "int",
      "COLUMN_TYPE" => "int unsigned",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_includes(actual, "unsigned: true")
    assert_equal('t.integer "count", unsigned: true', actual)
  end

  def test_column_with_comment
    column = base_column(
      "COLUMN_NAME" => "email",
      "COLUMN_COMMENT" => "user email"
    )
    actual = @dumper.send(:format_column, column)
    assert_includes(actual, 'comment: "user email"')
    assert_equal('t.string "email", comment: "user email"', actual)
  end

  def test_not_null_column
    column = base_column(
      "IS_NULLABLE" => "NO"
    )
    actual = @dumper.send(:format_column, column)
    assert_includes(actual, "null: false")
    assert_equal('t.string "name", null: false', actual)
  end

  def test_utf8mb4_bin_collation_includes_collation
    column = base_column(
      "DATA_TYPE" => "varchar",
      "COLUMN_TYPE" => "varchar(255)",
      "COLLATION_NAME" => "utf8mb4_bin"
    )
    actual = @dumper.send(:format_column, column)
    assert_includes(actual, 'collation: "utf8mb4_bin"')
    assert_equal('t.string "name", collation: "utf8mb4_bin"', actual)
  end

  def test_format_generated_column
    column = base_column(
      "COLUMN_NAME" => "active_unique_key",
      "DATA_TYPE" => "int",
      "COLUMN_TYPE" => "int",
      "EXTRA" => "STORED GENERATED",
      "GENERATION_EXPRESSION" => "if((`deleted_at` is null),1,NULL)",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal(
      't.virtual "active_unique_key", type: :integer, as: "if((`deleted_at` is null),1,NULL)", stored: true',
      actual
    )
  end

  def test_format_generated_column_with_comment
    column = base_column(
      "COLUMN_NAME" => "full_name",
      "EXTRA" => "VIRTUAL GENERATED",
      "GENERATION_EXPRESSION" => "concat(`first_name`,`last_name`)",
      "COLUMN_COMMENT" => "generated name"
    )
    actual = @dumper.send(:format_column, column)
    assert_equal(
      't.virtual "full_name", type: :string, comment: "generated name", as: "concat(`first_name`,`last_name`)"',
      actual
    )
  end

  def test_format_stored_generated_column_with_comment_matches_rails_order
    column = base_column(
      "COLUMN_NAME" => "active_unique_key",
      "DATA_TYPE" => "int",
      "COLUMN_TYPE" => "int",
      "EXTRA" => "STORED GENERATED",
      "GENERATION_EXPRESSION" => "if((`deleted_at` is null),1,NULL)",
      "COLUMN_COMMENT" => "generated discriminator",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal(
      't.virtual "active_unique_key", type: :integer, comment: "generated discriminator", as: "if((`deleted_at` is null),1,NULL)", stored: true',
      actual
    )
  end

  def test_generated_column_detection_does_not_match_default_generated
    column = base_column(
      "COLUMN_NAME" => "created_at",
      "DATA_TYPE" => "datetime",
      "COLUMN_TYPE" => "datetime",
      "EXTRA" => "DEFAULT_GENERATED",
      "COLUMN_DEFAULT" => "CURRENT_TIMESTAMP",
      "IS_NULLABLE" => "NO",
      "CHARACTER_MAXIMUM_LENGTH" => nil
    )
    actual = @dumper.send(:format_column, column)
    assert_equal('t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false', actual)
  end
end
