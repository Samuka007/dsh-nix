# Home Manager module factory for `programs.dsh`.
#
# Declarative plugin management in the Thunderbird style: the module owns the
# COMPOSITION layers under ~/.dsh (profiles/<name>/ + the home-level
# cordis.patch.yml), while the app owns its mutable data (settings.yaml after
# seeding, .credentials.yaml, sessions/, storages/).
#
# Activation materialises each immutable Nix-built profile into
# ~/.dsh/profiles/<name> (writable; dsh rewrites the profile root cordis.yml
# on every boot), comparing a stamp against the artifact store path.
#
# `plugins` accepts three kinds in one ordered list:
#   - in-box bundle names  ("@deepseek-ai/dsh-base")          name only
#   - pnpm spec strings    ("github:someone/plugin")          resolved at build
#     time by a fixed-output derivation; pin with `specsHash`
#   - Nix packages/paths   (pkgs.fetchFromGitHub { ... })     symlinked in
#
# Requires the user's nixpkgs to provide fetchPnpmDeps + pnpmConfigHook when
# `package` defaults to the callPackage-built dsh.
{ pluginsLib, profilesLib, inBoxNames, dshSrc }:

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.dsh;

  profileModule = lib.types.submodule {
    options = {
      plugins = lib.mkOption {
        type = lib.types.listOf (lib.types.oneOf [ lib.types.str lib.types.path lib.types.package ]);
        default = [ ];
        description = ''
          Ordered plugin list. Each entry is one of: an in-box bundle name
          (@deepseek-ai/dsh-*), a pnpm spec string (resolved at build time;
          pin with specsHash), or a Nix package/path.
        '';
      };
      userPatchesFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Profile-level cordis.patch.yml (the DSH user patch layer).";
      };
      userPatches = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Inline profile patch list (JSON-serialisable only; use userPatchesFile for !!js).";
      };
      specsHash = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Fixed-output hash pinning pnpm spec resolution for this profile.";
      };
    };
  };

  declarations = lib.mapAttrs (name: p:
    profilesLib.mkProfileBundle {
      inherit name;
      inherit (p) userPatchesFile userPatches specsHash;
      plugins = p.plugins;
      inherit inBoxNames;
    }) cfg.profiles;

  artifacts = lib.mapAttrs (name: declaration:
    profilesLib.buildProfileBundle { inherit pkgs; profile = declaration; }) declarations;

  profileDir = name: "$HOME/.dsh/profiles/" + lib.escapeShellArg name;
  stampFile = name: "${profileDir name}/.dsh-nix-stamp";

  activateProfile = name: artifact:
    let
      dir = profileDir name;
      stamp = stampFile name;
      artifactString = toString artifact;
    in
    ''
      if [ -f "${stamp}" ] && [ "$(cat "${stamp}")" = ${lib.escapeShellArg artifactString} ]; then
        :
      else
        rm -rf "${dir}"
        mkdir -p "${dir}"
        cp -a ${lib.escapeShellArg artifactString}/. "${dir}/"
        # cp -a syncs the destination directory attributes (read-only store
        # modes) too; dsh rewrites the profile root cordis.yml on every boot.
        chmod -R u+w "${dir}"
        printf '%s' ${lib.escapeShellArg artifactString} > "${stamp}"
      fi
    '';

  activateSettings = lib.optionalString (cfg.settings != { }) ''
    if [ ! -f "$HOME/.dsh/settings.yaml" ]; then
      mkdir -p "$HOME/.dsh"
      umask 077
      cat > "$HOME/.dsh/settings.yaml" <<'DSH_NIX_SETTINGS'
    ${builtins.toJSON cfg.settings}
    DSH_NIX_SETTINGS
    fi
  '';
in
{
  options.programs.dsh = {
    enable = lib.mkEnableOption "DeepSeek Harness (dsh)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dsh or (pkgs.callPackage ../../pkgs/dsh.nix { src = dshSrc; });
      defaultText = "pkgs.dsh (via inputs.dsh-nix.overlays.default) or callPackage fallback";
      description = "The dsh CLI package to install.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileModule;
      default = { };
      description = "DSH profiles materialised under ~/.dsh/profiles/<name>.";
    };

    homePatchesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Machine-level patch layer written to ~/.dsh/cordis.patch.yml.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Seed-only settings.yaml content; after first activation the app owns the file.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file = lib.mkIf (cfg.homePatchesFile != null) {
      ".dsh/cordis.patch.yml".source = cfg.homePatchesFile;
    };

    home.activation.dshProfiles =
      lib.concatStringsSep "\n" (lib.mapAttrsToList activateProfile artifacts)
      + "\n" + activateSettings;
  };
}
