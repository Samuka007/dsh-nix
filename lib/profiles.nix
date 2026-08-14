{ lib }:

let
  pluginsLib = import ./plugins.nix { inherit lib; };
  inherit (pluginsLib) classifyPlugin fetchSpecs;

  # Ordered patch-entry data for the in-box bundles, extracted verbatim from
  # the pinned dsh source (lib/in-box-patches.nix).  The check below replays
  # dsh's own patch semantics — no package-level knowledge is hard-coded.
  inBoxPatchEntries = (import ./in-box-patches.nix).inBoxPatchEntries;

  # Replay dsh's applyEntryPatches semantics (packages/include/src/index.ts)
  # over the profile's ordered in-box layers: an `override` entry (a
  # top-level patch row, which replaces or disables a row) must find its id
  # already defined by an earlier layer's `insert`; otherwise dsh skips it
  # with a warning and the patch silently never applies.  `insert` entries
  # define rows and always succeed.  A violation is a deterministic runtime
  # no-op, so it fails here at evaluation time instead.
  #
  # Only in-box string entries participate: nix-path and spec entries carry
  # their own dependency closure and cannot be inspected statically.
  checkInBoxPatches = profileName: inBoxLayers:
    let
      entriesOf = name: inBoxPatchEntries.${name} or [ ];
      step = { defined, errors }: name:
        let
          entries = entriesOf name;
          missing = builtins.filter (entry:
            entry.kind == "override" && !builtins.elem entry.id defined) entries;
          newDefined = defined ++ map (entry: entry.id)
            (builtins.filter (entry: entry.kind == "insert") entries);
        in
        {
          defined = newDefined;
          errors = errors ++ map (entry:
            "profile ${profileName}: in-box layer ${name} overrides row "
            + "${entry.id}, which no earlier layer defines — dsh would skip "
            + "the patch with a warning and boot without it") missing;
        };
      result = builtins.foldl' step { defined = [ ]; errors = [ ]; } inBoxLayers;
    in
    if result.errors == [ ] then
      true
    else
      throw "dsh profile bundle: ${builtins.concatStringsSep "\n" result.errors}";

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
      inBox = map (entry: entry.name)
        (builtins.filter (entry: entry.kind == "in-box") classified);
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
    assert checkInBoxPatches checkedName inBox;
    {
      inherit name userPatchesFile userPatches specsHash;
      plugins = classified;
      inherit inBox;
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
      touch "$out/cordis.yml"
      ${if patchSource != null then ''cp ${lib.escapeShellArg (toString patchSource)} "$out/cordis.patch.yml"'' else ''printf '%s' ${lib.escapeShellArg patchText} > "$out/cordis.patch.yml"''}
    '';
in
{
  inherit mkProfileBundle buildProfileBundle;
  mkProfile = mkProfileBundle;
  buildProfile = buildProfileBundle;
}
