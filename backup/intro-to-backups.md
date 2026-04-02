# Introduction to Backups
# Early Draft -- Under Active Development
# >>> NOT READY FOR EDITS <<<

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

## Quick Reference

| Command | What It Does |
|---------|-------------|
| `clan backups create <machine>` | Trigger a backup right now |
| `clan backups list <machine>` | List available backups |
| `clan backups restore <machine> borgbackup <name>` | Restore from a specific backup |
| `clan vars get <machine> borgbackup/borgbackup.ssh.pub` | Get the generated SSH public key. Use for clients. |

