require_relative '../lib/billow'
require 'fakefs/spec_helpers'
require 'net/scp'


SIMPLE_CONFIG = <<CONFIG
cloud:
  provider: DigitalOcean
  digitalocean_api_key: 123
  digitalocean_client_id: 456

envs:
  - staging
  - production

templates:
  web:
    image: Ubuntu 12.04 x64
    region: New York 1
    flavor: 512MB
    ssh_key: my-ssh-key-name
    ssh_key_path: resources/my-ssh-key

scripts:
  testing:
    copy_files:
      - [resources/web.conf.erb, /etc/init/web.conf]
      - [resources/testing.sh, /home/web/testing.sh]
    run_scripts:
      - /home/web/testing.sh
CONFIG


describe 'billow' do

  include FakeFS::SpecHelpers

  before(:each) do
    Fog.mock!
    Fog::Mock.reset
    FileUtils.mkdir_p('/tmp/bla')
    Dir.stub(:mktmpdir).and_return('/tmp/bla')
    Dir.mkdir('resources')
    File.open('resources/config.yml', 'w') { |f| f.write(SIMPLE_CONFIG) }
    File.open('resources/web.conf.erb', 'w') { |f| f.write("env = <%= server.env %>") }
    File.open('resources/testing.sh', 'w') { |f| f.write("echo hello > world") }
    File.open('resources/my-ssh-key', 'w') { |f| f.write("foobar") }
    storage.ssh_keys.create(name: 'my-ssh-key-name', ssh_pub_key: 'bla')
  end

  let(:storage) { Fog::Compute.new(provider: "DigitalOcean",
                                   digitalocean_api_key: "123",
                                   digitalocean_client_id: "456") }

  describe Billow::RunScript do

    it "uploads files (templating as needed) and runs scripts on the remote server" do
      storage.servers.create(name: 'staging-web-7', image_id: 2676, region_id: 1, flavor_id: 33)

      subject.should_receive(:system).with('tar -czf /tmp/bla/__billow__.tar.gz .')

      subject.call 'staging-web-7', 'testing'

      File.read('/tmp/bla/__billow__/etc/init/web.conf').should == "env = staging"

      scp = storage.servers.first.scp('foo', 'bar').first
      ssh1, ssh2 = *storage.servers.first.ssh('foo')

      [scp, ssh1, ssh2].each do |thing|
        thing[:options][:key_data].should == ['foobar']
        thing[:options][:auth_methods].should == ['publickey']
      end

      scp[:local_path].should == '/tmp/bla/__billow__.tar.gz'
      scp[:remote_path].should == '/tmp/__billow__.tar.gz'

      ssh1[:commands].should == "tar -xzf /tmp/__billow__.tar.gz -C /"
      ssh2[:commands].should == '/home/web/testing.sh'
    end

  end

  describe Billow::CreateServer do

    it "creates a new server" do
      subject.call 'staging', 'web'
      servers = storage.servers
      servers.map(&:name).should == ['staging-web-1']
    end

    it "requires a valid template" do
      expect { subject.call 'staging', 'FAKE' }.to raise_error SystemExit
    end

    it "requires a valid environment" do
      expect { subject.call 'FAKE', 'web' }.to raise_error SystemExit
    end

    it "uses unique names for servers" do
      subject.call 'staging', 'web'
      subject.call 'production', 'web'
      subject.call 'staging', 'web'
      servers = storage.servers
      servers.map(&:name).should == ['staging-web-1', 'production-web-1', 'staging-web-2']
    end

  end

end
