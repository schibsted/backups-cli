module Backups
  class Listener

    def self.listen *names, &block
      names.each do |name|
        if block_given?
          Events.on name do |params|
            block.call(params)
          end
        else
          Events.on name do |params|
            notify params
          end
        end
      end
    end

  end
end
