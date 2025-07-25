{
  config,
  lib,
  pkgs,
  ...
}:

with pkgs.lib.ordenada;

let
  cfg = config.ordenada.features.ssh;
in
{
  options = {
    ordenada.features.ssh = {
      enable = lib.mkEnableOption "the SSH feature";
      daemon = mkEnableTrueOption "the SSH server daemon";
      matchBlocks = lib.mkOption {
        type = lib.types.attrs;
        description = "The SSH stanzas to use in the client configuration.";
        default = { };
      };
      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of user authorized SSH keys.";
        default = cfg.rootAuthorizedKeys;
      };
    };
  };
  config = lib.mkMerge [
    {
      users = mkHomeConfig config "ssh" (user: {
        openssh.authorizedKeys.keys = user.features.ssh.authorizedKeys;
      });
      home-manager = mkHomeConfig config "ssh" (user: {
        services.ssh-agent.enable =
          !config.home-manager.users.${user.name}.services.gpg-agent.enableSshSupport;
        programs.ssh = {
          enable = true;
          matchBlocks = user.features.ssh.matchBlocks;
        };
      });
    }
  ];
}
