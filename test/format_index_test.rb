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
end
