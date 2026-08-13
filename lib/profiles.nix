{ lib }:

let
  mkProfileBundle =
    {
      name,
      plugins,
      userPatchesFile ? null,
      userPatches ? [ ],
      ...
    }:
    let
      packageNames = map (plugin: plugin.packageName) plugins;
      checkedName =
        if name == null || name == "" then
          throw "dsh profile bundle: name must not be empty"
        else
          name;
      uniquePackageNames =
        if builtins.length packageNames == builtins.length (lib.unique packageNames) then
          true
        else
          throw "dsh profile bundle: plugin packageNames must be unique";
    in
    assert uniquePackageNames;
    {
      name = checkedName;
      inherit plugins userPatchesFile userPatches;
      layers = map (plugin: plugin.packageName) (builtins.filter (plugin: plugin.isLayer) plugins);
      dependencies = builtins.listToAttrs (map (plugin: {
        name = plugin.packageName;
        value = plugin.packagePath;
      }) plugins);
    };

  buildProfileBundle =
    { pkgs, profile }:
    let
      packageJson = pkgs.writeText "dsh-profile-package.json" (builtins.toJSON {
        inherit (profile) name dependencies;
        version = "0.0.0";
        private = true;
        dsh.profile.bundles = profile.layers;
      });
      inlinePatches = pkgs.writeText "dsh-profile-cordis.patch.yml" (builtins.toJSON profile.userPatches);
      patchSource = if profile.userPatchesFile != null then profile.userPatchesFile else inlinePatches;
      linkPlugins = lib.concatMapStringsSep "\n" (plugin:
        let
          parent = builtins.dirOf plugin.packageName;
          parentCommand = lib.optionalString (parent != ".")
            ''mkdir -p "$out"/${lib.escapeShellArg "node_modules/${parent}"}'';
        in
        ''
          ${parentCommand}
          ln -s ${lib.escapeShellArg (toString plugin.packagePath)} "$out"/${lib.escapeShellArg "node_modules/${plugin.packageName}"}
        '') profile.plugins;
    in
    pkgs.runCommand "dsh-profile-${profile.name}" {
      userPatchesFile = patchSource;
    } ''
      mkdir -p "$out/node_modules"
      cp ${packageJson} "$out/package.json"
      touch "$out/cordis.yml"
      cp "$userPatchesFile" "$out/cordis.patch.yml"
      ${linkPlugins}
    '';
in
{
  inherit mkProfileBundle buildProfileBundle;
  mkProfile = mkProfileBundle;
  buildProfile = buildProfileBundle;
}
