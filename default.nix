{ repo ? builtins.fetchGit ./.
, versionFile ? ./.version
, officialRelease ? false

, nixpkgs ? null
, config ? {}
, system ? builtins.currentSystem
}:

let
  bootstrap = import ./nix/bootstrap.nix {
    inherit nixpkgs config system;
    inherit repo officialRelease versionFile;
  };

  pkgs = bootstrap.pkgs;
in

with builtins;

let

  jobs = rec {
    entrypoint = pkgs.writers.writeBashBin "entrypoint" (readFile ./entrypoint.sh);

    vector-conf = pkgs.writeTextFile {
      name = "vector.toml";
      text = readFile ./vector.toml;
      destination = "/vector.toml";
    };

    logrotate-conf = pkgs.writeTextFile {
      name = "logrotate.conf";
      text = readFile ./logrotate.conf;
      destination = "/logrotate.conf";
    };

    ## needed for container/host resolution
    nsswitch-conf = pkgs.writeTextFile {
      name = "nsswitch.conf";
      text = "hosts: dns files";
      destination = "/etc/nsswitch.conf";
    };

    docker =
      pkgs.dockerTools.buildImage {
        name = "quick-fastly-logger";
        tag  = bootstrap.version;

        contents = with jobs;
          [ vector-conf logrotate-conf entrypoint
            pkgs.ttyd pkgs.vector pkgs.logrotate
            nsswitch-conf pkgs.coreutils pkgs.bash
          ];

        runAsRoot = ''
          #!${pkgs.stdenv.shell}
          ${pkgs.dockerTools.shadowSetup}
          groupadd --system logrotate
          useradd --system --gid logrotate logrotate
        '';

        config = {
          Entrypoint = [ "/bin/entrypoint" ];
          WorkingDir = "/";
          Volumes = { "/var/lib/vector" = {}; };
        };
      };
  };
in jobs
