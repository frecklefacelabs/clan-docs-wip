# Getting Started

## 1. Create the key pair if it doesn't already exist

You will need a key pair called `id_ed25519`. Click here for information on how to find it or, if necessary, create it.

## 2. Create the clan:

Start by creating a new clan:

```
nix run "https://git.clan.lol/clan/clan-core/archive/25.11.tar.gz#clan-cli" --refresh -- flakes create
```

and enter a name for it, e.g. MY-CLAN-1

!!! Note Important
    The first time you run this, you'll see a messagea about backing up a key file. Please do so and then type "y".

!!! Note Important
    If you've run this before, you'll also be asked to select admin keys; you'll most likely want to type "1" and press enter.

Change to the new folder:

```bash
cd MY-CLAN-1
```

You will likely see a message about direnv needing permission to run. Type:

```
direnv allow
```

## 3. Set the name and domain:

Open `clan.nix`, and fill in the following two lines; change what's in quotes. Pick a name; you can use MY-CLAN-1 for the first, and pick a domain for the second; note that the domain does not have to be registered.

```
meta.name = "__CHANGE_ME__";
meta.domain = "changeme";
```

Type 

```
clan show
```

to test that the clan.nix file isn't broken.

## 4. Create a machine

Next create a machine; for this example, call it test-machine, by typing:

```
clan machines create test-machine
```

Open `clan.nix`, and find the `inventory.machines` line; add the following immediately after it, but replace the IP-ADDRESS with the IP address of your remote machine.

```
inventory.machines = { # FIND THIS LINE, ADD THE FOLLOWING
    test-machine = {
        deploy.targetHost = "root@<IP-ADDRESS>"; # REPLACE WITH YOUR MACHINE'S IP ADDRESS; keep "root@"
        tags = [ ];
    };
```

Test it out:
```
clan machines list
```

## 5. Add your allowed keys

Next you will add your key to the allowedKeys. Your best bet to finding it is:

```bash
cat ~/.ssh/id_ed25519.pub
```

Open `clan.nix`, and replace `PASTE_YOUR_KEY_HERE` with the contents of the file:

```
"admin-machine-1" = "PASTE_YOUR_KEY_HERE"; 
```

For example, it will start with something like this:

```
"admin-machine-1" = "ssh-ed25519 AAAAC3..."
```

Test out your .nix file to make sure it's not broken:

```bash
clan show
```

## 6. Get hardware config

Now it's time to gather info on your hardware. Type:

```
clan machines init-hardware-config test-machine --target-host <USERNAME>@<IP-ADDRESS>
```

replacing:
* <USERNAME> with the username to log into your system.
* <IP-ADDRESS> with the IP address of your system

You will be asked to enter "y" to proceed.

Note: Earlier, when you created a machine, you were told to leave the user as `root`. That's the username that will be used after the system is updated with NixOS. In this step, syou use the current username you log in with.

!!! Note Important
    This user must have sudo access without requiring a password. Also, this user must either accept a password, or be configured for login via SSH using the key file id_ed25519. For information on how to set this up, see [COMING SOON].

## 7. Prepare a disk

Next, configure a disk. You'll type this command twice; first, type it like so:

```
clan templates apply disk single-disk test-machine --set mainDisk ""
```

This will generate an error; note the disk ID it prints out, and add it inside the quotes, e.g.:

```
clan templates apply disk single-disk test-machine --set mainDisk "/dev/xvda"
```

## 8. Install:

Ready to go. Install by typing:

```clan machines install --update-hardware-config nixos-facter test-machine --target-host <USER>@<IP-ADDRESS>```

Again substituting USERNAME and IP-ADDRESS as before.

(You will be asked whether you want to install; type y. You will also be asked about a password; you can accept the defaults here and just press Enter for both.)

!!! Tip
    If you're asked for a password and you haven't created one, or if you have and the password doesn't work, try rebooting the server. If you're on a cloud server, you'll want to use the "reboot" feature (rather than shut down and restart) to ensure the IP address doesn't change.

## 9. Test

Now you can try connecting to the remote machine:

```bash
clan ssh test-machine
```

You'll quite likely get an error at first regarding the host identification. It should include a line to type to remove the old ID; paste the line you're shown, which will look similar to this:
```
remove with:
  ssh-keygen -f '/home/user/.ssh/known_hosts' -R '<IP-ADDRESS>'
```

Then try again:

```bash
clan ssh test-machine
```

You should connect and see the prompt:

```
[root@test-machine:~]#
```
