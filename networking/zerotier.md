# ZeroTier Networking

ZeroTier creates a private, encrypted mesh network between your machines. Once configured, every machine gets an automatically assigned IP address and can reach every other machine on the network, regardless of NAT, firewalls, or physical location. You don't need public IP addresses, open firewall ports, or an account on zerotier.com. Clan runs its own controller.

Use ZeroTier when your machines are behind NAT, when laptops travel between networks, or when you want an always-on private network that handles connectivity for you without exposing anything to the public internet.

# How It Works in Clan

Clan manages the entire ZeroTier setup through the vars system. When you run `clan vars generate`, Clan generates a unique ZeroTier identity for each machine and derives a stable IP address from it. No manual IP assignment is needed.

The ZeroTier service has a priority of 900. If you also configure the `internet` service (priority 2000), Clan tries direct SSH first and falls back to ZeroTier if that fails.

# Roles

The ZeroTier service has three roles:

**`controller`**: Manages network membership. When a machine wants to join the ZeroTier network, the controller decides whether to admit it. You must have exactly one controller per ZeroTier instance. The controller needs to be online when new machines join; once machines are admitted, they continue communicating even if the controller goes offline later.

Because the controller must be reachable by new peers, it should be a machine with a stable, publicly accessible address. Pairing it with the `internet` service is a good way to ensure this.

**`peer`**: A regular member of the ZeroTier network. Most machines will be peers. They connect to other peers directly when possible; when a direct path isn't available, they route through moon relay nodes.

**`moon`** (optional): A relay node for peers that can't reach each other directly, most commonly because both are behind NAT. A moon must have a stable, publicly reachable IP address. Moons are optional; ZeroTier will attempt direct peer-to-peer paths first regardless.

# Basic Example

```nix
# clan.nix
inventory.machines = {
  my-server     = { tags = [ "server" ]; };
  sally-laptop  = { tags = [ "laptop" ]; };
  fred-laptop   = { tags = [ "laptop" ]; };
};

inventory.instances = {
  zerotier = {
    roles.controller.machines."my-server" = {};
    roles.peer.tags = [ "all" ];
  };
};
```

`my-server` is the controller. All machines, including `my-server` itself via the `all` tag, join as peers. Clan generates ZeroTier identities and IPs for every machine automatically.

# Guide

To try out the ZeroTier feature, creating three cloud servers using the initial part of the Getting Started guide for a cloud ([such as AWS](../../getting-started/getting-started-aws.md) or [or Heztner](../../getting-started/getting-started-hetzner.md)), including adding your id_ed25519 key pair.

Create the clan, calling it CLAN-ZT:

```bash
nix run https://clan.lol/install/26.05 --refresh -- init
cd CLAN-ZT
direnv allow
```

and then create the three machines:

```bash
clan machines create my-controller
clan machines create peer1
clan machines create peer2
```

Update `clan.nix` to look like the following:

```nix
{
  # Ensure this is unique among all clans you want to use.
  meta.name = "CLAN-ZT";
  meta.domain = "clanzt.lol";

  inventory.machines = {
    my-controller = {
        tags = [ "controller" ];
    };
    peer1 = {
        tags = [ "peer" ];
    };
    peer2 = {
        tags = [ "peer" ];
    };
  };

  inventory.instances = {

    internet = {
      roles.default.machines."my-controller" = {
        settings.host = "<IP-ADDRESS>"; # REPLACE WITH YOUR CONTROLLER MACHINE'S IP ADDRESS
        settings.user = "root";
      };
      roles.default.machines."peer1" = {
        settings.host = "<IP-ADDRESS>"; # REPLACE WITH YOUR FIRST PEER MACHINE'S IP ADDRESS
        settings.user = "root";
      };
      roles.default.machines."peer2" = {
        settings.host = "<IP-ADDRESS>"; # REPLACE WITH YOUR SECOND PEER MACHINE'S IP ADDRESS
        settings.user = "root";
      };
    };

    zerotier = {
      # Specify the controller here
      roles.controller.machines."my-controller" = {};

      # Specify which machines become part of ZeroTier
      roles.peer.tags = [ "all" ];
    };

    # Docs: https://clan.lol/docs/services/official/sshd
    # SSH service for secure remote access to machines.
    # Generates persistent host keys and configures authorized keys.
    sshd = {
      roles.server.tags.all = { };
      roles.server.settings.authorizedKeys = {
        # Insert the public key that you want to use for SSH access.
        # All keys will have ssh access to all machines ("tags.all" means 'all machines').
        # Alternatively set 'users.users.root.openssh.authorizedKeys.keys' in each machine
        "admin-machine-1" = "PASTE_YOUR_KEY_HERE";
      };
    };

    # Docs: https://clan.lol/docs/unstable/services/official/users
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

    # Docs: https://clan.lol/docs/unstable/services/official/p2p-ssh-iroh
    # Status experimental
    # Firewall-traversing SSH access via encrypted QUIC streams
    # p2p-ssh-iroh = {
    #   roles.server.tags = [ "nixos" ];
    # };
  };
}

```

