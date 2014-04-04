require_relative '../command'
require 'tmpdir'
require 'fileutils'
require 'erb'

module Billow

  class RunScript < Billow::Command

    BILLOW_DIR = '__billow__'

    def call(server_name, script_name)
      server = get_server(server_name)
      script = get_script(script_name)

      tmpdir = Dir.mktmpdir('billow') # /tmp/billow
      fakeremote_dir = File.join(tmpdir, BILLOW_DIR) # /tmp/billow/__billow__

      template = config.templates[server.template]
      ssh_key_path = template[:ssh_key_path]
      server.private_key_path = ssh_key_path

      Dir.mkdir(fakeremote_dir)

      script.each do |thing|
        type, data = *thing.first

        case type.to_sym
        when :copy
          local, remote, opts = *data
          puts "Copying #{local} -> #{remote}"

          local_file = File.join(Dir.pwd, local)
          remote_file = File.join(fakeremote_dir, remote)

          # TODO: fail unless File.exists?(local_file)

          is_template = opts && opts.template

          FileUtils.mkdir_p File.dirname(remote_file)
          FileUtils.cp_r local_file, remote_file, preserve: true

          if is_template
            new_contents = ERB.new(File.read(remote_file)).result(binding)
            File.open(remote_file, 'w') {|f| f.write(new_contents)}
          end

          local_zipfile = File.join(tmpdir, BILLOW_DIR) + '.tar.gz'
          remote_zipfile = "/tmp/#{BILLOW_DIR}.tar.gz"

          Dir.chdir(fakeremote_dir) { system("tar -czf #{local_zipfile} .") }

          server.scp(local_zipfile, remote_zipfile)
          server.ssh("tar -xzf #{remote_zipfile} -C /")

        when :run
          script = data
          puts "Running #{script}"

          result = server.ssh("#{script}").first

          if result.respond_to?(:status)
            puts
            puts "---------------------------"
            if result.status == 0
              puts "Success!"
            else
              puts "Failed. Exit code: #{result.status}"
            end
          end

        end

      end

    end

  end

end
