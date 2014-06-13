require_relative '../../command'

module Management

  module Address

    class List < Management::Command

      include Management::Helper

      def run()
        servers = live_servers

        cols = [
                {size: 20, title: "IP",         fn: ->(addr){ addr.public_ip } },
                {size: 20, title: "Server",     fn: ->(addr){ s = servers.find{|server| server.id == addr.server_id }; s ? s.name : "n/a" } },
                {size: 30, title: "Name",       fn: ->(addr){ a = config[:addresses].find{|k, v| v == addr.public_ip}; a ? a.first : "n/a" } },
                {size: 15, title: "Status",     fn: ->(addr){ s = servers.find{|server| server.id == addr.server_id }; s ? s.state : "n/a" } },
               ]

        format = cols.map{|c| "%-#{c[:size]}s"}.join("  ") + "\n"

        send :printf, *([format].concat(cols.map{|c|c[:title]}))
        send :printf, *([format].concat(cols.map{|c|'-' * c[:size]}))

        cloud.addresses.each do |address|
          send :printf, *([format].concat(cols.map{|c|c[:fn].call address}))
        end
      end

    end

  end

end