Gather the hardware configuration:

```bash
clan machines init-hardware-config my-controller
clan machines init-hardware-config peer1
clan machines init-hardware-config peer2
```

(For AWS, you'll add on `--target-host ubuntu@<IP-ADDRESS>` to each line.)

Add a disk configuration using the usual approach of re-running each command with the generated output added inside double-quotes:

```bash
clan templates apply disk ext4-single-disk my-controller --set mainDisk ""
clan templates apply disk ext4-single-disk peer1 --set mainDisk ""
clan templates apply disk ext4-single-disk peer2 --set mainDisk ""
```

*Here's where we diverge from the usual steps.*

Now generate vars. This generates the necessary setup for ZeroTier. Start with controller:
s
```bash
clan vars generate my-controller
```

Then do the peers:

```bash
clan vars generate peer1
clan vars generate peer2
```

(Note that if you get messages that an identity doesn't exist, go ahead and run the vars generate command for the machine specified in the error message. Then loop back and start with the controller again, and then with peer1 again.)


Next install the controller first:

```
clan machines install my-controller
```

Then install the rest:

```
clan machines install peer1
```

```
clan machines install peer2
```


Here's how you discover the IPv6 addresses for each of the three machines:

```
clan vars get my-controller zerotier-ip-my-controller-zerotier/ip
clan vars get peer1 zerotier-ip-my-controller-zerotier/ip
clan vars get peer2 zerotier-ip-my-controller-zerotier/ip
```

Now you can try pinging. `SSH` into `peer1` and then:
From peer1:

```
ping <PEER2-IPv6-ADDRESS>
```

Then to be sure, try pinging the above from a computer not on the ZeroTier network. You'll get a message that the network is unreachable.


# Adding External Machines

If you have devices outside your Clan inventory that you want to admit to the ZeroTier network (a phone, a colleague's laptop, a cloud VM), you can allow them on the controller by node ID. The node ID of any ZeroTier device is shown by running `zerotier-cli info` on that device.

On Linux, first install ZeroTier:

```bash
curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/main/doc/contact%40zerotier.com.gpg' | gpg --import && \
if z=$(curl -s 'https://install.zerotier.com/' | gpg); then echo "$z" | sudo bash; fi
```

Note the ID at the end of the "Success!" message, e.g.:

```
*** Success! You are ZeroTier address [ 0c27a66feb ].
```

Now obtain the network ID:

```bash
clan vars get my-controller zerotier-network-zerotier/network-id
```

For example:

```
0d00bbf7d9b17658
```

Add this to inside zerotier:

  roles.controller.machines."my-controller".settings.allowedIds = [
    "deadbeef00"     # ← node ID from `zerotier-cli info` on the outside machine
  ];

Then update controller:

```bash
clan machines update my-controller
```

Then try pinging one of the other computers from the computer that joined:

```
ping6 fd0d:bb:f7d9:b176:5899:93bf:df38:8f4d
```


```nix
# clan.nix
inventory.instances = {
  zerotier = {
    roles.controller.machines."controller-server" = {
      settings.allowedIds = [ "deadbeef00" "abc1234567" ];
    };
    roles.peer.tags = [ "all" ];
  };
};
```

You can also allow external machines by their ZeroTier IP address if you already know it:

```nix
roles.controller.machines."controller-server" = {
  settings.allowedIps = [ "fd5d:bbe3:cbc5:fe6b:f699:935d:bbe3:cbc5" ];
};
```


# Moon Relay Demo

If you have computers managed by a Clan that are on different networks or behind NATs, a Relay (also called Moon) is helpful. Instead of opening the controller up to the world, you allow the machines to connect to a computer whose job is to relay information into the network.

Follow the Cloud getting started guide and create two servers:

1. One for the controller
2. One for the relay through which servers out-of-network (for example, laptops behind a NAT) can connect

Important: In addition to opening port 22 (SSH) for incoming traffic, you'll also need to open UDP port 9993:

* The relay needs to accept incoming UDP 9993 traffic from *anywhere*
* The controller needs to accept incoming UDP 9993 traffic, but only from *the relay*

Depending on your cloud platform, to accomplish the above, you'll need two different security groups or firewall rules.

Important: The relay needs a permanent IP address. (Or, if you're just trying this out, the IP address needs to remain the same throughout the exercise.)

Then, with a laptop, follow the Physical server for getting started. (Or, if you want to simulate this just to try it out, create a VirtualBox virtual machine.)

Next:

```bash
clan machines create my-controller
clan machines create my-relay
clan machines create my-laptop
```

For example, if you're using VirtualBox to simulate a laptop, and two cloud machines, you could use the following:

```nix
{
  # Ensure this is unique among all clans you want to use.
  meta.name = "CLAN-MOON2";
  meta.domain = "clanmoon2.lol";

  inventory.machines = {
    my-controller = {
        tags = [ "controller" ];
    };
    my-relay = {
        tags = [ "peer" ];
    };
    my-laptop = {
        tags = [ "peer" ];
    };

  };

  inventory.instances = {

    internet = {
      roles.default.machines."my-controller" = {
        settings.host = "<IP-ADDRESS>"; # REPLACE WITH YOUR MACHINE'S IP ADDRESS
        settings.user = "root";
      };
      roles.default.machines."my-relay" = {
        settings.host = "<IP-ADDRESS>"; # REPLACE WITH YOUR MACHINE'S IP ADDRESS
        settings.user = "root";
      };
      roles.default.machines."my-laptop" = {
        settings.host = "127.0.0.1"; # Use NAT with port forwarding
        settings.user = "root";
        settings.port = 2222;
      };
    };

    zerotier = {
      roles.controller.machines."my-controller" = {};
      roles.moon.machines."my-relay" = {
        settings.stableEndpoints = [ "<IP-ADDRESS>" ]; # Fill in with the Relay's public IP address
      };
      roles.peer.tags = [ "all" ];
    };

    # Docs: https://clan.lol/docs/services/official/sshd
    # SSH service for secure remote access to machines.
    # Generates persistent host keys and configures authorized keys.
    sshd = {
      roles.server.tags.all = { };
      roles.server.settings.authorizedKeys = {
        # Insert the public key that you want to use for SSH access.
        # All keys will have ssh access to all machines ("tags.all" means 'all machines').
        # Alternatively set 'users.users.root.openssh.authorizedKeys.keys' in each machine
        "admin-machine-1" = "PASTE_YOUR_KEY_HERE";
      };
    };

    # Docs: https://clan.lol/docs/unstable/services/official/users
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
}
```

Then when you do the hardward config:

```bash
clan machines init-hardware-config my-controller --target-host ubuntu@<IP-ADDRESS>
clan machines init-hardware-config my-relay --target-host ubuntu@<IP-ADDRESS>
clan machines init-hardware-config my-laptop
```

Then adding a disk you'll use, filling in the final quotes:

```bash
clan templates apply disk ext4-single-disk my-controller --set mainDisk ""
clan templates apply disk ext4-single-disk my-relay --set mainDisk ""
clan templates apply disk ext4-single-disk my-laptop --set mainDisk ""
```

Now add the ZeroTier configuration; put this inside inventory.instances:

Next, do a vars generate on each, starting with my-controller; you might need to repeat my-controller after finishing the other three:

```bash
clan vars generate my-controller
clan vars generate my-relay
clan vars generate my-laptop
```

Or, with --no-sandbox:

```bash
clan vars generate my-controller --no-sandbox
clan vars generate my-relay --no-sandbox
clan vars generate my-laptop --no-sandbox
```

At this point, Clan and ZeroTier have already created IPv6 addresses for each machine, even though you haven't installed Clan yet on any of them. You can obtain them as follows:

```bash
clan vars get my-controller zerotier-ip-my-controller-zerotier/ip
clan vars get my-relay zerotier-ip-my-relay-zerotier/ip
clan vars get my-laptop zerotier-ip-my-laptop-zerotier/ip
```

Now you're ready to install. Install in this order: my-controller, my-relay, my-laptop.

```bash
clan machines install my-controller
clan machines install my-relay
clan machines install my-laptop
```

Now try `SSH`ing into each; as before, you'll probably get a message that you have to run ssh-keygen for each before you can SSH in.

Inside each, try pinging each other IPv6 address.

Then, inside the `my-laptop` machine, look at the output from this:

```bash
zerotier-cli peers
```

You should see one MOON with link type DIRECT, and at least one LEAF with link type RELAY:

```
<ztaddr>   <ver>  <role> <lat> <link>   <lastTX> <lastRX> <path>
0575c8a9f4 1.16.0 MOON      56 DIRECT   3840     3784     35.88.39.174/48295
2cfda73752 -      LEAF      -1 RELAY
62f865ae71 -      LEAF      -1 RELAY
778cde7190 -      PLANET    72 DIRECT   3975     14316    103.195.103.66/9993
cafe04eba9 -      PLANET   214 DIRECT   3975     19175    84.17.53.155/9993
cafe80ed74 -      PLANET    41 DIRECT   3975     3897     185.152.67.145/9993
cafe9efeb9 -      LEAF      -1 RELAY
cafefd6717 -      PLANET   155 DIRECT   3975     14233    79.127.159.187/9993
```


ZeroTier handles outbound NAT traversal automatically. In a real-world production deployment, users won't need to change anything on their local router or firewall outbound settings; they only need to ensure their corporate firewalls don't aggressively block outgoing UDP traffic entirely.


## Pairing ZeroTier with Other Networking Services

ZeroTier works well alongside the `internet` service for direct access and Tor as a final fallback:

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."controller-server".settings.host = "controller.example.com";
  };

  zerotier = {
    roles.controller.machines."controller-server" = {};
    roles.peer.tags = [ "all" ];
  };

  tor = {
    roles.server.tags = [ "all" ];
  };
};
```

Clan tries direct SSH first (priority 2000), then ZeroTier (priority 900), then Tor (priority 10). The controller is always reachable via the `internet` service even before ZeroTier is established on a new machine.


