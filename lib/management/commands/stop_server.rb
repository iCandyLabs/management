require_relative '../command'

module Management

  class StopServer < Management::Command

    include Management::Helper

    def call(server_name)
      server = get_server(server_name)
      server.stop
      puts "Stopped #{server_name}."
    end

  end

end
