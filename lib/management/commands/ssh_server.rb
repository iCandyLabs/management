require_relative '../command'

module Management

  class SshServer < Management::Command

    include Management::Helper

    def call(server_name)
      server = get_server(server_name)

      type = config[:types][server.type.to_sym]
      ssh_key_path = type[:ssh_key_path]
      run "chmod 0600 #{ssh_key_path}"
      run "ssh -i #{ssh_key_path} #{config[:root_user]}@#{server.public_ip_address}"
    end

    def run(cmd)
      puts "Running: #{cmd}"
      system cmd
    end

  end

end
