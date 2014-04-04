require_relative '../command'

module Billow

  class CreateServer < Billow::Command

    def call(env_name, template_name)
      env = get_env(env_name)
      template = get_template(template_name)

      image = cloud.images.find{|image| image.name == template[:image]}
      region = cloud.regions.find{|region| region.name == template[:region]}
      flavor = cloud.flavors.find{|flavor| flavor.name == template[:flavor]}
      ssh_key = cloud.ssh_keys.find{|ssh_key| ssh_key.name == template[:ssh_key]}

      servers = cloud.servers
      name = make_unique_server_name(env_name, template_name, servers)

      cloud.servers.create(name: name,
                           flavor_id: flavor.id,
                           image_id: image.id,
                           region_id: region.id,
                           ssh_key_ids: [ssh_key.id],
                           private_networking: true)

      puts "Created \"#{name}\"."
    end

    def make_unique_server_name(env_name, template_name, servers)
      i = 1

      loop do
        name = "#{env_name}-#{template_name}-#{i}"
        if servers.find{|s|s.name == name}
          i += 1
        else
          return name
        end
      end
    end

  end

end
