{ config, lib, pkgs, ... }:

with pkgs.lib.ordenada;

let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.ordenada.features.sway;
in {
  options = {
    ordenada.features.sway = {
      enable = mkEnableOption "the Sway feature";
      package = mkOption {
        type = types.package;
        description = "The Sway package to use.";
        default = pkgs.sway;
      };
      modifier = mkOption {
        type = types.str;
        description = "The modifier to bind Sway keys to.";
        default = "Mod4";
      };
      left = mkOption {
        type = types.str;
        description = "The key to use for for the left orientation.";
        default = "Left";
      };
      right = mkOption {
        type = types.str;
        description = "The key to use for for the right orientation.";
        default = "Right";
      };
      up = mkOption {
        type = types.str;
        description = "The key to use for for the up orientation.";
        default = "Up";
      };
      down = mkOption {
        type = types.str;
        description = "The key to use for for the down orientation.";
        default = "Down";
      };
      keybindings = mkOption {
        type = types.attrs;
        description = "The Sway keybindings.";
        default = { };
      };
      extraConfig = mkOption {
        type = types.attrs;
        default = { };
        description = "Extra configuration for Sway.";
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable (lib.mkMerge [{
      ## TODO: Use a `setGlobal` function here to check for `ordenada.globals.wm === null`
      ##       and print a warning if so
      ordenada.globals.wm = "${cfg.package}/bin/sway";
      ordenada.globals.wayland = true;

      hardware.graphics.enable = true;
      security.polkit.enable = true;
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    }]))
    {
      home-manager = mkHomeConfig config "sway" (user: {
        programs.swayr = {
          enable = true;
          systemd.enable = true;
        };
        wayland.windowManager.sway = {
          enable = true;
          systemd.enable = true;
          xwayland = true;
          wrapperFeatures = {
            base = true;
            gtk = true;
          };
          extraSessionCommands = ''
            export QT_QPA_PLATFORM=wayland
            export XDG_SESSION_TYPE=wayland
            export XDG_CURRENT_DESKTOP=sway
            export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
            export SDL_VIDEODRIVER=wayland
            export _JAVA_AWT_WM_NONREPARENTING=1
          '';
          extraConfigEarly = ''
            ${if config.ordenada.globals.launcher != null then
              "set $launcher ${config.ordenada.globals.launcher}"
            else
              ""}
            ${if config.ordenada.globals.passwordManager != null then
              "set $passwordManager ${config.ordenada.globals.passwordManager}"
            else
              ""}
          '';
          config = with user.features.theme.scheme.withHashtag;
            lib.recursiveUpdate {
              defaultWorkspace = "workspace number 1";
              modifier = user.features.sway.modifier;
              input = with user.features.keyboard.layout; {
                "type:keyboard" = {
                  xkb_layout = name;
                  xkb_options = lib.strings.concatStringsSep "," options;
                } // (lib.optionalAttrs (variant != "") {
                  xkb_variant = variant;
                });
                "type:touchpad" = {
                  dwt = "enabled";
                  tap = "enabled";
                  middle_emulation = "enabled";
                };
              };
              output = {
                "*" = { bg = "${user.features.theme.wallpaper} fill"; };
              };
              seat."*" = with user.features.gtk.cursorTheme; {
                xcursor_theme =
                  "${name} ${toString user.features.gtk.cursorSize}";
              };
              floating = {
                titlebar = false;
                border = 2;
              };
              colors = with pkgs.lib.nix-rice.color;
                let
                  background = base00;
                  focused = toRgbHex
                    ((if user.features.theme.polarity == "dark" then
                      darken
                    else
                      brighten) 50 (hexToRgba base0D));
                  indicator = focused;
                  unfocused = base01;
                  text = base05;
                  urgent = base08;
                in {
                  inherit background;
                  urgent = {
                    inherit background indicator text;
                    border = urgent;
                    childBorder = urgent;
                  };
                  focused = {
                    inherit background indicator text;
                    border = focused;
                    childBorder = focused;
                  };
                  focusedInactive = {
                    inherit background indicator text;
                    border = unfocused;
                    childBorder = unfocused;
                  };
                  unfocused = {
                    inherit background indicator text;
                    border = unfocused;
                    childBorder = unfocused;
                  };
                  placeholder = {
                    inherit background indicator text;
                    border = unfocused;
                    childBorder = unfocused;
                  };
                };
              window = {
                titlebar = false;
                border = 2;
              };
              gaps.inner = 12;
              bars = [ ];
              keybindings = lib.mkMerge [
                (let
                  modifier = cfg.modifier;
                  left = cfg.left;
                  right = cfg.right;
                  up = cfg.up;
                  down = cfg.down;
                in {
                  # "${modifier}+Return" = "exec /bin/foot";
                  "${modifier}+Shift+q" = "kill";
                  "${modifier}+d" = "exec $launcher";
                  "${modifier}+p" = "exec $passwordManager";

                  "${modifier}+${left}" = "focus left";
                  "${modifier}+${down}" = "focus down";
                  "${modifier}+${up}" = "focus up";
                  "${modifier}+${right}" = "focus right";

                  "${modifier}+Shift+${left}" = "move left";
                  "${modifier}+Shift+${down}" = "move down";
                  "${modifier}+Shift+${up}" = "move up";
                  "${modifier}+Shift+${right}" = "move right";

                  "${modifier}+b" = "splith";
                  "${modifier}+v" = "splitv";
                  "${modifier}+f" = "fullscreen toggle";
                  "${modifier}+a" = "focus parent";

                  "${modifier}+s" = "layout stacking";
                  "${modifier}+w" = "layout tabbed";
                  "${modifier}+e" = "layout toggle split";

                  "${modifier}+Shift+space" = "floating toggle";
                  "${modifier}+space" = "focus mode_toggle";

                  "${modifier}+1" = "workspace number 1";
                  "${modifier}+2" = "workspace number 2";
                  "${modifier}+3" = "workspace number 3";
                  "${modifier}+4" = "workspace number 4";
                  "${modifier}+5" = "workspace number 5";
                  "${modifier}+6" = "workspace number 6";
                  "${modifier}+7" = "workspace number 7";
                  "${modifier}+8" = "workspace number 8";
                  "${modifier}+9" = "workspace number 9";
                  "${modifier}+0" = "workspace number 10";

                  "${modifier}+Shift+1" =
                    "move container to workspace number 1";
                  "${modifier}+Shift+2" =
                    "move container to workspace number 2";
                  "${modifier}+Shift+3" =
                    "move container to workspace number 3";
                  "${modifier}+Shift+4" =
                    "move container to workspace number 4";
                  "${modifier}+Shift+5" =
                    "move container to workspace number 5";
                  "${modifier}+Shift+6" =
                    "move container to workspace number 6";
                  "${modifier}+Shift+7" =
                    "move container to workspace number 7";
                  "${modifier}+Shift+8" =
                    "move container to workspace number 8";
                  "${modifier}+Shift+9" =
                    "move container to workspace number 9";
                  "${modifier}+Shift+0" =
                    "move container to workspace number 10";

                  "${modifier}+Shift+minus" = "move scratchpad";
                  "${modifier}+minus" = "scratchpad show";

                  "${modifier}+Shift+c" = "reload";
                  "${modifier}+Shift+e" =
                    "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'";

                  "${modifier}+r" = "mode resize";

                })
                user.features.sway.keybindings
              ];
            } cfg.extraConfig;
        };
      });
    }
  ];
}
