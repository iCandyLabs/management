require_relative '../lib/billow'
require 'fakefs/spec_helpers'
require 'net/scp'


SIMPLE_CONFIG = <<CONFIG
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
CONFIG


require 'stringio'

def silence_stdout
  old = $stdout
  $stdout = StringIO.new
  yield
  $stdout = old
end

def silence_stderr
  old = $stderr
  $stderr = StringIO.new
  yield
  $stderr = old
end

def silence_stdouterr
  silence_stdout { silence_stderr { yield } }
end


describe 'billow' do

  include FakeFS::SpecHelpers

  before(:each) do
    Fog.mock!
    Fog::Mock.reset
    FileUtils.mkdir_p('/tmp/billow')
    Dir.stub(:mktmpdir).with('billow').and_return('/tmp/billow')
    Dir.mkdir('resources')
    File.open('billow_config.yml', 'w') { |f| f.write(SIMPLE_CONFIG) }
    File.open('resources/web.conf.erb', 'w') { |f| f.write("env = <%= server.env %>") }
    File.open('resources/testing.sh', 'w') { |f| f.write("echo hello > world") }
    File.open('resources/my-ssh-key', 'w') { |f| f.write("foobar") }
  end

  let(:storage) { Fog::Compute.new(provider: "AWS",
                                   aws_access_key_id: "123",
                                   aws_secret_access_key: "456",
                                   region: "New York 1") }

  describe Billow::RunScript do

    it "uploads files (templating as needed) and runs scripts on the remote server" do
      pending

      storage.servers.create(name: 'staging-web-7', image_id: 2676, region_id: 1, flavor_id: 33)

      subject.should_receive(:system).with('find . \\( -type f -or -type d -empty \\) -exec tar -czf /tmp/billow/__billow__.tar.gz {} +').twice

      subject.call 'staging-web-7', 'testing'

      Dir.entries('/tmp/billow/__billow__').should == ['.', '..', 'etc']
      File.read('/tmp/billow/__billow__/etc/init/web.conf').should == "env = staging"

      scp = storage.servers.first.scp('foo', 'bar').first
      ssh1, ssh2, ssh3 = *storage.servers.first.ssh('foo')

      [scp, ssh1, ssh2, ssh3].each do |thing|
        thing[:options][:key_data].should == ['foobar']
        thing[:options][:auth_methods].should == ['publickey']
      end

      scp[:local_path].should == '/tmp/billow/__billow__.tar.gz'
      scp[:remote_path].should == '/tmp/__billow__.tar.gz'

      ssh1[:commands].should == "tar -xzf /tmp/__billow__.tar.gz -C /"
      ssh2[:commands].should == "tar -xzf /tmp/__billow__.tar.gz -C /"
      ssh3[:commands].should == '/home/web/testing.sh'
    end

  end

  describe Billow::Command do

    it "can safely get config values" do
      expect { silence_stdouterr { subject.get_env("FAKE") } }.to raise_error SystemExit
      expect { silence_stdouterr { subject.get_env("staging") } }.to_not raise_error

      expect { silence_stdouterr { subject.get_type("FAKE") } }.to raise_error SystemExit
      expect { silence_stdouterr { subject.get_type("web") } }.to_not raise_error

      expect { silence_stdouterr { subject.get_script("FAKE") } }.to raise_error SystemExit
      expect { silence_stdouterr { subject.get_script("testing") } }.to_not raise_error
    end

  end

  describe Billow::CreateServer do

    it "creates a new server" do
      pending

      subject.call 'staging', 'web'
      servers = storage.servers
      servers.map(&:name).should == ['staging-web-1']
    end

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

end
