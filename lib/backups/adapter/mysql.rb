require "yaml"

module Backups
  module Adapter
    class Mysql < Base

      include ::Backups::Util::Stats

      def run
        setup
        create_dump
        compress @job_dir, @job_zip, @secret

        @job_size = File.size(@job_zip) if not $DRY_RUN
        $LOGGER.info "File #{@job_zip} created with #{@job_size} bytes"

        send_to_s3 @s3_bucket, @s3_prefix, @job_zip, @config if @s3_active
        clean_up if @cleanup
        report

        return @report
      end

      def verify
        s3     = @config.fetch("s3", {})
        @name  = @config.fetch('_name')
        bucket = s3.fetch("bucket", "")
        path   = s3.fetch("path", "")
        date   = get_date_path()
        folder = "s3://#{bucket}/#{path}/#{@name}/#{date}/"
        $LOGGER.warn "Latest s3 path is: " + get_latest_s3(folder)
      end

      private
      # If you are lost here's what the vars mean:
      #
      # Variable    Value
      # ---------   ----------------------------------
      # backup_dir   /tmp/backups/
      # source_dir     <source>/
      # job_zip          <prefix>-<timestamp>.zip
      # job_dir          <prefix>-<timestamp>/
      def setup
        load_configs

        backups     = $GLOBAL.fetch('backups', {})
        paths       = backups.fetch('paths', {})
        encryption  = @config.fetch('encryption', {})
        s3          = @config.fetch('s3', {})
        prefix      = get_prefix()
        date_path   = get_date_path()
        timestamp   = get_timestamp()
        backup_dir  = paths.fetch('backups', '/tmp/backups')

        @backup     = @config.fetch('backup', {})
        @options    = @config.fetch('options', {})
        @connection = @backup.fetch('connection', {})
        @secret     = encryption.fetch('secret', nil)
        @cleanup    = @options.fetch('cleanup', true)
        @name       = @config.fetch('_name')
        @group      = @name.gsub(/[^0-9A-Za-z]/, '_')

        job_name    = "#{prefix}-#{timestamp}"
        @source_dir = "#{backup_dir}/#{@name}"
        @job_dir    = "#{@source_dir}/#{job_name}"
        @job_zip    = "#{@source_dir}/#{job_name}.zip"
        @job_size   = nil

        s3_path     = s3.fetch('path', "")
        @s3_region  = s3.fetch('region', "eu-west-1")
        @s3_bucket  = s3.fetch('bucket', nil)
        @s3_active  = s3.fetch('active', @s3_bucket != nil)
        @s3_prefix  = "#{s3_path}/#{@name}/#{date_path}"

        @report     = {
          started:   Time.now,
          completed: nil,
          file:      nil,
          size:      nil,
          report:    nil,
        }
      end

      private
      def get_dump_command database
        host         = @connection.fetch("host", "localhost")
        username     = @connection.fetch("username", nil)
        password     = @connection.fetch("password", nil)
        silent       = @options.fetch("silent", true)
        master_data  = @options.fetch("master-data", 0)
        disable_keys = @options.fetch("disable-keys", true)
        lock_tables  = @options.fetch("lock-tables", false)
        use_defaults = @group.size > 0 ? true : false
        use_defaults = @options.fetch("use-defaults", use_defaults)
        events       = @options.fetch("events", false)

        command = []
        command << "mysqldump"
        command << "--defaults-group-suffix=_#{@group}"
        command << "--host=#{host}"

        command << "--user='#{username}'"           if username and !use_defaults
        command << "--password='#{password}'"       if password and !use_defaults
        command << "--master-data=#{master_data}"   if master_data
        command << "--events"                       if events
        command << "--skip-events"                  unless events
        command << "--lock-tables"                  if lock_tables
        command << "--single-transaction"           unless lock_tables
        command << "--disable-keys"                 if disable_keys
        command << database
        command << "> #{@job_dir}/#{database}.sql"
        command << "2>/dev/null"                    if silent

        command.join(" ")
      end

      def get_db_list
        host = @connection.fetch("host", "localhost")
        skip = [
          "information_schema",
          "performance_schema",
          "sys",
        ]

        command =  "mysql --defaults-group-suffix=_#{@group}"
        command << " --host #{host}"
        command << " -e 'show databases' | awk 'NR>1'"
        $LOGGER.debug command

        `#{command}`.split().select do |db|
          not skip.include? db
        end
      end

      def create_dump
        $LOGGER.info "Creating #{@job_dir}"
        mkdir @job_dir

        database  = @backup.fetch("database", nil)
        databases = @backup.fetch("databases", [])
        databases << database if database

        # Are we dumping specific databases
        if databases.size > 0
          $LOGGER.info "Preparing databases dump"
          databases.each do |db|
            create_database_dump db
          end
        else
          create_server_dump
        end
      end

      def create_server_dump
        $LOGGER.info "Preparing server dump"
        get_db_list().each do |db|
          create_database_dump db
        end
      end

      def create_database_dump db
        $LOGGER.info "Dumping database #{db}"
        command = get_dump_command(db)
        create_database_stats db
        exec command
      end

      def create_database_stats db
        $LOGGER.debug "Creating #{db} database stats"
        file = "#{@job_dir}/#{db}-stats.yaml"
        stats = get_database_stats(db)
        write file, stats.to_yaml
      end

      def clean_up
        $LOGGER.info "Cleaning #{@source_dir}"
        delete @job_zip if File.exists? @job_zip
        nuke_dir @job_dir

        delete_dir @source_dir
      end

      def report
        path = "#{@s3_bucket}/#{@s3_prefix}/#{File.basename(@job_zip)}"

        @report[:completed] = Time.now
        @report[:file]      = @job_zip
        @report[:size]      = @job_size
        @report[:url]       = "s3://#{path}"
        @report[:view]      = "https://console.aws.amazon.com/s3/buckets" +
                              "#{path}?region=#{@s3_region}"
      end

      def get_latest_s3 folder
        $LOGGER.info "Finding latest dump in folder #{folder}"
        $LOGGER.info "aws s3 ls #{folder}/|awk '{ print $4 }'|tail -n 1"
        exec "aws s3 ls #{folder}/|awk '{ print $4 }'|tail -n 1"
      end

    end
  end
end
