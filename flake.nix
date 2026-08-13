# Nix-native DSH profile packager.
#
# A PLUGIN bundle is a plain (often non-flake) package directory: it carries
# its own package.json (with `dsh.bundle.patch`) and cordis.patch.yml.  We
# import it verbatim — we never transcribe its rows.
# A PROFILE bundle is the artifact we build: an immutable DSH profile
# directory (package.json manifest + node_modules view) that `dsh --profile`
# consumes.  Cordis stays DSH's runtime; this flake does not reimplement it.
#
#   nix flake check                         assertions + profile artifact shape
#   nix eval .#profiles.tui --json          the declared profile (ordered layers)
#   nix build .#packages.x86_64-linux.tui   the immutable profile directory
#   ./scripts/profile-smoke.sh              boot it in a real dsh checkout
#
# Optional: examples/profiles/dsh-web.nix shows importing dsh's own shipped
# bundles (non-flake repo input) with zero transcription; wire it in when a
# dsh checkout is visible to the flake.
{
  description = "Nix-native DSH profile packager";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.dsh = {
    url = "github:deepseek-ai/deepseek-harness/47f943859bef60e4160492346772ded9b24f765a";
    flake = false;
  };

  outputs = { self, nixpkgs, dsh }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: lib.genAttrs systems (system: f system);

      plugins = import ./lib/plugins.nix { inherit lib; };
      profilesLib = import ./lib/profiles.nix { inherit lib; };
      tui = import ./examples/profiles/tui.nix { inherit lib plugins profilesLib; };

      profiles = { inherit tui; };
    in
    {
      inherit lib plugins profilesLib profiles;

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          dsh = pkgs.callPackage ./pkgs/dsh.nix { src = dsh; };

          tui = profilesLib.buildProfileBundle {
            inherit pkgs;
            profile = profiles.tui;
          };
        });

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          profile = profiles.tui;
          artifact = self.packages.${system}.tui;
          expectedLayers = builtins.toJSON profile.layers;
          bundlePaths = map (plugin: "${plugin.packageName}") profile.plugins;
        in {
          profile-tui = pkgs.runCommand "dsh-profile-tui-check" {
            nativeBuildInputs = [ pkgs.jq ];
          } ''
            package_json=${artifact}/package.json
            actual_layers=$(jq -c '.dsh.profile.bundles' "$package_json")
            expected_layers=${lib.escapeShellArg expectedLayers}
            test "$actual_layers" = "$expected_layers"

            ${lib.concatMapStringsSep "\n" (packageName: ''
              test -L ${lib.escapeShellArg "${artifact}/node_modules/${packageName}"}
            '') bundlePaths}

            touch "$out"
          '';
        });

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ nodejs_22 pnpm yq-go ];
          };
        });
    };
}
