require_relative '../command'

module Management

  class CreateServer < Management::Command

    include Management::Helper

    def run(env_name, type_name)
      env = get_env(env_name)
      type = get_type(type_name)

      servers = cloud.servers
      name = make_unique_server_name(env_name, type_name, servers)

      puts "Creating \"#{name}\"..."

      cloud.servers.create(image_id: type[:image_id],
                           flavor_id: type[:flavor_id],
                           groups: type[:groups],
                           key_name: type[:key_name],
                           tags: {
                             "Creator" => current_user,
                             "CreatedAt" => Time.new.strftime("%Y%m%d%H%M%S"),
                             "Name" => name,
                             "Env" => env_name,
                             "Meal" => type_name,
                           })

      puts "Done."
    end

    def current_user
      `git config user.name`.strip
    rescue
      "unknown"
    end

    def make_unique_server_name(env_name, type_name, servers)
      (1..Float::INFINITY).each do |i|
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
