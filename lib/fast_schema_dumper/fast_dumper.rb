require 'json'
require 'bigdecimal'

module FastSchemaDumper
  class SchemaDumper
    class << self
      def dump(pool = ActiveRecord::Base.connection_pool, stream = $stdout, config = ActiveRecord::Base)
        new.dump(pool, stream, config)
      end
    end

    def dump(pool = ActiveRecord::Base.connection_pool, stream = $stdout, config = ActiveRecord::Base)
      conn = ActiveRecord::Base.connection

      @output = []

      # Get all tables (excluding ar_internal_metadata and schema_migrations)
      tables = conn.exec_query("
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_TYPE = 'BASE TABLE'
          AND TABLE_NAME NOT IN ('ar_internal_metadata', 'schema_migrations')
        ORDER BY TABLE_NAME
      ").map { |row| row['TABLE_NAME'] }

      # Get all columns
      columns_data = conn.exec_query("
      select
          TABLE_NAME
          , COLUMN_NAME
          , ORDINAL_POSITION
          , COLUMN_DEFAULT
          , IS_NULLABLE
          , DATA_TYPE
          , CHARACTER_MAXIMUM_LENGTH
          , NUMERIC_PRECISION
          , NUMERIC_SCALE
          , COLUMN_TYPE
          , EXTRA
          , COLUMN_COMMENT
          , DATETIME_PRECISION
          , COLLATION_NAME
      from INFORMATION_SCHEMA.COLUMNS
      where
          TABLE_SCHEMA = database()
      order by TABLE_NAME, ORDINAL_POSITION
    ")

      # Get all indexes
      indexes_data = conn.exec_query("
      SELECT
        s.TABLE_NAME,
        s.INDEX_NAME,
        s.NON_UNIQUE,
        s.COLUMN_NAME,
        s.SEQ_IN_INDEX,
        s.INDEX_COMMENT,
        s.COLLATION
      FROM INFORMATION_SCHEMA.STATISTICS s
      WHERE s.TABLE_SCHEMA = DATABASE()
      ORDER BY s.TABLE_NAME, s.INDEX_NAME, s.SEQ_IN_INDEX
    ")

      # Aggregate table information
      # Organize indexes by table
      indexes_by_table = indexes_data.each_with_object({}) do |idx, hash|
        hash[idx['TABLE_NAME']] ||= {}
        hash[idx['TABLE_NAME']][idx['INDEX_NAME']] ||= {
          columns: [],
          unique: idx['NON_UNIQUE'] == 0,
          # length
          orders: {},
          # opclass
          # where
          # using
          # include
          # nulls_not_distinct
          # type
          comment: idx['INDEX_COMMENT']
          # enabled
        }
        hash[idx['TABLE_NAME']][idx['INDEX_NAME']][:columns] << idx['COLUMN_NAME']
        # Track descending order columns (COLLATION = 'D')
        if idx['COLLATION'] == 'D'
          hash[idx['TABLE_NAME']][idx['INDEX_NAME']][:orders][idx['COLUMN_NAME']] = :desc
        end
      end

      # Get table options
      table_options = conn.exec_query("
      SELECT
        TABLE_NAME,
        TABLE_COLLATION,
        TABLE_COMMENT
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_TYPE = 'BASE TABLE'
    ").each_with_object({}) do |row, hash|
        hash[row['TABLE_NAME']] = {
          collation: row['TABLE_COLLATION'],
          comment: row['TABLE_COMMENT']
        }
      end

      # Get foreign keys
      foreign_keys_data = conn.exec_query("
      SELECT
        kcu.TABLE_NAME,
        kcu.CONSTRAINT_NAME,
        kcu.COLUMN_NAME,
        kcu.REFERENCED_TABLE_NAME,
        kcu.REFERENCED_COLUMN_NAME,
        rc.DELETE_RULE,
        rc.UPDATE_RULE
      FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
      JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
        ON kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA
        AND kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME
      WHERE kcu.TABLE_SCHEMA = DATABASE()
        AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
      ORDER BY kcu.TABLE_NAME, kcu.CONSTRAINT_NAME
    ")

      # Get CHECK constraints (MySQL 8.0.16+)
      result = conn.exec_query("
      SELECT COUNT(*) as count
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_SCHEMA = 'information_schema'
        AND TABLE_NAME = 'CHECK_CONSTRAINTS'
    ")
      check_constraints_data = if result.first['count'] > 0
        conn.exec_query("
        SELECT
          tc.CONSTRAINT_NAME,
          tc.TABLE_NAME,
          cc.CHECK_CLAUSE
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc
          ON tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA
          AND tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
        WHERE tc.TABLE_SCHEMA = DATABASE()
          AND tc.CONSTRAINT_TYPE = 'CHECK'
        ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_NAME
      ")
      else
        []
      end

      check_constraints_by_table = check_constraints_data.each_with_object({}) do |ck, hash|
        hash[ck['TABLE_NAME']] ||= []
        hash[ck['TABLE_NAME']] << {
          constraint_name: ck['CONSTRAINT_NAME'],
          check_clause: ck['CHECK_CLAUSE']
        }
      end

      # Organize columns by table
      columns_by_table = columns_data.each_with_object({}) do |col, hash|
        hash[col['TABLE_NAME']] ||= []
        hash[col['TABLE_NAME']] << col
      end

      # Generate schema for each table
      tables.each do |table_name|
        dump_table(
          table_name,
          columns: columns_by_table[table_name] || [],
          indexes: indexes_by_table[table_name] || {},
          check_constraints: check_constraints_by_table[table_name] || {},
          options: table_options[table_name]
        )
        @output << ""
      end

      # Remove trailing empty line
      @output.pop if @output.last == ""

      @output << ""

      # Foreign keys
      # ordered by table_name and constraint_name

      foreign_keys_by_table = foreign_keys_data.each_with_object({}) do |fk, hash|
        hash[fk['TABLE_NAME']] ||= {}
        hash[fk['TABLE_NAME']][fk['CONSTRAINT_NAME']] ||= {
          column: fk['COLUMN_NAME'],
          referenced_table: fk['REFERENCED_TABLE_NAME'],
          referenced_column: fk['REFERENCED_COLUMN_NAME'],
          constraint_name: fk['CONSTRAINT_NAME']
        }
      end

      all_foreign_keys = []
      foreign_keys_by_table.each do |table_name, foreign_keys|
        foreign_keys.each do |constraint_name, fk_data|
          all_foreign_keys << {
            table_name: table_name,
            constraint_name: constraint_name,
            fk_data: fk_data
          }
        end
      end

      # Sort by table_name first, then by referenced_table name, then by column name
      all_foreign_keys.sort_by { |fk| [fk[:table_name], fk[:fk_data][:referenced_table], fk[:fk_data][:column]] }.each do |fk|
        fk_line = "add_foreign_key \"#{fk[:table_name]}\", \"#{fk[:fk_data][:referenced_table]}\""

        # Determine if we need column: or name: option
        # Rails tries to infer the column name from the table name
        # For simple cases: "users" -> "user_id"
        # But it also handles more complex cases

        inferred_column = "#{singularize(fk[:fk_data][:referenced_table])}_id"

        # Check if column name matches what Rails would infer
        if fk[:fk_data][:column] != inferred_column
          # Column name is custom, need to specify it
          fk_line += ", column: \"#{fk[:fk_data][:column]}\""
        elsif !fk[:fk_data][:constraint_name].start_with?("fk_rails_")
          # Column matches default, check if constraint name is custom
          # Rails generates constraint names starting with "fk_rails_"
          fk_line += ", name: \"#{fk[:fk_data][:constraint_name]}\""
        end

        @output << fk_line
      end

      stream.print @output.join("\n")
    end

    private

    def escape_string(str)
      str.gsub("\\", "\\\\\\\\").gsub('"', '\"').gsub("\n", "\\n").gsub("\r", "\\r").gsub("\t", "\\t")
    end

    def singularize(str)
      # Simple singularization rules
      case str
      when 'news'
        'news'  # news is both singular and plural
      when /ies$/
        str.sub(/ies$/, 'y')
      when /ses$/
        str.sub(/es$/, '')
      when /s$/
        str.sub(/s$/, '')
      else
        str
      end
    end

    def dump_table(table_name, columns:, indexes:, check_constraints:, options:)
      table_def = "create_table \"#{table_name}\""

      # id (primary key)
      primary_key = indexes.delete('PRIMARY')
      if primary_key && primary_key[:columns].size == 1 && primary_key[:columns].first == 'id'
        id_column = columns.find { |c| c['COLUMN_NAME'] == 'id' }
        if id_column
          id_options = []

          needs_id_options = false

          # type
          if id_column['DATA_TYPE'] != 'bigint'
            id_options << "type: :#{id_column['DATA_TYPE']}"
            needs_id_options = true
          end

          # comment
          if id_column['COLUMN_COMMENT'] && !id_column['COLUMN_COMMENT'].empty?
            id_options << "comment: \"#{escape_string(id_column['COLUMN_COMMENT'])}\""
            needs_id_options = true
          end

          # unsigned
          if id_column['COLUMN_TYPE'].include?('unsigned')
            id_options << "unsigned: true"
            needs_id_options = true
          end

          # type
          if needs_id_options && id_column['DATA_TYPE'] == 'bigint'
            id_options.unshift("type: :bigint")
          end

          table_def += ", id: { #{id_options.join(', ')} }" if needs_id_options
        end
      elsif primary_key.nil? || (primary_key && primary_key[:columns].first != 'id')
        table_def += ", id: false"
      end

      # charset, collation
      if options && options[:collation]
        charset = options[:collation].split('_').first
        table_def += ", charset: \"#{charset}\""
        table_def += ", collation: \"#{options[:collation]}\""
      end

      # comment
      if options && options[:comment] && !options[:comment].empty?
        table_def += ", comment: \"#{escape_string(options[:comment])}\""
      end

      table_def += ", force: :cascade do |t|"
      @output << table_def

      # columns
      columns.reject { |c| c['COLUMN_NAME'] == 'id' }.each do |column|
        @output << "  #{format_column(column)}"
      end

      # Indexes
      # Rails orders indexes lexicographically by their column arrays
      # Example: ["a", "b"] < ["a"] < ["b", "c"] < ["b"] < ["d"]
      sorted_indexes = indexes.except('PRIMARY').sort_by do |index_name, index_data|
        # Create an array padded with high values for comparison
        # This ensures that missing columns sort after existing ones
        max_cols = indexes.values.map { |data| data[:columns].size }.max || 1
        cols = index_data[:columns].dup
        # Pad with a string that sorts after any real column name
        cols += ["\xFF" * 100] * (max_cols - cols.size)
        cols
      end

      sorted_indexes.each do |index_name, index_data|
        @output << "  #{format_index(index_name, index_data)}"
      end

      # Respect the CHECK constraint
      #
      # NOTE: original dumper sorts it according to the clause
      # ref: https://github.com/rails/rails/blob/cddcba97c369e12e2573af5af9eda16e6f530a29/activerecord/lib/active_record/schema_dumper.rb#L284
      check_constraints.sort_by { |c| c[:check_clause] }.each do |constraint|
        check_clause = constraint[:check_clause]

        # drop redundant parentheses at the most outer level for compatibility with the original dumper
        # Example: "((a > 0) and (b > 0))" => "(a > 0) and (b > 0)"
        if check_clause.start_with?("(") && check_clause.end_with?(")")
          # Check if removing outer parens would break the expression by ensuring parentheses are balanced after removal
          # For example, it shouldn’t remove the outer parentheses as in the following case, because doing so would break the balance: "(a > 0) and (b > 0)"
          inner = check_clause[1..-2]
          if balanced_parentheses?(inner)
            check_clause = inner
          end
        end

        check_clause.gsub!("\\'", "'") # don't escape single quotes for compatibility with the original dumper

        ck_line = "  t.check_constraint \"#{check_clause}\""

        # Check if constraint name is custom (doesn't start with "chk_rails_")
        # Rails generates constraint names starting with "chk_rails_" followed by a hash
        if !constraint[:constraint_name].start_with?("chk_rails_")
          ck_line += ", name: \"#{constraint[:constraint_name]}\""
        end

        @output << ck_line
      end

      @output << "end"
    end

    def format_column(column)
      col_def = "t.#{map_column_type(column)} \"#{column['COLUMN_NAME']}\""

      # limit (varchar, char)
      if ['varchar', 'char'].include?(column['DATA_TYPE']) && column['CHARACTER_MAXIMUM_LENGTH'] &&
          column['CHARACTER_MAXIMUM_LENGTH'] != 255
        col_def += ", limit: #{column['CHARACTER_MAXIMUM_LENGTH']}"
      end

      # limit (integers)
      case column['DATA_TYPE']
      when 'tinyint'
        # Always add limit: 1 for tinyint unless it's tinyint(1) which is boolean
        col_def += ", limit: 1" unless column['COLUMN_TYPE'] == 'tinyint(1)'
      when 'smallint'
        col_def += ", limit: 2"
      when 'mediumint'
        col_def += ", limit: 3"
      end

      # size (text)
      if column['DATA_TYPE'] == 'mediumtext'
        col_def += ", size: :medium"
      elsif column['DATA_TYPE'] == 'longtext'
        col_def += ", size: :long"
      end

      # precision (datetime)
      if column['DATA_TYPE'] == 'datetime' && column['DATETIME_PRECISION']
        precision = column['DATETIME_PRECISION'].to_i
        col_def += ", precision: nil" if precision == 0
      end

      # precision, scale (decimal)
      if column['DATA_TYPE'] == 'decimal' && column['NUMERIC_PRECISION']
        col_def += ", precision: #{column['NUMERIC_PRECISION']}"
        col_def += ", scale: #{column['NUMERIC_SCALE']}" if column['NUMERIC_SCALE']
      end

      # default
      if column['COLUMN_DEFAULT']
        default = format_default_value(column['COLUMN_DEFAULT'], column['DATA_TYPE'], column['COLUMN_TYPE'])
        col_def += ", default: #{default}" unless default.nil?
      end

      # null
      col_def += ", null: false" if column['IS_NULLABLE'] == 'NO'

      # comment
      if column['COLUMN_COMMENT'] && !column['COLUMN_COMMENT'].empty?
        col_def += ", comment: \"#{escape_string(column['COLUMN_COMMENT'])}\""
      end

      # unsigned
      if column['COLUMN_TYPE'].include?('unsigned')
        col_def += ", unsigned: true"
      end

      # collation
      if column['COLLATION_NAME'] && column['DATA_TYPE'] =~ /char|text/
        # Check if it's different from the table's default collation
        # For now, just check if it's utf8mb4_bin which seems to be the special case
        if column['COLLATION_NAME'] == 'utf8mb4_bin'
          col_def += ", collation: \"#{column['COLLATION_NAME']}\""
        end
      end

      col_def
    end

    def map_column_type(column)
      # Check for boolean (tinyint(1))
      if column['COLUMN_TYPE'] == 'tinyint(1)'
        return 'boolean'
      end

      case column['DATA_TYPE']
      when 'varchar', 'char'
        'string'
      when 'int', 'tinyint', 'smallint', 'mediumint'
        'integer'
      when 'bigint'
        'bigint'
      when 'text', 'tinytext', 'mediumtext', 'longtext'
        'text'
      when 'datetime', 'timestamp'
        'datetime'
      when 'date'
        'date'
      when 'time'
        'time'
      when 'decimal'
        'decimal'
      when 'float', 'double'
        'float'
      when 'json'
        'json'
      when 'binary', 'varbinary'
        'binary'
      when 'blob', 'tinyblob', 'mediumblob', 'longblob'
        'binary'
      else
        column['DATA_TYPE']
      end
    end

    def format_default_value(default, data_type, column_type = nil)
      return nil if default == 'NULL' || default.nil?

      # Special handling for boolean (tinyint(1))
      if column_type == 'tinyint(1)'
        return (default == '1') ? 'true' : 'false'
      end

      case data_type
      when 'varchar', 'char', 'text'
        "\"#{escape_string(default)}\""
      when 'int', 'tinyint', 'smallint', 'mediumint', 'bigint'
        default
      when 'datetime', 'timestamp'
        return '-> { "CURRENT_TIMESTAMP" }' if default == 'CURRENT_TIMESTAMP'
        "\"#{default}\""
      when 'decimal'
        # Same as Rails: activemodel/lib/active_model/type/decimal.rb#type_cast_for_schema
        BigDecimal(default).to_s.inspect
      when 'float', 'double'
        # Same as Rails: activemodel/lib/active_model/type/float.rb#type_cast_for_schema
        # MySQL double is mapped to Type::Float in Rails
        default.to_f.inspect
      when 'json'
        (default == "'[]'") ? '[]' : '{}'
      else
        /^'.*'$/.match?(default) ? "\"#{default[1..-2]}\"" : default
      end
    end

    def format_index(index_name, index_data)
      idx_def = "t.index "

      idx_def += if index_data[:columns].size == 1
        "[\"#{index_data[:columns].first}\"]"
      else
        "[#{index_data[:columns].map { |c| "\"#{c}\"" }.join(', ')}]"
      end

      idx_def += ", name: \"#{index_name}\""
      idx_def += ", unique: true" if index_data[:unique]

      # order
      if index_data[:orders] && !index_data[:orders].empty?
        order_hash = index_data[:columns].each_with_object({}) do |col, hash|
          if index_data[:orders][col]
            hash[col.to_sym] = index_data[:orders][col]
          end
        end

        unless order_hash.empty?
          idx_def += if index_data[:columns].size == 1
            # For single column index, use simplified syntax
            ", order: :#{order_hash.values.first}"
          else
            # For compound index, use hash syntax
            ", order: { #{order_hash.map { |k, v| "#{k}: :#{v}" }.join(', ')} }"
          end
        end
      end

      # comment
      if index_data[:comment] && !index_data[:comment].empty?
        idx_def += ", comment: \"#{escape_string(index_data[:comment])}\""
      end

      idx_def
    end

    def balanced_parentheses?(str)
      depth = 0
      str.each_char do |char|
        depth += 1 if char == '('
        depth -= 1 if char == ')'
        return false if depth < 0
      end
      depth == 0
    end
  end
end
