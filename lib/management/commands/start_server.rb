require_relative '../command'

module Management

  class StartServer < Management::Command

    include Management::Helper

    def call(server_name)
      server = get_server(server_name)
      server.start
      puts "Started #{server_name}."
    end

  end

end
