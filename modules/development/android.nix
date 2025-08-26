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
    types
    mkIf
    mkMerge
    mkAfter
    ;

  features = config.ordenada.features;
  cfg = features.android;
  unfreeApps = import pkgs.path {
    system = pkgs.system;
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };

  # isDarwin = builtins.hasAttr "launchd" options;
  # isLinux = isDarwin == false;

  # ifDarwin = options: attrs: if isDarwin == true then attrs else { };
  # ifLinux = options: attrs: if isLinux == true then attrs else { };

  ifDarwin = options: attrs: if builtins.hasAttr "launchd" options then attrs else { };
  ifLinux = options: attrs: if !builtins.hasAttr "launchd" options then attrs else { };

  generateSdkInstallScript =
    sdk:
    pkgs.writeShellScriptBin "install-android-sdk-${lib.strings.sanitizeDerivationName sdk.identifier}" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      echo "Setting up SDKs..."

      export JAVA_HOME="${pkgs.jdk}"
      export PATH="${
        pkgs.lib.makeBinPath [
          pkgs.gawk
          pkgs.gnugrep
          pkgs.gnused
          pkgs.coreutils
          pkgs.jdk
        ]
      }"
      SDK_HOME="${cfg.sdkHome}/${sdk.identifier}"
      SDK_MANAGER="${unfreeApps.androidsdk}/bin/sdkmanager"
      PACKAGES="${lib.concatStringsSep " " sdk.packages}"

      # Check for a core component to determine if the SDK is already installed.
      if [ -f "$SDK_HOME/platform-tools/adb" ]; then
        exit 0
      fi

      # Ensure the target directory exists.
      mkdir -p "$SDK_HOME"

      # The 'yes' command automatically accepts license agreements.
      # The sdkmanager is then called with the specific root and packages for this SDK.
      yes | "$SDK_MANAGER" --sdk_root="$SDK_HOME" --install $PACKAGES

      # Verify successful installation.
      if [ -f "$SDK_HOME/platform-tools/adb" ]; then
        exit 0
      else
        echo "ERROR: Android SDK installation failed in $SDK_HOME. Please check logs."
        exit 1
      fi
    '';

  # Generate a list of script derivations, one for each SDK defined in the config.
  sdkInstallScripts = lib.map generateSdkInstallScript cfg.sdks;

  # Create the final activation script text by creating a line to execute each
  # of the generated scripts.
  activationScriptText = lib.concatStringsSep "\n" (
    lib.map (script: "${script}/bin/${script.meta.mainProgram}") sdkInstallScripts
  );

  mkEmulator =
    emu:
    let
      name = if emu.name != null then emu.name else "emulator-android-${emu.platformVersion}";

      emulator = unfreeApps.androidenv.emulateApp {
        name = name;
        deviceName = name;

        configOptions = {
          "hw.gpu.enabled" = "true";
          "hw.gpu.mode" = "host";
          "hw.ramSize" = "2048";

          "hw.lcd.height" = emu.height;
          "hw.lcd.width" = emu.width;
          "hw.lcd.density" = emu.density;
        }
        // emu.extraConfig;

        platformVersion = emu.platformVersion;
        abiVersion = emu.abiVersion;
        systemImageType = emu.systemImageType;
      };
    in
    pkgs.writeShellScriptBin name ''
      unset ANDROID_HOME
      unset ANDROID_SDK_ROOT
      exec ${emulator}/bin/run-test-emulator "$@"
    '';
in
{
  options = {
    ordenada.features.android = {
      enable = lib.mkEnableOption "the Android feature";
      sdkHome = lib.mkOption {
        type = types.nullOr types.str;
        default = "${features.userInfo.homeDirectory}/Android/Sdk";
      };
      activeSdk = lib.mkOption {
        type = lib.types.str;
        description = "The identifier of the SDK to use by default. \
The $ANDROID_HOME and $ANDROID_SDK_ROOT environment variables will be set to it.";
        default = "34";
      };
      sdks = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              identifier = lib.mkOption {
                type = types.str;
                description = "An identifier for the sdk (e.g. 34).";
                default = "34";
              };
              packages = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "A list of SDK Manager packages to install for this SDK.";
                example = [
                  "platform-tools"
                  "platforms;android-34"
                  "build-tools;34.0.0"
                  "cmdline-tools;latest"
                  "emulator"
                ];
              };
            };
          }
        );
        default = [ ];
      };
      emulators = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "Name of the emulator (e.g. Small phone)";
                default = null;
              };
              platformVersion = lib.mkOption {
                type = lib.types.str;
                description = "Android platform version (e.g. 35)";
              };
              abiVersion = lib.mkOption {
                type = lib.types.str;
                description = "ABI platform version (e.g. arm64-v8a)";
              };
              systemImageType = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "System Image type (e.g. google_apis_playstore)";
                default = "google_apis_playstore";
              };
              width = lib.mkOption {
                type = lib.types.str;
                description = "Width of the AVD in px (e.g. \"500\")";
                default = "1280";
              };
              height = lib.mkOption {
                type = lib.types.str;
                description = "height of the AVD in px (e.g. \"1000\")";
                default = "2856";
              };
              density = lib.mkOption {
                type = lib.types.str;
                description = "density of the AVD in PPI (e.g. \"350\")";
                default = "495";
              };
              extraConfig = lib.mkOption {
                type = types.attrs;
                description = ''
                  Extra options to add to the AVD config. Note that the following options:

                    "hw.gpu.enabled" = "true";
                    "hw.gpu.mode" = "host";
                    "hw.ramSize" = "2048";

                  are set by default, but can be overwritten using this option.
                '';
                default = { };
              };
            };
          }
        );
        default = [ ];
        description = "List of emulators to create.";
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable (mkMerge [
      ## All platforms
      {
        environment.variables = {
          ANDROID_HOME = "${cfg.sdkHome}/${cfg.activeSdk}";
          ANDROID_SDK_ROOT = "${cfg.sdkHome}/${cfg.activeSdk}";
        };
      }

      ## darwin
      # (ifDarwin options (mkMerge [ { } ]))

      ## linux
      (ifLinux options {
        programs.adb.enable = true;
        services.udev.packages = [ pkgs.android-udev-rules ];
        virtualisation.waydroid.enable = true;
      })
    ]))
    {
      users = mkHomeConfig config "android" (
        user:
        (mkMerge [
          ## Linux
          (ifLinux options {
            extraGroups = [ "adbusers" ];
          })
        ])
      );

      home-manager = mkHomeConfig config "android" (
        user:
        (mkMerge [
          ## All platforms
          {
            home.packages =
              with pkgs;
              [
                unfreeApps.androidsdk
                android-tools
                jdk
                payload-dumper-go
                fdroidcl
              ]
              ++ (lib.map mkEmulator cfg.emulators);

            home.activation.setupSDKs = mkAfter ''
              run ${activationScriptText}
            '';
          }

          ## Linux
          (ifLinux options {
            wayland.windowManager.sway.config.floating.criteria = mkIf (config.ordenada.globals.wm == "sway") [
              { app_id = "Waydroid"; }
            ];
          })

          ## Darwin
          ## (ifDarwin options {})
        ])
      );
    }
  ];
}
