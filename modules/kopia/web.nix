{
  pkgs,
  lib,
  config,
  ...
}:
let
  instanceType = lib.types.submodule {
    options = {
      web = {
        enable = lib.mkEnableOption "enable Kopia web interface";
        guiAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:51515";
        };
        serverUsername = lib.mkOption {
          type = lib.types.str;
          default = "admin";
          description = "Username for the Kopia web server(basic auth).";
        };
        serverPassword = lib.mkOption {
          type = lib.types.str;
          default = "admin";
          description = "Password for the Kopia web server(basic auth).";
        };
        serverPasswordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "File containing the password for the Kopia web server, content in this file would override instance.<name>.web.serverPassword.";
        };
      };
    };
  };
in
{
  options.services.kopia.instances = lib.mkOption {
    type = lib.types.attrsOf instanceType;
  };

  config = lib.mkIf config.services.kopia.enabled {
    # systemd service for repositories open
    systemd.services =
      let
        mkWebService =
          # refactor with mkRepositoryArgs
          name: instance:
          lib.attrsets.nameValuePair "kopia-web-${name}" {
            description = "Kopia S3 web service";
            wants = [
              "kopia-repository-${name}.service"
            ];
            after = [ "kopia-repository-${name}.service" ];
            script =
              let
                nullToEmpty = val: if val == null then "" else val;
              in
              ''
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
                export KOPIA_SERVER_USERNAME=${instance.web.serverUsername}
                load_secret "KOPIA_SERVER_PASSWORD" "${nullToEmpty instance.web.serverPasswordFile}" "${nullToEmpty instance.web.serverPassword}"

                # Start Kopia web server
                ${pkgs.kopia}/bin/kopia server start --insecure --address ${instance.web.guiAddress}
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
            };
          };
      in
      lib.recursiveUpdate { } (lib.attrsets.mapAttrs' mkWebService config.services.kopia.instances);
  };
}
