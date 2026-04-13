# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class FastSchemaDumperTest < Minitest::Test
  TABLES = %w[
    users posts comments profiles products
  ].freeze

  def setup
    setup_database_connection!
    @conn = ActiveRecord::Base.connection
    reset_test_tables!

    @conn.execute <<~SQL
      CREATE TABLE users (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) NOT NULL DEFAULT '',
        age INT UNSIGNED,
        score DECIMAL(10,2) DEFAULT '0.00',
        rating FLOAT DEFAULT '0',
        active TINYINT(1) NOT NULL DEFAULT 1,
        role TINYINT NOT NULL DEFAULT 0,
        bio TEXT,
        long_bio MEDIUMTEXT,
        metadata JSON,
        avatar BINARY(16),
        born_on DATE,
        login_at DATETIME,
        preferences VARCHAR(255) COLLATE utf8mb4_bin,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE INDEX index_users_on_email (email),
        INDEX index_users_on_name_and_age (name, age)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci COMMENT='User accounts'
    SQL

    @conn.execute <<~SQL
      CREATE TABLE posts (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id BIGINT NOT NULL,
        title VARCHAR(255) NOT NULL,
        body LONGTEXT,
        status SMALLINT NOT NULL DEFAULT 0,
        published_at DATETIME(6),
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX index_posts_on_user_id (user_id),
        INDEX index_posts_on_status_and_published_at (status, published_at),
        CONSTRAINT fk_posts_user FOREIGN KEY (user_id) REFERENCES users(id)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
    SQL

    @conn.execute <<~SQL
      CREATE TABLE comments (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        post_id BIGINT NOT NULL,
        user_id BIGINT NOT NULL,
        body TEXT NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX index_comments_on_post_id (post_id),
        CONSTRAINT fk_rails_comment_post FOREIGN KEY (post_id) REFERENCES posts(id),
        CONSTRAINT fk_rails_comment_user FOREIGN KEY (user_id) REFERENCES users(id)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
    SQL

    @conn.execute <<~SQL
      CREATE TABLE profiles (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id BIGINT NOT NULL,
        display_name VARCHAR(255),
        full_name VARCHAR(255) AS (CONCAT(display_name, ' (profile)')) VIRTUAL,
        slug VARCHAR(255) AS (LOWER(display_name)) STORED,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
    SQL

    @conn.execute <<~SQL
      CREATE TABLE products (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        price INT NOT NULL DEFAULT 0 COMMENT 'Price in cents',
        quantity INT NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT chk_products_price CHECK (price >= 0),
        CONSTRAINT chk_products_quantity CHECK (quantity >= 0)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci COMMENT='Product catalog'
    SQL
  end

  def teardown
    reset_test_tables!
  end

  def test_that_it_has_a_version_number
    refute_nil ::FastSchemaDumper::VERSION
  end

  def test_dump_basic_column_types
    output = dump_schema

    # string
    assert_match(/t\.string "name", limit: 100, null: false/, output)
    assert_match(/t\.string "email", default: "", null: false/, output)

    # integer (unsigned)
    assert_match(/t\.integer "age", unsigned: true/, output)

    # decimal
    assert_match(/t\.decimal "score", precision: 10, scale: 2/, output)

    # float
    assert_match(/t\.float "rating"/, output)

    # boolean
    assert_match(/t\.boolean "active", default: true, null: false/, output)

    # tinyint (non-boolean)
    assert_match(/t\.integer "role", limit: 1/, output)

    # text
    assert_match(/t\.text "bio"/, output)

    # mediumtext
    assert_match(/t\.text "long_bio", size: :medium/, output)

    # json
    assert_match(/t\.json "metadata"/, output)

    # binary
    assert_match(/t\.binary "avatar"/, output)

    # date
    assert_match(/t\.date "born_on"/, output)

    # datetime
    assert_match(/t\.datetime "login_at"/, output)

    # datetime with default CURRENT_TIMESTAMP
    assert_match(/t\.datetime "created_at",.*default: -> \{ "CURRENT_TIMESTAMP" \}, null: false/, output)
  end

  def test_dump_collation
    output = dump_schema
    assert_match(/t\.string "preferences".*collation: "utf8mb4_bin"/, output)
  end

  def test_dump_table_options
    output = dump_schema
    assert_match(/create_table "users".*charset: "utf8mb4".*collation: "utf8mb4_general_ci".*comment: "User accounts"/, output)
  end

  def test_dump_indexes
    output = dump_schema

    # unique index
    assert_match(/t\.index \["email"\], name: "index_users_on_email", unique: true/, output)

    # compound index
    assert_match(/t\.index \["name", "age"\], name: "index_users_on_name_and_age"/, output)
  end

  def test_dump_foreign_keys
    output = dump_schema

    assert_match(/add_foreign_key "posts", "users"/, output)
    assert_match(/add_foreign_key "comments", "posts"/, output)
    assert_match(/add_foreign_key "comments", "users"/, output)
  end

  def test_dump_longtext
    output = dump_schema
    assert_match(/t\.text "body", size: :long/, output)
  end

  def test_dump_smallint
    output = dump_schema
    assert_match(/t\.integer "status", limit: 2/, output)
  end

  def test_dump_datetime_precision
    output = dump_schema
    # DATETIME without fractional seconds outputs precision: nil
    assert_match(/t\.datetime "created_at", precision: nil/, output)
    # DATETIME(6) omits precision (6 is the default when fractional seconds are used)
    assert_match(/t\.datetime "published_at"/, output)
  end

  def test_dump_generated_columns
    output = dump_schema

    # VIRTUAL generated column
    assert_match(/t\.virtual "full_name", type: :string/, output)
    refute_match(/t\.virtual "full_name".*stored: true/, output)

    # STORED generated column
    assert_match(/t\.virtual "slug", type: :string.*stored: true/, output)
  end

  def test_dump_check_constraints
    output = dump_schema

    assert_match(/t\.check_constraint.*`price` >= 0/, output)
    assert_match(/t\.check_constraint.*`quantity` >= 0/, output)
  end

  def test_dump_table_comment
    output = dump_schema
    assert_match(/create_table "products".*comment: "Product catalog"/, output)
  end

  def test_dump_column_comment
    output = dump_schema
    assert_match(/t\.integer "price".*comment: "Price in cents"/, output)
  end

  def test_dump_excludes_internal_tables
    output = dump_schema
    refute_match(/ar_internal_metadata/, output)
    refute_match(/schema_migrations/, output)
  end

  def test_dump_complete_roundtrip
    output = dump_schema

    # Verify all test tables appear in the dump
    TABLES.each do |table|
      assert_match(/create_table "#{table}"/, output, "Expected table #{table} in dump output")
    end

    # Verify dump ends properly (foreign keys come after table definitions)
    assert_match(/^end\n\nadd_foreign_key/m, output)
  end

  private

  def dump_schema
    stream = StringIO.new
    FastSchemaDumper::SchemaDumper.dump(
      ActiveRecord::Base.connection_pool,
      stream,
      ActiveRecord::Base
    )
    stream.string
  end

  def reset_test_tables!
    @conn.execute "SET FOREIGN_KEY_CHECKS = 0"
    begin
      TABLES.each do |table|
        @conn.execute "DROP TABLE IF EXISTS #{table}"
      end
    ensure
      @conn.execute "SET FOREIGN_KEY_CHECKS = 1"
    end
  end
end
