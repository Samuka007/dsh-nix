{ lib }:

let
  mkPluginBundle =
    { packageName ? null, path, patchPath ? null, ... }:
    let
      packagePath =
        if builtins.isPath path then
          builtins.path { inherit path; }
        else
          path;
      # Only local directories are inspectable at evaluation time.  A
      # derivation provides its package.json when built, so treat it as a
      # plain dependency unless the caller declares the patch explicitly.
      inspectable = builtins.isPath path;
      manifest =
        if inspectable then
          let manifestPath = "${toString path}/package.json";
          in
          if builtins.pathExists manifestPath then
            builtins.fromJSON (builtins.readFile manifestPath)
          else
            throw "dsh plugin bundle: missing package.json at ${manifestPath}"
        else null;
      resolvedPackageName = if packageName != null then packageName else manifest.name or null;
      checkedPackageName =
        if resolvedPackageName == null || resolvedPackageName == "" then
          throw "dsh plugin bundle: packageName is required (set it explicitly or provide package.json name)"
        else
          resolvedPackageName;
      declaredPatch =
        if manifest == null then null
        else (((manifest.dsh or { }).bundle or { }).patch or null);
      resolvedPatchPath = if patchPath != null then patchPath else declaredPatch;
    in
    {
      packageName = checkedPackageName;
      inherit packagePath;
      patchPath = resolvedPatchPath;
      isLayer = resolvedPatchPath != null;
    };
in
{
  inherit mkPluginBundle;
  mkPlugin = mkPluginBundle;
}
