require_relative '../command'
require 'tmpdir'
require 'fileutils'
require 'erb'
require 'shellwords'

module Management

  class RunScript < Management::Command

    include Management::Helper

    def run(server_name, script_name)
      server = get_server(server_name)
      script = get_script(script_name)

      server.private_key_path = config[:types][server.type.to_sym][:ssh_key_path]

      missing = missing_local_files(script)
      abort "The following files are missing:" + (["\n"] + missing).join("\n - ") if !missing.empty?

      script.each do |tuple|
        type, data = *tuple.first

        case type.to_sym
        when :copy
          copy_file(server, *data)
        when :run
          run_remote_command(server, data)
        end

      end

    end

    def copy_file(server, local_path, remote_path, opts = nil)
      should_template = opts && opts[:template]
      custom_chown = opts && opts[:chown]

      puts "Copying #{local_path} -> #{remote_path}"

      Dir.mktmpdir('management-file-dir') do |file_tmpdir|

        # copy to the fake "remote" path locally
        remote_looking_path = File.join(file_tmpdir, remote_path)
        FileUtils.mkdir_p File.dirname(remote_looking_path)
        FileUtils.cp_r local_path, remote_looking_path, preserve: true

        # overwrite the fake "remote" file with its own templated contents if necessary
        if should_template
          new_contents = ERB.new(File.read(remote_looking_path)).result(binding)
          File.write(remote_looking_path, new_contents)
        end

        Dir.mktmpdir('management-tar-dir') do |tar_tmpdir|

          # zip this file up, starting from its absolute path
          local_tar_path = File.join(tar_tmpdir, "__management__.tar.gz")
          zip_relevant_files(file_tmpdir, local_tar_path)

          # copy tar file to remote and extract
          remote_tar_path = "/tmp/__management__.tar.gz"
          server.copy_file(local_tar_path, remote_tar_path)
          server.extract_tar(remote_tar_path)
          server.chown_r(remote_path, custom_chown) if custom_chown

        end

      end

    end

    def run_remote_command(server, cmd)
      puts "Running #{cmd}"

      result = server.ssh("#{cmd}").first

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

    def missing_local_files(script)
      script.find_all do |tuple|
        type, data = *tuple.first
        if type == :copy
          local, remote = *data
          ! File.exists?(local)
        end
      end.map do |tuple|
        type, data = *tuple.first
        local, remote = *data
        local
      end
    end

    def relevant_files(at_dir)
      abort unless at_dir.start_with? "/"

      Dir[File.join(at_dir, "**/*")].select do |path|
        File.file?(path) || (File.directory?(path) && Dir.entries(path) == [".", ".."])
      end.map do |path|
        path.slice! at_dir.end_with?("/") ? at_dir : "#{at_dir}/"
        "./#{path}"
      end
    end

    private

    def zip_relevant_files(in_dir, out_file)
      Dir.chdir(in_dir) do
        file_list = Shellwords.join(relevant_files(in_dir))
        system("tar -czf #{out_file} #{file_list}")
      end
    end

  end

end
