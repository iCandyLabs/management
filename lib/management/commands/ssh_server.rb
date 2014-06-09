require_relative '../command'

module Management

  class SshServer < Management::Command

    include Management::Helper

    def run(server_name)
      server = get_server(server_name)

      type = config[:types][server.type.to_sym]
      ssh_key_path = type[:ssh_key_path]
      system_verbose "chmod 0600 #{ssh_key_path}"
      system_verbose "ssh -i #{ssh_key_path} #{config[:root_user]}@#{server.public_ip_address}"
    end

  end

end
