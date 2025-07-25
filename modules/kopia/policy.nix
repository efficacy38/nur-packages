{
  pkgs,
  lib,
  config,
  ...
}:
let

  # kopia policy json definition
  compressionType = lib.types.enum [
    "none"
    "deflate-best-compression"
    "deflate-best-speed"
    "deflate-default"
    "gzip"
    "gzip-best-compression"
    "gzip-best-speed"
    "pgzip"
    "pgzip-best-compression"
    "pgzip-best-speed"
    "s2-better"
    "s2-default"
    "s2-parallel-4"
    "s2-parallel-8"
    "zstd"
    "zstd-better-compression"
    "zstd-fastest"
  ];

  policyType = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          retention = {
            keepLatest = lib.mkOption {
              type = lib.types.int;
              default = 5;
              description = "Number of latest snapshots to keep.";
            };
            keepHourly = lib.mkOption {
              type = lib.types.int;
              default = 48;
              description = "Number of hourly snapshots to keep.";
            };
            keepDaily = lib.mkOption {
              type = lib.types.int;
              default = 7;
              description = "Number of daily snapshots to keep.";
            };
            keepWeekly = lib.mkOption {
              type = lib.types.int;
              default = 4;
              description = "Number of weekly snapshots to keep.";
            };
            keepMonthly = lib.mkOption {
              type = lib.types.int;
              default = 3;
              description = "Number of monthly snapshots to keep.";
            };
            keepAnnual = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Number of yearly snapshots to keep.";
            };
          };

          files = {
            ignoreDotFiles = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                ".gitignore"
                ".kopiaignore"
              ];
              description = "List of files to source ignore lists from.";
            };
            noParentDotFiles = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = false;
              description = "Do not use parent ignore dot files.";
            };
            ignoreCacheDirs = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = false;
              description = "Ignore cache directories.";
            };
            maxFileSize = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Maximum file size to include in backup.";
            };
            oneFileSystem = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Stay in parent filesystem when finding files.";
            };
          };

          errorHandling = {
            ignoreFileErrors = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Ignore errors reading ignore files.";
            };
            ignoreDirectoryErrors = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Ignore errors reading directories.";
            };
            ignoreUnknownTypes = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Ignore unknown file types.";
            };
          };

          compression = {
            compressorName = lib.mkOption {
              type = compressionType;
              default = "none";
              description = "Name of the compressor to use.";
            };

            onlyCompress = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "List of file extensions to compress.";
            };

            noParentOnlyCompress = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Do not use parent only compress list.";
            };

            neverCompress = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "List of file extensions to never compress.";
            };

            noParentNeverCompress = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Do not use parent never compress list.";
            };

            minSize = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Minimum file size to compress.";
            };

            maxSize = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Maximum file size to compress.";
            };
          };

          metadataCompression = {
            compressorName = lib.mkOption {
              type = compressionType;
              default = "zstd-fastest";
              description = "Name of the compressor to use.";
            };
          };

          splitter = {
            algorithm = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Name of the splitter algorithm to use.";
            };
          };

          # FIXME: add action definition afterward (maybe implement it during implement at zfs, btrfs snapshot)

          osSnapshots = {
            volumeShadowCopy = {
              enable = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.enum [
                    "never"
                    "always"
                    "when-available"
                    "inherit"
                  ]
                );
                default = null;
                description = "Enable volume shadow copy";
              };
            };
          };

          logging = {
            directories = {
              snapshotted = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Log detail when a directory is snapshotted";
              };
              ignored = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Log detail when a directory is ignored";
              };
            };

            entries = {
              snapshotted = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Log detail when an entry is snapshotted";
              };
              ignored = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Log detail when an entry is ignored";
              };
            };
          };

          upload = {
            # maxParallelSnapshots - GUI only
            maxParallelFileReads = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Maximum number of parallel file reads(GUI Only)";
            };
            parallelUploadAboveSize = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Use parallel uploads above size(GUI Only)";
            };
          };
        };
      }
    );
    default = null;
  };

  instanceType = lib.types.submodule {
    options = {
      policy = policyType;
    };
  };

  # application logic
  jsonFormat = (pkgs.formats.json { });

  # generate policy name for policy file generation
  mkPolicyName =
    user: hostname: path:
    "${user}@${hostname}${if path != "" then ":${path}" else ""}";

  mkPolicyFile = policy: (jsonFormat.generate "kopia-policy.json" policy);

  mkInstancePolicyService =
    name: instance:
    let
      policyName = mkPolicyName instance.user config.networking.hostName instance.path;
      policyFile = mkPolicyFile (
        {
          "${policyName}" = instance.policy;
        }
        // lib.optionalAttrs (config.services.kopia.globalPolicy != null) {
          "(global)" = config.services.kopia.globalPolicy;
        }
      );
    in
    (lib.attrsets.nameValuePair "kopia-policy-${name}" {
      description = "Kopia policy setup";
      wants = [ "kopia-repository-${name}.service" ];
      wantedBy = [ "kopia-snapshot-${name}.service" ];
      after = [ "kopia-repository-${name}.service" ];
      before = [ "kopia-snapshot-${name}.service" ];
      script = ''
        ${pkgs.kopia}/bin/kopia policy import --from-file=${policyFile}
      '';
      serviceConfig = {
        Type = "oneshot";
        User = instance.user;
        WorkingDirectory = "~";
        SetLoginEnvironment = true;
      };
    });
in
{
  options.services.kopia = {
    globalPolicy = policyType;

    instances = lib.mkOption {
      type = lib.types.attrsOf instanceType;
    };
  };

  config = lib.mkIf config.services.kopia.enable {
    systemd.services = lib.recursiveUpdate { } (
      lib.attrsets.mapAttrs' mkInstancePolicyService config.services.kopia.instances
    );
  };
}
