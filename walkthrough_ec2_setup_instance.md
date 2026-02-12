# Running a setup instance on AWS

Here we walk through the steps of configuring an Amazon EC2 Instance to be used as the setup machine.


!!! Note Prerequisite
    An understanding of how to launch EC2 instances, and how to connect to them through ssh using a key file.


## Provisioning the Instance

From inside the AWS Console, go to EC2, and click on Instances on the left. Then click `Launch Instances`.

Provide a name, such as `Clan Setup`.

Under **Application and OS Images**, choose **Quick Start**, and under that click on **Amazon Linux**.

Under **Instance type** you have some flexibility, but we recommend choosing at least **t2-small**; however **t2-large** works best.

Under **Key pair**, select one of your existing key pairs, or create a new one.

Under **Network Settings** you can either create a security group or use an existing one; in either case it needs to allow SSH traffic from at least your own IP address.

Click **Launch instance**.

## Connecting and Installing Software

Now connect to your server using ssh; for example:

```bash
ssh -i <KEY-PAIR-FILE> ec2-user@<IP-ADDRESS>
```

substituting:
* **<KEY-PAIR-FILE>** for the path and name of your key pair file
* **<IP-ADDRESS>** for your new server's public IP address. You can find this by clicking on the instance ID in the console; it will be in the middle near the top.

!!! Tip
    The main username for Amazon Linux is `ec2-user`.

Once inside, you need to install:

* git
* nix
* direnv

Below are instructions on each.

### Install git

Install git:

```bash
sudo dnf update -y
sudo dnf install git -y
```

Test it:
git --version

### Install nix

Install nix:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

Next, log out and log back in so your path can find it.

Then test it:

```bash
nix --version
```

Now enable experimental features:

```bash
echo "extra-experimental-features = nix-command flakes" \
| sudo tee -a /etc/nix/nix.conf
```

### Install direnv:

Install direnv and test it:

```bash
nix-env -iA nixpkgs.direnv
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc
direnv --version
```

## Next Steps

You just set up an instance that can be used as the main Clan setup server. Next you can set try our Getting Started steps. 

For this we recommend provisioning an Ubuntu server on AWS within the same VPC, and connecting to it through the private IP addresses.

You can find the initial setup steps here.

