{ pkgs ? import <nixpkgs> { } }:

let
  sources = builtins.readDir ./.;
  isPkg = pkg: sources.${pkg} == "directory" && pkg != "personal-scripts"; # Exclude personal-scripts for now
  pkgNames = builtins.filter isPkg (builtins.attrNames sources);
  toPkg = pkg: {
    name = pkg;
    value = pkgs.callPackage ./${pkg} { };
  };
in
  builtins.listToAttrs (map toPkg pkgNames)
