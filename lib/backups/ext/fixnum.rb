unless Fixnum.method_defined?(:european)
  class ::Fixnum
    def european
      self.to_s.reverse.gsub(/...(?=.)/,'\& ').reverse
    end
  end
end

unless Fixnum.method_defined?(:to_filesize)
  class ::Fixnum
    def to_filesize
      {
        'B'  => 1024,
        'KB' => 1024 * 1024,
        'MB' => 1024 * 1024 * 1024,
        'GB' => 1024 * 1024 * 1024 * 1024,
        'TB' => 1024 * 1024 * 1024 * 1024 * 1024
      }.each_pair {|e, s| return "#{(self.to_f / (s/1024)).round(2)} #{e}" if self < s }
    end
  end
end
