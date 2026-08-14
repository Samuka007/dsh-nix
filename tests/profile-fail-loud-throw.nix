# Counterexample for build-time fail-loud (issue #1): evaluating this file
# MUST throw with the skipped-override row in the message.  The flake check
# runs nix-instantiate on it, expects a non-zero exit, and greps stderr for
# the first override id web-app's patch targets ("system-prompt").
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
