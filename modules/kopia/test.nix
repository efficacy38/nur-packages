{
  self,
  pkgs,
  ...
}:
pkgs.testers.nixosTest {
  name = "kopia-test";
  nodes.machine =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.kopia
      ];
      services.kopia = {
        enable = true;
        instances = {
          test = {
            enable = true;
            user = "root";
            passwordFile = pkgs.writeText "kopia-password" "test-password";
            repository = {
              s3 = {
                bucket = "kopia";
                endpoint = "minio:9000";
                accessKeyFile = pkgs.writeText "minio-access-key" "minio";
                secretKeyFile = pkgs.writeText "minio-secret-key" "minio-secret";
                region = "us-east-1";
                disableTLS = true;
              };
            };
            path = "/tmp/test-data";
            schedule = "daily";
          };
        };
      };
      environment.systemPackages = with pkgs; [
        kopia
        jq
      ];
    };

  nodes.minio =
    { pkgs, ... }:
    {
      services.minio = {
        enable = true;
        accessKey = "minio";
        secretKey = "minio-secret";
        region = "us-east-1";
      };

      networking.firewall = {
        allowedTCPPorts = [ 9000 ];
      };

      environment.systemPackages = with pkgs; [
        minio-client
      ];

    };

  testScript = ''
    start_all()

    minio.wait_for_unit("minio.service")
    minio.wait_for_open_port(9000)
    minio.succeed("mc alias set minio http://localhost:9000 minio minio-secret")
    minio.succeed("mc mb minio/kopia")

    # check repository initialization
    machine.succeed("systemctl start kopia-repository-test.service")

    machine.execute("mkdir -p /tmp/test-data")
    machine.execute("echo This is a test file. > /tmp/test-data/file1.txt")
    machine.succeed("systemctl start kopia-snapshot-test.service")

    # use kopia commands to check snapshot is created
    machine.succeed("systemctl start kopia-repository-test.service")
    machine.succeed("kopia snapshot list /tmp/test-data --json | jq '. | length == 1'")
  '';
}
