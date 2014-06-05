require_relative '../command'

module Billow

  class ListServers < Billow::Command

    def call(env_name = nil)
      env = get_env(env_name)

      cols = [
        {size: 15, title: "Name",       fn: :name },
        {size: 10, title: "State",      fn: :state },
        {size: 20, title: "IP",         fn: :public_ip_address },
        {size: 20, title: "Private IP", fn: :private_ip_address },
        {size: 10, title: "Size",       fn: :flavor_id },
        {size: 15, title: "Env",        fn: :env },
        {size: 15, title: "Type",       fn: :type },
        {size: 11, title: "EC2 ID",     fn: :id },
      ]

      format = cols.map{|c| "%-#{c[:size]}s"}.join("  ") + "\n"
      header = [format].concat(cols.map{|c|c[:title]})
      seps = [format].concat(cols.map{|c|'-' * c[:size]})

      send :printf, *header
      send :printf, *seps

      cloud.servers.each do |server|
        next if env_name && server.env != env_name

        row = [format].concat(cols.map{|c|server.send(c[:fn])})
        send :printf, *row
      end
    end

  end

end
