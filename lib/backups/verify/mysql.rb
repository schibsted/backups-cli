require "yaml"

module Backups
  module Verify
    class Mysql < Base

      VERIFY_PREFIX = "__verify__"

      include ::Backups::Stats::Mysql

      def verify
        setup
        download
        import
        clean_up
        report

        return @details
      end

      private
      def setup
        load_configs

        @compared   = 0
        @failures   = 0
        @compsize   = nil
        @datedir    = get_date_path()
        @backups    = $GLOBAL.fetch("backups", {})
        @name       = @config["_name"]
        @verify     = @config.fetch("verify", {})
        @connection = @verify.fetch("connection", {})
        @secret     = @config.fetch("encryption", {}).fetch("secret", "")
        @paths      = @backups.fetch("paths", {})
        @verifydir  = @paths.fetch("verify", "/tmp/verify")
        @jobdir     = "#{@verifydir}/#{@name}"
        @s3bucket   = "#{@config["s3"]["bucket"]}"
        @s3path     = "#{@config["s3"]["path"]}"
        @s3fullpath = "s3://#{@s3bucket}/#{@s3path}/#{@name}/#{@datedir}"
        @package    = get_latest_s3(@s3fullpath)

        raise RuntimeError, "Error: Could not found the latest package in #{@s3fullpath}." \
          unless @package.length > 1

        @s3file     = "#{@s3fullpath}/#{@package}"
        @basename   = File.basename(@package).gsub(".zip", "")
        @download   = "#{@jobdir}/#{@package}"
        @timedir    = @download.gsub(".zip", "")

        @details    = {
          started:   Time.now,
          completed: nil,
          file:      nil,
          size:      nil,
          report:    nil,
        }

        $LOGGER.info "Preparing #{@jobdir}"
        # We clean up previous imports as we are less strict with them clearing
        # up cleanly.
        exec "rm -fr #{@jobdir}"
        exec "mkdir -p #{@jobdir}"
      end

      def download
        $LOGGER.info "Downloading #{@s3file}"
        exec "aws s3 cp #{@s3file} #{@download}"
        @compsize = File.size(@download) if not $DRY_RUN
        exec "cd #{@jobdir} && unzip -P #{@secret} #{@download}"
        $LOGGER.info "Downloaded #{@compsize} bytes"
      end

      def import
        files = get_import_files()

        if files == []
          $LOGGER.fatal "Error: There were no files in #{@timedir} to import."
          return
        end

        # Are we importing the whole server?
        if File.basename(files[0], ".sql") == ALL_DATABASES
          file = files[0]
          import_server file
          check_stats file
        else
          files.each do |file|
            db = File.basename(file, ".sql")
            dbname = "#{VERIFY_PREFIX}#{db}"
            import_database dbname, file
            check_database_stats dbname, file
            drop_database dbname
          end
        end
      end

      def import_server file
        $LOGGER.info "Importing server from #{file}"
        exec "mysql < #{file}"
      end

      def import_database db, file
        $LOGGER.info "Importing database #{db} from #{file}"
        exec "mysql -e 'DROP DATABASE IF EXISTS #{db}'"
        exec "mysql -e 'CREATE DATABASE #{db}'"
        exec "mysql #{db} < #{file}"
      end

      def get_import_files
        Dir["#{@timedir}/*.sql"]
      end

      def check_database_stats db, file
        # return if db == "mysql"

        file = file.gsub(".sql", "-stats.yaml")
        data = YAML.load_file(file)

        data.each do |table, stats|
          object = "#{db}.#{table}"
          check_table db, table

          imported = get_table_count(db, table)
          saved = stats["rows"]

          @compared = @compared + 1
          if saved.to_i == imported.to_i
            $LOGGER.debug "Row count match for #{object} matches"
          else
            $LOGGER.warn "Row count failed for #{object}. Saved #{saved} vs imported #{imported}"
          end
        end
      end

      def get_table_count db, table
        sql = "SELECT COUNT(1) FROM #{db}.#{table}"
        exec "mysql -e \"#{sql}\"|awk 'NR>1'"
      end

      def drop_database db
        $LOGGER.debug "Dropping database #{db}"
        sql = "DROP DATABASE #{db}"
        exec "mysql -e '#{sql}'"
      end

      def check_table database, table
        @compared = @compared + 1
        rs = get_result("CHECK TABLE #{database}.#{table}")
        if rs["Msg_text"] != "OK"
          @failures += 1
          $LOGGER.warn "Check table failed for #{database}.#{table}"
        else
          $LOGGER.debug "Check table passed for #{database}.#{table}"
        end
      end

      def clean_up
        $LOGGER.info "Cleaning #{@jobdir}"
        @compsize = File.size(@download)
        exec "rm -fr #{@jobdir}"
      end

      def report
        $LOGGER.info "Reporting that #{@compared} checks were compared"
        if @failures > 0
          $LOGGER.warn "#{@failures} checks failed"
        else
          $LOGGER.info "All checks passed"
        end

        @details[:file]      = @download
        @details[:size]      = @compsize
        @details[:view]      = "https://console.aws.amazon.com/s3/home?region=eu-west-1#&bucket=#{@s3bucket}&prefix=#{@s3path}"
        @details[:report]    = "#{@compared} stats compared with #{@failures} failures"
        @details[:completed] = Time.now
      end

    end
  end
end
