module Backups
  class Events

    @@events = {}

    def self.on *events, &block
      names = []
      if events.kind_of? Array
        names = events
      else
        names << events
      end

      names.each do |name|
        @@events[name] ||= []
        @@events[name] << block
      end
    end

    def self.fire event, params
      params[:event] = event
      names = []
      if event.kind_of? Array
        names = event
      else
        names << event
      end

      names.each do |name|
        if @@events.has_key? name
          @@events[name].each do |cb|
            res = cb.call(params)
            break if res == false
          end
        end
      end
    end

  end
end
