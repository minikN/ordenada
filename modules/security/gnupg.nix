{
  config,
  lib,
  pkgs,
  options,
  ...
}:

with pkgs.lib.ordenada;

let
  inherit (lib) mkEnableOption mkOption types;
  pinentryPkg = if (builtins.hasAttr "launchd" options) then pkgs.pinentry_mac else pkgs.pinentry-qt;
in
{
  options = {
    ordenada.features.gnupg = {
      enable = mkEnableOption "the GnuPG feature";
      sshKeys = mkOption {
        type = types.listOf types.str;
        description = "List of SSH key fingerprints.";
        default = [ ];
      };
      pinentryPackage = mkOption {
        type = types.nullOr types.package;
        description = "The package for pinentry input.";
        default = pinentryPkg;
      };
      defaultTtl = mkOption {
        type = types.int;
        description = "The cache TTL for GnuPG operations.";
        default = 86400;
      };
    };
  };
  config = {
    home-manager = mkHomeConfig config "gnupg" (user: {
      services.gpg-agent = with user.features.gnupg; {
        inherit sshKeys;
        enable = true;
        defaultCacheTtl = defaultTtl;
        defaultCacheTtlSsh = defaultTtl;
        maxCacheTtl = defaultTtl;
        maxCacheTtlSsh = defaultTtl;
        enableSshSupport = true;
        pinentry.package = pinentryPackage;
        noAllowExternalCache = true;
      };
      programs = {
        gpg = {
          enable = true;
          homedir = "${user.features.xdg.baseDirs.dataHome}/gnupg";
        };
      };
    });
  };
}
