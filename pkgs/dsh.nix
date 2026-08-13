# The DeepSeek Harness CLI as a Nix package: pnpm monorepo build of the
# deepseek-harness repo, producing `bin/dsh`.
#
# - `fetchPnpmDeps` materialises the pnpm store from pnpm-lock.yaml.
# - `pnpmConfigHook` points the offline install at that store.
# - The HMR service requires Node internals access, so the wrapper launches
#   node with `--expose-internals` (dsh itself never sets this flag).
{ lib
, stdenv
, nodejs
, pnpm
, pnpmConfigHook
, fetchPnpmDeps
, makeBinaryWrapper
, src
}:

let
  version = "0.1.0-rc.5";
  pnpmDeps = fetchPnpmDeps {
    pname = "deepseek-harness";
    inherit version src;
    fetcherVersion = 4;
    hash = "sha256-aySHq0ywTMM5q7YuGHZrV3yQE3bwppgGfWH3wRnHCXk=";
  };
in
stdenv.mkDerivation {
  pname = "dsh";
  inherit version src;

  nativeBuildInputs = [ nodejs pnpm pnpmConfigHook makeBinaryWrapper ];
  inherit pnpmDeps;

  buildPhase = ''
    runHook preBuild
    pnpm install --offline --frozen-lockfile
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    # The CLI resolves workspace packages through the pnpm node_modules
    # layout at runtime, so ship the built repo together with node_modules.
    cp -r . "$out/"
    rm -rf "$out/.git" "$out/.github" "$out/website" \
      "$out/.agents" "$out/.claude" \
      "$out/node_modules/.pnpm/node_modules/@deepseek-ai/website" \
      "$out/node_modules/.cache"
    mkdir -p "$out/bin"
    makeBinaryWrapper "${nodejs}/bin/node" "$out/bin/dsh" \
      --add-flags "--expose-internals" \
      --add-flags "$out/apps/cli/lib/bin.js" \
      --append-flags ""
    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Harness CLI (dsh)";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.all;
  };
}
