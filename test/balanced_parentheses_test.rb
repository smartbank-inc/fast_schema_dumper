# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class BalancedParenthesesTest < Minitest::Test
  def setup
    @dumper = FastSchemaDumper::SchemaDumper.new
  end

  def test_balanced_expression_returns_true
    assert(@dumper.send(:balanced_parentheses?, "(a > 0) and (b > 0)"))
  end

  def test_unmatched_open_paren_returns_false
    refute(@dumper.send(:balanced_parentheses?, "(a > 0"))
  end

  def test_expression_without_parens_returns_true
    assert(@dumper.send(:balanced_parentheses?, "a > 0"))
  end

  def test_nested_balanced_parens_returns_true
    assert(@dumper.send(:balanced_parentheses?, "((a))"))
  end

  def test_depth_goes_negative_returns_false
    refute(@dumper.send(:balanced_parentheses?, ")(a"))
  end

  def test_empty_string_returns_true
    assert(@dumper.send(:balanced_parentheses?, ""))
  end
end
