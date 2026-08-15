{ profilesLib, inBoxNames }:
profilesLib.mkProfileBundle {
  name = "headless";
  inherit inBoxNames;
  plugins = [
    "@deepseek-ai/dsh-base"
    "@deepseek-ai/dsh-headless"
  ];
}
