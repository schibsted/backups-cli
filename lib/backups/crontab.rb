require "tablelize"

module Backups
  class Crontab

    include System
    include Loader

    PADDING = 10

    def initialize
      load_configs
      @base = File.expand_path('../../..', __FILE__)
    end

    def list
      paddings = {
        'job'    => 20,
        'backup' => 10,
        'verify' => 10,
      }

      rows = []
      rows << ["JOB", "CRONTAB", "INSTALL", "ENABLED"]

      $GLOBAL["jobs"].each do |job, config|
        backup   = config.fetch('backup',  {})
        crontab  = backup.fetch('crontab', {})
        crontime = get_crontime(crontab)
        install  = crontab.fetch('install', true)
        enabled  = config.fetch('enabled', true)

        rows << [job, crontime, install, enabled]
      end

      Tablelize::table rows
    end

    def show
      get_install_lines()
    end

    def install
      last_log_active  = $LOG_ACTIVE
      $LOG_ACTIVE = 0

      install_mysql_groups

      content = get_install_lines()
      cronfile = "/tmp/crontab.new"
      write cronfile, content
      exec "crontab #{cronfile}"
      exec "rm #{cronfile}"
      exec "crontab -l"

      $LOG_ACTIVE = last_log_active
    end

    private
    def get_install_lines
      # We dont want passwords in the main log and write does that

      start    = "# BEGIN SECTION Backups\n"
      finish   = "# END SECTION Backups\n"
      previous = `crontab -l 2>/dev/null`

      backups = $GLOBAL.fetch("backups", {})
      crontab = backups.fetch("crontab", {})
      header  = crontab.fetch("header", "")
      run_all = crontab.fetch("run-all", false)
      content = "#{header}\n#{previous}" \
        if header and not previous.include? header

      content << start
      content << "# Generated at #{Time.now}\n"
      if run_all
        content << get_all_crontab() + "\n"
      else
        content << get_jobs_crontab() + "\n"
      end
      content << finish
    end

    def get_all_crontab
      backups = $GLOBAL.fetch("backups", {})
      crontab = backups.fetch("crontab", {})
      minute  = crontab.fetch("minute", 0)
      hour     = crontab.fetch("hour", "*")
      crontime = get_crontime(crontab)

      line    = "#{@base}/bin/backups start"
      prefix  = crontab.fetch("prefix", "")
      postfix = crontab.fetch("postfix", "")

      line = "#{prefix} #{line}" if prefix
      line = "#{line} #{postfix}" if postfix

      "#{crontime} #{line}"
    end

    def get_jobs_crontab
      contents = []

      $GLOBAL['jobs'].each do |job, config|
        backup   = config.fetch('backup', {})
        crontab  = backup.fetch('crontab', {})
        crontime = get_cronjob(job, 'start', crontab)
        contents << crontime
      end

      contents.join("\n")
    end

    def get_cronjob job, command, crontab
      return unless crontab.fetch('install', true)
      line = "#{@base}/bin/backups #{command} #{job}"
      time = get_crontime(crontab)

      prefix  = crontab.fetch("prefix", "")
      postfix = crontab.fetch("postfix", "")
      line = "#{prefix} #{line}" if prefix
      line = "#{line} #{postfix}" if postfix

      "#{time} #{line}" if not time.nil?
    end

    def get_crontime crontab
      time = "#{crontab.fetch('minute',    '0')}"
      time << " #{crontab.fetch('hour',    '4')}"
      time << " #{crontab.fetch('day',     '*')}"
      time << " #{crontab.fetch('month',   '*')}"
      time << " #{crontab.fetch('weekday', '*')}"

      time.strip()
    end

    def install_mysql_groups
      $GLOBAL["jobs"].each do |job, config|
        install_mysql_group job, config if config["type"].downcase === "mysql"
      end
    end

    def install_mysql_group job, config
      group = "client_" + job.gsub("-", "_")
      username = config["backup"]["connection"]["username"]
      password = config["backup"]["connection"]["password"]

      contents = []
      contents << "[" + group + "]"
      contents << "user = " + username if username
      contents << "password = " + password if password
      replace_mysql_group group, contents.join("\n")
    end

    def replace_mysql_group group, content
      path  = File.expand_path("~/.my.cnf")
      lines = []
      if File.exist? path
        found = false
        File.readlines(path).each do |line|
          if line === "[#{group}]\n"
            found = true
          elsif line.match(/^\[.*\]\n/)
            found = false
          end
          lines << line if not found
        end
      end

      contents = lines.join()
      contents += "\n" if contents.size > 0 and contents[contents.size-1..-1] != "\n"
      contents += content

      write path, contents
    end

  end
end
