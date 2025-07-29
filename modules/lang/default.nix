{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./clojure.nix
    ./javascript.nix
    ./json.nix
    ./json5.nix
    ./markdown.nix
    ./nix.nix
    ./yaml.nix
  ];
}
