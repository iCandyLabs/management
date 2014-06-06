require_relative '../command'

module Billow

  class StopServer < Billow::Command

    def call(server_name)
      server = get_server(server_name)
      server.stop
      puts "Stopped #{server_name}."
    end

  end

end
