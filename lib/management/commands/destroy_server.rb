require_relative '../command'

module Billow

  class DestroyServer < Billow::Command

    def call(server_name)
      server = get_server(server_name)

      print "Are you sure you want to do this? Type 'Yes' to continue, or anything else to abort: "
      answer = $stdin.gets.chomp

      if answer == 'Yes'
        server.destroy
        puts "Destroyed."
      else
        puts "Aborted."
      end
    end

  end

end
