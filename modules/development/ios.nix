{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

let
  inherit (lib)
    types
    mkIf
    mkMerge
    mkAfter
    mkOption
    mkEnableOption
    ;
  features = config.ordenada.features;
  cfg = features.ios;

  simulatorScript = pkgs.writeShellScript "manage-simulators" ''
    echo "Setting up simulators..."
    export DEVELOPER_DIR="$(${pkgs.xcodes}/bin/xcodes select -p)"

    runtimes_installed="$(${pkgs.xcodes}/bin/xcodes runtimes \
      | ${pkgs.gnugrep}/bin/grep "Installed" \
      | ${pkgs.gawk}/bin/awk -F'[()]' '{print $1}')"

    ## Removing obsolete simulators
    ${pkgs.xcbuild}/bin/xcrun simctl list devices \
      | ${pkgs.gnugrep}/bin/grep nixos \
      | ${pkgs.gawk}/bin/awk -F' ' '{print $1 " " $2}' \
      | while read -r name version; do
        simName="$name $version"
        case "$simName" in
          ${lib.concatStringsSep "\n" (
            map (
              sim:
              let
                expectedSimName = "${lib.replaceStrings [ "-" ] [ "" ] sim.device}-${
                  lib.replaceStrings [ ".0" " " ] [ "" "" ] sim.os
                } (nixos)";
              in
              ''"${expectedSimName}") ;;''
            ) cfg.simulators
          )}
          *)
            ${pkgs.xcbuild}/bin/xcrun simctl delete "$simName"
          ;;
        esac
      done

    ## Installing new simulators and runtimes
    ${lib.concatStringsSep "\n" (
      map (
        sim:
        let
          runtime = sim.os;
          runtimeId =
            "com.apple.CoreSimulator.SimRuntime." + (builtins.replaceStrings [ "." " " ] [ "-" "-" ] runtime);
          deviceType = "com.apple.CoreSimulator.SimDeviceType." + sim.device;
          simName = "${lib.replaceStrings [ "-" ] [ "" ] sim.device}-${
            lib.replaceStrings [ ".0" " " ] [ "" "" ] sim.os
          } (nixos)";
        in
        ''
          runtime_installed="$(echo $runtimes_installed | ${pkgs.gnugrep}/bin/grep "${runtime}")"
          simulator_installed="$(${pkgs.xcbuild}/bin/xcrun simctl list devices \
            | ${pkgs.gnugrep}/bin/grep "${simName}")"

          if [ -z "$runtime_installed" ]; then
            ${pkgs.xcodes}/bin/xcodes runtimes install "${runtime}"
          fi

          if [ -z "$simulator_installed" ]; then
            ${pkgs.xcbuild}/bin/xcrun simctl create "${simName}" "${deviceType}" "${runtimeId}"
          fi
        ''
      ) cfg.simulators
    )}
  '';

  xcodeScript = pkgs.writeShellScript "manage-xcodes" ''
    set -euo pipefail

    export HOME=${features.userInfo.homeDirectory};
    export USER=${features.userInfo.username};
    export PATH="$PATH:${
      lib.makeBinPath [
        pkgs.gnugrep
        pkgs.xcodes
        pkgs.coreutils
      ]
    }"

    echo "Setting up Xcode versions..."
    installed_versions="$(xcodes list | grep 'Installed' | cut -d' ' -f1)"

    # Install missing versions
    ${lib.concatStringsSep "\n" (
      map (v: ''
        if ! echo "$installed_versions" | grep -q "^${v}$"; then
          /usr/bin/sudo -u $USER xcodes install "${v}" --experimental-unxip --empty-trash --no-superuser
        fi
      '') xcodeVersions
    )}

    # Refresh installed versions after potential installs
    installed_versions="$(xcodes list | grep 'Installed' | cut -d' ' -f1)"

    # Uninstall versions not in desired list
    for ver in $installed_versions; do
      case " ${lib.concatStringsSep " " xcodeVersions} " in
        *" $ver "*) ;;
        *)
          /usr/bin/sudo sudo -u $USER xcodes uninstall "$ver --empty-trash"
          ;;
      esac
    done

    ${
      if (xcodeActiveVersion != null) then
        let
          activeXcodePath = "/Applications/Xcode-${xcodeActiveVersion}.0.app/Contents/Developer";
        in
        ''
          # Select active version

          if [[ $(xcode-select -p) != "${activeXcodePath}" ]]; then
            xcodes select "${xcodeActiveVersion}"
            xcode-select -s "${activeXcodePath}"
            sudo xcodebuild -license accept
          fi

          # Ensure active version is installed
          if ! echo "$installed_versions" | grep -q "^${xcodeActiveVersion}$"; then
            echo "Error: Xcode active version '${xcodeActiveVersion}' is not installed."
            exit 1
          fi
        ''
      else
        ""
    }
  '';

  sanitize = str: builtins.replaceStrings [ " " "." "-" ] [ "-" "-" "" ] str;

  mkSimulatorBin =
    sim:
    let
      name = "simulator-${sanitize sim.device}-${sanitize sim.os}";
      script = pkgs.writeShellScriptBin name ''
        # Find runtime identifier
        runtime=$(
          /usr/bin/xcrun simctl list runtimes \
            | ${pkgs.gnugrep}/bin/grep -F '${sim.os}' \
            | ${pkgs.coreutils}/bin/head -n1 \
            | ${pkgs.gawk}/bin/awk -F '[()]' '{print $1}'
        )

        sanitizedRuntime=$(echo "$runtime" | ${pkgs.coreutils}/bin/tr -d ' .0')
        sanitizedDevice=$(echo "${sim.device}" | ${pkgs.coreutils}/bin/tr -d '-')

        if [ -z "$runtime" ]; then
          echo "Runtime for ${sim.os} not found or not available." >&2
          exit 1
        fi

        # Find matching simulator UDID
        uuid=$(
          /usr/bin/xcrun simctl list devices \
            | ${pkgs.gnugrep}/bin/grep -A1 "$sanitizedRuntime" \
            | ${pkgs.gnugrep}/bin/grep "$sanitizedDevice" \
            | ${pkgs.gnugrep}/bin/grep -v unavailable \
            | ${pkgs.gawk}/bin/awk -F '[()]' '{print $4}'
        )

        if [ -z "$uuid" ]; then
          echo "Simulator ${sim.device} with runtime $runtime not found." >&2
          exit 1
        fi

        # Boot the simulator if not already booted
        state=$(
          /usr/bin/xcrun simctl list devices \
            | ${pkgs.gnugrep}/bin/grep "$uuid" \
            | ${pkgs.gawk}/bin/awk '{print $NF}' \
            | ${pkgs.coreutils}/bin/tr -d '()'
        )

        if [ "$state" != "Booted" ]; then
          echo "Booting simulator $uuid ($runtime)..."
          /usr/bin/xcrun simctl boot "$uuid"
        fi

        # Open Simulator GUI
        open -a Simulator
      '';
    in
    script;

