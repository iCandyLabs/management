require_relative '../command'

module Management

  class StopServer < Management::Command

    include Management::Helper

    def run(server_name)
      server = get_server(server_name)
      puts "Stopping #{server_name}..."
      server.stop
      puts "Done."
    end

  end

end
