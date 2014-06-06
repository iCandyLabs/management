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

      type = config[:types][server.type.to_sym]
      ssh_key_path = type[:ssh_key_path]
      server.private_key_path = ssh_key_path

      script.each do |thing|
        type, data = *thing.first

        case type.to_sym
        when :copy

          local, remote, opts = *data
          puts "Copying #{local} -> #{remote}"

          begin FileUtils.rm_rf(fakeremote_dir) rescue Exception end
          Dir.mkdir(fakeremote_dir)

          local_file = File.join(Dir.pwd, local) # ./resources/web.conf.erb
          remote_file = File.join(fakeremote_dir, remote) # /tmp/billow/__billow__/etc/init/web.conf

          # TODO: fail unless File.exists?(local_file)

          is_template = opts && opts[:template]

          FileUtils.mkdir_p File.dirname(remote_file) # /tmp/billow/__billow__/etc/init/
          FileUtils.cp_r local_file, remote_file, preserve: true

          if is_template
            new_contents = ERB.new(File.read(remote_file)).result(binding)
            File.open(remote_file, 'w') {|f| f.write(new_contents)}
          end

          local_zipfile = File.join(tmpdir, BILLOW_DIR) + '.tar.gz' # /tmp/billow/__billow__.tar.gz
          remote_zipfile = "/tmp/#{BILLOW_DIR}.tar.gz" # /tmp/__billow__.tar.gz

          # find either the file or empty leaf directory in /tmp/billow/__billow__ and zip it into /tmp/billow/__billow__.tar.gz
          Dir.chdir(fakeremote_dir) { system("find . \\\( -type f -or -type d -empty \\\) -exec tar -czf #{local_zipfile} {} +") }

          server.scp(local_zipfile, remote_zipfile) # copy /tmp/billow/__billow__.tar.gz to remote /tmp/__billow__.tar.gz
          server.ssh("tar -xzf #{remote_zipfile} -C /")

          if chown = opts && opts[:chown]
            server.ssh("chown -R #{chown} #{remote}")
          end

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
