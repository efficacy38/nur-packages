{
  lib,
  ...
}:
let
  instanceType = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "Enable Kopia instance";
      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Password for the Kopia instance.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File containing the password for the Kopia instance, content in this file would override instance.<name>.password.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "User under which the Kopia instance runs.";
      };

      test = lib.mkOption {
        default = null;
      };
    };
  };
in
{
  imports = [
    ./repositories.nix
    ./snapshot.nix
    ./policy.nix
    ./web.nix
  ];

  options.services.kopia = {
    enable = lib.mkEnableOption "Enable Kopia backup";
    instances = lib.mkOption {
      type = lib.types.attrsOf instanceType;
      default = { };
    };
  };
}
