# Provisioning an AWS EC2 Ubuntu Instance

!!! Note Prerequisite
    An existing id_ed25519 key pair. To find out if you have one, or to learn how to create one, click here.


## Provisioning the Instance

From inside the AWS Console, go to EC2, and click on Instances on the left. Then click `Launch Instances`.

Provide a name, such as `Clan Setup`.

Under **Application and OS Images**, choose **Quick Start**, and under that click on **Ubuntu**.

Under **Instance type** you have some flexibility, but we recommend choosing at least **t2-small**; however **t2-large** works best.

Under **Key pair**, select one of your existing key pairs, or create a new one.

Under **Network Settings** you can either create a security group or use an existing one; in either case it needs to allow SSH traffic from at least your own IP address.

Click **Launch instance**.

After the server is created, make sure you can log into it:

```bash
ssh -i <KEY-PAIR-FILE> ubuntu@<IP-ADDRESS>
```

substituting:
* **\<KEY-PAIR-FILE\>** for the path and name of your key pair file
* **\<IP-ADDRESS\>** for your new server's public IP address. You can find this by clicking on the instance ID in the console; it will be in the middle near the top.

!!! Tip
    The main username for Ubuntu on EC2 is `ubuntu`.

## Add your id_ed25519 key pair

Next we need to configure your server by adding your key pair.

Add the key pair from your local server:

```bash
ssh -i ~/.ssh/<KEY-PAIR-FILE>.pem ubuntu@<IP-ADDRESS> \
"cat >> /home/ubuntu/.ssh/authorized_keys" < ~/.ssh/id_ed25519.pub
```

Now you should be able to connect without specifying a key:

```
ssh ubuntu@<IP-ADDRESS>
```

!!! Important
    This step is not optional; Clan uses an existing id_ed25519 key to connect.

Now you're ready to proceed with the steps in the Getting Started Guide.





