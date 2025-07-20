{ config, lib, pkgs, ... }:

with pkgs.lib.ordenada;
let
  inherit (lib) mkIf mkOption mkEnableOption types;
  cfg = config.ordenada.features.networking;
in {
  options = {
    ordenada.features.networking = {
      enable = mkEnableOption "the networking feature";
      nameservers = mkOption {
        description = "List of nameservers to use.";
        type = types.listOf types.str;
        default = [ ];
      };
    };
  };
  config = mkIf cfg.enable {
    networking.useDHCP = false;
    networking.networkmanager.enable = true;
    networking.nameservers = cfg.nameservers;

    programs.nm-applet = {
      enable = true;
      indicator = true;
    };
    home-manager = mkHomeConfig config "networking" (user: {
      ## Needed for nm-applet icon to show in tray.
      home.packages = with pkgs; [ networkmanagerapplet ];
    });

    users = mkHomeConfig config "networking" (user: {
      extraGroups = [ "networkmanager" ];
    });
  };
}
