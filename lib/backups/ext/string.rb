unless String.method_defined?(:to_bool)
  class String
    def to_bool
      return true if self == true || self =~ (/^(true|t|yes|y|1)$/i)
      return false if self == false || self.blank? || self =~ (/^(false|f|no|n|0)$/i)
      raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
    end
  end
end

unless String.method_defined?(:squish!)
  class String
    def squish!
      gsub!(/\A[[:space:]]+/, '')
      gsub!(/[[:space:]]+\z/, '')
      gsub!(/[[:space:]]+/, ' ')
      self
    end
  end
end
