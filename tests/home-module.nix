# Self-test for modules/home-manager/dsh.nix: evaluate the module with stub
# home-manager options and assert the composition of home.file and the
# activation script. Run: nix-instantiate --eval --strict --json
{ pkgs }:

let
  lib = pkgs.lib;
  pluginsLib = import ../lib/plugins.nix { inherit lib; };
  profilesLib = import ../lib/profiles.nix { inherit lib; };
  module = import ../modules/home-manager/dsh.nix {
    inherit pluginsLib profilesLib;
    inBoxNames = [ "@deepseek-ai/dsh-base" ];
    dshSrc = null;
  };

  stub = { lib, ... }: {
    options.home.packages = lib.mkOption { type = lib.types.listOf lib.types.package; default = [ ]; };
    options.home.file = lib.mkOption { type = lib.types.attrs; default = { }; };
    options.home.activation = lib.mkOption { type = lib.types.attrs; default = { }; };
  };

  evaluated = lib.evalModules {
    modules = [
      stub
      module
      {
        programs.dsh = {
          enable = true;
          package = pkgs.writeText "dsh-dummy" "dummy";
          homePatchesFile = null;
          profiles.agent = {
            plugins = [ "@deepseek-ai/dsh-base" ../examples/plugins/tui-core ];
            userPatches = [ ];
          };
        };
      }
    ];
    specialArgs = { inherit pkgs; };
  };

  config = evaluated.config;
  activation = config.home.activation.dshProfiles or "";
in
{
  checks = [
    (lib.hasAttr ".dsh/cordis.patch.yml" config.home.file == false)
    (lib.hasInfix "$HOME/.dsh/profiles/agent" activation)
    (lib.hasInfix ".dsh-nix-stamp" activation)
    (lib.hasInfix "dsh-profile-agent" activation)
    (builtins.length config.home.packages == 1)
  ];
  all = lib.all (x: x) [
    (lib.hasAttr ".dsh/cordis.patch.yml" config.home.file == false)
    (lib.hasInfix "$HOME/.dsh/profiles/agent" activation)
    (lib.hasInfix ".dsh-nix-stamp" activation)
    (lib.hasInfix "dsh-profile-agent" activation)
    (builtins.length config.home.packages == 1)
  ];
}
