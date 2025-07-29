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
        config = # elisp
          ''
            (require 'exec-path-from-shell)

            (dolist (var
            '("SSH_AUTH_SOCK"
              "SSH_AGENT_PID"
              "GPG_AGENT_INFO"
              "GNUPGHOME"
              "LANG"
              "LC_CTYPE"
              "NIX_SSL_CERT_FILE"
              "NIX_PATH"
            ))
            (add-to-list 'exec-path-from-shell-variables var))

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
