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

      puts "Running #{script_name} on #{server_name}..."

      tmpdir = Dir.mktmpdir('billow')
      fakeremote_dir = File.join(tmpdir, BILLOW_DIR)

      template = config.templates[server.template]
      ssh_key_path = template[:ssh_key_path]
      server.private_key_path = ssh_key_path

      Dir.mkdir(fakeremote_dir)

      script.copy_files.each do |local, remote|
        local_file = File.join(Dir.pwd, local)
        remote_file = File.join(fakeremote_dir, remote)

        # TODO: fail unless File.exists?(local_file)

        is_template = local_file.end_with?('.erb')

        puts "Copying #{local} to #{remote}#{' and templating' if is_template} ..."

        FileUtils.mkdir_p File.dirname(remote_file)
        FileUtils.cp_r local_file, remote_file, preserve: true

        if is_template
          new_contents = ERB.new(File.read(remote_file)).result(binding)
          File.open(remote_file, 'w') {|f| f.write(new_contents)}
        end
      end

      local_zipfile = File.join(tmpdir, BILLOW_DIR) + '.tar.gz'
      remote_zipfile = "/tmp/#{BILLOW_DIR}.tar.gz"

      Dir.chdir(fakeremote_dir) { system("tar -czf #{local_zipfile} .") }

      server.scp(local_zipfile, remote_zipfile)
      server.ssh("tar -xzf #{remote_zipfile} -C /")

      script.run_scripts.each do |path|
        puts "Running #{path} remotely ...\n"

        result = server.ssh("#{path}").first

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
