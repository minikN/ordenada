{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";


    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    emacs-darwin = {
      url = "github:nix-giant/nix-darwin-emacs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
    nur.url = "github:nix-community/NUR";
    nix-rice.url = "github:bertof/nix-rice";
    base16.url = "github:SenchoPens/base16.nix";
    arkenfox-nixos.url = "github:dwarfmaster/arkenfox-nixos";
    systems.url = "github:nix-systems/default";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      nur,
      nix-rice,
      base16,
      home-manager,
      mac-app-util,

      emacs-overlay,
      emacs-darwin,
      ...
    }:
    let
      # Move overlay definition here so it's in scope for both flake + perSystem
      overlay = final: prev: {
        lib = prev.lib // {
          ordenada = nixpkgs.lib.callPackagesWith {
            inherit (nixpkgs) lib;
            pkgs = import nixpkgs {
              inherit (prev) system;
              overlays = [ ];
            };
          } ./lib { };

          base16 = prev.callPackage base16.lib { };
        };
      };

      # Define ordenada for output.lib (doesn't rely on pkgs, just nixpkgs)
      ordenada = nixpkgs.lib.callPackagesWith {
        inherit (nixpkgs) lib;
        pkgs = import nixpkgs {
          system = "x86_64-linux"; # temporary, overridden in perSystem
          overlays = [ ];
        };
      } ./lib { };

    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      flake = {
        overlays.default = overlay;
        lib = ordenada;

        nixosModules.ordenada =
          { pkgs, ... }:
          {
            imports = [
              ./modules
              home-manager.nixosModules.home-manager
            ];
            config = {
              nixpkgs.overlays = [
                overlay
                nur.overlays.default
                nix-rice.overlays.default
                emacs-overlay.overlays.default
                (final: prev: { inherit inputs; })
              ];
            };
          };

        darwinModules.ordenada =
          { pkgs, ... }:
          {
            imports = [
              ./modules
              home-manager.darwinModules.home-manager
              mac-app-util.darwinModules.default
              (
                {
                  pkgs,
                  config,
                  inputs,
                  ...
                }:
                {
                  home-manager.sharedModules = [
                    mac-app-util.homeManagerModules.default
                  ];
                }
              )
            ];
            config = {
              nixpkgs.overlays = [
                overlay
                nur.overlays.default
                nix-rice.overlays.default
                emacs-darwin.overlays.emacs
                emacs-overlay.overlays.package
                (final: prev: { inherit inputs; })
              ];
            };
          };
      };

      perSystem =
        {
          config,
          system,
          pkgs,
          modulesPath,
          ...
        }:
        let
          pkgs' = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };

          ordenada' = nixpkgs.lib.callPackagesWith {
            inherit (nixpkgs) lib;
            pkgs = pkgs';
          } ./lib { };

          overlay' = final: prev: {
            lib = prev.lib // {
              inherit ordenada';
              base16 = pkgs'.callPackage base16.lib { };
            };
          };
        in
        {
          _module.args = {
            ordenada = ordenada';
            overlays.default = overlay'; # consumer overlay
            lib = ordenada'; # consumer lib
          };

          packages = rec {
            docs = pkgs.callPackage ./mkDocs.nix {
              pkgs = pkgs';
            };
            default = docs;
          };

          apps.darwin-rebuild = {
            type = "app";
            program = inputs.darwin.packages.${system}.darwin-rebuild;
          };
        };
    };
}
