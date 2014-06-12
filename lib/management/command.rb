module Management

  class Command

    def self.all
      @all ||= []
    end

    def self.inherited(subclass)
      all << subclass.new
    end

    def fn
      method(:run)
    end

    def command_name
      self.class.name.split('::').last.
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr('_', '-').
        downcase
    end

    def help_string
      return sprintf("%20s ", self.command_name) + fn.parameters.map do |req, name|
        name = '<' + name.to_s.sub(/_names?/, '') + '>'
        case req
        when :opt then '[' + name + ']'
        when :rest then name + ' [...]'
        else name
        end
      end.join(' ')
    end

    def true_arity
      min = fn.parameters.take_while{|req, name| req == :req}.count
      max = fn.parameters.count
      max = Float::INFINITY if max > 0 && fn.parameters.last.first == :rest
      min..max
    end

    def call_with(args, error_handler)
      arity = self.true_arity

      error_handler.call "not enough arguments" if args.count < arity.begin
      error_handler.call "too many arguments"   if args.count > arity.end

      fn.call *args
    end

  end

end
