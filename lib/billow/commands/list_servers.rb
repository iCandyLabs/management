require_relative '../command'

module Billow

  class ListServers < Billow::Command

    def call(env_name = nil)
      env = get_env(env_name)

      format = "%-15s  %-10s  %-20s  %-20s\n"

      printf format, "Name", "State", "IP", "Private IP"
      printf format, "-" * 15, "-" * 10, "-" * 20, "-" * 20

      cloud.servers.each do |server|
        next if env_name && server.env != env_name
        printf format, server.name, server.state, server.public_ip_address, server.private_ip_address
      end
    end

  end

end
