module Management

  module Helper

    def get_env(name)
      return nil if name.nil?
      config[:envs].include?(name) and name or invalid_selection "Invalid environment: #{name}", config[:envs]
    end

    def get_type(name)
      config[:types][name.to_sym] or invalid_selection "Invalid type: #{name}", config[:types].map(&:first)
    end

    def get_script(name)
      config[:scripts][name.to_sym] or invalid_selection "Invalid script: #{name}", config[:scripts].map(&:first)
    end

    def get_server(name)
      servers = live_servers
      server = servers.find{|server| server.name == name} or invalid_selection "Invalid server: #{name}", servers.map(&:name)
      server.username = config[:root_user] if server && config[:root_user]
      server
    end

    def get_address(name)
      addresses = cloud.addresses
      ip = config[:addresses][name.to_sym] or invalid_selection "Invalid address: #{name}", config[:addresses].map(&:first)
      addresses.find{|a| a.public_ip == ip} or abort "Could not find an address with the IP #{ip} (#{name})"
    end

    def live_servers
      cloud.servers.reject{ |s| s.state == 'terminated' || s.state == 'shutting-down' }
    end

    def config
      @config ||= symbolize_keys!(raw_yaml)
    end

    def cloud
      require 'fog'
      require_relative '../ext/fog'
      @cloud ||= Fog::Compute.new(config[:cloud])
    end

    def system_verbose(cmd)
      puts "Running: #{cmd}"
      system cmd
    end


    private

    def raw_yaml
      require 'yaml'
      YAML.load(File.read("management_config.yml"))
    end

    def invalid_selection(str, selection)
      abort "#{str}\nValid choices:" + (["\n"] + selection).join("\n - ")
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
