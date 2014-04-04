## billow

Minimalist generic deployment tool.

- Version: **0.1**

#### Usage

```
$ billow
Usage:

       create-server <env> <template>
      destroy-server <server>
        list-servers [<env>]
          run-script <server> <script>
          ssh-server <server>

    -h, --help                       Display this screen
    -v, --version                    Show version
```

```
$ billow list-servers
```

```
$ billow create-server staging web
Created "staging-web-1".
```

```
$ billow list-servers
  staging-web-1  107.170.80.230  new
```

```
$ billow run-script staging-web-1 provision
Running provision on staging-web-1...
Copying resources/files/web.conf.erb -> /etc/init/web.conf
Copying resources/files/nginx.conf -> /etc/init/nginx.conf
Copying resources/scripts/setup_new_server.sh -> /home/webapp/setup_new_server.sh
Copying resources/scripts/upgrade_server.sh -> /home/webapp/upgrade_server.sh
Running /home/webapp/setup_new_server.sh
---------------------------
++ echo hello world

hello world

Success!
```

#### How it works

Most of the interesting functionality is in `run-script`. Here's
roughly what it does:

- copies all your files into a temp directory,
- renames them to their remote paths,
- templates any individual files that end with .erb,
- gzips them,
- scps this to the server,
- extracts them into their (absolute) destinations,
- runs whatever scripts you've chosen

#### Setup

Put this in `billow_config.yml':

```yaml
cloud:  # NOTE: this just gets passed to Fog::Compute.new
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
    ssh_key_path: resources/keys/id_rsa_digitalocean

scripts:
  provision:
    - copy: [resources/files/web.conf.erb, /etc/init/web.conf, template: true]
    - copy: [resources/files/nginx.conf, /etc/init/nginx.conf]
    - copy: [resources/scripts/setup_new_server.sh, /home/webapp/setup_new_server.sh]
    - copy: [resources/scripts/upgrade_server.sh, /home/webapp/upgrade_server.sh]
    - run: /home/webapp/setup_new_server.sh
```

Billow doesn't care where any of your files are, with the exception of
`billow_config.yml`, which it expects to be in your project's root.

Here's the relevant part of the file structure that the above sample
config assumes:

```
./my-project
|-- billow_config.yml
`-- resources
    |-- files
    |   |-- nginx.conf
    |   `-- web.conf.erb
    |-- keys
    |   |-- id_rsa_digitalocean
    |   `-- id_rsa_digitalocean.pub
    `-- scripts
        |-- setup_new_server.sh
        `-- upgrade_server.sh
```

Note: there's nothing special about the internal structure
here. Everything in this dir is referenced via `billow_config.yml`.

#### Details

Most of how it works should be self-explanatory from the examples
above. There's just a few things to keep in mind:

1. Billow assumes it's only dealing with servers it created. So it
   assumes that the name will be in the "{env}-{template}-{n}"
   format. But that's really all it assumes.

2. A `copy` line in the `scripts` section will copy all the files from
   the local paths (relative to the project root) to the remote
   *absolute* path, creating directories as needed.

3. If a `copy` line has a third entry of `template: true`, then it
   will be run through ERB. The context will have access to `server`
   representing the Fog server, `cloud` representing the Fog::Compute
   instance, and `configs` representing your configs (via
   [figgy](https://github.com/pd/figgy)). Also, each Fog server has
   two new methods: `env` and `template`. NOTE: if you only specified
   a directory, and it happens to contain `.erb` files, they won't be
   templated.

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
   just creates a new server based on the given template.

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
