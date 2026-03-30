# Introduction to Backups
# Early Draft -- Under Active Development
# >>> NOT READY FOR EDITS <<<

# ROUGH NOTES, RANDOM SCRIBBLINGS TO BE REWRITTEN INTO DOC

Start up two machines. If you're using either Virtual Box or a cloud server, we suggest naming them appropriately, such as Clan-Alice and Clan-Backup. Then make note of both instances IP address.


nix run "https://git.clan.lol/clan/clan-core/archive/main.tar.gz#clan-cli" --refresh -- init

Enter a name for the new clan: MY-BACKUP-CLAN
Enter domain for the clan [clan]: mybackupclan.lol

cd MY-BACKUP-CLAN/

direnv allow

Start with Alice
clan machines create alice-laptop
clan machines create backup-server


Open clan.nix.

```
    alice-laptop = {
        deploy.targetHost = "<IP-ADDRESS>"; # REPLACE WITH ALICE'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
    backup-server = {
        deploy.targetHost = "<IP-ADDRESS>"; # REPLACE WITH BACKUP'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
```

Add user for Alice:
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

The usual:
```
cat ~/.ssh/id_ed25519.pub
```

Replace key in this line:
"admin-machine-1" = "PASTE_YOUR_KEY_HERE";
but this time also this line:
openssh.authorizedKeys.keys = [ "PASTE_YOUR_KEY_HERE" ];

TODO: Update the getting started docs with the above to allow Alice to log in with an SSH key

Gather both hardware:

```bash
clan machines init-hardware-config alice-laptop
```
type Y

For VirtualBox, enter password shown on the screen for Alice. (If it's obstructed by text, press Ctrl+C followed by Ctrl+D.)

```
clan machines init-hardware-config backup-server
```
(Same process as for Alice follows)

Disk configuration for both:

clan templates apply disk ext4-single-disk alice-laptop --set mainDisk ""
etc.
Same for backup-server

Install on both:

(If you get the sandbox error, run the vars generate command for both servers, even though you're only doing Alice first, then Backup separately.)

(On Ubuntu, you might need to rerun alice-laptop again after doing backup-server.)
```bash
clan vars generate alice-laptop --no-sandbox
clan vars generate backup-server --no-sandbox
```

Then install:
```bash
clan machines install alice-laptop
clan machines install backup-server
```

If using VirtualBox, reboot both machines, removing the virtual ISO disk in between.


## Set up some docs on Alice's computer to be backed up


Log into Clan as alice. If you need her password type:

```
clan vars get alice-laptop user-password-alice/user-password
```

And log in directly through ssh:

```
ssh alice@<IP-ADDRESS>
```
replacing `<IP-ADDRESS>` with the IP address of Alice's laptop virtual machine.


Then:

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

```bash
more welcome.md 
```
and you should see:
```
Hello World!
```

Now in the same directory create a file called finance.txt

```bash
nano finance.txt
```

Type:

```
Account total: 5000
```

Save (Ctrl+O, Enter) and Exit (Ctrl+X)

Type:

```
more finance.md
```
you should see:

```
Account total: 5000
```

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

## Configure machines for backups

Open up clan.nix

Under inventory.instances:

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

Generate secrets for both machines:

```
clan vars generate alice-laptop
clan vars generate backup-server
```

If on Ubuntu, include --no-sandbox:

```
clan vars generate alice-laptop --no-sandbox
clan vars generate backup-server --no-sandbox
```

Now definte "State" on Alice's machine. This is where you list folders to be backed up. Open up clan.nix. Add this under machines:

  machines = {

    alice-laptop = { ... }: {
      clan.core.state."my-documents" = {
        folders = [
          "/home/alice/documents"
          "/home/alice/pictures"
        ];
      };
    };


Now update both machines:
```bash
clan machines update alice-laptop
clan machines update backup-server
```

Ready to test:

```bash
creating backup for alice-laptop
```

Should see:

```
successfully started backup
```

If you want to see the actual encrypted backup data on backup-server:

```bash
clan ssh backup-server
```

Then:
```
ls -l /var/lib/borgbackup/alice-laptop/
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

On each machine, you define a **state**, which refers to the folders and data that are to be included in the backup. This goes in the machine's machines part:

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

**Note:** While `clan.nix` holds your inventory (services, machines, roles), each machine also has its own `configuration.nix` file for machine-specific settings. You're encouraged to edit these files as needed if you need per-machine customization.

**Why "state" instead of "backup"?** The `clan.core.state` option declares "this data is important" and that it's not specific to backups. The backup service reads your state definitions and includes them automatically. This separation means you define what matters once, and different services (backup, restore, migration) can all use it. If you ever switch backup tools, your state definitions stay the same.

### 2. Set Up the Backup Service

In your `clan.nix`, add the borgbackup service with **client** and **server** roles:

```nix
inventory.instances.borgbackup = {
  roles.client.machines."my-laptop" = {};
  roles.server.machines."my-server" = {};
};
```

This says: "Back up my-laptop to my-server." Clients send backups; servers store them.

---

## TODO: FULL WORKING EXAMPLE - USE EXAMPLE STEPS FROM ROUGH NOTES

### Prerequisites
    
* One Clan created for testing
* Two machines added to the Clan. Call one "alice" to represent an actual user's computer, and the other "backups" to represent a machine dedicated to backups. 



---

## More Detail on Clients and Servers

The borgbackup service has two roles:

| Role | What it does |
|------|--------------|
| **client** | Creates backups and sends them to the server |
| **server** | Receives and stores backups from clients |

A machine can be both. For example, your NAS might store backups from your laptops (server role) while also backing itself up to an offsite location (in which case it takes on the client role).

---

## What Gets Backed Up?

By default, Clan backs up:

- Any folders you define in `clan.core.state`
- PostgreSQL databases (if you enable the PostgreSQL module)
- Secrets and vars needed by your services

You can also add **hooks**, which are scripts that run before or after backups, to handle special cases like stopping a service before backing up its data.

---

## Running a Backup

To back up a machine:

```bash
clan backups create my-laptop
```

This collects all the state you defined, encrypts it, and sends it to the server.

Backups can also run on a schedule. See the [Minimal Example](./minimal-example.md) for how to configure automatic backups with `startAt`.

---

## Restoring from Backup

When you need to restore:

```bash
clan backups restore my-laptop
```

Clan decrypts the backup and restores your state folders. If you defined hooks, they run automatically (stopping services before restore, starting them after).

---

