require "yaml"

module Backups
  module Loader

    CONFIG_ENV    = "BACKUPS_CONFIG_DIR"
    CONFIG_USER   = "~/.backups-cli"
    CONFIG_SYSTEM = "/etc/backups-cli"

    def load_configs
      config_dir = find_dir()
      load_files config_dir
    end

    private
    def load_files dir
      $GLOBAL = {
        "backups"  => {},
        "defaults" => {},
        "jobs"     => {},
      }

      # First, we dep merge all config into a single config
      Dir["#{dir}/**/*.yaml"].each do |file|
        $GLOBAL = $GLOBAL.deep_merge(YAML.load_file(file))
      end

      # Second, we apply the defaults config to all jobs
      $GLOBAL["jobs"].each do |name, config|
        $GLOBAL["jobs"][name] = $GLOBAL["defaults"].deep_merge(config)
        $GLOBAL["jobs"][name]["_name"] = name
      end

      File.write("#{dir}/merged.compiled-yaml", $GLOBAL.to_yaml)
    end

    def find_dir
      dirs = []
      dirs << ENV.fetch(CONFIG_ENV) if ENV[CONFIG_ENV]
      dirs << File.expand_path(CONFIG_USER) if ENV["HOME"]
      dirs << CONFIG_SYSTEM

      dirs.each do |dir|
        return File.realpath(dir) if File.directory? dir
      end

      raise RuntimeError, <<-EOS.squish!
        The config directory could not be found. You need to either set
        the BACKUPS_CONFIG_DIR env var to a valid directory or create either a
        #{CONFIG_USER} or a #{CONFIG_SYSTEM} directory.
      EOS
    end

  end
end
