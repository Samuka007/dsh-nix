# Counterexample for build-time fail-loud (issue #1): evaluating this file
# MUST throw with the missing-layer name in the message.  The flake check
# runs nix-instantiate on it, expects a non-zero exit, and greps stderr for
# "@deepseek-ai/dsh-base".
{ pkgs }:

let
  lib = pkgs.lib;
  profilesLib = import ../lib/profiles.nix { inherit lib; };
in
profilesLib.mkProfileBundle {
  name = "web-without-base";
  plugins = [ "@deepseek-ai/dsh-web-app" ];
  inBoxNames = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" ];
}
