# More on Backups
# Early Draft -- Under Active Development
# >>> NOT READY FOR EDITS <<<

# MAIN TEXT

## Backup Hooks: Pre/Post Scripts

Sometimes you need to stop a service before backing up its data (to avoid corrupted files), then start it again after. Clan supports this with hooks.

Hooks are defined as part of state, not as part of the backup service, because stopping a service before a backup is really about the *data*, not the backup tool.

For exapmle, you might be backing up a machine that has one or more docker containers running. You generally donl't want to back up running containers when they're running, as you might end with...

The following partial example shows where you would add in the pre and post scripts, the former pausing the docker container, and the latter resuming it:

```nix
  machines = {

    postgres-server = { config, ... }: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "mydatabase" ];
      };

      clan.core.postgresql.enable = true;
      clan.core.postgresql.databases.mydatabase = { };
                  
      clan.core.state."postgresql" = {
        folders = [];
        preBackupScript = ''
          docker pause $(docker ps -q)
        '';
        postBackupScript = ''
          docker unpause $(docker ps -q)
        '';
      };
    };
systemctl stop postgresql
  };

```

Other examples where you would want to use pre and post backup scripts include:

- databases (we have a complete example later)

- virtual machines

- mail servers

- monitoring tools that use an append-only approach to writing data to files

- application log rotation

In general, you would want to use such hooks on any service that has a live, mutable state.


There are four hooks available:

| Hook | When It Runs |
|------|-------------|
| `preBackupScript` | Before the backup starts |
| `postBackupScript` | After the backup finishes |
| `preRestoreScript` | Before a restore starts |
| `postRestoreScript` | After a restore finishes |



## PostgreSQL Database Backups

Clan has built-in support for PostgreSQL. Instead of manually writing pre/post scripts to dump and restore databases, you can use the PostgreSQL module.

Below is a complete example:

```nix
{
  # Ensure this is unique among all clans you want to use.
  meta.name = "MY-HETZNER-CLAN";
  meta.domain = "myhetznerclan.lol";

  inventory.machines = {
    postgres-server = {
        deploy.targetHost = "root@192.168.56.105";
        tags = [ ];
    };
    # Define machines here.
    # server = { };
  };

  # Docs: See https://docs.clan.lol/latest/services/definition/
  inventory.instances = {

    # Docs: https://docs.clan.lol/latest/services/official/sshd/
    # SSH service for secure remote access to machines.
    # Generates persistent host keys and configures authorized keys.
    sshd = {
      roles.server.tags.all = { };
      roles.server.settings.authorizedKeys = {
        # Insert the public key that you want to use for SSH access.
        # All keys will have ssh access to all machines ("tags.all" means 'all machines').
        # Alternatively set 'users.users.root.openssh.authorizedKeys.keys' in each machine
        "admin-machine-1" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZGMNlooljzJfmzQKaVcmj4tRYW+gqBIfdWbG0NU3XL freckleface@freckleface--Laptop";
      };
    };

    # Docs: https://docs.clan.lol/latest/services/official/users/
    # Root password management for all machines.
    user-root = {
      module = {
        name = "users";
      };
      roles.default.tags.all = { };
      roles.default.settings = {
        user = "root";
        prompt = true;
      };
    };

  };

  # Additional NixOS configuration can be added here.
  # machines/server/configuration.nix will be automatically imported.
  # See: https://docs.clan.lol/latest/guides/inventory/autoincludes/
  machines = {

    postgres-server = { config, ... }: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "mydatabase" ];
      };

      clan.core.postgresql.enable = true;
      clan.core.postgresql.databases.mydatabase = { };
                  
      clan.core.state."postgresql" = {
        folders = [];
        preBackupScript = ''
          systemctl stop postgresql
        '';
        postBackupScript = ''
          systemctl start postgresql
        '';
      };
    };

  };
}
```

## Backing up two machines

Below is a clan.nix file that demonstrates how to back up two machines:

- A laptop named alice-laptop

- A database server named postgres-server

to a single machine called backup-server.

