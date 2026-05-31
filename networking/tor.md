# Tor Networking

The Tor service gives every machine a `.onion` address: a stable, cryptographically unique identifier that works anywhere Tor is running. Machines are reachable through the Tor network without public IP addresses, open firewall ports, or any DNS configuration.

Tor has the lowest priority (10) of all Clan networking services. Clan only uses it after every other configured networking service has failed. It is designed as a last-resort fallback: always available in theory, but the slowest option by a wide margin.

Use Tor when:

- You want a guaranteed fallback for machines that might be temporarily unreachable via direct SSH or VPN
- You have machines completely behind NAT with no public address and no VPN infrastructure
- You need to reach machines in environments with restrictive firewalls that block VPN protocols
- You want connections to remain possible even during major network disruptions

:::admonition[Experimental]{type=danger}
This service is experimental and will change in the future.
:::

---

## How It Works in Clan

When you assign a machine the `server` role, Clan generates a unique Ed25519 key pair for it and configures a Tor version 3 onion service. The `.onion` hostname is derived from the key pair and managed as a var. Clan distributes the hostname to any machine that needs to connect and uses it automatically when falling back to Tor.

By default, the hostname is stored as a secret var and does not appear in plaintext in your configuration. This is recommended: anyone who discovers the `.onion` address could attempt brute-force attacks against the SSH service.

---

## Roles

**`server`**: Configures a Tor onion service on the machine. The machine becomes reachable at a `.onion` address. By default, port 22 on the onion address maps to port 22 on the machine (SSH). Assign this role to every machine you want to be reachable via Tor.

**`client`** (optional): Enables a persistent Tor proxy on the machine. If you don't assign this role, Clan starts a temporary Tor proxy on demand whenever it needs to connect via Tor. The `client` role is useful on machines that frequently initiate Tor connections, since the proxy is already running and connections establish faster.

---

## Basic Example

```nix
# clan.nix
inventory.instances = {
  tor = {
    roles.server.tags = [ "all" ];
  };
};
```

This is all you need. After running `clan vars generate` and deploying, every machine has a Tor onion address and Clan can use it as a fallback automatically.

---

## Complete Example

This setup uses the `internet` service for primary connectivity and Tor as a fallback for all machines. The admin laptop gets the `client` role because it frequently connects to other machines and benefits from a persistent Tor proxy.

```nix
# clan.nix
inventory.machines = {
  web-server    = { tags = [ "server" ]; };
  db-server     = { tags = [ "server" ]; };
  backup-server = { tags = [ "server" ]; };
  admin-laptop  = { tags = [ "laptop" ]; };
};

inventory.instances = {
  # Primary: direct SSH for servers with public addresses
  internet = {
    roles.default.machines."web-server".settings.host    = "web.example.com";
    roles.default.machines."db-server".settings.host     = "db.example.com";
    roles.default.machines."backup-server".settings.host = "backup.example.com";
  };

  # Fallback: Tor for all machines
  tor = {
    roles.server.tags = [ "all" ];

    # Keep a persistent Tor proxy on the admin laptop
    roles.client.machines."admin-laptop" = {};
  };
};
```

Clan tries direct SSH first (priority 2000). If a server is unreachable at its public address, Clan falls back to Tor (priority 10).

---

## Port Mapping

By default, the onion service maps port 22 to port 22. If your SSH daemon listens on a different port, adjust the mapping:

```nix
# clan.nix
inventory.instances = {
  tor = {
    roles.server.machines."my-server" = {
      settings.portMapping = [
        { port = 22; target.port = 2222; }
      ];
    };
  };
};
```

This exposes port 22 on the onion address and forwards it to port 2222 on the machine.

---

## Secret Hostnames

The `secretHostname` setting defaults to `true`, keeping the `.onion` address out of plaintext configuration. This is strongly recommended for any machine exposed to the internet.

In a controlled internal environment where you are certain exposure of the address isn't a concern, you can disable it:

```nix
# clan.nix
inventory.instances = {
  tor = {
    roles.server.machines."internal-machine" = {
      settings.secretHostname = false;
    };
  };
};
```

Clan handles distributing onion addresses to machines that need them. You don't manage or share the hostname yourself.
