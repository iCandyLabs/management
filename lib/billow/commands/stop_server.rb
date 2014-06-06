require_relative '../command'

module Billow

  class StopServer < Billow::Command

    def call(server_name)
      server = get_server(server_name)

      print "Are you sure you want to stop #{server_name}? Type 'Yes' to continue, or anything else to abort: "
      answer = gets.chomp

      if answer == 'Yes'
        server.stop
        puts "Stopped."
      else
        puts "Aborted."
      end
    end

  end

end
