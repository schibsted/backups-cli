require "dogapi"

module Backups
  module Listeners
    module Notify
      class Datadog < Listener

        def initialize config
          @config = config
          api_key = @config.fetch("api_key")
          app_key = @config.fetch("app_key")

          @dog = Dogapi::Client.new(api_key, app_key)

          $LOGGER.debug "Datadog listener started"
          Events::on :start, :done, :error do |params|
            _notify params
          end
        end

        private
        def _notify params
          metric = @config.fetch("metric", "monitoring.backups")
          tags   = _flatten(params.fetch(:config, {}).fetch("tags", {}))
          tags << "type:#{params[:event]}"
          tags << "job:#{params[:job]}"

          status, response = @dog.emit_point(metric, 1, tags: tags)
          abort "Failed to send metric to Datadog." unless status == "202"
        end

        def _flatten tags
          values = []
          tags.each do |k, v|
            next if v == nil
            values << "#{k}:#{v}"
          end
          values
        end
      end

    end
  end
end
