require_relative '../../command'

module Management

  module Server

    class Destroy < Management::Command

      include Management::Helper

      def run(*server_names)
        servers = server_names.map{|server_name| get_server(server_name)}

        puts "You are about to delete the following servers:"
        puts ['', *servers.map{ |server| " - #{server.name}" }, '', ''].join("\n")

        print "Are you sure you want to do this? Type 'Yes' to continue, or anything else to abort: "
        abort "Aborted." if $stdin.gets.chomp != 'Yes'

        servers.each do |server|
          puts "Destroying #{server.name}..."
          server.destroy
          puts "Done."
        end
      end

    end

  end

end
