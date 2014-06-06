require 'fog'
require 'yaml'

module Billow

  class Command

    class << self

      def all
        ObjectSpace.each_object(Class).select { |klass| klass < Billow::Command }.sort_by(&:name)
      end

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
