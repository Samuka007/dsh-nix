{ lib }:

let
  pluginsLib = import ./plugins.nix { inherit lib; };
  inherit (pluginsLib) classifyPlugin fetchSpecs;

  # Explicit in-box layer dependency table (issue #1).  A layer named as a
  # key must not appear in a profile unless every listed layer precedes it
  # among the profile's in-box entries.  Only in-box string entries are
  # validated; nix-path and spec entries carry their own dependency closure
  # and cannot be inspected statically.
  #
  # Rationale (upstream dsh, pinned 47f9438): @deepseek-ai/dsh-base is the
  # only core insert layer (its cordis.patch.yml is a 78-line insert);
  # web-app and headless patches override base rows by id and npm-declare no
  # dependency on it.  Omitting base boots dsh into a runtime fail-loud
  # (assertEntriesActivated lists the missing services); this table turns
  # that into an evaluation-time failure naming the missing layer.
  inBoxDependencies = {
    "@deepseek-ai/dsh-web-app" = [ "@deepseek-ai/dsh-base" ];
    "@deepseek-ai/dsh-headless" = [ "@deepseek-ai/dsh-base" ];
  };

  # Validate an ordered in-box layer list against inBoxDependencies.
  # Checking each layer against the set already seen yields transitivity for
  # free: a chain (a requires b, b requires c) needs only its direct pairs in
  # the table.  Returns true or throws with every violation.
  checkInBoxDependencies = profileName: inBoxLayers:
    let
      depsOf = name: inBoxDependencies.${name} or [ ];
      step = { satisfied, errors }: name:
        let
          missing = builtins.filter (dep: !builtins.elem dep satisfied) (depsOf name);
        in
        {
          satisfied = satisfied ++ [ name ];
          errors = errors ++ map (dep:
            "profile ${profileName}: in-box layer ${dep} must precede ${name} "
            + "(declared in inBoxDependencies in lib/profiles.nix)") missing;
        };
      result = builtins.foldl' step { satisfied = [ ]; errors = [ ]; } inBoxLayers;
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
    assert checkInBoxDependencies checkedName inBox;
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
