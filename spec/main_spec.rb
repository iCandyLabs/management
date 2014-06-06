require_relative '../lib/billow'
require 'fakefs/spec_helpers'
# require 'net/scp'
require 'stringio'
require 'pry'


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

    describe "copying files over" do

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

      it "copies file contents into their remote paths" do
        File.write("foo", "the contents of foo")

        remote_files = {}
        extracted_files = []
        # chowned_files = []

        file_contents = {}

        subject.define_singleton_method(:zip_relevant_files) do |in_dir, out_file|
          names = self.relevant_files(in_dir)

          # add the file contents to check later, when mapping from the remote tar
          names.each do |name|
            file_contents[name] = File.read(File.join(in_dir, name))
          end

          # add a line to prove that this method created this tar file
          names.unshift "[fake tar list]"
          File.write(out_file, names.join(" - "))
        end

        server = Object.new

        server.define_singleton_method(:name) { "server-1" }

        server.define_singleton_method(:copy_file) do |local, remote|
          # copying the tar file just puts its contents into a hash representing the remote
          remote_files[remote] = File.read(local)
        end

        server.define_singleton_method(:extract_tar) do |remote|
          # "extract" the tar file's contents into a list
          extracted_files << remote_files[remote]
        end

        server.define_singleton_method(:chown_r) do |remote, chowner|
          # unused in this test (TODO: move into its own test)
          # chowned_files << [remote, chowner]
        end

        # without_stdout {
        subject.copy_file(server, "foo", "/remote/foo")
        # }

        extracted_files.should == ["[fake tar list] - ./remote/foo"]

        # get the filenames individually (we don't need the proof-line anymore)
        file_list = extracted_files.first.split(" - ").drop(1)

        file_list.map{ |path| file_contents[path] }.should == ["the contents of foo"]
      end

      it "templates files correctly" do
        pending
        # File.write('resources/web.conf.erb', "env = <%= server.env %>")
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
