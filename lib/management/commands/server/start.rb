require_relative '../../command'

module Management

  module Server

    class Start < Management::Command

      include Management::Helper

      def run(server_name)
        server = get_server(server_name)
        puts "Starting #{server_name}..."
        server.start
        puts "Done."
      end

    end

  end

end
