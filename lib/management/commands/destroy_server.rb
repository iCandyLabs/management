require_relative '../command'

module Management

  class DestroyServer < Management::Command

    include Management::Helper

    def run(server_name)
      server = get_server(server_name)

      print "Are you sure you want to do this? Type 'Yes' to continue, or anything else to abort: "
      answer = $stdin.gets.chomp

      if answer == 'Yes'
        puts "Destroying #{server_name}..."
        server.destroy
        puts "Done."
      else
        puts "Aborted."
      end
    end

  end

end
