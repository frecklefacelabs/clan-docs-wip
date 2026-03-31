# Introduction to Backups
# Early Draft -- Under Active Development
# >>> NOT READY FOR EDITS <<<

# ROUGH NOTES, RANDOM SCRIBBLINGS TO BE REWRITTEN INTO DOC




### Let's move this next part to a later example
If you want to see the actual encrypted backup data on backup-server:

```bash
clan ssh backup-server
```

Then:
```
cd /var/lib/borgbackup/alice-laptop/
ls -l
```
You should see:

```
total 68
-rw------- 1 borg borg   700 Mar 30 03:53 config
drwx------ 3 borg borg  4096 Mar 30 03:53 data
-rw------- 1 borg borg   155 Mar 30 03:53 hints.13
-rw------- 1 borg borg 41258 Mar 30 03:53 index.13
-rw------- 1 borg borg   190 Mar 30 03:53 integrity.13
-rw------- 1 borg borg    16 Mar 30 03:53 nonce
-rw------- 1 borg borg    73 Mar 30 03:53 README
```

To see how much total space is being used:

```bash
du -sh
```

You should see something similar to this:

```
356K	.
```

Now run another backup without changing anything. Borg will detect that there's nothing to do and only store a bit of metadata about the backup. Back on the setup machine:

```
clan backups create alice-laptop
```

Now log into the backup server and repeat the above steps. When you run du -sh it shouldn't change much, perhaps 5 or 6 kilobytes.


## Two clients, plus ZeroTier

clan machines create alice-laptop
clan machines create bob-laptop
clan machines create backup-server

```nix
    alice-laptop = {
        deploy.targetHost = "<IP-ADDRESS>"; # REPLACE WITH ALICE'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
    alice-laptop = {
        deploy.targetHost = "<IP-ADDRESS>"; # REPLACE WITH BOB'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
    backup-server = {
        deploy.targetHost = "<IP-ADDRESS>"; # REPLACE WITH BACKUP'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
```

Here we'll demonstrate deduplication.

First create on Alice's computer:

cd documents

Create a 20MB file called big_demo_file.txt
```bash
yes "This is a repeating line of text for Freckleface's Clan backup demo. " | head -c $((20 * 1024 * 1024)) > big_demo_file.txt
```

Back on setup machine:

```bash
clan backups create alice-laptop
```


On Bob's computer:

```bash
cd documents
yes "This is a repeating line of text for Freckleface's Clan backup demo. " | head -c $((20 * 1024 * 1024)) > big_demo_file.txt
```


Modify one byte roughly in the middle:

```bash
echo -n "Z" | dd of=big_demo_file.txt bs=1 seek=10000000 count=1 conv=notrunc
```


## More NOTES

It sounds like you can backup to Hetzner's equivalent to S3? Need to check the existing docs.

Talk about multiple states and why we might need them. Example:

```nix
  clan.core.state."my-documents" = { # <--- This implies you can have multiple states
    folders = [
      "/home/alice/documents"
      "/home/alice/pictures"
    ];
  };
}
```

Now 

Talk about hooks, scripts, etc.

Can you choose a folder to include and exclude some subfolder under one of them?



# FIRST DRAFT

Clan makes it easy to back your machines up from one to another. You define what to back up and where to send it, and Clan handles the rest: encryption, scheduling, and restoration.

---

## How Clan Backups Work

Clan backups have two parts:

1. **What to back up**: folders, databases, application state
2. **Where to send it**: another machine in your clan

