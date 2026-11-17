# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class SingularizeTest < Minitest::Test
  def test_users_becomes_user
    assert_equal("user", "users".singularize)
  end

  def test_companies_becomes_company
    assert_equal("company", "companies".singularize)
  end

  def test_statuses_becomes_status
    assert_equal("status", "statuses".singularize)
  end

  def test_news_stays_news
    assert_equal("news", "news".singularize)
  end

  def test_already_singular_stays_unchanged
    assert_equal("category", "category".singularize)
  end

  def test_addresses_becomes_address
    assert_equal("address", "addresses".singularize)
  end

  def test_releases_becomes_release
    assert_equal("release", "releases".singularize)
  end

  def test_project_releases_becomes_project_release
    assert_equal("project_release", "project_releases".singularize)
  end
end
