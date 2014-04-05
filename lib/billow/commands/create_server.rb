require_relative '../command'

module Billow

  class CreateServer < Billow::Command

    def call(env_name, type_name)
      env = get_env(env_name)
      type = get_type(type_name)

      image = cloud.images.find{|image| image.name == type[:image]}
      region = cloud.regions.find{|region| region.name == type[:region]}
      flavor = cloud.flavors.find{|flavor| flavor.name == type[:flavor]}
      ssh_key = cloud.ssh_keys.find{|ssh_key| ssh_key.name == type[:ssh_key]}

      servers = cloud.servers
      name = make_unique_server_name(env_name, type_name, servers)

      cloud.servers.create(name: name,
                           flavor_id: flavor.id,
                           image_id: image.id,
                           region_id: region.id,
                           ssh_key_ids: [ssh_key.id],
                           private_networking: true)

      puts "Created \"#{name}\"."
    end

    def make_unique_server_name(env_name, type_name, servers)
      i = 1

      loop do
        name = "#{env_name}-#{type_name}-#{i}"
        if servers.find{|s|s.name == name}
          i += 1
        else
          return name
        end
      end
    end

  end

end
