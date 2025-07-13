{
  pkgs,
  lib,
  config,
  ...
}:
let
  s3RepositoryType = lib.types.submodule {
    options = {
      bucket = lib.mkOption {
        type = lib.types.str;
        default = "default-bucket-value";
        description = "Bucket name for S3 repository.";
      };
      accessKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Access key for S3 repository.";
      };
      accessKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing access key for S3 repository, content in this file would override instance.<name>.accessKey.";
      };
      secretKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Secret key for S3 repository.";
      };
      secretKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing secret key for S3 repository, content in this file would override instance.<name>.secretKey.";
      };
      region = lib.mkOption {
        type = lib.types.str;
        default = "us-east-1";
        description = "Region for S3 repository.";
      };
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "https://s3.amazonaws.com";
        description = "Endpoint for S3 repository.";
      };
    };
  };

  azureRepositoryType = lib.types.submodule {
    options = {
      azure = lib.mkOption {
        type = lib.types.str;
        default = "default-azure-value";
        description = "Bar option for Azure repository.";
      };
    };
  };

  instanceType = lib.types.submodule {
    options = {
      repository = lib.mkOption {
        type = lib.types.attrTag {
          s3 = lib.mkOption {
            type = s3RepositoryType;
          };
          azure = lib.mkOption {
            type = azureRepositoryType;
          };
        };
      };
    };
  };
in
{
  options.services.kopia.instances = lib.mkOption {
    type = lib.types.attrsOf instanceType;
  };

  config = {
    # systemd service for repositories open
    systemd.services =
      let
        mkRepositoryArgs =
          name: instance:
          (
            if lib.hasAttr "s3" instance.repository then
              [
                "--bucket"
                instance.repository.s3.bucket
                "--endpoint"
                instance.repository.s3.endpoint
                "--region"
                instance.repository.s3.region
              ]
            else if lib.hasAttr "azure" instance.repository then
              [
                "--azure-account-name"
                instance.repository.azure.azure
              ]
            else
              throw "Unsupported repository type for Kopia instance ${name}"
          )
          ++ [
            "--password"
            instance.password
          ];

        mkRepository =
          let
            nullToEmpty = val: if val == null then "" else val;
          in
          # refactor with mkRepositoryArgs
          name: instance:
          if lib.hasAttr "s3" instance.repository then
            lib.attrsets.nameValuePair "kopia-repository-${name}" {
              description = "Kopia S3 repository service";
              wantedBy = [ "multi-user.target" ];
              script = ''
                load_secret() {
                  local var_name="$1"
                  local file_value="$2"
                  local direct_value="$3"

                  if [[ -n "$file_value" ]]; then
                    export "$var_name"="$(cat $file_value)"
                  else
                    export "$var_name"="$direct_value"
                  fi
                }

                # Load secrets
                load_secret "KOPIA_PASSWORD" "${nullToEmpty instance.passwordFile}" "${nullToEmpty instance.password}"
                load_secret "AWS_ACCESS_KEY_ID" "${nullToEmpty instance.repository.s3.accessKeyFile}" "${nullToEmpty instance.repository.s3.accessKey}"
                load_secret "AWS_SECRET_ACCESS_KEY" "${nullToEmpty instance.repository.s3.secretKeyFile}" "${nullToEmpty instance.repository.s3.secretKey}"

                # Check required environment variables
                for var in KOPIA_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
                  if [[ -z "''${!var}" ]]; then
                    echo "''$var is not set, exiting."
                    exit 1
                  fi
                done

                if ! ${pkgs.kopia}/bin/kopia repository connect s3 ${lib.concatStringsSep " " (mkRepositoryArgs name instance)}; then
                  ${pkgs.kopia}/bin/kopia repository create s3 ${lib.concatStringsSep " " (mkRepositoryArgs name instance)};
                fi
              '';
              serviceConfig = {
                Type = "simple";
                User = "${instance.user}";
                WorkingDirectory = "~";
                SetLoginEnvironment = true;
              };
            }
          else if lib.hasAttr "azure" instance.repository then
            lib.attrsets.nameValuePair "kopia-repository-${name}" {
              description = "Kopia Azure repository service";
              wantedBy = [ "multi-user.target" ];
              environment = {
                XDG_CACHE_HOME = "/var/cache";
              };
              serviceConfig = {
                Type = "simple";
                ExecStart = "${pkgs.kopia}/bin/kopia repository create azure ${lib.concatStringsSep " " (mkRepositoryArgs name instance)}";
                Restart = "on-failure";
              };
            }
          else
            throw "Unsupported repository type for Kopia instance ${name}";
      in
      lib.recursiveUpdate { } (lib.attrsets.mapAttrs' mkRepository config.services.kopia.instances);
  };
}
