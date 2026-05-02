{ lib, mkFeature, ... }:

let
  inherit (lib) mkPackageOption mkForce mkIf;
in
mkFeature {
  name = "ghostty";
  options =
    { pkgs, ... }:
    {
      package = mkPackageOption pkgs "ghostty-bin" { };
    };
  globals =
    { config, ... }:
    {
      apps.terminal =
        with config.ordenada.features.ghostty;
        let
          path =
            if (config.ordenada.globals.platform == "darwin") then
              "${package}/Applications/Ghostty.app/Contents/MacOS/ghostty"
            else
              "${package}/bin/ghostty";
        in
        mkIf (enable) (mkForce path);
    };
  homeManager =
    { config, ... }:
    {
      programs.ghostty = with config.ordenada.features.ghostty; {
        enable = true;
        package = package;
        settings = with config.ordenada.features.fontutils.fonts; {
          theme = "ordenada";
          font-family = "${monospace.name}";
          font-style = "Regular";

          font-family-bold = "${monospace.name}";
          font-style-bold = "Bold";

          font-family-italic = "${monospace.name}";
          font-style-italic = "Italic";

          font-family-bold-italic = "${monospace.name}";
          font-style-bold-italic = "Bold Italic";

          font-size = monospace.size;
        };
        themes = {
          ordenada = with config.ordenada.features.theme.scheme.withHashtag; {
            background = "${base00}";
            cursor-color = "${base05}";
            foreground = "${base05}";
            palette = [
              "0=${base05}"
              "1=${base08}"
              "2=${base0B}"
              "3=${base0A}"
              "4=${base0D}"
              "5=${base0E}"
              "6=${base0C}"
              "7=${base05}"
              "8=${base03}"
              "9=${base08}"
              "10=${base0B}"
              "11=${base0A}"
              "12=${base0D}"
              "13=${base0E}"
              "14=${base0C}"
              "15=${base06}"
            ];
            selection-background = "${base02}";
            selection-foreground = "${base05}";
          };
        };
      };
    };
}
