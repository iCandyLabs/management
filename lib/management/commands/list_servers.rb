require_relative '../command'

module Management

  class ListServers < Management::Command

    include Management::Helper

    def run(env_name = nil)
      env = get_env(env_name)

      cols = [
        {size: 20, title: "Name",       field: :name },
        {size: 10, title: "State",      field: :state },
        {size: 20, title: "IP",         field: :public_ip_address },
        {size: 20, title: "Private IP", field: :private_ip_address },
        {size: 10, title: "Size",       field: :flavor_id },
        {size: 15, title: "Env",        field: :env },
        {size: 15, title: "Type",       field: :type },
        {size: 11, title: "EC2 ID",     field: :id },
      ]

      format = cols.map{|c| "%-#{c[:size]}s"}.join("  ") + "\n"

      send :printf, *([format].concat(cols.map{|c|c[:title]}))
      send :printf, *([format].concat(cols.map{|c|'-' * c[:size]}))

      servers = cloud.servers.sort_by(&:name)

      servers.each do |server|
        next if env_name && server.env != env_name
        next if server.state == 'terminated'

        send :printf, *([format].concat(cols.map{|c|server.send(c[:field])}))
      end
    end

  end

end
