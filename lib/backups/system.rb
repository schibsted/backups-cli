module Backups
  module System

    def exec command
      # $LOGGER.debug "Running #{command}" if $LOG_ACTIVE == 1
      return if $DRY_RUN

      output = `#{command}`
      if $?.exitstatus != 0
        raise RuntimeError, \
          "Command '#{command}' failed with exit code #{$?.exitstatus}."
      end

      return output.chomp()
    end

    def delete file
      exec "rm #{file}"
    end

    def delete_dir start, stop = nil
      return exec "rmdir #{start}" unless stop
      stop = stop.chomp("/")
      loop do
        exec "rmdir #{start}" if File.directory? start
        break if start == stop
        start = File.dirname(start)
      end
    end

    def nuke_dir dir
      exec "rm -fr #{dir}"
    end

    def mkdir dirname
      exec "mkdir -p #{dirname}"
    end

    def write filename, contents
      commands = []
      commands << "cat << CONTENTS > #{filename}"
      commands << contents
      commands << "CONTENTS"

      exec commands.join("\n")
    end

    def get_latest_s3 path
      # $LOGGER.debug  "aws s3 ls #{path}/|awk '{ print $4 }'|tail -n 1"
      exec "aws s3 ls #{path}/|awk '{ print $4 }'|tail -n 1"
    end

  end
end
