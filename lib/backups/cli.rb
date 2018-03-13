require "thor"

module Backups
  class Cli < Thor

    desc "version", "Show current version"
    def version
      puts "v#{VERSION}"
    end

    desc "ls", "Lists all the configured jobs"
    def ls
      Crontab.new.list()
    end

    desc "show [JOB]", "Shows the merged config (for a JOB or them all)"
    def show job = nil
      data = Runner.new.show(job)
      puts data.to_json
    end

    desc "start [JOB]", "Starts a backup JOB or all of them"
    def start job = nil
      if job
        Runner.new.start job
      else
        Runner.new.start_all
      end
    end

    desc "verify [JOB]", "Restores and verifies a backup JOB or all of them"
    def verify job = nil
      if job
        Runner.new.verify job
      else
        Runner.new.verify_all
      end
    end

    desc "install", "Sets up the crontab for all jobs"
    def install
      Crontab.new.install
    end

    desc "crontab", "Shows the crontab config"
    def crontab
      puts Crontab.new.show()
    end

  end
end
