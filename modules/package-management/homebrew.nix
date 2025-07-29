{
  config,
  lib,
  pkgs,
  options,
  ...
}:

with pkgs.lib.ordenada;

let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    types
    ;
  features = config.ordenada.features;
  cfg = features.homebrew;
  isDarwin = builtins.hasAttr "launchd" options;
in
{
  options = {
    ordenada.features.homebrew = {
      enable = mkOption {
        type = types.bool;
        description = "Whether to enable homebrew integration. For this to work, homebrew must be installed manually.";
        default = false;
      };
      repositories = mkOption {
        type = types.listOf types.str;
        description = "Additional repositories for homebrew to tap into.";
        default = [ ];
      };
      updateOnSwitch = mkOption {
        type = types.bool;
        description = "Whether to update outdated formulae and casks when switching to a new configuration.";
        default = false;
      };
    };
  };
  config = mkIf (cfg.enable && isDarwin) {
    environment.systemPath = [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ];
    homebrew = {
      enable = true;
      brews = [
        "mas"
      ];
      onActivation.cleanup = "uninstall";
      onActivation.upgrade = cfg.updateOnSwitch;
      taps = cfg.repositories;
    };
  };
}
