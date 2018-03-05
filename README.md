# backups-cli

[![Build Status](https://travis.schibsted.io/spt-payment/backups-cli.svg?token=up4siHpqEe3uNvEPryNi&branch=master)](https://travis.schibsted.io/spt-payment/backups-cli)

This tool backups different data sources to S3.


# Usage

To see all available commands run the tool with no options:

```
% ./bin/backups
Commands:
  backups crontab         # Shows the crontab config
  backups help [COMMAND]  # Describe available commands or one specific command
  backups install         # Sets up the crontab for all jobs
  backups ls              # Lists all the configured jobs
  backups show [JOB]      # Shows the merged config (for a JOB or them all)
  backups start [JOB]     # Starts a backup JOB or all of them
  backups verify JOB      # Restores and verifies a backup JOB
  backups version         # Show current version

```

### Configuration

The look up directories for the configs are, in order:

  - The value in the `BACKUPS_CONFIG_DIR` env variable
  - `${HOME}/.backups-cli`
  - `/etc/backups-cli`

The config directory will be the first it can find. All `*.yaml` files under
that directory will be loaded. You might find useful to organise backups into
subfolders. You can inline `BACKUPS_CONFIG_DIR` to override existing file system
directories:

    BACKUPS_CONFIG_DIR="/opt/my-backups" ./bin/backups start local-mysql


### List all jobs

To list all defined jobs call the `ls` command:

```
$ ./bin/backups ls
JOB          CRONTAB    INSTALL  ENABLED
local-mysql  0 4 * * *  true     true
minimal      0 4 * * *  true     true
```

`INSTALL` refers if a job will be installed on the crontab and `ENABLED` if it
can be run. You can run manually not installed jobs but the script will refuse
to start disabled jobs.


### Show one job details

Use the command `show` to print out json details about all the details for a
job. Note that the details presented here show the job as perceived from the
script, meaning when all the defaults have been merged. Leave the `job` argument
out to show the whole config after the app has processed all yaml files and
applied the defaults. The merge pattern is:

- Deep merge any local `default` settings into all jobs entries in the same file
- Finally deep merge the top `default` entry (in the `main.yaml` file)

These merges mean you can provide global and file fallbacks (local settings
prevail), which means you can organise the backup config files by env/adapter
type or any way you fancy.


```json
$ ./bin/backups show local-mysql | jq .
{
  "s3": {
    "bucket": "acme-productions-backups",
    "path": "local/mysql"
  },
  "encryption": {
    "secret": "pass"
  },
  "tags": {
    "env": "local",
    "new": null
  },
  "type": "mysql",
  "backup": {
    "connection": {
      "username": "root",
      "password": "root"
    }
  },
  "_name": "mysql-local",
  "_file": "/Users/pedro/.backups-cli/local/mysql.yaml"
}
```

### Add a new job

Here's the minimal backup config needed:

```yaml
  ---
  jobs:
    my-fancy-backup:
      type: mysql
```

Here's a more reasonable example of job (they go under the tops `jobs` entry):

```yaml
---
jobs:
  acme-productions:
    type:             mysql
    tags:
      env:            local
      type:           test
    s3:
      bucket:         acme-dumps
      path:           production/mysql
    backup:
      connection:
        host:         localhost
        username:     backup
        password:     password
      crontab:
        hour:         "*/4"
```

Note the lack of the leading and trailing slashes in the S3 path configs. The
only required parameter is the `type`. All others parameters depend either on
the adapter itself or are defaulted from the `backups.defaults` entry.

Tags are metadata associated with a job and are passed to listeners, like
Datadog or Slack. To remove a defaulted tag simply set it to `null`.


### Run a job

Run `./bin/backup` with the command `start` and pass a job name:

    ./bin/backups start <job>

The `<job>` parameter should exist somewhere on some yaml file within
config directory under the entry `jobs`. Look into `config/jobs-example.yaml`
for inspiration. For our example:

    ./bin/backups start local-mysql

The backups comes with a dry-run mode that you can use to preview what it would
execute in a real run:

    ./bin/backups start local-mysql --dry-run

Backups are encrypted if you set the `encryption.secret` setting.

Sending to S3 is done when the `s3.bucket` setting is set and the setting
`s3.active` is not explicitly set to `false`.


### Install the crontab

Run the command `install` to loop through the configured job and set a crontab
job for each of them

    ./bin/backups install

If you want to add a custom job but not install it you need to set the field
`backup.crontan.install` to `false` in the crontab settings for that backup job:

```yaml
  acme-productions:
    type:           mysql
    enabled:        false
    backup:
      crontab:
        install:    false
        hour:       0
```

This config shows also where to disable the job. It's the `enabled` setting
directly under the job.

### Development

Create the file `/etc/backups-cli/main.yaml`

```yaml
---
backups:
  paths:
    backups:        /tmp/backups
    verify:         /tmp/verify
  listeners:
    slack:
      webhook:      https://hooks.slack.com/services/X/Y/Z
      channel:      spt-payment-backups
      _active:       false
      _events:
        - _start
        - error
    datadog:
      api_key:      x
      app_key:      y
  crontab:
    header:         "MAILTO=backups@spid.no\nPATH=/usr/bin:/bin:/usr/local/bin"

defaults:
  # options:
  #   cleanup:        false
  #   silent:         false
  s3:
    bucket:         740872874188-database-backups
    path:           test/mysql
    # active:         false
  encryption:
    secret:         x
  backup:
    crontab:
      prefix:       ". /etc/profile.d/proxy.sh &&"
      postfix:      "2>/dev/null"
```


### Release procedure

To release a new version of this gem you need to have the Ryubygems credentials
in place. Start with going into https://rubygems.org/profile/edit and run the
`curl -u schibsted https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials`
command they recommend there. This is the *only* step required to release a new
gem version to rubygems.

On this repo, just update the file `lib/backups/version.rb` with a bumped version
and commit all changes to the git repo. Then run:

    rake

If you need to revoke an older gem version just run:

    gem yank -v 0.5.14 backups-cli

### Known issues

The verify code runs two checks per table:

- A `CHECK TABLE <table>`
- A `SELECT COUNT(*) FROM <table>` on the table
  
The problem with the second is that the count is run after the dump and these
stats can be skewed in inserts are done after the dump. If you start to get
mismatches in this last one I suggest you use a float comparision, that is, one
that only reports if the stats are more than say 1% different.
  