Note also that alice-machine has a tag called "employees" and then provides an attribute in borgbackup that backs up any machine with that tag.

### Installation Order

When setting up borgbackup (or any service with cross-machine dependencies), the order in which you install your machines matters.

The borgbackup client needs the server's SSH host key to establish connection to the borgbackup server. This key is generated during the borgbackup server's installation. If you install a client machine before the server, the client won't be able to find the server's key, and you'll need to re-generate its vars afterward. To avoid this, install the backup server before any client machines:
  
clan machines install backup-server --target-host root@<BACKUP-IP>

clan machines install db-server --target-host root@<DB-IP>

clan machines install alice-laptop --target-host root@<ALICE-IP>

This applies to any service where one machine depends on another machine's generated secrets — always install or generate vars for the machine that provides the secret before the machines that consume it.


```nix
{
  # Ensure this is unique among all clans you want to use.
  meta.name = "MY-BACKUP-CLAN";
  meta.domain = "mybackupclan.lol";

  inventory.machines = {
    alice-laptop = {
        deploy.targetHost = "root@192.168.56.101";
        tags = [ "employees" ];
    };
    backup-server = {
        deploy.targetHost = "root@192.168.56.104";
        tags = [ ];
    };
    postgres-server = {
        deploy.targetHost = "root@192.168.56.102";
        tags = [ ];
    };
  };

  inventory.instances = {
    borgbackup = {
      roles.client.tags = [ "employees" ];
      roles.client.machines."postgres-server" = {};
      roles.server.machines."backup-server" = {
        settings.address = "192.168.56.104";
        settings.directory = "/var/lib/borgbackup";
      };
    };

    user-alice = {
      module.name = "users";
      roles.default.machines."alice-laptop" = {};
      roles.default.tags = [ "all" ];
      roles.default.settings = {
        user = "alice";
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZGMNlooljzJfmzQKaVcmj4tRYW+gqBIfdWbG0NU3XL freckleface@freckleface--Laptop" ];
      };
    };

    sshd = {
      roles.server.tags.all = { };
      roles.server.settings.authorizedKeys = {
        "admin-machine-1" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZGMNlooljzJfmzQKaVcmj4tRYW+gqBIfdWbG0NU3XL freckleface@freckleface--Laptop";
      };
    };

    user-root = {
      module.name = "users";
      roles.default.tags.all = { };
      roles.default.settings = {
        user = "root";
        prompt = true;
      };
    };
  };

  machines = {

    alice-laptop = { ... }: {
      systemd.tmpfiles.rules = [
        "d /home/alice/documents 0755 alice users -"
        "d /home/alice/pictures 0755 alice users -"
      ];

      clan.core.state."my-documents" = {
        folders = [
          "/home/alice/documents"
          "/home/alice/pictures"
        ];
      };
    };


    postgres-server = { config, ... }: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "mydb" ];
      };
                                                                                                                                                                      
      clan.core.postgresql.enable = true;
      clan.core.postgresql.databases.mydb = { };                                                                                                                  
                  
      clan.core.state."postgresql" = {                                                                                                                                  
        folders = [];
        preBackupScript = ''                                                                                                                                            
          systemctl stop postgresql
        '';
        postBackupScript = ''
          systemctl start postgresql
        '';
      };
    };
  

  };
}

```

## Excluding folders

You can exclude files and folders from the backup using this general pattern:

```nix
roles.client.tags.employees.settings = {
  exclude = [ "*.bak" ]; 
}
```

This would exclude all files ending with .bak on every machine tagged with employee.

Here's an example that excluded multiple files and patterns on only the machine called alice-laptop.

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

Below is a partial clan.nix file that demontrates three workstations backing up to a NAS, each on different schedules.


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



## External Backup Destinations

You don't have to back up to another Clan machine. You can add external destinations like a Hetzner Storage Box or any SSH-accessible BorgBackup server.

