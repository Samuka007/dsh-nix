{ plugins, profilesLib, ... }:
profilesLib.mkProfileBundle {
  name = "tui";
  plugins = [
    (plugins.mkPluginBundle {
      path = ./../plugins/tui-core;
    })
  ];
}
