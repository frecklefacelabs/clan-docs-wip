# ZeroTier Networking

ZeroTier creates a private, encrypted mesh network between your machines. Once configured, every machine gets an automatically assigned IP address and can reach every other machine on the network, regardless of NAT, firewalls, or physical location. You don't need public IP addresses, open firewall ports, or an account on zerotier.com. Clan runs its own controller.

Use ZeroTier when your machines are behind NAT, when laptops travel between networks, or when you want an always-on private network that handles connectivity for you without exposing anything to the public internet.

---

## How It Works in Clan

Clan manages the entire ZeroTier setup through the vars system. When you run `clan vars generate`, Clan generates a unique ZeroTier identity for each machine and derives a stable IP address from it. No manual IP assignment is needed.

The ZeroTier service has a priority of 900. If you also configure the `internet` service (priority 2000), Clan tries direct SSH first and falls back to ZeroTier if that fails.

---

## Roles

The ZeroTier service has three roles:

**`controller`**: Manages network membership. When a machine wants to join the ZeroTier network, the controller decides whether to admit it. You must have exactly one controller per ZeroTier instance. The controller needs to be online when new machines join; once machines are admitted, they continue communicating even if the controller goes offline later.

Because the controller must be reachable by new peers, it should be a machine with a stable, publicly accessible address. Pairing it with the `internet` service is a good way to ensure this.

**`peer`**: A regular member of the ZeroTier network. Most machines will be peers. They connect to other peers directly when possible; when a direct path isn't available, they route through moon relay nodes.

**`moon`** (optional): A relay node for peers that can't reach each other directly, most commonly because both are behind NAT. A moon must have a stable, publicly reachable IP address. Moons are optional; ZeroTier will attempt direct peer-to-peer paths first regardless.

---

## Basic Example

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

---

## Complete Example

This example adds a moon relay node. The moon is useful when laptops behind NAT may not be able to reach the controller directly.

```nix
# clan.nix
inventory.machines = {
  controller-server = { tags = [ "server" ]; };
  relay-server      = { tags = [ "server" ]; };
  sally-laptop      = { tags = [ "laptop" ]; };
  fred-laptop       = { tags = [ "laptop" ]; };
  backup-server     = { tags = [ "server" ]; };
};

inventory.instances = {
  # Give the controller a direct SSH address so new peers can always reach it
  internet = {
    roles.default.machines."controller-server".settings.host = "controller.example.com";
    roles.default.machines."relay-server".settings.host      = "relay.example.com";
  };

  zerotier = {
    # Exactly one controller is required
    roles.controller.machines."controller-server" = {};

    # Moon relay for peers that can't reach the controller directly
    roles.moon.machines."relay-server" = {
      settings.stableEndpoints = [ "203.0.113.5" ];
    };

    # All machines join as peers (includes controller and relay)
    roles.peer.tags = [ "all" ];
  };
};
```

After running `clan vars generate` and deploying, every machine has a ZeroTier IP and can reach every other machine in the network.

---

## Adding External Machines

If you have devices outside your Clan inventory that you want to admit to the ZeroTier network (a phone, a colleague's laptop, a cloud VM), you can allow them on the controller by node ID. The node ID of any ZeroTier device is shown by running `zerotier-cli info` on that device.

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

---

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
