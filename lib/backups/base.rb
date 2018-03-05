module Backups
  class Base

    ALL_DATABASES = "all-databases"

    include System
    include Loader

    def initialize config
      @config = config
    end

    def get_timestamp
      now = Time.new
      now = now.utc if now.utc?
      now.iso8601.gsub(':', '-')
    end

    def get_date_path
      Time.now.strftime('%Y/%m/%d')
    end

    def get_prefix
      return @options['s3']['prefix'] if @options['s3']['prefix']
      return @config["_name"]
    end

    def compress source, dest, secret
      if source.kind_of? Array
        dir  = File.dirname(source[0])
        base = source.map {|v| File.basename(v)}.join(' ')
      else
        dir  = File.dirname(source)
        base = File.basename(source)
      end

      commands  = []
      commands << "cd #{dir} && zip"
      commands << "--password #{secret}" if secret
      commands << "-r #{dest} #{base}"

      exec commands.join(' ')
    end

    def send_to_s3 bucket, path, filename, options = nil
      dest = "s3://#{bucket}/#{path}"
      $LOGGER.info "Sending to #{dest}"
      exec "aws s3 cp #{filename} #{dest}/"

      return unless options
      tags = options.fetch('tags', {})

      return unless tags.size > 0
      key = "#{path}/#{File.basename(filename)}"
      tag_s3_object bucket, key, tags
    end

    def tag_s3_object bucket, key, tags
      tagSet  = tags.map{ |k, v| "{Key=#{k},Value=#{v}}" }.join(",")
      $LOGGER.info "Tagging s3://#{bucket}/#{key}"
      $LOGGER.debug "Tagset: #{tagSet}"

      exec "aws s3api put-object-tagging \
        --bucket #{bucket} \
        --key #{key} \
        --tagging 'TagSet=[#{tagSet}]'"
    end

  end
end
