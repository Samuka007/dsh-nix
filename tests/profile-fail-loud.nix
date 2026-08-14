# Self-test for build-time fail-loud layer dependency validation (issue #1):
# a profile whose in-box layers use web-app/headless without a preceding
# base must throw at evaluation time.  Run:
#   nix-instantiate --eval --strict --json tests/profile-fail-loud.nix
{ pkgs }:

let
  lib = pkgs.lib;
  profilesLib = import ../lib/profiles.nix { inherit lib; };
  inBoxNames = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" "@deepseek-ai/dsh-headless" ];

  tryThrow = name: plugins:
    let
      thrown = builtins.tryEval (profilesLib.mkProfileBundle {
        inherit name inBoxNames plugins;
      });
    in
    {
      name = name;
      ok = !thrown.success;
      message =
        if !thrown.success then
          "threw"
        else
          "did not throw";
    };

  # In-box string entries only: nix-path and spec entries are never validated.
  mixed = plugins: [
    "@deepseek-ai/dsh-web-app"
    ../examples/plugins/tui-core
  ] ++ plugins;

  # name -> plugins; the ordered in-box sequence (after nix/spec filtering)
  # is what the validation sees.
  throwingCases = [
    {
      name = "web-without-base";
      plugins = [ "@deepseek-ai/dsh-web-app" ];
    }
    {
      name = "headless-without-base";
      plugins = [ "@deepseek-ai/dsh-headless" ];
    }
    {
      name = "base-after-web";
      plugins = [ "@deepseek-ai/dsh-web-app" "@deepseek-ai/dsh-base" ];
    }
    {
      name = "base-missing-with-nix-entry";
      plugins = mixed [ ];
    }
    {
      name = "headless-missing-with-spec-entry";
      plugins = [
        "@deepseek-ai/dsh-headless"
        ("file:" + toString ../examples/plugins/tui-core)
      ];
    }
  ];

  cases = map (c: tryThrow c.name c.plugins) throwingCases;

  failed = builtins.filter (case: !case.ok) cases;

  # Control: the legal order must NOT throw (guards against an inverted
  # check silently failing everything).
  legal = builtins.tryEval (profilesLib.mkProfileBundle {
    name = "web-with-base";
    inherit inBoxNames;
    plugins = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" ];
  });
in
{
  inherit cases failed;
  inherit legal;
  ok = failed == [ ] && legal.success;
}
