{ profilesLib, inBoxNames }:
profilesLib.mkProfileBundle {
  name = "tui-spec";
  inherit inBoxNames;
  plugins = [
    ("file:" + toString ./../plugins/tui-core)
  ];
  specsHash = "sha256-HzwnswH6AVnUtJdC7scM+xUHi+5ipDukK2nJDj6zx3E=";
}
