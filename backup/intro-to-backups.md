# Introduction to Backups

Clan makes it easy to back your machines up from one to another. You define what to back up and where to send it, and Clan handles the rest: encryption, scheduling, and restoration.

---

## How Clan Backups Work

Clan backups have two parts:

1. **What to back up**: folders, databases, application state
2. **Where to send it**: another machine in your clan

Under the hood, Clan uses [BorgBackup](https://www.borgbackup.org/), which provides:

- **Deduplication**: only stores changes, saving disk space
- **Encryption**: backups are encrypted before leaving the machine
- **Compression**: smaller backups, faster transfers

You don't need to know BorgBackup to use Clan backups. Clan configures everything for you.

---

## The Basic Setup

### 1. Define What to Back Up

On each machine, you define a **state**, which refers to the folders and data that are to be included in the backup. This goes in the machine's configuration file:

```nix
# machines/my-laptop/configuration.nix
{ ... }:
{
  clan.core.state.my-app = {
    folders = [
      "/var/lib/my-app"
      "/etc/my-app"
    ];
  };
}
```

**Note:** While `clan.nix` holds your inventory (services, machines, roles), each machine also has its own `configuration.nix` file for machine-specific settings. You're encouraged to edit these files as needed if you need per-machine customization.

**Why "state" instead of "backup"?** The `clan.core.state` option declares "this data is important" and that it's not specific to backups. The backup service reads your state definitions and includes them automatically. This separation means you define what matters once, and different services (backup, restore, migration) can all use it. If you ever switch backup tools, your state definitions stay the same.

### 2. Set Up the Backup Service

In your `clan.nix`, add the borgbackup service with **client** and **server** roles:

```nix
inventory.instances.borgbackup = {
  roles.client.machines."my-laptop" = {};
  roles.server.machines."my-server" = {};
};
```

This says: "Back up my-laptop to my-server." Clients send backups; servers store them.

---

## TODO: FULL WORKING EXAMPLE

### Prerequisites
    
* One Clan created for testing
* Two machines added to the Clan. Call one "alice" to represent an actual user's computer, and the other "backups" to represent a machine dedicated to backups. 



---

## More Detail on Clients and Servers

The borgbackup service has two roles:

| Role | What it does |
|------|--------------|
| **client** | Creates backups and sends them to the server |
| **server** | Receives and stores backups from clients |

A machine can be both. For example, your NAS might store backups from your laptops (server role) while also backing itself up to an offsite location (in which case it takes on the client role).

---

## What Gets Backed Up?

By default, Clan backs up:

- Any folders you define in `clan.core.state`
- PostgreSQL databases (if you enable the PostgreSQL module)
- Secrets and vars needed by your services

You can also add **hooks**, which are scripts that run before or after backups, to handle special cases like stopping a service before backing up its data.

---

## Running a Backup

To back up a machine:

```bash
clan backups create my-laptop
```

This collects all the state you defined, encrypts it, and sends it to the server.

Backups can also run on a schedule. See the [Minimal Example](./minimal-example.md) for how to configure automatic backups with `startAt`.

---

## Restoring from Backup

When you need to restore:

```bash
clan backups restore my-laptop
```

Clan decrypts the backup and restores your state folders. If you defined hooks, they run automatically (stopping services before restore, starting them after).

---

## Next Steps

- [Minimal Example](./minimal-example.md) — A complete walkthrough setting up backups between machines
- [Advanced Example](./advanced-example.md) — Multiple backup destinations, scheduling, and more

