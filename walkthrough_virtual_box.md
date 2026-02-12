# Configuring a Virtual Box Machine

# UNDER CONSTRUCTION -- DO NOT EDIT

!!! Note Prerequisite
    An existing id_ed25519 key pair. To find out if you have one, or to learn how to create one, click here.


You have several options for initial operating system to install; one is Ubuntu Server, which you can download here.

## Setting Up Ubuntu Server

In the Oracle VirtualBox GUI, click the **New** button in the upper left (with a star icon).

Provide an appropriate name for the VM, such as `Ubuntu Server`.

Click the **ISO Image** dropdown; then click **Other**, and navigate to your **Downloads** folder, and select the `.iso` file you downloaded, such as `ubuntu-24.04.3-live-server-amd64.iso`.

Expand **Set up unattended guest OS installation**. Provide a username and password of your choice, and save these, as you'll need them later.




## Post-Installation Steps

THIS IS A WORK IN PROGRESS - DO NOT EDIT


Log in with the username/password you chose

Install ssh if it's not present

To check:

```
systemctl status ssh
```

  If it says:
  - ❌ "Unit ssh.service could not be found" → SSH not installed
  - ❌ "inactive (dead)" → SSH installed but not running
  - ✅ "active (running)" → SSH is running (different problem)


To install:
```
sudo apt update
sudo apt install openssh-server -y
```

Then start it:

```
sudo systemctl start ssh
sudo systemctl enable ssh
```

Verify:

```
systemctl status ssh
```

Get IP address:

```
hostname -I
```

Should start with either 10. or 192. This is the IP address you will use below.

Update the sudo to not require password:

```
sudo visudo -f /etc/sudoers.d/<USERNAME>-nopasswd
```
Add this line:

```
<USERNAME> ALL=(ALL) NOPASSWD:ALL
```



Copy your public key into authorized_keys

On setup system:

```
cat ~/.ssh/id_ed25519.pub
```
You'll see something like:
```
ssh-ed25519 AAAAC3Nza...
```
Copy the entire line to the clipboard.

On the VirtualBox system; use your favorite editor:

```
nano ~/.ssh/authorized_keys
```

Paste in the entire line and exit the editor.

On the setup machine, verify you can log in:

ssh <IP-ADDRESS>

Get the IP address (usually starts with 10):

hostname -I

From host machine, try connecting:

```
ssh <IP-ADDRESS>
```

