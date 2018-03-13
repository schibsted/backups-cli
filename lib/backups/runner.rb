module Backups
  class Runner

    ADAPTER_PREFIX = "Backups::Adapter::"
    VERIFY_PREFIX  = "Backups::Verify::"

    include System
    include Loader

    def initialize
      load_configs
      load_listeners
    end

    def start_all
      $LOGGER.info "Starting all jobs sequentially"
      $GLOBAL["jobs"].each do |name, config|
        start name
      end
    end

    def verify_all
      $LOGGER.info "Verifying all jobs sequentially"
      $GLOBAL["jobs"].each do |name, config|
        verify name
      end
    end

    def start job
      $LOGGER.progname = job
      $LOGGER.info "Started backup"

      config = _load_config(job)

      Events.fire :start, {
        job:    job,
        config: config,
      }

      details = _backup(job, config)

      Events.fire :done, {
        type:    :backup,
        job:     job,
        config:  config,
        details: details,
      }

      $LOGGER.info "Completed backup"
    end

    def verify job
      $LOGGER.progname = job
      $LOGGER.info "Started verification"

      config = _load_config(job)

      Events.fire :start, {
        job:    job,
        config: config,
      }

      details = _verify(job, config)

      Events.fire :done, {
        type:    :verify,
        job:     job,
        config:  config,
        details: details,
      }

      $LOGGER.info "Completed verification"
    end

    def show job = nil
      return _load_config(job) if job
      $GLOBAL
    end

    private
    def _load_config job
      config = $GLOBAL["jobs"][job]
      raise "Job #{job} is not defined." unless config
      raise "Job #{job} is not enabled." unless config.fetch("enabled", true)
      raise "Job #{job} has no type."    unless config["type"]

      config
    end

    def _backup job, config
      type  = config["type"].capitalize
      klass = class_for_name("#{ADAPTER_PREFIX}#{type}")
      raise RuntimeError, "Could not load the #{type} adapter." unless klass
      adapter = klass.new(config)
      details = adapter.run()

      ### Test the verify step immediately after
      # details["verify"] = _verify(job, config)

      details
    end

    def _verify job, config
      type  = config["type"].capitalize
      klass = class_for_name("#{VERIFY_PREFIX}#{type}")
      raise RuntimeError, "Could not load the #{type} verify." unless klass
      adapter = klass.new(config)
      adapter.verify()
    end

    def class_for_name name
      name.split("::").inject(Object) { |o, c| o.const_get c }
    end

    def load_listeners
      Dir["#{File.dirname(__FILE__)}/listeners/**/*.rb"].each do |file|
        require file

        name = file.gsub("#{File.dirname(__FILE__)}/listeners/", "")
        name = name[0..-4]
        full = ""
        name.split("/").each do |v|
          full += "::#{v.capitalize}"
        end

        listeners = $GLOBAL["backups"].fetch("listeners", {})
        # search    = name.gsub("/", ".")
        search    = File.basename(name)
        config    = listeners.fetch(search, {})

        klass = class_for_name("Backups::Listeners#{full}")
        listn = klass.new(config)
      end
    end

  end
end
