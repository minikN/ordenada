{
  lib,
  config,
  pkgs,
  system ? builtins.currentSystem,
  ...
}:

let
  isLinux =
    lib.strings.hasPrefix "x86_64-linux" system || lib.strings.hasPrefix "aarch64-linux" system;
  isDarwin =
    lib.strings.hasPrefix "x86_64-darwin" system || lib.strings.hasPrefix "aarch64-darwin" system;
in
{
  imports = [
    ./compile.nix
    ./direnv.nix
    ./android.nix
  ]
  ++ lib.optionals (isLinux) [
  ]
  ++ lib.optionals (isDarwin) [
    ./ios.nix
  ];
}
