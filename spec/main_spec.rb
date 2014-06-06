require_relative '../lib/billow'
# require 'fakefs/spec_helpers'
# require 'net/scp'
require 'stringio'


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

  # include FakeFS::SpecHelpers

  # before(:each) do
  #   Fog.mock!
  #   Fog::Mock.reset
  #   FileUtils.mkdir_p('/tmp/billow')
  #   Dir.stub(:mktmpdir).with('billow').and_return('/tmp/billow')
  #   Dir.mkdir('resources')
  #   File.open('billow_config.yml', 'w') { |f| f.write(SIMPLE_CONFIG) }
  #   File.open('resources/web.conf.erb', 'w') { |f| f.write("env = <%= server.env %>") }
  #   File.open('resources/testing.sh', 'w') { |f| f.write("echo hello > world") }
  #   File.open('resources/my-ssh-key', 'w') { |f| f.write("foobar") }
  # end

  describe Billow::RunScript do

    # loop through every line in the given script
    #
    # if its a run line:
    #   execute the line literally on the server
    #
    # if it's a copy line:
    #   copy it to a temporary dir with in a subpath based on the remote-absolute-path
    #   tar it up relative the the remote-absolute-path
    #   copy the tar file to somewhere remote in /tmp
    #   delete the local tar file
    #   untar it remotely relative to /
    #   delete the remote tar file

    it "uploads files (templating as needed) and runs scripts on the remote server" do
      pending

      # storage.servers.create(name: 'staging-web-7', image_id: 2676, region_id: 1, flavor_id: 33)

      # subject.should_receive(:system).with('find . \\( -type f -or -type d -empty \\) -exec tar -czf /tmp/billow/__billow__.tar.gz {} +').twice

      # subject.call 'staging-web-7', 'testing'

      # Dir.entries('/tmp/billow/__billow__').should == ['.', '..', 'etc']
      # File.read('/tmp/billow/__billow__/etc/init/web.conf').should == "env = staging"

      # scp = storage.servers.first.scp('foo', 'bar').first
      # ssh1, ssh2, ssh3 = *storage.servers.first.ssh('foo')

      # [scp, ssh1, ssh2, ssh3].each do |thing|
      #   thing[:options][:key_data].should == ['foobar']
      #   thing[:options][:auth_methods].should == ['publickey']
      # end

      # scp[:local_path].should == '/tmp/billow/__billow__.tar.gz'
      # scp[:remote_path].should == '/tmp/__billow__.tar.gz'

      # ssh1[:commands].should == "tar -xzf /tmp/__billow__.tar.gz -C /"
      # ssh2[:commands].should == "tar -xzf /tmp/__billow__.tar.gz -C /"
      # ssh3[:commands].should == '/home/web/testing.sh'
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

    it "stops the given server if you type 'Yes' verbatim" do
      server.should_not_receive(:destroy)
      server.should_receive(:stop).once
      without_stdout { with_stdin("Yes\n") { subject.call("server-1") } }
    end

    it "does not stop the given server if you don't type 'Yes' verbatim" do
      server.should_not_receive(:destroy)
      server.should_not_receive(:stop)
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

end
