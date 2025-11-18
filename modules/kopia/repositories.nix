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
      disableTLS = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable TLS for S3 repository.";
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

  config = lib.mkIf config.services.kopia.enable {
    # warn user that specify password in repository is not recommended, use secretFiles instead
    warnings = lib.lists.flatten (
      lib.attrsets.mapAttrsToList (
        name: instance:
        (
          (lib.optional
            (
              instance.repository != null
              && (lib.hasAttr "s3" instance.repository || lib.hasAttr "azure" instance.repository)
              && (instance.password != null)
            )
            "Kopia repository '${name}' has a password set directly. It is recommended to use 'passwordFile' instead to prevent password is visible at /nix/store."
          )
          ++ (lib.optional
            (
              lib.hasAttr "s3" instance.repository
              && lib.hasAttr "accessKey" instance.repository.s3
              && instance.repository.s3.accessKey != null
            )
            "Kopia repository '${name}' has an access key set directly. It is recommended to use 'accessKeyFile' instead to prevent access key is visible at /nix/store."
          )
          ++ (lib.optional
            (
              lib.hasAttr "s3" instance.repository
              && lib.hasAttr "secretKey" instance.repository.s3
              && instance.repository.s3.secretKey != null
            )
            "Kopia repository '${name}' has a secret key set directly. It is recommended to use 'secretKeyFile' instead to prevent secret key is visible at /nix/store."
          )
        )
        # s3 related
      ) config.services.kopia.instances
    );

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
              ++ (lib.optional (instance.repository.s3.disableTLS) "--disable-tls")
            else if lib.hasAttr "azure" instance.repository then
              [
                "--azure-account-name"
                instance.repository.azure.azure
              ]
            else
              throw "Unsupported repository type for Kopia instance ${name}"
          );

        mkRepository =
          let
            nullToEmpty = val: if val == null then "" else val;
            mkS3Repository =
              name: instance:
              lib.attrsets.nameValuePair "kopia-repository-${name}" {
                description = "Kopia S3 repository service";
                serviceConfig =
                  let
                    startScript = pkgs.writeShellScript "start-repository.sh" ''
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

                    stopScript = pkgs.writeShellScript "stop-repository.sh" ''
                      ${pkgs.kopia}/bin/kopia repository disconnect
                    '';
                  in
                  {
                    Type = "oneshot";
                    User = "${instance.user}";
                    WorkingDirectory = "~";
                    SetLoginEnvironment = true;
                    RemainAfterExit = true;
                    ExecStart = "${startScript}";
                    ExecStop = "${stopScript}";
                  };
              };

            # FIXME: azure's repository setup is not finished, this is a placeholder
            mkAzureRepository =
              name: instance:
              lib.attrsets.nameValuePair "kopia-repository-${name}" {
                description = "Kopia Azure repository service";
                script = ''
                  load_secret() {
                    local var_name="$1"
                    local file_value="$2"
                    local direct_value="$3"

                    if [[ -n "$file_value" ]]; then
                      # check this script has permission to load credential
                      if [[ ! -r "$file_value" ]]; then
                        echo "Cannot read file $file_value for variable $var_name, exiting."
                        echo "Please make sure the file($file_value) has proper permission to be read by the user($(whoami)) running this service."
                        exit 1
                      fi
                      export "$var_name"="$(cat $file_value)"
                    else
                      export "$var_name"="$direct_value"
                    fi
                  }

                  # Load secrets
                  load_secret "KOPIA_PASSWORD" "${nullToEmpty instance.passwordFile}" "${nullToEmpty instance.password}"

                  # Check required environment variables
                  if [[ -z "$KOPIA_PASSWORD" ]]; then
                    echo "KOPIA_PASSWORD is not set, exiting."
                    exit 1
                  fi

                  if ! ${pkgs.kopia}/bin/kopia repository connect azure ${lib.concatStringsSep " " (mkRepositoryArgs name instance)}; then
                    ${pkgs.kopia}/bin/kopia repository create azure ${lib.concatStringsSep " " (mkRepositoryArgs name instance)};
                  fi
                '';
                serviceConfig = {
                  Type = "simple";
                  User = "${instance.user}";
                  WorkingDirectory = "~";
                  SetLoginEnvironment = true;
                };
              };
          in
          name: instance:
          if lib.hasAttr "s3" instance.repository then
            (mkS3Repository name instance)
          else if lib.hasAttr "azure" instance.repository then
            mkAzureRepository name instance
          else
            throw "Unsupported repository type for Kopia instance ${name}";
      in
      (lib.attrsets.mapAttrs' mkRepository config.services.kopia.instances);
  };
}
