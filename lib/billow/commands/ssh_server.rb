require_relative '../command'

module Billow

  class SshServer < Billow::Command

    def call(server_name)
      server = get_server(server_name)

      type = config.types[server.type]
      ssh_key_path = type[:ssh_key_path]
      system("ssh -i #{ssh_key_path} root@#{server.public_ip_address}")
    end

  end

end
