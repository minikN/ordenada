{
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

{
  options = {
    ordenada.features.emacs.exec-path = {
      enable = lib.mkEnableOption "the Emacs exec-path-from-shell feature";
    };
  };
  config = {
    home-manager = mkHomeConfig config "emacs.exec-path" (user: {
      programs.emacs = mkElispConfig {
        name = "ordenada-exec-path";
        config = ''
          (eval-when-compile
            (require 'exec-path-from-shell))
          (when (memq window-system '(mac ns x))
            (exec-path-from-shell-initialize))
          (when (daemonp)
            (exec-path-from-shell-initialize))
        '';
        elispPackages = with pkgs.emacsPackages; [
          exec-path-from-shell
        ];
      };
    });
  };
}
