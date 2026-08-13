# Optional example: inject dsh's own shipped bundles (a non-flake repo input)
# into a profile with zero transcription of their rows.  Activate by making
# the dsh checkout visible to the flake (or import this file directly with a
# `path` argument), then wire `profiles.dsh-web` into flake outputs.
{ plugins, profilesLib, ... }:
if ! builtins.pathExists ../../dsh/packages/bundle/base then
  null
else
  profilesLib.mkProfileBundle {
    name = "dsh-web";
    plugins = [
      (plugins.mkPluginBundle {
        path = ../../dsh/packages/bundle/base;
      })
      (plugins.mkPluginBundle {
        path = ../../dsh/packages/bundle/web-app;
      })
    ];
  }
