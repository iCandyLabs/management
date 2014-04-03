require_relative '../command'

module Billow

  class DestroyServer < Billow::Command

    def call(server_name)
      server = get_server(server_name)
      server.destroy
      puts "Destroyed."
    end

  end

end
