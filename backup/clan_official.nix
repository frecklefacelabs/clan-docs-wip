{
  # Ensure this is unique among all clans you want to use.
  meta.name = "MY-BACKUP-CLAN";
  meta.domain = "mybackupclan.lol";

  inventory.machines = {
    alice-laptop = {
        deploy.targetHost = "root@10.0.0.39";
        tags = [ "employees" ];
    };
    backup-server = {
        deploy.targetHost = "root@10.0.0.40";
        tags = [ ];
    };
    db-server = {
        deploy.targetHost = "root@<IP-ADDRESS>"; # REPLACE WITH YOUR DB SERVER'S IP ADDRESS
        tags = [ ];
    };
  };

  inventory.instances = {
    borgbackup = {
      roles.client.tags = [ "employees" ]
      roles.client.machines."db-server" = {};
      roles.server.machines."backup-server" = {
        settings.address = "10.0.0.40";
        settings.directory = "/var/lib/borgbackup";
      };
    };

    user-alice = {
      module.name = "users";
      roles.default.machines."alice-laptop" = {};
      roles.default.tags = [ "all" ];
      roles.default.settings = {
        user = "alice";
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZGMNlooljzJfmzQKaVcmj4tRYW+gqBIfdWbG0NU3XL freckleface@freckleface--Laptop" ];
      };
    };

    sshd = {
      roles.server.tags.all = { };
      roles.server.settings.authorizedKeys = {
        "admin-machine-1" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZGMNlooljzJfmzQKaVcmj4tRYW+gqBIfdWbG0NU3XL freckleface@freckleface--Laptop";
      };
    };

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

  machines = {

    alice-laptop = { ... }: {
      systemd.tmpfiles.rules = [
        "d /home/alice/documents 0755 alice users -"
        "d /home/alice/pictures 0755 alice users -"
      ];

      clan.core.state."my-documents" = {
        folders = [
          "/home/alice/documents"
          "/home/alice/pictures"
        ];
      };
    };

    db-server = { pkgs, ... }: {
      services.postgresql.enable = true;
      services.postgresql.package = pkgs.postgresql_16;

      clan.core.postgresql.databases.mydb = {};
      clan.core.postgresql.users.myuser = {};

      clan.core.state."postgresql" = {
        preBackupScript = ''
          systemctl stop postgresql
        '';
        postBackupScript = ''
          systemctl start postgresql
        '';
      };
    };

  };
}
