{
  pkgs,
  lib,
  config,
  ...
}:
let
  instanceType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        default = "/persistent";
        description = "snapshoted path for kopia instance.";
      };
      schedule = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "Snapshot schedule for the Kopia instance.";
      };
    };
  };
in
{
  options.services.kopia.instances = lib.mkOption {
    type = lib.types.attrsOf instanceType;
  };

  config = lib.mkIf config.services.kopia.enable {
    # systemd service for repositories open
    systemd.services =
      let
        mkSnapshotService =
          # refactor with mkRepositoryArgs
          name: instance:
          lib.attrsets.nameValuePair "kopia-snapshot-${name}" {
            description = "Kopia S3 snapshot service";
            wants = [
              "kopia-repository-${name}.service"
            ];
            after = [ "kopia-repository-${name}.service" ];
            script = ''
              ${pkgs.kopia}/bin/kopia snapshot create ${instance.path} --description "Snapshot for ${name}"
            '';
            serviceConfig = {
              Type = "simple";
              User = "${instance.user}";
              WorkingDirectory = "~";
              SetLoginEnvironment = true;
              # retry on failure
              Restart = "on-failure";
              # wait 30 seconds before restarting
              RestartSec = "30";
              # limit the number of restarts to 5 in 1 day
              StartLimitIntervalSec = "1d";
              StartLimitBurst = "5";
              # lower priority
              Nice = "-19";
              IOSchedulingClass = "idle";
            };
          };
      in
      lib.recursiveUpdate { } (lib.attrsets.mapAttrs' mkSnapshotService config.services.kopia.instances);

    systemd.timers =
      let
        mkSnapshotTimer =
          name: instance:
          lib.attrsets.nameValuePair "kopia-snapshot-${name}" {
            description = "Kopia S3 snapshot timer";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = instance.schedule;
            };
          };
      in
      lib.recursiveUpdate { } (lib.attrsets.mapAttrs' mkSnapshotTimer config.services.kopia.instances);
  };
}