Under the hood, Clan uses [BorgBackup](https://www.borgbackup.org/), which provides:

- **Deduplication**: only stores changes, saving disk space
- **Encryption**: backups are encrypted before leaving the machine
- **Compression**: smaller backups, faster transfers

You don't need to know BorgBackup to use Clan backups. Clan configures everything for you.

---

## The Basic Setup

### 1. Define What to Back Up

On each machine, you define a **state**, which refers to the folders and data that are to be included in the backup. This goes in the clan.nix file's `machines` attribute:

```nix
  machines = {

    alice-laptop = { ... }: {
      clan.core.state."my-documents" = {
        folders = [
          "/home/alice/documents"
          "/home/alice/pictures"
        ];
      };
    };
```

**Why "state" instead of "backup"?** The `clan.core.state` option declares "this data is important" and that it's not specific to backups. The backup service reads your state definitions and includes them automatically. This separation means you define what matters once, and different services (backup, restore, migration) can all use it. If you ever switch backup tools, your state definitions stay the same.

### 2. Set Up the Backup Service

In your `clan.nix`, add the borgbackup service with **client** and **server** roles:

```nix
inventory.instances.borgbackup = {
  roles.client.machines."alice-laptop" = {};
  roles.server.machines."backup-server" = {};
};
```

This says: "Back up alice-laptop to backup-server." Clients send backups; servers store them.

## Starting Example

Before proceding to advanced settings, we're presenting you with a step-by-step example, as that will demonstrate exactly how to use backups.

Prerequisites
You should be familiar with how to set up a machine on Clan. If not, please follow the steps [here]().

Start up two machines. If you're using either Virtual Box or a cloud server, we suggest naming them appropriately, such as Clan-Alice and Clan-Backup. Then make note of both instances IP address.

```bash
nix run "https://git.clan.lol/clan/clan-core/archive/main.tar.gz#clan-cli" --refresh -- init
```

Enter a name for the new clan, such as `MY-BACKUP-CLAN`. Enter a domain for the clan, such as `mybackupclan.lol`.

Next:

```bash
cd MY-BACKUP-CLAN/
direnv allow
```

Now create the two machines:

```bash
clan machines create alice-laptop
clan machines create backup-server
```

Then open clan.nix, and add the following inside `inventory.machines`, replacing the IP addresses accordingly:

```
  inventory.machines = { // Add the following under this line
    alice-laptop = {
        deploy.targetHost = "<IP-ADDRESS>"; # REPLACE WITH ALICE'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
    backup-server = {
        deploy.targetHost = "<IP-ADDRESS>"; # REPLACE WITH BACKUP'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
```

Next, add a user for Alice:
```nix
  inventory.instances = { # Add the following under this line
    user-alice = {
      module.name = "users";
      roles.default.machines."test-machine" = {};
      roles.default.tags = [ "all" ];
      roles.default.settings = {
        user = "alice";
        openssh.authorizedKeys.keys = [ "PASTE_YOUR_KEY_HERE" ];
      };
    };
```

Print out what's in your public key file:
```
cat ~/.ssh/id_ed25519.pub
```

and copy it to the clipboard. Then open clan.nix again. Replace the placeholder text in this line:

```
"admin-machine-1" = "PASTE_YOUR_KEY_HERE";
```

and also in this line:

```
openssh.authorizedKeys.keys = [ "PASTE_YOUR_KEY_HERE" ];
```

TODO: Update the getting started docs with the above to allow Alice to log in with an SSH key

Now gather both hardware settings:

```bash
clan machines init-hardware-config alice-laptop
```
type Y

If you're using VirtualBox, enter password shown on the screen for Alice. (If it's obstructed by text, press Ctrl+C followed by Ctrl+D.)

And now the backup-server:

```
clan machines init-hardware-config backup-server
```

Next, complete the disk configuration for both:

```
clan templates apply disk ext4-single-disk alice-laptop --set mainDisk ""
```

When you get an error, copy it in between the quotes and repeat the line. 

Repeat the same process for backup-server:

```
clan templates apply disk ext4-single-disk backup-server --set mainDisk ""
```


Now you're ready to install on both:


Then install:
```bash
clan machines install alice-laptop
clan machines install backup-server
```

