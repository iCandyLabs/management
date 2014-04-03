### billow

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

$ billow list-servers
Running task "list-servers"...


$ billow create-server staging web
Running task "create-server"...

Created "staging-web-1".

$ billow list-servers
Running task "list-servers"...

  staging-web-1  107.170.80.230  new

$ billow run-script staging-web-1 provision
Running task "run-script"...

Running provision on staging-web-1...
Copying resources/files/web.conf.erb to /etc/init/web.conf and templating ...
Copying resources/files/nginx.conf to /etc/init/nginx.conf ...
Copying resources/scripts/setup_new_server.sh to /home/webapp/setup_new_server.sh ...
Copying resources/scripts/upgrade_server.sh to /home/webapp/upgrade_server.sh ...
Running /home/webapp/setup_new_server.sh remotely ...
---------------------------
Success!
```

#### Setup

Put this in `resources/config.yml':

```yaml
cloud: # this just gets passed to Fog::Compute.new
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
    copy_files:
      - [resources/files/web.conf.erb, /etc/init/web.conf] # this will get templated via ERB
      - [resources/files/nginx.conf, /etc/init/nginx.conf]
      - [resources/scripts/setup_new_server.sh, /home/webapp/setup_new_server.sh]
      - [resources/scripts/upgrade_server.sh, /home/webapp/upgrade_server.sh]
    run_scripts:
      - /home/webapp/setup_new_server.sh
```

Billow assumes everything relevant is in `./resources/`:

```
resources/
|-- config.yml
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
here. Everything in this dir is referenced via `config.yml`.

#### Details

Most of how it works should be self-explanatory from the examples
above. There's just a few things to keep in mind:

1. Billow assumes it's only dealing with servers it created. So it
   assumes that the name will be in the "{env}-{template}-{n}"
   format. But that's really all it assumes.

2. The `copy_files` section of a script will copy all the files from
   the local paths (relative to the project root) to the remote
   *absolute* path, creating directories as needed.

3. The `copy_files` section will template any *individual* files whose
   local path end in `.erb`, using ERB. The context will have access
   to `server` representing the Fog server, `cloud` representing the
   Fog::Compute instance, and `configs` representing your configs (via
   [figgy](https://github.com/pd/figgy)). Also, each Fog server has
   two new methods: `env` and `template`.

4. The files in `run_scripts` will be run *after* the `copy_files`
   section is done being copied over, and the paths represent the
   remote *absolute* paths. It's your responsibility to make sure
   they're executable.
