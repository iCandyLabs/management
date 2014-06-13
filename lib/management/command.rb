module Management

  class Command

    def self.all
      @all ||= []
    end

    def self.inherited(subclass)
      all << subclass.new
    end

    def self.maxlen
      all.map(&:command_name).map(&:size).max
    end

    def fn
      method(:run)
    end

    def command_name
      self.class.name.
        split('::').
        drop(1).
        join(":").
        downcase
    end

    def arg_list
      fn.parameters.map do |req, name|
        name = '<' + name.to_s.sub(/_names?/, '') + '>'
        case req
        when :opt then '[' + name + ']'
        when :rest then name + ' [...]'
        else name
        end
      end.join(' ')
    end

    def help_string
      sprintf "  %-#{Command.maxlen + 2}s %s", command_name, arg_list
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
