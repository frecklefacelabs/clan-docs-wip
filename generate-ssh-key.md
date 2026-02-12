# Generating an SSH ED25519 Key Pair

## What is this?

SSH keys provide secure, passwordless authentication to remote servers. Instead of typing a password every time you connect, your computer proves its identity using cryptographic keys. This is more secure than passwords and required for Clan to manage your machines.

**Why ED25519?** This is the recommended modern SSH key type. It's faster, more secure, and uses smaller keys than older RSA keys. While RSA keys still work, ED25519 is the current best practice. Additionally, this key behaves as a default key, allowing you to type ssh commands without specifying a key.

## Check if you already have one

Before generating a new key, check if you already have one:

```bash
ls ~/.ssh/id_*.pub
```

If you see `id_ed25519.pub`, you already have an SSH key and can skip to "View Your Public Key" below.

## Generate a new key

If you don't have a key, generate one:

### Quick Command

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

Press Enter to accept defaults, and optionally set a passphrase for extra security.

## What This Creates

Two files in `~/.ssh/`:

- **`id_ed25519`** - Your PRIVATE key (never share this!)
- **`id_ed25519.pub`** - Your PUBLIC key (safe to share)

## View Your Public Key

```bash
cat ~/.ssh/id_ed25519.pub
```

This outputs something like:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFtw1BOb553JRTNxM2lelAZqPY1THQtA16vBIvv2TQcl your-email@example.com
```

## How It Works

- **Private key** stays on your computer - this is like your password
- **Public key** goes on servers you want to access - this is like a lock
- Only your private key can unlock the public key

## Security Notes

- Keep your private key (`id_ed25519`) secure
- Never commit it to git or share it
- The public key (`id_ed25519.pub`) is safe to put anywhere

You'll typicall add the public key to the `.ssh/authorized_keys` file to grant access to that server via ssh without having to specify a key.

