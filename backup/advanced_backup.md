# More on Backups
# Early Draft -- Under Active Development
# >>> NOT READY FOR EDITS <<<

## ROUGH NOTES -- DO NOT EDIT, AS THESE ARE JUST MY RANDOM SCRIBBLINGS

### Backup with Postgres - how to pause a service before backing it up

Create a new clan, call it CLAN-BACKUP-POSTGRES with domain clanpostgres.lol

Create three machines: alice-laptop, postgres-server, backup-server

```
clan machines create alice-laptop
clan machines create postgres-server
clan machines create backup-server
```

Create the clan.nix file. Instead of going through the whole step-by-step instructions, here is the entire clan.nix file; paste in the appropriate IP addresses and the key file contents.

[paste here]

Then gather machine info:

```
clan machines init-hardware-config alice-laptop
clan machines init-hardware-config postgres-server
clan machines init-hardware-config backup-server
```

Setup disks (repeat each one twice as usual):

```
clan templates apply disk ext4-single-disk alice-laptop --set mainDisk ""
clan templates apply disk ext4-single-disk postgres-server --set mainDisk ""
clan templates apply disk ext4-single-disk backup-server --set mainDisk ""
```

If necessary:
```
clan vars generate alice-laptop --no-sandbox
clan vars generate postgres-server --no-sandbox
clan vars generate backup-server --no-sandbox
```
[Still need to investigate: alice-laptop issues an error at the end, and it seems I need to re-run alice-laptop?]

And install:

```
clan machines install alice-laptop
clan machines install postgres-server
clan machines install backup-server
```

If using VirtualBox, remove the install disk on each machine.

Then:

ssh into Alice and create some files.



## Changing the Backup Schedule

The default schedule is 1:00 AM daily. To change it, add `startAt` to the client settings:

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines."alice-laptop" = {
      settings.startAt = "*-*-* 04:00:00";   # 4 AM daily
    };
    roles.server.machines."backup-server" = {};
  };
};
```

The schedule uses [systemd calendar event syntax](https://www.freedesktop.org/software/systemd/man/systemd.time.html).

Here are some examples of the pattern:

| Schedule | Meaning |
|----------|---------|
| `*-*-* 01:00:00` | Every day at 1 AM (default) |
| `*-*-* 04:00:00` | Every day at 4 AM |
| `*-*-* *:00:00` | Every hour |
| `Mon *-*-* 03:00:00` | Every Monday at 3 AM |


## Backup Hooks: Pre/Post Scripts

Sometimes you need to stop a service before backing up its data (to avoid corrupted files), then start it again after. Clan supports this with hooks.

Hooks are defined as part of state, not as part of the backup service, because stopping a service before a backup is really about the *data*, not the backup tool.

In the following example, the preBackupScript stops the NextCloud service. 

```nix
# machines/alice-laptop/configuration.nix
{ config, lib, ... }:
{
  clan.core.state.nextcloud = {
    folders = [ "/var/lib/nextcloud" ];

    preBackupScript = ''
      export PATH=${lib.makeBinPath [ config.systemd.package ]}
      systemctl stop phpfpm-nextcloud.service
    '';

    postBackupScript = ''
      export PATH=${lib.makeBinPath [ config.systemd.package ]}
      systemctl start phpfpm-nextcloud.service
    '';
  };
}
```

There are four hooks available:

| Hook | When It Runs |
|------|-------------|
| `preBackupScript` | Before the backup starts |
| `postBackupScript` | After the backup finishes |
| `preRestoreScript` | Before a restore starts |
| `postRestoreScript` | After a restore finishes |

## Excluding Files

You can exclude certain file patterns from backups:

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines."alice-laptop" = {
      settings.exclude = [
        "*.pyc"
        "*.tmp"
        "__pycache__"
        ".cache"
      ];
    };
    roles.server.machines."backup-server" = {};
  };
};
```

## External Backup Destinations

You don't have to back up to another Clan machine. You can add external destinations like a Hetzner Storage Box or any SSH-accessible BorgBackup server.

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines."alice-laptop" = {
      settings.destinations."storagebox" = {
        repo = "user-sub1@user-sub1.your-storagebox.de:/./borgbackup";
        rsh = "ssh -p 23 -oStrictHostKeyChecking=accept-new -i /run/secrets/vars/borgbackup/borgbackup.ssh";
      };
    };
  };
};
```

After configuring, add your Clan-generated SSH public key to the external server:

```bash
# Get the public key Clan generated
clan vars get alice-laptop borgbackup/borgbackup.ssh.pub