in
{
  options = {
    ordenada.features.ios = {
      enable = mkEnableOption "the iOS feature";
      xcodeVersions = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "The XCode versions to install.";
      };
      xcodeActiveVersion = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The XCode version to use.";
      };
      simulators = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              device = lib.mkOption {
                type = lib.types.str;
                description = "Device type (e.g. iPhone-14)";
              };
              os = lib.mkOption {
                type = lib.types.str;
                description = "iOS runtime version (e.g. iOS 17.0)";
              };
              bootOnLogin = lib.mkOption {
                type = types.nullOr types.bool;
                description = "Whether the simulator should be booted on login.";
                default = null;
              };
            };
          }
        );
        default = [ ];
        description = "List of simulators to create.";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      # system.activationScripts.preActivation.text = builtins.trace "post" ''
      #   ${if (cfg.xCodeVersions != [ ]) then xCodeScript else ""}
      #   ${simulatorScript}
      # '';
      home-manager = mkHomeConfig config "ios" (user: {
        home.packages =
          with pkgs;
          [
            xcodes
          ]
          ++ (lib.map mkSimulatorBin cfg.simulators);

        home.activation.setupSimulators = mkAfter ''
          ## TODO: Update xcodeScript to work here, fix its cleanup
          run ${simulatorScript}
        '';

        home.activation.trampolineSimulators = mkAfter ''
          ${builtins.concatStringsSep "\n" (
            lib.map (
              sim:
              let
                name = "simulator-${sanitize sim.device}-${sanitize sim.os}";
              in
              "nix run github:hraban/mac-app-util -- mktrampoline \"${mkSimulatorBin sim}/bin/${name}\" ~/Applications/${name}.app"
            ) cfg.simulators
          )}
        '';
      });
      launchd.agents = builtins.listToAttrs (
        builtins.map (
          sim:
          let
            simName = "${lib.replaceStrings [ "-" ] [ "" ] sim.device}-${
              lib.replaceStrings [ ".0" " " ] [ "" "" ] sim.os
            }";
          in
          {
            name = "simulator.${simName}";
            value = {
              script = ''
                export DEVELOPER_DIR="$(${pkgs.xcbuild}/bin/xcode-select -p)"
                ${pkgs.xcbuild}/bin/xcrun simctl boot "${simName}"
              '';
              serviceConfig = {
                RunAtLoad = true;
                StandardOutPath = "/tmp/${simName}.out.log";
                StandardErrorPath = "/tmp/${simName}.err.log";
              };
            };
          }
        ) (builtins.filter (sim: sim.bootOnLogin or false) cfg.simulators)
      );
    })
    {
    }
  ];
}
