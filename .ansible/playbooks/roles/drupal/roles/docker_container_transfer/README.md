# transfer files from one host to another container host
Idea is to conditionnally transfer files on docker volumes, 
using docker itself on macosx or direct access to volumes path on Linux.

When using docker, we sync first files on a local intermediate folder 
and move then files inside the final docker volumes.

See also drupal/default/main.yml for full list of options in the teleport section

```yaml
globals variables:
  teleport_wd: working directory for docker compose
  teleport_dc: docker compose command to use
  teleport_reset_perms: reset perms true/false
  teleport_dryrun: dryrun
  teleport_owner: owner to chown to
  teleport_group: group to chown to
  teleport_rsynccmd: rsync cmd (default rsync)
  teleport_rsync_args: args to give to rsync
  teleport_rsync_extra_args: extra args to give to rsync (default blank)
  teleport_sshargs: ssh args (-e) to give to rsync
  teleport_sshcmd: ssh cmd (default ssh)
  teleport_ssh_key_path: ssh key to use connecting
  teleport_items: [] list of dict describing what to transfer
```


`teleport_items` has this form:
```yaml
teleport_items:
  myitem:
    origin_path: origin FS location to sync
    container: container to hook inside to transfer files
    container_path: container path to sync with
    owner: default global
    group: default global
    rsync_args: default global
    rsync_extra_args: default global
    rsynccmd: default global
    sshcmd: default global
    sshargs: default global
    reset_perms: default global
    ssh_key_path: default global
```

You have to define them in the defaults / inventory of your ansible setup, as defaults can collide, that's why there are not defaults in this role

Sane defaults look like

```yaml
teleport_origin: ansibleGroupWithOneHost1
teleport_destination: ansibleGroupWithOneHost2
teleport_origin_host:  myOriginAnsiblegroupWithOneServer
teleport_host: myDestinationAnsiblegroupWithOneServer
teleport_wd: "{{playbook_dir|copsf_dirname|copsf_dirname}}"
# or teleport_wd: /srv/docker/myapp
teleport_dc: docker-compose -p myproject -f compo1.yml -f compo2.yml
# or teleport_dc: docker-compose
teleport_ssh_key_path: ~/.ssh/my.app.id_rsa
teleport_ssh_key_path: null
teleport_owner: myuser
teleport_group: "{{teleport_owner}}"
teleport_rsync_extra_args: "-azv --delete --delete-after"
teleport_reset_perms: true
teleport_sshcmd: ssh
teleport_rsynccmd: rsync
- set_fact:
   teleport_owner: myuser
   teleport_group: mygroup
```

Example call
```yaml
- include_role: {name: corpusops.roles/docker_container_transfer}
  vars:
    teleport_items:
      # using docker container hook
      proddirectory:
      origin_path: /srv/foo/prod/
      container: drupal
      container_path: /code/data/prod/
```
