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

TODO: (Redo all this) CREATE A USER FOR ALICE

cat ~/.ssh/id_ed25519.pub
Replace key in this line:
"admin-machine-1" = "PASTE_YOUR_KEY_HERE";

Gather both hardware:

clan machines init-hardware-config alice-laptop
click Y

For VirtualBox, enter password shown on the screen for Alice. (If it's obstrcuted by text, press Ctrl+C followed by Ctrl+D.)

clan machines init-hardware-config backup-server
(Same process as for Alice follows)

Disk configuration for both:

clan templates apply disk ext4-single-disk test-machine --set mainDisk ""
etc.
Same for backup-server

Install on both:

(If you get the sandbox error, run the vars generate command for both servers, even though you're only doing Alice first, then Backup separately.)

clan vars generate alice-laptop --no-sandbox
clan vars generate backup-server --no-sandbox

Then install:
clan machines install alice-laptop
clan machines install backup-server

If using VirtualBox, reboot both machines, removing the virtual ISO disk in between.

# Set up some docs on Alice's computer to be backed up

clan ssh alice-laptop

TODO/REDO: Put this in Alice's home directory

```
[root@alice-laptop:~]# mkdir documents
[root@alice-laptop:~]# cd documents
[root@alice-laptop:~/documents]# nano welcome.md
```

Type:

```
Hello World!
```
Save (Ctrl+O) and Exit (Ctrl+X)

```
[root@alice-laptop:~/documents]# more welcome.md 
Hello World!
```

[root@alice-laptop:~/documents]# nano finance.md

Type:

```
Account total: 5000
```

Save (Ctrl+O) and Exit (Ctrl+X)

```
[root@alice-laptop:~/documents]# more finance.md
Account total: 5000
```

Next, create a pictures directory:

```
[root@alice-laptop:~/documents]# cd ~
[root@alice-laptop:~]# mkdir pictures
[root@alice-laptop:~]# cd pictures
```

Obtain any image you like, such as:

```
curl -o hero.jpg https://clan.lol/_assets/25.11/_app/immutable/assets/docs-hero.CUEOsCNu.jpg
```

(We used curl here, because, by default, NixOS ships with curl, but not wget.)

Now check that everything is present:

```
[root@alice-laptop:~/pictures]# cd ..

[root@alice-laptop:~]# ls documents
finance.md  welcome.md

[root@alice-laptop:~]# ls pictures/
hero.jpg

```

# Configure machines for backups

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

Now definte "State" on Alice's machine. Open up machines/alice-laptop/configuration.nix



# NOTES

It sounds like you can backup to Hetzner's equivalent to S3? Need to check the existing docs.

Talk about multiple states and why we might need them. Example:

```nix
# machines/my-laptop/configuration.nix
{ ... }:
{
  clan.core.state.my-documents = { # <--- This implies you can have multiple states
    folders = [
      "/home/user/Documents"
      "/home/user/Photos"
    ];
  };
}
```

Talk about hooks, scripts, etc.

Can you choose a folder to include and exclude some subfolder under one of them?

