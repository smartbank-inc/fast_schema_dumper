# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class FormatIndexTest < Minitest::Test
  def setup
    @dumper = FastSchemaDumper::SchemaDumper.new
  end

  def test_single_column_non_unique
    index_data = {columns: ["email"], unique: false, orders: {}, comment: ""}
    actual = @dumper.send(:format_index, "index_users_on_email", index_data)
    assert_equal('t.index ["email"], name: "index_users_on_email"', actual)
  end

  def test_single_column_unique
    index_data = {columns: ["email"], unique: true, orders: {}, comment: ""}
    actual = @dumper.send(:format_index, "index_users_on_email", index_data)
    assert_includes(actual, "unique: true")
    assert_equal('t.index ["email"], name: "index_users_on_email", unique: true', actual)
  end

  def test_compound_columns
    index_data = {columns: ["a", "b"], unique: false, orders: {}, comment: ""}
    actual = @dumper.send(:format_index, "index_on_a_and_b", index_data)
    assert_equal('t.index ["a", "b"], name: "index_on_a_and_b"', actual)
  end

  def test_single_column_with_desc_order
    index_data = {columns: ["name"], unique: false, orders: {"name" => :desc}, comment: ""}
    actual = @dumper.send(:format_index, "index_users_on_name", index_data)
    assert_includes(actual, "order: :desc")
    assert_equal('t.index ["name"], name: "index_users_on_name", order: :desc', actual)
  end

  def test_compound_with_desc_order_on_one_column
    index_data = {columns: ["a", "b"], unique: false, orders: {"a" => :desc}, comment: ""}
    actual = @dumper.send(:format_index, "index_on_a_and_b", index_data)
    assert_includes(actual, "order: { a: :desc }")
    assert_equal('t.index ["a", "b"], name: "index_on_a_and_b", order: { a: :desc }', actual)
  end

  def test_with_non_empty_comment
    index_data = {columns: ["email"], unique: false, orders: {}, comment: "user email index"}
    actual = @dumper.send(:format_index, "index_users_on_email", index_data)
    assert_includes(actual, 'comment: "user email index"')
    assert_equal('t.index ["email"], name: "index_users_on_email", comment: "user email index"', actual)
  end

  def test_with_empty_comment_adds_no_comment
    index_data = {columns: ["email"], unique: false, orders: {}, comment: ""}
    actual = @dumper.send(:format_index, "index_users_on_email", index_data)
    refute_includes(actual, "comment:")
  end

  def test_expression_index
    index_data = {
      columns: [],
      parts: [{expression: "lower(`name`)", desc: false}],
      unique: false, orders: {}, comment: ""
    }
    actual = @dumper.send(:format_index, "index_events_on_lower_name", index_data)
    assert_equal('t.index "(lower(`name`))", name: "index_events_on_lower_name"', actual)
  end

  def test_expression_index_unescapes_quotes
    # INFORMATION_SCHEMA.STATISTICS escapes ' as \' in EXPRESSION values
    index_data = {
      columns: [],
      parts: [{expression: "cast(json_unquote(json_extract(`payload`,_utf8mb4\\'$.type\\')) as char(10) charset utf8mb4)", desc: false}],
      unique: false, orders: {}, comment: ""
    }
    actual = @dumper.send(:format_index, "index_events_on_payload_type", index_data)
    assert_equal(%q{t.index "(cast(json_unquote(json_extract(`payload`,_utf8mb4'$.type')) as char(10) charset utf8mb4))", name: "index_events_on_payload_type"}, actual)
  end

  def test_expression_index_already_parenthesized_is_not_double_wrapped
    index_data = {
      columns: [],
      parts: [{expression: "(`price` + `tax`)", desc: false}],
      unique: false, orders: {}, comment: ""
    }
    actual = @dumper.send(:format_index, "index_on_total", index_data)
    assert_equal('t.index "(`price` + `tax`)", name: "index_on_total"', actual)
  end

  def test_expression_index_with_desc_and_plain_column
    # Rails inlines DESC in the string instead of emitting an order: option
    index_data = {
      columns: ["name"],
      parts: [
        {expression: "month(`starts_at`)", desc: true},
        {column: "name", sub_part: nil, desc: false}
      ],
      unique: true, orders: {}, comment: ""
    }
    actual = @dumper.send(:format_index, "index_events_on_month_and_name", index_data)
    assert_equal('t.index "(month(`starts_at`)) DESC, `name`", name: "index_events_on_month_and_name", unique: true', actual)
  end

  def test_expression_index_with_sub_part_column
    index_data = {
      columns: ["bio"],
      parts: [
        {expression: "lower(`name`)", desc: false},
        {column: "bio", sub_part: 10, desc: false}
      ],
      unique: false, orders: {}, comment: ""
    }
    actual = @dumper.send(:format_index, "index_on_lower_name_and_bio", index_data)
    assert_equal('t.index "(lower(`name`)), `bio`(10)", name: "index_on_lower_name_and_bio"', actual)
  end

  def test_expression_index_escapes_backticks_in_plain_column
    index_data = {
      columns: ["display`name"],
      parts: [
        {expression: "lower(`name`)", desc: false},
        {column: "display`name", sub_part: nil, desc: false}
      ],
      unique: false, orders: {}, comment: ""
    }
    actual = @dumper.send(:format_index, "index_on_lower_name_and_display_name", index_data)
    assert_equal('t.index "(lower(`name`)), `display``name`", name: "index_on_lower_name_and_display_name"', actual)
  end

  def test_expression_index_with_comment
    index_data = {
      columns: [],
      parts: [{expression: "lower(`name`)", desc: false}],
      unique: false, orders: {}, comment: "case-insensitive lookup"
    }
    actual = @dumper.send(:format_index, "index_events_on_lower_name", index_data)
    assert_equal('t.index "(lower(`name`))", name: "index_events_on_lower_name", comment: "case-insensitive lookup"', actual)
  end

  def test_plain_index_with_parts_key_keeps_array_format
    index_data = {
      columns: ["email"],
      parts: [{column: "email", sub_part: nil, desc: false}],
      unique: false, orders: {}, comment: ""
    }
    actual = @dumper.send(:format_index, "index_users_on_email", index_data)
    assert_equal('t.index ["email"], name: "index_users_on_email"', actual)
  end
end
