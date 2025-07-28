{
  config,
  lib,
  pkgs,
  options,
  ...
}:

with pkgs.lib.ordenada;

let
  features = config.ordenada.features;
  cfg = features.alacritty;
  capitalize =
    str:
    if str == "" then
      ""
    else
      lib.strings.toUpper (lib.strings.substring 0 1 str)
      + lib.strings.substring 1 (lib.strings.stringLength str) str;

  ifDarwin = options: attrs: if builtins.hasAttr "launchd" options then attrs else { };
  ifLinux = options: attrs: if !builtins.hasAttr "launchd" options then attrs else { };
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
        settings = {
          window = lib.mkMerge [
            {
              padding = {
                x = 8;
                y = 8;
              };
            }
            (ifDarwin options {
              decorations = "Buttonless";
            })
          ];
          font = with features.fontutils.fonts; {
            normal = {
              family = monospace.name;
              style = capitalize monospace.style;
            };
            size = monospace.size;
          };
          colors = with user.features.theme.scheme.withHashtag; {
            primary = {
              background = base00;
              foreground = base05;
            };
            normal = {
              black = base05;
              white = base00;
              red = base08;
              green = base0B;
              yellow = base09;
              cyan = base0C;
              magenta = base0E;
              blue = base0D;
            };
          };
        };
      };
    });
  };
}
