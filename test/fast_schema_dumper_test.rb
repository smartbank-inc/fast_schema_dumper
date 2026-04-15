# frozen_string_literal: true

require "test_helper"
require "fast_schema_dumper/fast_dumper"

class FastSchemaDumperTest < Minitest::Test
  INTERNAL_TABLES = %w[
    ar_internal_metadata schema_migrations
  ].freeze

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
        full_name VARCHAR(255) AS (CONCAT(display_name, ' (profile)')) VIRTUAL COMMENT 'Profile display label',
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

  def test_dump_basic_column_types
    output = dump_schema

    # string
    assert_includes(output, 't.string "name", limit: 100, null: false')
    assert_includes(output, 't.string "email", default: "", null: false')
    # integer (unsigned)
    assert_includes(output, 't.integer "age", unsigned: true')
    # decimal
    assert_includes(output, 't.decimal "score", precision: 10, scale: 2')
    # float
    assert_includes(output, 't.float "rating"')
    # boolean
    assert_includes(output, 't.boolean "active", default: true, null: false')
    # tinyint (non-boolean)
    assert_includes(output, 't.integer "role", limit: 1')
    # text
    assert_includes(output, 't.text "bio"')
    # mediumtext
    assert_includes(output, 't.text "long_bio", size: :medium')
    # json
    assert_includes(output, 't.json "metadata"')
    # binary
    assert_includes(output, 't.binary "avatar"')
    # date
    assert_includes(output, 't.date "born_on"')
    # datetime
    assert_includes(output, 't.datetime "login_at"')
    # datetime with default CURRENT_TIMESTAMP
    assert_includes(output, 't.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false')
  end

  def test_dump_collation
    output = dump_schema
    assert_includes(output, 't.string "preferences", collation: "utf8mb4_bin"')
  end

  def test_dump_table_options
    output = dump_schema
    assert_includes(output, 'create_table "users", charset: "utf8mb4", collation: "utf8mb4_general_ci", comment: "User accounts", force: :cascade do |t|')
  end

  def test_dump_indexes
    output = dump_schema

    # unique index
    assert_includes(output, 't.index ["email"], name: "index_users_on_email", unique: true')
    # compound index
    assert_includes(output, 't.index ["name", "age"], name: "index_users_on_name_and_age"')
  end

  def test_dump_foreign_keys
    output = dump_schema

    assert_includes(output, 'add_foreign_key "posts", "users"')
    assert_includes(output, 'add_foreign_key "comments", "posts"')
    assert_includes(output, 'add_foreign_key "comments", "users"')
  end

  def test_dump_longtext
    output = dump_schema
    assert_includes(output, 't.text "body", size: :long')
  end

  def test_dump_smallint
    output = dump_schema
    assert_includes(output, 't.integer "status", limit: 2')
  end

  def test_dump_datetime_precision
    output = dump_schema
    # DATETIME without fractional seconds outputs precision: nil
    assert_includes(output, 't.datetime "created_at", precision: nil')
    # DATETIME(6) omits precision (6 is the default when fractional seconds are used)
    assert_includes(output, 't.datetime "published_at"')
  end

  def test_dump_generated_columns
    output = dump_schema
    full_name_definition = column_definition_for(output, "profiles", "full_name")

    # VIRTUAL generated column
    assert_includes(output, 't.virtual "full_name", type: :string, comment: "Profile display label", as:')
    refute_includes(full_name_definition, "stored: true")
    # STORED generated column
    assert_includes(output, 't.virtual "slug", type: :string, as: "lower(`display_name`)", stored: true')
  end

  def test_dump_check_constraints
    output = dump_schema

    assert_includes(output, 't.check_constraint "`price` >= 0", name: "chk_products_price"')
    assert_includes(output, 't.check_constraint "`quantity` >= 0", name: "chk_products_quantity"')
  end

  def test_dump_table_comment
    output = dump_schema
    assert_includes(output, 'create_table "products", charset: "utf8mb4", collation: "utf8mb4_general_ci", comment: "Product catalog", force: :cascade do |t|')
  end

  def test_dump_column_comment
    output = dump_schema
    assert_includes(output, 't.integer "price", default: 0, null: false, comment: "Price in cents"')
  end

  def test_dump_excludes_internal_tables
    create_internal_tables!
    output = dump_schema
    refute_includes(output, 'ar_internal_metadata')
    refute_includes(output, 'schema_migrations')
  ensure
    drop_internal_tables!
  end

  def test_dump_complete_roundtrip
    output = dump_schema

    # Verify all test tables appear in the dump
    TABLES.each do |table|
      assert_includes(output, %(create_table "#{table}"), "Expected table #{table} in dump output")
    end

    # Verify dump ends properly (foreign keys come after table definitions)
    assert_includes(output, "end\n\nadd_foreign_key")
  end

  def test_dump_matches_active_record_for_generated_column_definitions
    active_record_output = dump_active_record_schema
    fast_output = dump_schema

    %w[full_name slug].each do |column_name|
      expected = column_definition_for(active_record_output, "profiles", column_name)
      actual = column_definition_for(fast_output, "profiles", column_name)

      assert_equal expected, actual, <<~MSG
        Expected generated column profiles.#{column_name} to match ActiveRecord::SchemaDumper output
        expected: #{expected.inspect}
        actual:   #{actual.inspect}
      MSG
    end
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

  def dump_active_record_schema
    stream = StringIO.new
    ActiveRecord::SchemaDumper.dump(
      ActiveRecord::Base.connection_pool,
      stream,
      ActiveRecord::Base
    )
    stream.string
  end

  def column_definition_for(output, table_name, column_name)
    table_block = output[/^\s*create_table "#{table_name}".*?^\s*end$/m]
    raise "Could not find table #{table_name} in schema output" unless table_block

    definition = table_block.lines.find { |line| line.include?("\"#{column_name}\"") }
    raise "Could not find column #{table_name}.#{column_name} in schema output" unless definition

    definition.strip
  end

  def create_internal_tables!
    @conn.execute <<~SQL
      CREATE TABLE schema_migrations (
        version VARCHAR(255) NOT NULL PRIMARY KEY
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
    SQL

    @conn.execute <<~SQL
      CREATE TABLE ar_internal_metadata (
        `key` VARCHAR(255) NOT NULL PRIMARY KEY,
        value VARCHAR(255),
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci
    SQL
  end

  def drop_internal_tables!
    INTERNAL_TABLES.each do |table|
      @conn.execute "DROP TABLE IF EXISTS #{table}"
    end
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
