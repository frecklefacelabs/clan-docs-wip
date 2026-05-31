# WireGuard Networking

WireGuard creates a private, encrypted VPN mesh between your machines using automatic IPv6 address allocation. Every machine gets a stable address on the network without manual configuration, and keys are generated and distributed by Clan through the vars system.

WireGuard has a priority of 1000, so if you also configure the `internet` service (priority 2000), Clan tries direct SSH first and falls back to WireGuard if that fails.

---

## How It Differs from ZeroTier

Both WireGuard and ZeroTier create encrypted private networks with auto-assigned IPs, but they work differently:

- **ZeroTier** attempts direct peer-to-peer connections and routes through relay nodes only when needed. The controller just manages membership; peers talk to each other directly when possible.
- **WireGuard** routes all peer traffic through controllers. Controllers must have publicly reachable endpoints. Peers never talk to each other directly; traffic always hops through a controller.

Use WireGuard when you want the performance and simplicity of a well-established VPN protocol and you have at least one server with a public address to act as a controller. Use ZeroTier when you want true P2P connectivity and are comfortable with its additional complexity.

---

## Requirements

- Controllers must have a stable, publicly reachable endpoint (IP address or DNS hostname)
- Peers must be in networks where UDP traffic is not blocked (WireGuard uses port 51820 by default)

---

## Roles

**`controller`**: Routes traffic between all peers. Must have a publicly reachable endpoint. You can have multiple controllers for redundancy; controllers also connect to each other. A machine cannot be both a controller and a peer in the same WireGuard instance.

Controller settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `endpoint` | (required) | Hostname or IP where this controller can be reached |
| `port` | `51820` | UDP port for WireGuard |
| `domain` | instance name | Hostname suffix used in `/etc/hosts` entries |
| `mtu` | `null` | MTU for the WireGuard interface, if you need to override it |

**`peer`**: Connects to all controllers and sends all traffic through them. Most machines will be peers.

Peer settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `controller` | auto | Which controller's subnet to use for hostname resolution. Required only when multiple controllers exist. |
| `port` | `51820` | UDP port |
| `domain` | instance name | Hostname suffix used in `/etc/hosts` entries |
| `mtu` | `null` | MTU override |

---

## Basic Example

```nix
# clan.nix
inventory.machines = {
  vpn-server   = { tags = [ "server" ]; };
  sally-laptop = { tags = [ "laptop" ]; };
  fred-laptop  = { tags = [ "laptop" ]; };
};

inventory.instances = {
  wireguard = {
    roles.controller.machines."vpn-server" = {
      settings.endpoint = "vpn.example.com";
    };
    roles.peer.tags = [ "laptop" ];
  };
};
```

`vpn-server` is the controller. The laptops are peers and connect to it. Note that the `laptop` tag is used for peers rather than `all`: a machine cannot be both a controller and a peer in the same WireGuard instance, so you must keep the controller out of the peer role.

---

## Complete Example

This example shows two controllers for redundancy, with peers specifying which controller to use for hostname resolution.

```nix
# clan.nix
inventory.machines = {
  vpn-server-1 = { tags = [ "server" ]; };
  vpn-server-2 = { tags = [ "server" ]; };
  sally-laptop = { tags = [ "laptop" ]; };
  fred-laptop  = { tags = [ "laptop" ]; };
  backup-server = { tags = [ "backup" ]; };
};

inventory.instances = {
  wireguard = {
    roles.controller.machines."vpn-server-1" = {
      settings.endpoint = "vpn1.example.com";
      settings.port = 51820;
    };
    roles.controller.machines."vpn-server-2" = {
      settings.endpoint = "vpn2.example.com";
      settings.port = 51820;
    };

    # When multiple controllers exist, peers must declare which one
    # to use for hostname resolution
    roles.peer.machines."sally-laptop" = {
      settings.controller = "vpn-server-1";
    };
    roles.peer.machines."fred-laptop" = {
      settings.controller = "vpn-server-2";
    };
    roles.peer.machines."backup-server" = {
      settings.controller = "vpn-server-1";
    };
  };
};
```

Both controllers connect to each other and to all peers. If one controller goes down, peers can still reach each other through the remaining one.

---

## Hostname Resolution

WireGuard automatically adds entries to `/etc/hosts` for every machine in the network. Each machine is reachable using the format `<machine-name>.<instance-name>`.

With the instance named `wireguard` in the example above:

```bash
ping6 vpn-server-1.wireguard
ssh user@sally-laptop.wireguard
```

If you want a different suffix, set the `domain` option on the controller (peers inherit it):

```nix
roles.controller.machines."vpn-server-1" = {
  settings.endpoint = "vpn1.example.com";
  settings.domain = "vpn";
};
```

Machines would then be reachable as `sally-laptop.vpn`, `fred-laptop.vpn`, and so on.

---

## MTU Issues

If ping works but other connections behave strangely (dropped packets, stalled transfers), the WireGuard interface MTU may be too high for your network path. Try lowering it:

```nix
roles.controller.machines."vpn-server-1" = {
  settings.endpoint = "vpn1.example.com";
  settings.mtu = 1350;
};
```

Set the same MTU on peers if the controller alone doesn't resolve it. Start low (1280 is a safe minimum for IPv6) and work up to find the highest value that still works reliably.

---

## Pairing with Other Networking Services

WireGuard works well alongside the `internet` service for direct access to controllers, and Tor as a last-resort fallback:

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."vpn-server-1".settings.host = "vpn1.example.com";
    roles.default.machines."vpn-server-2".settings.host = "vpn2.example.com";
  };

  wireguard = {
    roles.controller.machines."vpn-server-1" = {
      settings.endpoint = "vpn1.example.com";
    };
    roles.controller.machines."vpn-server-2" = {
      settings.endpoint = "vpn2.example.com";
    };
    roles.peer.tags = [ "laptop" ];
  };

  tor = {
    roles.server.tags = [ "all" ];
  };
};
```

Clan tries direct SSH first (priority 2000), then WireGuard (priority 1000), then Tor (priority 10).
