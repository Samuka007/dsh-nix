# dsh-nix

Nix-native packaging for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`):

1. **`pkgs.dsh`** — the CLI as a reproducible Nix package (pnpm monorepo build,
   upstream pinned at `47f9438`).
2. **Profile packager** — compose DSH profiles from three kinds of plugins in
   one ordered list, with build-time resolution instead of `dsh plugin`'s
   activation-time pnpm reconcile.
3. **`programs.dsh` Home Manager module** — declarative plugin management in
   the Thunderbird style: the module owns the composition under `~/.dsh`,
   the app owns its data.

## Plugin model

A profile's `plugins` list accepts three kinds, mixed in any order:

| Kind | Example | Resolution |
|---|---|---|
| in-box bundle | `"@deepseek-ai/dsh-base"` | name only; resolved from the `dsh` installation |
| pnpm spec | `"github:someone/plugin"` | fixed-output derivation runs `pnpm add` at build time; pin with `specsHash` |
| Nix package/path | `pkgs.fetchFromGitHub { ... }` or `./my-plugin` | symlinked into the profile; carries its own dependency closure |

Layer registration (which plugins join `dsh.profile.bundles`) is a pure
build-time reconcile that reads each resolved package's `dsh.bundle.patch`
declaration — `dsh plugin`'s install/resolve/reconcile is replaced wholesale,
so removal is declarative and resolution failures surface at `nix build`.

In-box profiles get a **build-time boot check**: `checks.profile-boot-web`
and `checks.profile-boot-headless` boot the composed profile with dsh's own
`boot()` (which runs `assertEntriesActivated`) inside the Nix sandbox and
dispose immediately. A profile that would fail at runtime — missing
services, failed activation — fails `nix build` instead. The check is the
real dsh fail-loud, not a reimplementation: `scripts/check-profile.mjs`
loads the profile exactly as `dsh --profile` would and lets dsh's own
audit decide. `checks.profile-boot-web-nobase` proves the check catches a
web-app-without-base composition (8 pending entries).

## Usage

### Overlay

```nix
# nixos configuration:
imports = [ inputs.dsh-nix.nixosModules.default ];   # or:
nixpkgs.overlays = [ inputs.dsh-nix.overlays.default ];

# now pkgs.dsh is available everywhere:
environment.systemPackages = [ pkgs.dsh ];
```

The Home Manager module's `package` option defaults to `pkgs.dsh` when the
overlay is applied, falling back to a self-contained `callPackage` build.

### Home Manager

```nix
inputs.dsh-nix.url = "github:Samuka007/dsh-nix";
inputs.dsh-nix.inputs.nixpkgs.follows = "nixpkgs";

# in your home-manager config:
imports = [ inputs.dsh-nix.homeManagerModules.dsh ];

programs.dsh = {
  enable = true;
  profiles.headless = {
    plugins = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-headless" ];
  };
  profiles.web = {
    plugins = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" ];
  };
  profiles.custom = {
    plugins = [
      "@deepseek-ai/dsh-base"
      "github:someone/cool-plugin"          # build-time resolve
    ];
    specsHash = "sha256-...";               # pin the resolution
    userPatchesFile = ./patches.yml;        # profile-level cordis.patch.yml
  };
  homePatchesFile = ./home-patches.yml;     # -> ~/.dsh/cordis.patch.yml
  # settings = { ... };                     # seeds ~/.dsh/settings.yaml once
};
```

Activation materialises each immutable profile into
`~/.dsh/profiles/<name>` (stamp-based idempotent refresh). The module owns
only the composition layers; sessions, settings, and credentials under
`~/.dsh` remain the app's.

```sh
dsh --profile headless "task"
dsh --profile web          # http://127.0.0.1:3080
```

### Standalone

```nix
nix build .#packages.x86_64-linux.dsh        # the CLI
nix build .#packages.x86_64-linux.tui-spec   # example: spec-resolved profile
nix eval .#profiles.tui-spec --json          # the declaration
```

The package also ships `dsh-acp-demo`, the ACP automation server app
(JSON-RPC over stdio; supply a leaf `cordis.yml` via `--config`, e.g. the
upstream `examples/acp-agent/cordis.yml`).

## Verification

```sh
nix flake check                    # artifact shape + module assertions
./scripts/profile-smoke.sh         # boot tui profile with packaged dsh,
                                   # assert activate/dispose lifecycle
./scripts/hm-e2e.sh                # module eval -> activation -> boot
```

Real agent runs need credentials (`DEEPSEEK_API_KEY`, or configure the model
in the web UI so `~/.dsh/.credentials.yaml` is populated).

## Notes

- The Home Manager module's default `package` builds `pkgs/dsh.nix` against
  your nixpkgs, which must provide `fetchPnpmDeps` and `pnpmConfigHook`.
- Spec-string plugins change their resolved content only when their
  `specsHash` is updated — deliberate lockfile-style ceremony.
- Upstream `dsh` ships no TUI surface (only `web` and `headless` profiles);
  a third-party TUI bundle would slot in as one plugin entry.

## License

MIT
