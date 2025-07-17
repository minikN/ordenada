{ config, lib, pkgs, ... }:

let inherit (lib) types mkOption mkEnableOption;
in
{
  imports = [
    ./age.nix
    ./gnupg.nix
    ./passage.nix
    ./password-store.nix
    ./ssh.nix
  ];

  options = {
    ordenada.globals.passwordManager = mkOption {
      type = types.nullOr types.str;
      description = "The system wide used password manager";
      default = null;
    };
  };
}
