{ pkgs, ... }:
{

  imports = [
    ./modules/kopia
  ];

  config = {
    virtualisation.cores = 4;
    virtualisation.memorySize = 20 * 1024;

    nix.nixPath = [
      "nixpkgs=${pkgs.path}"
    ];

    programs.fish.enable = true;
    users.users.root.shell = pkgs.bash;

    environment.systemPackages = with pkgs; [
      vim
    ];

    services.kopia = {
      enabled = true;
      instances = {
        s3 = {
          enabled = true;
          password = "test";
          path = "/tmp/test";
          repository = {
            s3.bucket = "test-kopia";
            s3.endpoint = "s3.amazonaws.com";
            s3.accessKey = "test";
            s3.secretKey = "test";
            # s3.accessKeyFile = "/etc/kopia/accessKey";
            # s3.secretKeyFile = "/etc/kopia/secretKey";
          };

          policy = {
            # retention = {
            #   keepLatest = 5;
            #   keepHourly = 48;
            #   keepDaily = 7;
            #   keepWeekly = 4;
            #   keepMonthly = 3;
            #   keepAnnual = 0;
            # };

            # compression = {
            #   compressorName = "pgzip";
            #   neverCompress = [
            #     "*.zip"
            #     "*.tar"
            #     "*.gz"
            #     "*.tgz"
            #     "*.xz"
            #     "*.bz2"
            #     "*.7z"
            #     "*.rar"
            #     "*.iso"
            #   ];
            # };
          };
        };
      };
    };
  };
}
