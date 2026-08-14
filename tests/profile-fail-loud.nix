# Self-test for build-time fail-loud patch validation (issue #1): the check
# replays dsh's applyEntryPatches semantics over the profile's ordered in-box
# layers — an override whose id no earlier layer defines would be silently
# skipped at runtime, so it must throw at evaluation time.  Run:
#   nix-instantiate --eval --strict --json tests/profile-fail-loud.nix
{ pkgs }:

let
  lib = pkgs.lib;
  profilesLib = import ../lib/profiles.nix { inherit lib; };
  inBoxNames = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" "@deepseek-ai/dsh-headless" ];

  tryEval = name: plugins:
    let
      thrown = builtins.tryEval (profilesLib.mkProfileBundle {
        inherit name inBoxNames plugins;
      });
    in
    {
      name = name;
      ok = !thrown.success;
      message = if !thrown.success then "threw" else "did not throw";
    };

  # In-box string entries only: nix-path and spec entries are never validated.
  mixed = plugins: [
    "@deepseek-ai/dsh-web-app"
    ../examples/plugins/tui-core
  ] ++ plugins;

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

  cases = map (c: tryEval c.name c.plugins) throwingCases;
  failed = builtins.filter (case: !case.ok) cases;

  # Controls: legal compositions must NOT throw (guards against an inverted
  # check silently failing everything).
  legalCases = [
    {
      name = "base-only";
      plugins = [ "@deepseek-ai/dsh-base" ];
    }
    {
      name = "base-then-web";
      plugins = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" ];
    }
    {
      name = "base-then-headless";
      plugins = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-headless" ];
    }
    {
      name = "base-then-both";
      plugins = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" "@deepseek-ai/dsh-headless" ];
    }
  ];
  legal = map (c: {
    name = c.name;
    ok = (builtins.tryEval (profilesLib.mkProfileBundle {
      inherit (c) name plugins;
      inherit inBoxNames;
    })).success;
  }) legalCases;
  legalFailed = builtins.filter (case: !case.ok) legal;
in
{
  inherit cases failed legal;
  ok = failed == [ ] && legalFailed == [ ];
}
