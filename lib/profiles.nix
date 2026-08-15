{ lib }:

let
  pluginsLib = import ./plugins.nix { inherit lib; };
  inherit (pluginsLib) classifyPlugin fetchSpecs;

  mkProfileBundle =
    {
      name,
      plugins,
      inBoxNames ? [ ],
      userPatchesFile ? null,
      userPatches ? [ ],
      specsHash ? "",
    }:
    let
      classified = map (plugin: classifyPlugin { inherit inBoxNames plugin; }) plugins;
      nixPlugins = map (entry: entry.plugin)
        (builtins.filter (entry: entry.kind == "nix") classified);
      packageNames = map (plugin: plugin.packageName) nixPlugins;
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
      inherit name userPatchesFile userPatches specsHash;
      plugins = classified;
      inBox = map (entry: entry.name)
        (builtins.filter (entry: entry.kind == "in-box") classified);
      inherit nixPlugins;
      specs = map (entry: entry.spec)
        (builtins.filter (entry: entry.kind == "spec") classified);
    };

  buildProfileBundle =
    { pkgs, profile }:
    let
      classified = profile.plugins;
      nixEntries = builtins.filter (entry: entry.kind == "nix") classified;
      specEntries = builtins.filter (entry: entry.kind == "spec") classified;
      specsRoot = if profile.specs == [ ] then null else fetchSpecs {
        inherit pkgs;
        specs = profile.specs;
        hash = profile.specsHash;
      };
      nixMetadata = map (entry: {
        packageName = entry.plugin.packageName;
        packagePath = toString entry.plugin.packagePath;
      }) nixEntries;
      metadata = pkgs.writeText "dsh-profile-plugins.json" (builtins.toJSON {
        inherit nixMetadata;
        specCount = builtins.length specEntries;
        classes = map (entry:
          if entry.kind == "in-box" then { kind = entry.kind; name = entry.name; }
          else if entry.kind == "spec" then { kind = entry.kind; }
          else { kind = entry.kind; packageName = entry.plugin.packageName; packagePath = toString entry.plugin.packagePath; }
        ) classified;
      });
      patchText = builtins.toJSON profile.userPatches;
      patchSource = if profile.userPatchesFile != null then profile.userPatchesFile else null;
      specRootArg = if specsRoot == null then "" else toString specsRoot;
    in
    pkgs.runCommand "dsh-profile-${profile.name}" {
      buildInputs = [ pkgs.jq ];
    } ''
      mkdir -p "$out/node_modules"
      metadata=${lib.escapeShellArg (toString metadata)}
      specRoot=${lib.escapeShellArg specRootArg}

      layers='[]'
      specIndex=0
      while IFS= read -r entry; do
        kind=$(printf '%s' "$entry" | jq -r '.kind')
        case "$kind" in
          in-box)
            layer=$(printf '%s' "$entry" | jq -r '.name')
            ;;
          spec)
            layer=$(jq -r --argjson i "$specIndex" '.dependencies | keys_unsorted[$i]' "$specRoot/package.json")
            specIndex=$((specIndex + 1))
            ;;
          nix)
            packageName=$(printf '%s' "$entry" | jq -r '.packageName')
            packagePath=$(printf '%s' "$entry" | jq -r '.packagePath')
            if jq -e '((.dsh // {}).bundle // {}).patch != null' "$packagePath/package.json" >/dev/null; then
              layer=$packageName
            else
              layer=""
            fi
            ;;
        esac
        if [ -n "$layer" ]; then
          layers=$(printf '%s' "$layers" | jq -c --arg layer "$layer" '. + [$layer]')
        fi
      done < <(jq -c '.classes[]' "$metadata")

      dependencies=$(jq -n '{ }')
      while IFS= read -r entry; do
        packageName=$(printf '%s' "$entry" | jq -r '.packageName')
        packagePath=$(printf '%s' "$entry" | jq -r '.packagePath')
        dependencies=$(printf '%s' "$dependencies" | jq -c --arg name "$packageName" --arg path "$packagePath" '. + {($name): $path}')
        parent=$(dirname "$packageName")
        if [ "$parent" != . ]; then mkdir -p "$out/node_modules/$parent"; fi
        ln -s "$packagePath" "$out/node_modules/$packageName"
      done < <(jq -c '.nixMetadata[]' "$metadata")

      if [ -n "$specRoot" ]; then
        for entry in "$specRoot"/node_modules/*; do
          [ -e "$entry" ] || continue
          ln -s "$entry" "$out/node_modules/$(basename "$entry")"
        done
      fi

      jq -n --arg name ${lib.escapeShellArg profile.name} --argjson layers "$layers" --argjson dependencies "$dependencies" \
        '{name: $name, version: "0.0.0", private: true, dsh: {profile: {bundles: $layers}}, dependencies: $dependencies}' > "$out/package.json"
      printf '[]\n' > "$out/cordis.yml"
      ${if patchSource != null then ''cp ${lib.escapeShellArg (toString patchSource)} "$out/cordis.patch.yml"'' else ''printf '%s' ${lib.escapeShellArg patchText} > "$out/cordis.patch.yml"''}
    '';
in
{
  inherit mkProfileBundle buildProfileBundle;
  mkProfile = mkProfileBundle;
  buildProfile = buildProfileBundle;
}