# For Hetzner Storage Box, you can pipe it directly:
clan vars get alice-laptop borgbackup/borgbackup.ssh.pub | ssh -p23 user-sub1@user-sub1.your-storagebox.de install-ssh-key
```

You can combine internal (server role) and external destinations. The client will back up to all of them.

## PostgreSQL Database Backups

Clan has built-in support for PostgreSQL. Instead of manually writing pre/post scripts to dump and restore databases, you can use the PostgreSQL module:

```nix
# machines/backup-server/configuration.nix
{
  clan.core.postgresql.enable = true;

  clan.core.postgresql.databases.myapp = {
    create = {
      TEMPLATE = "template0";
      ENCODING = "UTF8";
      OWNER = "myapp";
    };
    restore.stopOnRestore = [
      "myapp.service"
    ];
  };
}
```

This automatically:
- Dumps the database before each backup
- Stores the dump in the backup repository
- Stops the listed services during restore
- Recreates the database with the correct settings on restore

## A Machine Can Be Both Client and Server

A machine can back up other machines (server role) while also backing itself up somewhere else (client role). For example, your NAS stores backups from your workstations, but also backs itself up to an offsite storage box:

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines = {
      "laptop" = {};
      "desktop" = {};
      # The NAS is also a client -- it backs itself up offsite
      "nas" = {
        settings.destinations."offsite" = {
          repo = "user@offsite-server.example.com:/backups/nas";
          rsh = "ssh -i /run/secrets/vars/borgbackup/borgbackup.ssh -o StrictHostKeyChecking=accept-new";
        };
      };
    };
    roles.server.machines."nas" = {
      settings.directory = "/data/backups";
    };
  };
};
```

## Complete Examples

### Example 1: Simple Two-Machine Backup

The most basic setup -- one laptop backed up to one server.

```nix
# clan.nix
{
  inventory.machines = {
    laptop = { deploy.targetHost = "root@192.168.1.10"; };
    server = { deploy.targetHost = "root@192.168.1.20"; };
  };

  inventory.instances = {
    borgbackup = {
      roles.client.machines."laptop" = {};
      roles.server.machines."server" = {};
    };
  };
}
```

```nix
# machines/laptop/configuration.nix
{ ... }:
{
  clan.core.state.home-data = {
    folders = [ "/home/user/Documents" "/home/user/Projects" ];
  };
}
```

```bash
clan vars generate laptop --no-sandbox
clan vars generate server --no-sandbox
clan machines update laptop
clan machines update server
```

### Example 2: Multiple Machines with Custom Schedules

Three workstations backing up to a NAS, each on different schedules.

```nix
# clan.nix
{
  inventory.machines = {
    laptop    = { deploy.targetHost = "root@192.168.1.10"; tags = [ "workstation" ]; };
    desktop   = { deploy.targetHost = "root@192.168.1.11"; tags = [ "workstation" ]; };
    work-pc   = { deploy.targetHost = "root@192.168.1.12"; tags = [ "workstation" ]; };
    nas       = { deploy.targetHost = "root@192.168.1.50"; };
  };

  inventory.instances = {
    borgbackup = {
      roles.client.machines = {
        "laptop"  = { settings.startAt = "*-*-* 02:00:00"; };    # 2 AM
        "desktop" = { settings.startAt = "*-*-* 03:00:00"; };    # 3 AM
        "work-pc" = { settings.startAt = "*-*-* 04:00:00"; };    # 4 AM
      };
      roles.server.machines."nas" = {
        settings.address = "192.168.1.50";
        settings.directory = "/data/backups";
      };
    };
  };
}
```

### Example 3: Offsite Backup to Hetzner Storage Box

A machine backing up to both a local server and an offsite Hetzner Storage Box.

```nix
# clan.nix
{
  inventory.instances = {
    borgbackup = {
      roles.client.machines."backup-server" = {
        settings.destinations."hetzner" = {
          repo = "u123456-sub1@u123456-sub1.your-storagebox.de:/./borgbackup";
          rsh = "ssh -p 23 -oStrictHostKeyChecking=accept-new -i /run/secrets/vars/borgbackup/borgbackup.ssh";
        };
      };
      # Also back up to a local server
      roles.server.machines."local-nas" = {};
    };
  };
}
```

Setup steps:

```bash
# 1. Generate keys
clan vars generate backup-server --no-sandbox

# 2. Add the SSH key to the Hetzner Storage Box
clan vars get backup-server borgbackup/borgbackup.ssh.pub | ssh -p23 u123456-sub1@u123456-sub1.your-storagebox.de install-ssh-key

# 3. Deploy
clan machines update backup-server
```

### Example 4: Application Server with Database Backups and Hooks

A server running Nextcloud with both file and database backups.

```nix
# machines/app-server/configuration.nix
{ config, lib, pkgs, ... }:
{
  # PostgreSQL database backup
  clan.core.postgresql.enable = true;
  clan.core.postgresql.databases.nextcloud = {
    create = {
      TEMPLATE = "template0";
      LC_COLLATE = "C";
      LC_CTYPE = "C";
      ENCODING = "UTF8";
      OWNER = "nextcloud";
    };
    restore.stopOnRestore = [
      "phpfpm-nextcloud.service"
      "nextcloud-cron.timer"
    ];
  };

  # File state with hooks
  clan.core.state.nextcloud-files = {
    folders = [ "/var/lib/nextcloud/data" ];

    preBackupScript = ''
      export PATH=${lib.makeBinPath [ config.systemd.package ]}
      systemctl stop phpfpm-nextcloud.service
      systemctl stop nextcloud-cron.timer
    '';

    postBackupScript = ''
      export PATH=${lib.makeBinPath [ config.systemd.package ]}
      systemctl start phpfpm-nextcloud.service
      systemctl start nextcloud-cron.timer
    '';
  };
}
```

```nix
# clan.nix -- the backup configuration
{
  inventory.instances = {
    borgbackup = {
      roles.client.machines."app-server" = {
        settings.startAt = "*-*-* 02:00:00";
        settings.exclude = [ "*.log" "*.tmp" ];
      };
      roles.server.machines."backup-server" = {
        settings.directory = "/data/backups";
      };
    };
  };
}
```