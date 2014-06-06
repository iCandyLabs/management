require_relative '../lib/billow'
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
    image: ami-1234
    flavor: m1.small
    key_pair_name: my-ssh-key-name
    ssh_key_path: resources/my-ssh-key
    groups: ["web"]

scripts:
  testing:
    - copy: [resources/testing.sh, /home/web/testing.sh]
    - copy: [resources/web.conf.erb, /etc/init/web.conf, template: true]
    - run: /home/web/testing.sh
EOC


def with_stdin(s) old = $stdin; $stdin = StringIO.new(s); yield; $stdin = old end
def without_stdout old = $stdout; $stdout = StringIO.new; yield; $stdout = old end
def without_stderr old = $stderr; $stderr = StringIO.new; yield; $stderr = old end

describe 'billow' do

  before { subject.stub(:raw_yaml).and_return(YAML.load(SampleConfig)) }

  describe Billow::Command do

    it "can safely get config values" do
      expect { without_stderr { subject.get_env("FAKE") } }.to raise_error SystemExit
      expect { without_stderr { subject.get_env("staging") } }.to_not raise_error

      expect { without_stderr { subject.get_type("FAKE") } }.to raise_error SystemExit
      expect { without_stderr { subject.get_type("web") } }.to_not raise_error

      expect { without_stderr { subject.get_script("FAKE") } }.to raise_error SystemExit
      expect { without_stderr { subject.get_script("testing") } }.to_not raise_error
    end

  end

  describe Billow::RunScript do

    include FakeFS::SpecHelpers

    describe "finding relevant files to zip" do

      it "finds all files in the tree" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        File.write("/foo/bar/baz/zap", "wat")
        subject.relevant_files("/").should == ["./foo/bar/baz/quux", "./foo/bar/baz/zap"]
      end

      it "finds empty leaf directories in the tree" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/zap")
        subject.relevant_files("/").should == ["./foo/bar/baz/quux", "./foo/bar/baz/zap"]
      end

      it "returns dot files" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/.quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/.zap")
        subject.relevant_files("/").should == ["./foo/bar/baz/.quux", "./foo/bar/baz/.zap"]
      end

      it "returns relative filenames" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/zap")
        subject.relevant_files("/foo/bar").should == ["./baz/quux", "./baz/zap"]
      end

      it "returns relative filenames, even when you add a trailing slash" do
        FileUtils.mkdir_p("/foo/bar/baz")
        File.write("/foo/bar/baz/quux", "woot")
        FileUtils.mkdir_p("/foo/bar/baz/zap")
        subject.relevant_files("/foo/bar/").should == ["./baz/quux", "./baz/zap"]
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
        File.read("/fake-remote-dir/remote/foo").should == "the contents of foo"
      end

      it "templates files correctly" do
        File.write("foo", "the contents of <%= server.env %>")
        without_stdout { subject.copy_file(server, "foo", "/remote/foo", template: true) }
        File.read("/fake-remote-dir/remote/foo").should == "the contents of staging"
      end

      it "chowns files correctly when specified" do
        File.write("foo", "hello world")
        # without_stdout {
          subject.copy_file(server, "foo", "/remote/foo", chown: "root:nobody")
        # }

        stats = File.stat("/fake-remote-dir/remote/foo")
        Etc.getpwuid(stats.uid).name.should == "root"
        Etc.getgrgid(stats.gid).name.should == "nobody"
      end

    end

  end

  describe Billow::CreateServer do

    it "uses unique names for servers" do
      fake_server = Struct.new(:name)
      servers = [fake_server.new('staging-web-1'),
                 fake_server.new('production-web-1'),
                 fake_server.new('staging-web-2')]

      subject.make_unique_server_name("staging", "web", []).should == "staging-web-1"
      subject.make_unique_server_name("staging", "web", servers).should == "staging-web-3"
      subject.make_unique_server_name("production", "web", servers).should == "production-web-2"
    end

  end

  describe Billow::DestroyServer do

    let(:server) { Object.new }
    before { subject.stub(:get_server).with("server-1").and_return(server) }

    it "destroys the given server if you type 'Yes' verbatim" do
      server.should_receive(:destroy).once
      without_stdout { with_stdin("Yes\n") { subject.call("server-1") } }
    end

    it "does not destroy the given server if you don't type 'Yes' verbatim" do
      server.should_not_receive(:destroy)
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

  describe Billow::StopServer do

    let(:server) { Object.new }
    before { subject.stub(:get_server).with("server-1").and_return(server) }

    it "stops the given server" do
      server.should_not_receive(:destroy)
      server.should_receive(:stop).once
      without_stdout { subject.call("server-1") }
    end

  end

end
