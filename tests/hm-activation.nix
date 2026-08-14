# Extract the Home Manager module's activation script and artifact path for a
# realistic end-to-end run: evaluate the module with stubs, print activation
# to stdout and the artifact store path to stderr. Not part of flake checks.
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
  cfg = {
    programs.dsh = {
      enable = true;
      package = pkgs.writeText "dsh-dummy" "dummy";
      profiles.agent.plugins = [ "@deepseek-ai/dsh-base" ../examples/plugins/tui-core ];
    };
  };
  evaluated = lib.evalModules {
    modules = [ stub module cfg ];
    specialArgs = { inherit pkgs; };
  };

  declarations = lib.mapAttrs (name: p:
    profilesLib.mkProfileBundle {
      inherit name;
      plugins = p.plugins;
      inBoxNames = [ "@deepseek-ai/dsh-base" ];
      userPatchesFile = null;
      userPatches = [ ];
      specsHash = "";
    }) cfg.programs.dsh.profiles;
  artifacts = lib.mapAttrs (name: d: profilesLib.buildProfileBundle { inherit pkgs; profile = d; }) declarations;
in
{
  activation = evaluated.config.home.activation.dshProfiles;
  artifact = artifacts.agent;
}
