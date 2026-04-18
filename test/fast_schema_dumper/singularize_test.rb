# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class SingularizeTest < Minitest::Test
  def setup
    @dumper = FastSchemaDumper::SchemaDumper.new
  end

  def test_users_becomes_user
    assert_equal("user", @dumper.send(:singularize, "users"))
  end

  def test_companies_becomes_company
    assert_equal("company", @dumper.send(:singularize, "companies"))
  end

  def test_statuses_becomes_status
    assert_equal("status", @dumper.send(:singularize, "statuses"))
  end

  def test_news_stays_news
    assert_equal("news", @dumper.send(:singularize, "news"))
  end

  def test_already_singular_stays_unchanged
    assert_equal("category", @dumper.send(:singularize, "category"))
  end

  def test_addresses_becomes_address
    assert_equal("address", @dumper.send(:singularize, "addresses"))
  end
end
