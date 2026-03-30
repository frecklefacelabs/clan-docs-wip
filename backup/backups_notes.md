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
      roles.server.machines."backup-server" = {};
    };
```

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

BUT: This doesn't work yet, because we haven't configured ZeroTier, and alice-laptop can't find backup-server by name.

NEXT UP: ADD IN ZERO TIER

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

