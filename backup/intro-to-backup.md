# Introduction to Clan Backups

## Early Draft -- Under Active Development

Clan makes it straightforward to back up your machines to each other. You tell Clan which machine to back up and which machine to store the backups on, and it handles encryption, scheduling, key management, and restoration for you.

Under the hood, Clan uses [BorgBackup](https://www.borgbackup.org/) -- a tool that provides deduplication, encryption, and compression -- but you don't need to know BorgBackup to use Clan backups.

---

## The Two Things You Need to Know

Clan backups boil down to two concepts:

1. **Which machine sends backups** (the **client**)
2. **Which machine stores backups** (the **server**)

You configure both in your `clan.nix` file.

---

## Your First Backup Setup

Let's say you have two machines: a laptop you want to back up, and a server to store those backups.

### Step 1: Assign Roles in `clan.nix`

```nix
# clan.nix
inventory.instances = {
  borgbackup = {
    roles.client.machines."my-laptop" = {};
    roles.server.machines."my-server" = {};
  };
};
```

That's it. This says: "Back up `my-laptop` to `my-server`."

- **client** = the machine that gets backed up
- **server** = the machine that stores the backups

### Step 2: Generate Secrets

Clan automatically creates SSH keys and encryption keys for your backups. You just need to trigger the generation:

```bash
clan vars generate my-laptop --no-sandbox   # --no-sandbox needed on Ubuntu
clan vars generate my-server --no-sandbox
```

### Step 3: Deploy

```bash
clan machines update my-laptop
clan machines update my-server
```

That's a working backup setup. By default, backups run automatically at **1:00 AM daily**.

---

## What Gets Backed Up?

By default, Clan backs up the **state** defined on each machine. State is any data you declare as important -- folders, database dumps, application data.

Some services (like PostgreSQL) automatically register their data as state. You can also define your own.

### Defining State

State definitions go in the machine's `configuration.nix` file (not in `clan.nix`):

```nix
# machines/my-laptop/configuration.nix
{ ... }:
{
  clan.core.state.my-documents = {
    folders = [
      "/home/user/Documents"
      "/home/user/Photos"
    ];
  };
}
```

The key insight: **state** is separate from **backups**. You declare "this data matters" once, and the backup service picks it up automatically. If you ever switch backup tools, your state definitions stay the same.

---

## Running Backups Manually

Backups run on a schedule, but you can trigger one anytime:

```bash
# Back up a machine right now
clan backups create my-laptop
```

### Listing Backups

```bash
# See what backups exist
clan backups list my-laptop
```

### Restoring from Backup

```bash
# Restore everything
clan backups restore my-laptop borgbackup <backup-name>

# Restore only a specific service's data
clan backups restore my-laptop borgbackup <backup-name> --service my-documents
```

The backup name comes from the `clan backups list` output.

---

## Changing the Backup Schedule

The default schedule is 1:00 AM daily. To change it, add `startAt` to the client settings:

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines."my-laptop" = {
      settings.startAt = "*-*-* 04:00:00";   # 4 AM daily
    };
    roles.server.machines."my-server" = {};
  };
};
```

The schedule uses [systemd calendar event syntax](https://www.freedesktop.org/software/systemd/man/systemd.time.html). Some common patterns:

| Schedule | Meaning |
|----------|---------|
| `*-*-* 01:00:00` | Every day at 1 AM (default) |
| `*-*-* 04:00:00` | Every day at 4 AM |
| `*-*-* *:00:00` | Every hour |
| `Mon *-*-* 03:00:00` | Every Monday at 3 AM |

---

## Server Settings

The server has two settings you can configure:

```nix
roles.server.machines."my-server" = {
  settings.address = "192.168.1.50";          # How clients reach this server
  settings.directory = "/data/backups";       # Where to store backup repos
};
```

- **address**: The hostname or IP that clients use to connect. If not set, Clan uses the machine name.
- **directory**: Where backup repositories are stored on disk. Defaults to `/var/lib/borgbackup`.

---

## Backing Up Multiple Machines

You can back up as many machines as you want to the same server:

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines = {
      "laptop" = {};
      "desktop" = {};
      "workstation" = {};
    };
    roles.server.machines."nas" = {
      settings.directory = "/data/backups";
    };
  };
};
```

Each client gets its own isolated backup repository on the server. They can't see each other's data.

### Using Tags