(If you get the sandbox error, run the vars generate command for both servers, even though you're only doing Alice first, then Backup separately.)

TODO: INVESTIGATE THIS NEXT PART AS I'M NOT SURE IT HAPPENED EVERY TIME
(On Ubuntu, you might need to rerun alice-laptop again after doing backup-server.)
```bash
clan vars generate alice-laptop --no-sandbox
clan vars generate backup-server --no-sandbox
```


If using VirtualBox, reboot both machines, removing the virtual ISO disk in between. For detailed instructions, visit [...]().


### Set up some docs on Alice's computer to be backed up

Now let's create some documents on Alice's laptop that will be backed up.

Log into alice-laptop as **alice**. If you need her password, on the setup machine, type:

```
clan vars get alice-laptop user-password-alice/user-password
```

And log in directly through ssh:

```
ssh alice@<IP-ADDRESS>
```
replacing `<IP-ADDRESS>` with the IP address of Alice's laptop virtual machine.


Then, once logged in as **alice**, create some directories and documents, like so:

```bash
mkdir documents
cd documents
nano welcome.md
```

Type:

```
Hello World!
```
Save (Ctrl+O, Enter) and Exit (Ctrl+X)

Now in the same directory create a file called `finance.txt`:

```bash
nano finance.txt
```

Type:

```
Account total: 5000
```

Save (Ctrl+O, Enter) and Exit (Ctrl+X)

Next, create a pictures directory:

```bash
cd ~
mkdir pictures
cd pictures
```

Obtain any image you like, such as an image frmo the Clan docs:

```
curl -o hero.jpg https://clan.lol/_assets/25.11/_app/immutable/assets/docs-hero.CUEOsCNu.jpg
```

(We used curl here, because, by default, NixOS ships with curl, but not wget.)

Now check that everything is present:

```
cd ~
ls documents
ls pictures

```

You should see the two files in `documents` and the `hero.jpg` file in `pictures`.

Go ahead and exit:

```bash
exit
```

### Configure machines for backups

Now we'll configure backup system. Open clan.nix. Under inventory.instances, add:

```
    borgbackup = {
      roles.client.machines."alice-laptop" = {};
      roles.server.machines."backup-server" = {
        settings.address = "<BACKUP-SERVER-IP-ADDRESS>"; # REPLACE WITH BACKUP-SERVER'S IP ADDRESS
        settings.directory = "/var/lib/borgbackup";
      };
    };
```
TODO: DO WE NEED THE directory attribute?

While still in `clan.nix`, definte "State" on Alice's machine. This is where you list folders to be backed up. Open up clan.nix. Add this under machines:


Generate secrets for both machines:
```nix
  machines = {

    alice-laptop = { ... }: {
      clan.core.state."my-documents" = {
        folders = [
          "/home/alice/documents"
          "/home/alice/pictures"
        ];
      };
    };
```

Exit out, and now generate some new keys:
```bash
clan vars generate alice-laptop
clan vars generate backup-server
```
(If on Ubuntu, include `--no-sandbox` at the end of each line.)

Now update both machines:
```bash
clan machines update alice-laptop
clan machines update backup-server
```

Ready to try it out:

```bash
clan backups create alice-laptop
```

Should see:

```
successfully started backup
```

Wait a minute or so, and then list the backups:

```bash
clan backups list alice-laptop
```

You'll see a list similar to this:

```
backup-server::borg@10.0.0.40:.::alice-laptop-backup-server-2026-03-30T03:53:34
```

Next, delete a file from Alice's computer. Log into alice-laptop, and then:

```
cd documents
rm welcome.md
```

Now back on the setup machine, first list the backups again:

```bash
clan backups list alice-laptop
```

You'll see a list of one item, similar to this:

```
backup-server::borg@10.0.0.40:.::alice-laptop-backup-server-2026-05-30T03:53:34
```

Depending how many times you ran the backup command, you might see more listed. Copy the final one to the clipboard, and then type:

```bash
clan backups restore alice-laptop borgbackup <PASTE>
```

For `<PASTE>` paste the backup name from the clipboard, such as:

```bash
clan backups restore alice-laptop borgbackup backup-server::borg@10.0.0.40:.::alice-laptop-backup-server-2026-05-31T03:08:51
```

Log back in to  alice-laptop, return to the `documents` directory, and type `ls` and you'll see that the `welcome.md` file has been restored.

## More Detail on Clients and Servers

The borgbackup service has two roles:

| Role | What it does |
|------|--------------|
| **client** | Creates backups and sends them to the server |
| **server** | Receives and stores backups from clients |

A machine can be both. For example, you might store backups from your laptops (server role) while also backing itself up to an offsite location (in which case it takes on the client role).

## What Gets Backed Up?

By default, Clan backs up:

- Any folders you define in `clan.core.state`
- PostgreSQL databases (if you enable the PostgreSQL modle)
- Secrets and vars needed by your services

You can also add **hooks**, which are scripts that run before or after backups, to handle special cases like stopping a service before backing up its data.

## Running a Backup

To back up a machine:

```bash
clan backups create alice-laptop
```

This collects all the state you defined, encrypts it, and sends it to the server.

Backups can also run on a schedule. See the [Minimal Example](./minimal-example.md) for how to configure automatic backups with `startAt`.

## Restoring from Backup

When you need to restore:

```bash
clan backups restore alice-laptop
```

Clan decrypts the backup and restores your state folders. If you defined hooks, they run automatically (stopping services before restore, starting them after).

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

### Using Tags for multiple backups

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

Hooks are defined as part of state, not as part of the backup service -- because stopping a service before a backup is really about the *data*, not the backup tool.

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

---

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

---

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

---

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
