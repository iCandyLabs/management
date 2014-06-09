## Management

Minimalist EC2 configuration & deployment tool.

- Version: **1.1**

![build status](https://travis-ci.org/sdegutis/management.svg?branch=master)

#### Install

`gem install management`

#### Usage

```
$ management
Usage: management [command] [args*]

Commands:
       create-server <env> <type>
        list-servers [<env>]
      destroy-server <server>
        start-server <server>
         stop-server <server>
          run-script <server> <script>
          ssh-server <server>

    -h, --help                       Display this screen
    -v, --version                    Show version

$ management list-servers
Name                  State       IP                    Private IP            Size        Env              Type             EC2 ID
--------------------  ----------  --------------------  --------------------  ----------  ---------------  ---------------  -----------


$ management create-server staging web
Created "staging-web-1".


$ management list-servers
Name                  State       IP                    Private IP            Size        Env              Type             EC2 ID
--------------------  ----------  --------------------  --------------------  ----------  ---------------  ---------------  -----------
staging-web-1         running     101.102.103.104       1.2.3.4               m1.large    staging          db               i-12341234


$ management run-script staging-web-1 setup-web
Copying resources/scripts/bootstrap_base.sh -> /home/webapp/bootstrap_base.sh
Running /home/webapp/bootstrap_base.sh
[...snip...]
Copying resources/files/web.conf.erb -> /etc/init/web.conf
Copying resources/files/nginx.conf -> /etc/init/nginx.conf
Copying resources/scripts/start_web_server.sh -> /home/webapp/start_web_server.sh
Running /home/webapp/start_web_server.sh
[...snip...]
```

#### Niche

The remote server only needs ssh and `tar -xzf` to be available, which
means it'll work in pretty much any linux server, out-of-the-box.

If you only need to provision and manage a handful of servers, this
project may be right for you.

#### Setup

Put this in `management_config.yml':

```yaml
cloud:  # NOTE: this just gets passed to Fog::Compute.new
  provider: AWS
  aws_access_key_id: 123
  aws_secret_access_key: 456
  region: New York 1

envs:
  - staging
  - production

types:
  web:  # NOTE: this just gets passed to compute.servers.create
    image_id: ami-1234
    flavor_id: m1.small
    key_name: my-ssh-key-name
    groups: ["web"]
    ssh_key_path: resources/my-ssh-key

scripts:
  setup-web:
    - copy: [resources/scripts/bootstrap_base.sh, /home/webapp/bootstrap_base.sh]
    - run: /home/webapp/bootstrap_base.sh
    - copy: [resources/files/web.conf.erb, /etc/init/web.conf, template: true]
    - copy: [resources/files/nginx.conf, /etc/init/nginx.conf]
    - copy: [resources/scripts/start_web_server.sh, /home/webapp/start_web_server.sh]
    - run: /home/webapp/start_web_server.sh
```

Management doesn't care where any of your files are, with the exception of
`management_config.yml`, which it expects to be in your project's
root. Here's the relevant part of the file structure that the above
sample config assumes:

```
./my-project
|-- management_config.yml
`-- resources
    |-- files
    |   |-- nginx.conf
    |   `-- web.conf.erb
    |-- keys
    |   |-- id_rsa_digitalocean
    |   `-- id_rsa_digitalocean.pub
    `-- scripts
        |-- bootstrap_base.sh
        `-- start_web_server.sh
```

#### Details

Most of how it works should be self-explanatory from the examples
above. There's just a few things that might not be obvious:

1. Management assumes it's only dealing with servers it created. So it
   assumes that the name will be in the "{env}-{type}-{n}"
   format. But that's really all it assumes.

2. A `copy` line in the `scripts` section will copy all the files from
   the local paths (relative to the project root) to the remote
   *absolute* path, creating directories as needed.

3. If a `copy` line has a third entry of `template: true`, then it
   will be run through ERB. The context will have access to `server`
   representing the Fog server, `cloud` representing the Fog::Compute
   instance, and `configs` representing your configs (YAML). Also,
   each Fog server has two new methods: `env` and `type`. NOTE: if you
   only specified a directory, and it happens to contain `.erb` files,
   they won't be templated.

4. A `run` line in a script will be run on the remote server. The
   paths represent the remote *absolute* paths. It's your
   responsibility to make sure they're executable.

5. Files specified by `run` aren't copied for you automatically; they
   should either already be on the remote server, or you should copy
   them with a `copy` line.

6. The `envs` section is strictly there to catch typos and
   wrongly-ordered arguments at the command line. You can only
   create/destroy/etc servers in a valid environment.

7. The `create-server` command doesn't run any scripts for you, it
   just creates a new server based on the given type.

8. The `scripts` section is admittedly poorly named, since each
   "script" is really an ordered list of files to copy and scripts to
   run remotely. Couldn't think of a better word for it though that
   wasn't too far out there or knee-deep in analogies. I'd love some
   suggestions.

9. A `script` line doesn't have to be a bash scripts, although that's
   the simplest way. It just needs to be something executable. TIP: if
   it's a bash script, it's a good idea to add `set -e` and `set -x`
   to the top of them.

#### Example Scripts

If you wanted to install Ruby 2 in your setup phase, you might add
this to one of your scripts
([courtesy of Brandon Hilkert](https://github.com/brandonhilkert/fucking_shell_scripts)):

```bash
sudo apt-get -y install build-essential zlib1g-dev libssl-dev libreadline6-dev libyaml-dev
cd /tmp
wget http://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz
tar -xzf ruby-2.0.0-p247.tar.gz
cd ruby-2.0.0-p247
./configure --prefix=/usr/local
make
sudo make install
rm -rf /tmp/ruby*
```

#### License

> Released under MIT license.
>
> Copyright (c) 2013 Steven Degutis
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.
