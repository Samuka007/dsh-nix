{ plugins, profilesLib, inBoxNames }:
profilesLib.mkProfileBundle {
  name = "tui";
  inherit inBoxNames;
  plugins = [
    (plugins.mkPluginBundle {
      path = ./../plugins/tui-core;
    })
  ];
}
