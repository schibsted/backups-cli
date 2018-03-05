unless NilClass.method_defined?(:[])
  class ::NilClass
    def [](*args)
      nil
    end
  end
end
