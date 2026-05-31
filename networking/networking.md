# Networking

Clan needs to know how to reach your machines when you run commands like `clan machines update` or `clan ssh`. Rather than hard-coding an IP address or hostname on each machine, you declare a **networking service** that tells Clan how to connect.

The real advantage is that you can configure more than one networking service at a time. Clan tries them in priority order until one succeeds. If your direct connection fails, it falls back to your VPN. If the VPN is down, it falls back to Tor. You don't have to decide which path to use; Clan works through them automatically.

---

## Available Networking Services

| Service | Priority | What It Does |
|---------|----------|--------------|
| `p2p-ssh-iroh` | 3000 | Peer-to-peer SSH via Iroh |
| `internet` | 2000 | Direct SSH via IP address or hostname |
| `wireguard` | 1000 | WireGuard VPN mesh with auto-assigned IPs |
| `zerotier` | 900 | ZeroTier VPN mesh with auto-assigned IPs |
| `mycelium` | 800 | Mycelium peer-to-peer overlay network |
| `tor` | 10 | Tor onion services; lowest priority, last-resort fallback |

A higher priority number means Clan tries that service first. When multiple services are configured, Clan works down the list from highest to lowest until it finds one that works.

---

## Internet: Direct SSH

The `internet` service is the simplest option. You give each machine a hostname or IP address and Clan connects directly via SSH.

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."my-server".settings.host = "server.example.com";
    roles.default.machines."my-laptop".settings.host = "192.168.1.10";
  };
};
```

By default, Clan connects as `root` on port 22. You can override both per machine:

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."my-server" = {
      settings.host = "server.example.com";
      settings.user = "admin";
      settings.port = 2222;
    };
  };
};
```

---

## ZeroTier: Mesh VPN

ZeroTier creates a private mesh network between your machines. Each machine gets an automatically assigned IP address; you don't need to know or track the addresses yourself. Clan generates and stores them.

The ZeroTier service requires exactly one machine to act as the **controller**. The controller manages network membership and admits machines to the network. All other machines are **peers**.

```nix
# clan.nix
inventory.instances = {
  zerotier = {
    roles.controller.machines."my-server" = {};
    roles.peer.tags = [ "all" ];
  };
};
```

Here `my-server` is the controller. Every machine in the inventory (via the `all` tag) joins as a peer. The controller is included in the `all` tag and participates as a peer as well.

The controller must be reachable by all peers, so it should be a machine with a stable public address. Pairing the `internet` service with ZeroTier is a good way to ensure the controller is always reachable while the peers connect via the mesh.

### Moon Nodes

If peers can't reach the controller directly (both behind NAT, for example), you can designate one or more machines as **moon** relay nodes. A moon must have a stable public address.

```nix
# clan.nix
inventory.instances = {
  zerotier = {
    roles.controller.machines."my-server" = {};
    roles.moon.machines."relay-server" = {
      settings.stableEndpoints = [ "203.0.113.5" ];
    };
    roles.peer.tags = [ "all" ];
  };
};
```

---

## Tor: Onion Service Fallback

Tor gives every machine a `.onion` address, making it reachable even without a public IP or open ports. Because Tor has the lowest priority (10), Clan only uses it when every other configured networking service has failed. It is meant as a last-resort fallback.

The `server` role sets up the onion service on machines you want to reach. The `client` role enables a persistent Tor proxy on machines that need to connect. If you don't assign the `client` role, Clan starts a temporary Tor proxy automatically when needed, so it is optional.

```nix
# clan.nix
inventory.instances = {
  tor = {
    roles.server.tags = [ "all" ];
  };
};
```

With just this, every machine gets a Tor onion address. Clan generates the onion keys automatically via `clan vars generate`.

To keep a Tor proxy running persistently on a machine that frequently initiates connections:

```nix
# clan.nix
inventory.instances = {
  tor = {
    roles.server.tags = [ "all" ];
    roles.client.machines."my-laptop" = {};
  };
};
```

---

## Combining Services

The real power of the networking system shows when you use multiple services together. Clan tries the highest-priority service first and falls back automatically if it cannot connect.

A straightforward setup: direct SSH for a public server, with Tor as a universal fallback for everything:

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."my-server".settings.host = "server.example.com";
  };

  tor = {
    roles.server.tags = [ "all" ];
  };
};
```

Clan always tries direct SSH first (priority 2000). If that fails, it falls back to Tor (priority 10).

A mesh setup with Tor as the final fallback:

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."my-server".settings.host = "server.example.com";
  };

  zerotier = {
    roles.controller.machines."my-server" = {};
    roles.peer.tags = [ "all" ];
  };

  tor = {
    roles.server.tags = [ "all" ];
  };
};
```

Clan tries direct SSH first (internet, priority 2000), then ZeroTier (priority 900), then Tor (priority 10).

---

## Emergency Override

If all configured networking is failing and you need to reach a machine directly, you can bypass the networking system entirely with the `--target-host` flag:

```bash
clan machines update my-server --target-host root@backup-ip.example.com
clan ssh my-server --target-host root@10.0.0.5
```

This is intended for debugging and emergency access only.
