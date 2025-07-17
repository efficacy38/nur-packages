# nur-packages

**My personal [NUR](https://github.com/nix-community/NUR) repository**

<!-- Remove this if you don't use github actions -->
![Build and populate cache](https://github.com/efficacy38/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)

[![Cachix Cache](https://img.shields.io/badge/cachix-efficacy38-blue.svg)](https://efficacy38.cachix.org)

## Modules

### Kopia

#### How to use this kopia module

```
config = {
   services.kopia = {
   enabled = true;
   instances = {
      s3 = {
         enabled = true;
         # password = "test";
         passwordFile = "/test/";
         path = "/tmp/";
         repository = {
         s3.bucket = "test-kopia";
         s3.endpoint = "s3.amazonaws.com";
         # s3.accessKey = "**************";
         # s3.secretKey = "**************";
         s3.accessKeyFile = "/etc/kopia/accessKey";
         s3.secretKeyFile = "/etc/kopia/secretKey";
         };
      };
   };
   };
}
```

#### RoadMap
- [x] policy
- [ ] global policy
- [ ] let kopia snapshot on btrfs or zfs's snapshot
- [ ] webui setup
- [ ] add other instance type 
   - [ ] `kopia`, allow this kopia instance push snapshot to remote kopia server
   - [ ] `b2`
   - [ ] `azure`
   - [ ] ...
