require "mysql2"

module Backups
  module Util
    module Stats

      def connect
        @connection[flags: Mysql2::Client::MULTI_STATEMENTS]
        @mysql = Mysql2::Client.new(@connection)
      end

      def exec_query(sql)
        return puts sql if $dry_run
        connect if not @mysql
        @mysql.query sql
      end

      def get_results(sql)
        return [] if not rset = exec_query(sql)
        rows = []
        rset.each do |row|
          rows << row
        end

        return rows
      end

      def get_result(sql)
        rows = get_results(sql)
        return rows[0]
      end

      def get_server_tables(databases = nil)
        query = <<-EOS
          SELECT
                  TABLE_SCHEMA `database`,
                  TABLE_NAME `table`
          FROM
                  INFORMATION_SCHEMA.TABLES
          WHERE
                  TABLE_SCHEMA NOT IN ('#{get_excluded_schemas.join("', '")}')
          EOS

        query += "AND TABLE_SCHEMA IN ('#{databases.join("', '")}')" \
          if databases
        query += "ORDER BY TABLE_SCHEMA ASC"

        get_results(query)
      end

      def get_database_tables(database)
        query = <<-EOS
          SELECT
                  TABLE_NAME `table`
          FROM
                  INFORMATION_SCHEMA.TABLES
          WHERE
                  TABLE_SCHEMA = '#{database}'
          EOS

        get_results(query)
      end

      def get_database_stats(database)
        tables = get_database_tables(database)
        stats  = {}
        tables.each do |item|
          table = item['table']

          stats[table] = get_table_stats(database, table)
          $LOGGER.debug "Writing stats for table #{database}.#{table}: #{stats[table]}"
        end

        return stats
      end

      def get_excluded_schemas
        ['information_schema', 'performance_schema', 'mysql']
      end

      def get_database_names
        query = <<-EOS
          SELECT
                  SCHEMA_NAME `database`
          FROM
                  INFORMATION_SCHEMA.SCHEMATA
          WHERE
                  SCHEMA_NAME NOT IN ('#{get_excluded_schemas.join("', '")}')
        EOS

        get_results(query)
      end

      def get_table_stats(database, table)
        query = <<-EOS
          SELECT
                  COUNT(*) `rows`
          FROM
                  `#{database}`.`#{table}`
        EOS

        get_result(query)
      end

    end
  end
end