```nix
{
  # Ensure this is unique among all clans you want to use.
  meta.name = "MY-HETZNER-CLAN";
  meta.domain = "myhetznerclan.lol";

  inventory.machines = {
    postgres-server = {
        deploy.targetHost = "root@192.168.56.106";
        tags = [ ];
    };
  };

  inventory.instances = {

    borgbackup = {
      roles.client.machines."postgres-server" = {
        settings.destinations."storagebox" = {
          repo = "u576452@u576452.your-storagebox.de:/./borgbackup";
          rsh = "ssh -p 23 -oStrictHostKeyChecking=accept-new -i /run/secrets/vars/borgbackup/borgbackup.ssh";
        };
      };
    };

    sshd = {
      roles.server.tags.all = { };
      roles.server.settings.authorizedKeys = {
        # Insert the public key that you want to use for SSH access.
        # All keys will have ssh access to all machines ("tags.all" means 'all machines').
        # Alternatively set 'users.users.root.openssh.authorizedKeys.keys' in each machine
        "admin-machine-1" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZGMNlooljzJfmzQKaVcmj4tRYW+gqBIfdWbG0NU3XL freckleface@freckleface--Laptop";
      };
    };

    user-root = {
      module = {
        name = "users";
      };
      roles.default.tags.all = { };
      roles.default.settings = {
        user = "root";
        prompt = true;
      };
    };

  };

  machines = {

    postgres-server = { config, ... }: {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "mydatabase" ];
      };

      clan.core.postgresql.enable = true;
      clan.core.postgresql.databases.mydatabase = { };
                  
      clan.core.state."postgresql" = {
        folders = [];
        preBackupScript = ''
          systemctl stop postgresql
        '';
        postBackupScript = ''
          systemctl start postgresql
        '';
      };
    };

  };
}
```

After configuring, add your Clan-generated SSH public key to the external server:

WORKFLOW:

Create the storage box on hetzner (or use an existing one). If you're creating one, you can probably use your own id_ed25519.pub file for the key. (Make sure the following settings are checked when you create the box: Under **Additional Settings** check **Allow SSH** and **External Reachability**.
)

Create a new clan. Replace the entire clan.nix file with the clan file below, and type in the clan name and domain you previously chose. 

Create one machines, postgres-server. Gather hardware requirements, and create a disk as usual.

Click on the overview screen for the storage box, and copy the user and server (URL) into the clan.nix file below.

```bash
# For non-Hetzner: Get the public key Clan generated
clan vars get alice-laptop borgbackup/borgbackup.ssh.pub

# For Hetzner Storage Box, you can pipe it directly:
clan vars get alice-laptop borgbackup/borgbackup.ssh.pub | ssh -p23 user-sub1@user-sub1.your-storagebox.de install-ssh-key
```

Regarding the rsh attribute, which looks like this:

```nix
rsh = "ssh -p 23 -oStrictHostKeyChecking=accept-new -i /run/secrets/vars/borgbackup/borgbackup.ssh";
```

here's an explanation:

- rsh — stands for "remote shell." It's the borgbackup setting that defines what command to use for connecting to the remote repository.
- ssh — use the SSH command for the connection.

- -p 23 — connect on port 23 (Hetzner's SSH port for storage boxes, instead of the default port 22).
- -oStrictHostKeyChecking=accept-new — this controls host key verification:

  - yes (default) would require the host key to already be in known_hosts, otherwise refuse
  - no would blindly accept anything (insecure)
  - accept-new is the sweet spot — accepts new hosts on first connection automatically (so the backup doesn't fail the first time), but still rejects if the key changes later (protecting against man-in-the-middle attacks)

- -i /run/secrets/vars/borgbackup/borgbackup.ssh — use this specific private key file. This is the Clan-generated borgbackup private key, which gets deployed to postgres-server at that path under /run/secrets/ (a RAM-only directory, so the key never touches disk). That matches the public key you pushed to Hetzner with      
install-ssh-key.

So in plain English: "To reach the backup repo, run ssh on port 23, auto-trust new hosts but not changed ones, and authenticate with the borgbackup private key     
stored in secrets."




BigTime-Noise-123

You can combine internal (server role) and external destinations. The client will back up to all of them.


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



