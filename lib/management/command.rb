module Management

  class Command

    def self.all
      @all ||= []
    end

    def self.inherited(subclass)
      all << subclass.new
    end

    def fn
      method(:call)
    end

    def command_name
      self.class.name.split('::').last.
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("_", "-").
        downcase
    end

    def help_string
      return sprintf("%20s ", self.command_name) + fn.parameters.map do |req, name|
        name = "<#{name.to_s.sub('_name', '')}>"
        req == :opt ? "[#{name}]" : name
      end.join(' ')
    end

    def call_with(args, error_handler)
      num_all_args = fn.parameters.count
      num_req_args = fn.arity

      error_handler.call "not enough arguments" if args.count < num_req_args
      error_handler.call "too many arguments"   if args.count > num_all_args

      fn.call *args
    end

  end

end
