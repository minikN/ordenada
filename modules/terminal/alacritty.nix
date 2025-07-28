{
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

let
  cfg = config.ordenada.features.alacritty;
in
{
  options = {
    ordenada.features.alacritty = {
      enable = lib.mkEnableOption "the Alacritty feature";
      package = lib.mkPackageOption pkgs "alacritty" { default = "alacritty"; };
    };
  };
  config = lib.mkIf cfg.enable {
    ## TODO: Use a `setGlobal` function here to check for `ordenada.globals.shell === null`
    ##       and print a warning if so
    ordenada.globals.terminal = "${cfg.package}/bin/alacritty";

    home-manager = mkHomeConfig config "alacritty" (user: {
      programs.alacritty = {
        enable = true;
      };
    });
  };
}
