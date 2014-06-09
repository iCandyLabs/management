require_relative '../lib/management'
require 'fakefs/spec_helpers'
require 'stringio'
require 'pry'
require 'etc'


SampleConfig = <<EOC
cloud:
  provider: AWS
  aws_access_key_id: 123
  aws_secret_access_key: 456
  region: New York 1

envs:
  - staging
  - production

types:
  web:
    image_id: ami-1234
    flavor_id: m1.small
    key_name: my-ssh-key-name
    groups: ["web"]
    ssh_key_path: resources/my-ssh-key

scripts:
  testing:
    - copy: [resources/testing.sh, /home/web/testing.sh]
    - copy: [resources/web.conf.erb, /etc/init/web.conf, template: true]
    - run: /home/web/testing.sh
EOC


def with_stdin(s) old = $stdin; $stdin = StringIO.new(s); yield; $stdin = old end
def without_stdout old = $stdout; $stdout = StringIO.new; yield; $stdout = old end
def without_stderr old = $stderr; $stderr = StringIO.new; yield; $stderr = old end

describe 'management' do

  before { subject.define_singleton_method(:raw_yaml) { YAML.load(SampleConfig) } }

  describe Management::Command do

    describe "safely getting config values" do

      it "can get env" do
        expect { without_stderr { subject.get_env("FAKE") } }.to raise_error SystemExit
        expect { without_stderr { subject.get_env("staging") } }.to_not raise_error
      end

      it "can get type" do
        expect { without_stderr { subject.get_type("FAKE") } }.to raise_error SystemExit
        expect { without_stderr { subject.get_type("web") } }.to_not raise_error
      end

      it "can get script" do
        expect { without_stderr { subject.get_script("FAKE") } }.to raise_error SystemExit
        expect { without_stderr { subject.get_script("testing") } }.to_not raise_error
      end

    end


  end

  describe Management::RunScript do

    include FakeFS::SpecHelpers

    describe "finding relevant files to zip" do

      it "finds all files in the tree" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        File.write("/foo/bar/baz/zap", "wat")
        expect( subject.relevant_files("/") ).to eq ["./foo/bar/baz/quux", "./foo/bar/baz/zap"]
      end

      it "finds empty leaf directories in the tree" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/zap")
        expect( subject.relevant_files("/") ).to eq ["./foo/bar/baz/quux", "./foo/bar/baz/zap"]
      end

      it "returns dot files" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/.quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/.zap")
        expect( subject.relevant_files("/") ).to eq ["./foo/bar/baz/.quux", "./foo/bar/baz/.zap"]
      end

      it "returns relative filenames" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/zap")
        expect( subject.relevant_files("/foo/bar") ).to eq ["./baz/quux", "./baz/zap"]
      end

      it "returns relative filenames, even when you add a trailing slash" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/zap")
        expect( subject.relevant_files("/foo/bar/") ).to eq ["./baz/quux", "./baz/zap"]
      end

      it "requires an absolute path" do
        FileUtils.mkdir_p("/foo")
        expect{ subject.relevant_files("foo") }.to raise_error SystemExit
      end

    end

    describe "copying files over" do

      let(:server) { Object.new }

      before(:each) do

        # just copy_r the given directory's contents into a new temp dir
        # and put the filename of that new temp dir into out_file
        subject.define_singleton_method(:zip_relevant_files) do |in_dir, out_file|
          zip_dir = Dir.mktmpdir("fake-local-zip-dir")
          FileUtils.cp_r Dir[File.join(in_dir, "*")], zip_dir
          File.write(out_file, zip_dir)
        end

        server.define_singleton_method(:name) { "server-1" }
        server.define_singleton_method(:env) { "staging" }

        # local just contains the name of a dir containing all the files
        server.define_singleton_method(:copy_file) do |local, remote|
          # copying "local" zip file to "remote" zip file
          fake_remote = File.join("/fake-remote-dir", remote)
          FileUtils.cp local, fake_remote
        end

        # just cp_r the files under fake-zip-dir into /fake-remote-dir
        server.define_singleton_method(:extract_tar) do |remote|
          tar_dir = File.read(File.join("/fake-remote-dir", remote))
          FileUtils.cp_r(File.join(tar_dir, "*"), "/fake-remote-dir")
        end

        server.define_singleton_method(:chown_r) do |remote, chowner|
          user, group = chowner.split(":")
          FileUtils.chown_R(user, group, File.join("/fake-remote-dir", remote))
        end

      end

      it "copies file contents into their remote paths" do
        File.write("foo", "the contents of foo")
        without_stdout { subject.copy_file(server, "foo", "/remote/foo") }
        expect( File.read("/fake-remote-dir/remote/foo") ).to eq "the contents of foo"
      end

      it "templates files correctly" do
        File.write("foo", "the contents of <%= server.env %>")
        without_stdout { subject.copy_file(server, "foo", "/remote/foo", template: true) }
        expect( File.read("/fake-remote-dir/remote/foo") ).to eq "the contents of staging"
      end

      it "chowns files correctly when specified" do
        user = Etc.passwd.name
        group = Etc.group.name

        File.write("foo", "hello world")
        without_stdout { subject.copy_file(server, "foo", "/remote/foo", chown: "#{user}:#{group}") }

        stats = File.stat("/fake-remote-dir/remote/foo")
        expect( Etc.getpwuid(stats.uid).name ).to eq user
        expect( Etc.getgrgid(stats.gid).name ).to eq group
      end

      it "doesn't chown anything unless specified" do
        File.write("foo", "hello world")
        without_stdout { subject.copy_file(server, "foo", "/remote/foo") }

        stats = File.stat("/fake-remote-dir/remote/foo")
        expect( Etc.getpwuid(stats.uid).name ).to eq `id -un`.chomp
        expect( Etc.getgrgid(stats.gid).name ).to eq `id -gn`.chomp
      end

      it "fails if multiple local paths don't exist" do
        script = subject.get_script("testing")
        list = subject.missing_local_files(script)
        expect(list).to eq ["resources/testing.sh", "resources/web.conf.erb"]
      end

      it "fails if a single local path doesn't exist" do
        FileUtils.mkdir_p "resources"
        File.write "resources/testing.sh", "hello world"
        script = subject.get_script("testing")
        list = subject.missing_local_files(script)
        expect(list).to eq ["resources/web.conf.erb"]
      end

    end

  end

  describe Management::CreateServer do

    it "uses unique names for servers" do
      fake_server = Struct.new(:name)
      servers = [fake_server.new('staging-web-1'),
                 fake_server.new('production-web-1'),
                 fake_server.new('staging-web-2')]

      expect( subject.make_unique_server_name("staging", "web", []) ).to eq "staging-web-1"
      expect( subject.make_unique_server_name("staging", "web", servers) ).to eq "staging-web-3"
      expect( subject.make_unique_server_name("production", "web", servers) ).to eq "production-web-2"
    end

  end

  describe Management::DestroyServer do

    let(:server) { Object.new }
    before do
      s = server # lol Ruby
      subject.define_singleton_method(:get_server) { |arg| return s if arg == "server-1" }
    end

    it "destroys the given server if you type 'Yes' verbatim" do
      expect(server).to receive(:destroy).once
      with_stdin("Yes\n") { without_stdout { subject.call("server-1") } }
    end

    it "does not destroy the given server if you don't type 'Yes' verbatim" do
      expect(server).not_to receive(:destroy)
      without_stdout do
        with_stdin("yes\n") { subject.call("server-1") }
        with_stdin("Y\n") { subject.call("server-1") }
        with_stdin("y\n") { subject.call("server-1") }
        with_stdin("yep\n") { subject.call("server-1") }
        with_stdin("\n") { subject.call("server-1") }
        with_stdin("YES\n") { subject.call("server-1") }
        with_stdin("Yes.\n") { subject.call("server-1") }
      end
    end

  end

  describe Management::StopServer do

    let(:server) { Object.new }
    before do
      s = server # lol Ruby
      subject.define_singleton_method(:get_server) { |arg| return s if arg == "server-1" }
    end

    it "stops the given server" do
      expect(server).not_to receive(:destroy)
      expect(server).to receive(:stop).once
      without_stdout { subject.call("server-1") }
    end

  end

end
