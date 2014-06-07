require 'fog'
require 'yaml'

module Billow

  class Command

    class << self

      def all
        @all ||= []
      end

      def inherited(subclass)
        all << subclass
      end

      def arg_specs
        @arg_specs ||= []
      end

      def arg(type, opts = nil)
        arg_specs << [type, opts]
      end

      # is_optional = opts && opts[:optional]

      # p [type, is_optional]

      # TODO:
      #   @env_name = arg_value (if type at this position == :env)
      #   @env = get_env(env_name)
      #   the get_* helper functions can go away and be integrated with this
      #   valid options: [:optional, :default]

      # - redefine help_string and command_name in terms of self.args
      # - give each command instance @env and @env_name, etc
      # - call each command instance's :call method with no args
      # - give better errors when arguments:
      #   - dont fit the right type
      #   - or are omitted
      #   - or are the right type but arent valid values
      #
      # NOTE: this means changing the tests, and it should
      #       be designed in a way thats still easy to test
      #       and not hard to mentally trace.

      def help_string
        params = instance_method(:call).parameters

        output = sprintf("%20s ", command_name)
        args = []

        params.each do |req, name|
          name = "<#{name.to_s.sub('_name', '')}>"
          if req == :opt
            name = "[#{name}]"
          end
          args << name
        end

        return output + args.join(' ')
      end

      def command_name
        self.name.split('::').last.
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("_", "-").
          downcase
      end

    end


    def get_env(name)
      return nil if name.nil?
      config[:envs].include?(name) and name or abort "Invalid environment: #{name}"
    end

    def get_type(name)
      config[:types][name.to_sym] or abort "Invalid type: #{name}"
    end

    def get_script(name)
      config[:scripts][name.to_sym] or abort "Invalid script: #{name}"
    end

    def get_server(name)
      cloud.servers.find{|server| server.name == name} or abort "Invalid server: #{name}"
    end

    def config
      @config ||= symbolize_keys!(raw_yaml)
    end

    def cloud
      @cloud ||= Fog::Compute.new(config[:cloud])
    end


    private

    def raw_yaml
      YAML.load(File.read("billow_config.yml"))
    end

    def symbolize_keys! h
      case h
      when Hash
        pairs = h.map { |k, v| [k.respond_to?(:to_sym) ? k.to_sym : k, symbolize_keys!(v)] }
        return Hash[pairs]
      when Array
        return h.map{ |e| symbolize_keys!(e) }
      else
        return h
      end
    end

  end

end
