require_relative '../command'

module Billow

  class SshServer < Billow::Command

    def call(server_name)
      server = get_server(server_name)

      type = config.types[server.type]
      ssh_key_path = type[:ssh_key_path]
      run "chmod 0600 #{ssh_key_path}"
      run "ssh -i #{ssh_key_path} #{config.root_user}@#{server.public_ip_address}"
    end

    def run(cmd)
      puts "Running: #{cmd}"
      system cmd
    end

  end

end
