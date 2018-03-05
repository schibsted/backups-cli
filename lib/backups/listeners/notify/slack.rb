require "slack-notifier"

module Backups
  module Listeners
    module Notify
      class Slack < Listener

        def initialize config
          @config = config

          webhook  = config.fetch("webhook")
          channel  = config.fetch("channel", "backups")
          username = config.fetch("username", "backups-cli")
          events   = config.fetch("events", "all")
          active   = config.fetch("active", true)

          unless active
            $LOGGER.debug "Slack listener not active"
            return
          end

          @slack = ::Slack::Notifier.new webhook, channel: channel, username: username
          $LOGGER.debug "Slack listener initialized"

          if events == "all" or events.include? "start"
            $LOGGER.debug "Slack listening to start events"
            Events::on :start do |params|
              _start params
            end
          end

          if events == "all" or events.include? "complete"
            $LOGGER.debug "Slack listening to complete events"
            Events::on :done do |params|
              _done params
            end
          end

          if events == "all" or events.include? "error"
            $LOGGER.debug "Slack listening to error events"
            Events::on :error do |params|
              _error params
            end
          end
        end

        private
        def _tags attachment, params
          params.fetch(:config, {}).fetch("tags", {}).each do |k,v|
            next if v == nil
            attachment[:fields] << {
              title: "Tag: #{k}",
              value: v,
              short: true,
            }
          end
        end

        def _done params
          details = params.fetch(:details)
          notes   = {
            color:  "good",
            fields: [
              {
                title: "Size",
                value: "#{details[:size].to_filesize} (#{details[:size]} bytes)",
                short: true,
              },
              {
                title: "Took",
                value: "#{(details[:completed] - details[:started]).round(2)} seconds",
                short: true,
              },
              {
                title: "File",
                value: "<#{details[:view]}|#{details[:url]}>",
              },
            ],
          }

          _tags notes, params
          _send "Backup job `#{params[:job]}` is complete.", [notes]
        end

        def _error params
          error = params.fetch(:error, "Something went wrong but I don't know what.")
          notes = {
            color:    "danger",
            fallback: error,
            fields:   [
              {
                title: "Error",
                value: error,
              },
            ],
          }

          _tags notes, params
          _send "Backup job `#{params[:job]}` failed.", [notes]
        end

        def _start params
          notes = { fields: [] }
          msg = "Backup job `#{params[:job]}` has started.".encode!("UTF-8", {undef: :replace})

          _tags notes, params
          _send msg, [notes]
        end

        def _send message, attachments
          res = @slack.ping message, attachments: attachments
          $LOGGER.debug "Event sent to Slack: #{message}"
          # if res.code
          #   $LOGGER.debug "Slack result: #{res.code} #{res.message}"
          # end
        end

      end
    end
  end
end
