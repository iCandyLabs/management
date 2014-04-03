require_relative '../command'

module Billow

  class ListServers < Billow::Command

    def call(env_name = nil)
      env = get_env(env_name)

      cloud.servers.each do |server|
        next if env_name && server.env != env_name
        printf "%15s  %s  %s\n", server.name, server.public_ip_address, server.state
      end
    end

  end

end
