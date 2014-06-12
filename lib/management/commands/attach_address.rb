require_relative '../command'

module Management

  class AttachAddress < Management::Command

    include Management::Helper

    def run(address_name, server_name)
      address = get_address(address_name)
      server = get_server(server_name)

      puts "Attaching #{address_name} to #{server_name}..."
      address.server = server
      puts "Done."
    end

  end

end
