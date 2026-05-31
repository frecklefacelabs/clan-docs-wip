# Internet Networking

The `internet` service is the most straightforward way to connect to your machines. You give each machine a hostname or IP address, and Clan connects directly via SSH. Use it when your machines have stable, reachable addresses: public IPs, DNS hostnames, or local network addresses that don't change.

When Clan connects to a machine, it tries networking services in priority order. The `internet` service has a priority of 2000, the highest of the standard networking services, so Clan always tries direct SSH first. If the connection fails and you have other networking services configured, Clan falls back to them automatically.

:::admonition[Experimental]{type=danger}
This service is experimental and will change in the future.
:::

---

## When to Use

Use the `internet` service when:

- Your machines have public IP addresses or DNS hostnames
- Your machines are on a local network and always reachable by IP
- You want the simplest possible networking setup with no VPN infrastructure
- You want direct SSH as the first-choice connection method, with other services as fallback

If your machines are behind NAT and have no way to be reached directly, the `internet` service won't work on its own. Consider adding ZeroTier or Tor alongside it, or instead of it.

---

## Settings

The `internet` service has a single role, `default`, with these settings per machine:

| Setting | Default | Description |
|---------|---------|-------------|
| `host` | (required) | IP address or hostname of the machine |
| `port` | `22` | SSH port |
| `user` | `null` (connects as `root`) | SSH user |
| `jumphosts` | `[]` | List of SSH jump hosts to route through |

---

## Basic Example

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."web-server".settings.host  = "web.example.com";
    roles.default.machines."backup-server".settings.host = "192.168.1.100";
  };
};
```

Both machines use the defaults: connect as `root` on port 22.

---

## Complete Example

This example shows a realistic setup with machines that need different settings: a standard server, one with a non-standard port and user, and one that is only reachable through a jump host.

```nix
# clan.nix
inventory.machines = {
  web-server = { tags = [ "server" ]; };
  db-server  = { tags = [ "server" ]; };
  admin-box  = { tags = [ "server" ]; };
};

inventory.instances = {
  internet = {
    # Public web server, standard SSH defaults
    roles.default.machines."web-server" = {
      settings.host = "web.example.com";
    };

    # Database server on a non-standard port with a dedicated deploy user
    roles.default.machines."db-server" = {
      settings.host = "db.example.com";
      settings.port = 2222;
      settings.user = "deploy";
    };

    # Admin box behind a firewall, reachable only through a jump host
    roles.default.machines."admin-box" = {
      settings.host = "admin.internal.example.com";
      settings.jumphosts = [ "jump.example.com" ];
    };
  };
};
```

When Clan connects to `admin-box`, it tunnels through `jump.example.com` automatically.

---

## Using Internet with Other Networking Services

Because `internet` has the highest standard priority, it works well as your first-choice connection method with other services providing fallback. A common pattern is direct SSH plus Tor for resilience:

```nix
# clan.nix
inventory.instances = {
  internet = {
    roles.default.machines."web-server".settings.host    = "web.example.com";
    roles.default.machines."backup-server".settings.host = "backup.example.com";
  };

  tor = {
    roles.server.tags = [ "all" ];
  };
};
```

Clan tries direct SSH first (priority 2000). If a machine is temporarily unreachable at its public address, Clan falls back to Tor (priority 10). The machines stay reachable even during network disruptions.