If you have a lot of machines, use tags instead of listing each one:

```nix
# Define tags on your machines
inventory.machines = {
  laptop   = { tags = [ "workstation" ]; deploy.targetHost = "root@192.168.1.10"; };
  desktop  = { tags = [ "workstation" ]; deploy.targetHost = "root@192.168.1.11"; };
  nas      = { tags = [ "server" ];      deploy.targetHost = "root@192.168.1.12"; };
};

# Use tags to assign roles
inventory.instances = {
  borgbackup = {
    roles.client.tags.workstation = {};    # All "workstation" machines are clients
    roles.server.machines."nas" = {};
  };
};
```

---

## Backup Hooks: Pre/Post Scripts

Sometimes you need to stop a service before backing up its data (to avoid corrupted files), then start it again after. Clan supports this with hooks.

Hooks are defined as part of state, not as part of the backup service -- because stopping a service before a backup is really about the *data*, not the backup tool.

```nix
# machines/my-server/configuration.nix
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

---

## Excluding Files

You can exclude certain file patterns from backups:

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines."my-laptop" = {
      settings.exclude = [
        "*.pyc"
        "*.tmp"
        "__pycache__"
        ".cache"
      ];
    };
    roles.server.machines."my-server" = {};
  };
};
```

---

## External Backup Destinations

You don't have to back up to another Clan machine. You can add external destinations like a Hetzner Storage Box or any SSH-accessible BorgBackup server.

```nix
inventory.instances = {
  borgbackup = {
    roles.client.machines."my-laptop" = {
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
clan vars get my-laptop borgbackup/borgbackup.ssh.pub

# For Hetzner Storage Box, you can pipe it directly:
clan vars get my-laptop borgbackup/borgbackup.ssh.pub | ssh -p23 user-sub1@user-sub1.your-storagebox.de install-ssh-key
```

You can combine internal (server role) and external destinations. The client will back up to all of them.

---

## PostgreSQL Database Backups

Clan has built-in support for PostgreSQL. Instead of manually writing pre/post scripts to dump and restore databases, you can use the PostgreSQL module:

```nix
# machines/my-server/configuration.nix
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

---

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

---

## How It All Fits Together

Here's the mental model:

```
┌────────────────────────────┐
│  clan.nix (Inventory)      │   You define roles: who backs up, who stores
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│  State definitions         │   Each machine declares what data matters
│  (configuration.nix)       │   (folders, databases, hooks)
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│  Vars / Secrets            │   Clan auto-generates SSH keys and
│  (clan vars generate)      │   encryption keys
└────────────┬───────────────┘
             │
             ▼
┌────────────────────────────┐
│  Backup runs               │   Scheduled (systemd timer) or manual
│  (clan backups create)     │   (clan backups create <machine>)
└────────────────────────────┘
```

1. **`clan.nix`** defines which machines are clients and servers
2. **`configuration.nix`** on each machine defines what data to back up (state)
3. **`clan vars generate`** creates the encryption and SSH keys
4. **`clan machines update`** deploys the configuration
5. Backups run on schedule, or you trigger them with `clan backups create`
6. Restore with `clan backups restore`

---

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
      roles.client.machines."my-server" = {
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
clan vars generate my-server --no-sandbox

# 2. Add the SSH key to the Hetzner Storage Box
clan vars get my-server borgbackup/borgbackup.ssh.pub | ssh -p23 u123456-sub1@u123456-sub1.your-storagebox.de install-ssh-key

# 3. Deploy
clan machines update my-server
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

---

## Quick Reference

| Command | What It Does |
|---------|-------------|
| `clan vars generate <machine>` | Generate backup encryption and SSH keys |
| `clan machines update <machine>` | Deploy the backup configuration |
| `clan backups create <machine>` | Trigger a backup right now |
| `clan backups list <machine>` | List available backups |
| `clan backups restore <machine> borgbackup <name>` | Restore from a specific backup |
| `clan vars get <machine> borgbackup/borgbackup.ssh.pub` | Get the generated SSH public key |

---

## Retention Policy

Clan configures BorgBackup with a default retention policy:

| Keep | Duration |
|------|----------|
| All archives | From the last 1 day |
| Daily | 7 days |
| Weekly | 4 weeks |

Older backups are automatically pruned to save disk space. Deduplication means that even kept backups share common data, so storage grows slowly over time.
