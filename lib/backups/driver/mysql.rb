require "mysql2"

module Backups
  module Driver
    module Mysql

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

    end
  end
end
