#!/usr/bin/env node
/**
 * Build-time profile check: boot a composed profile with dsh's own boot()
 * and dispose immediately.  boot() runs assertEntriesActivated internally
 * (app-boot/src/index.ts:784), so a non-zero exit means the tree failed to
 * settle or an enabled entry stayed PENDING/FAILED — the exact runtime
 * fail-loud, surfaced at `nix build` time.  No app lifecycle runs: the
 * check disposes the tree as soon as boot returns.
 *
 * Usage: check-profile.mjs <dsh-install> <profile-name> <dsh-home> [args...]
 *   <dsh-install>  the packaged dsh store path (its apps/cli/package.json
 *                  is the install anchor)
 *   <profile-name> the profile directory name under <dsh-home>/profiles
 *   <dsh-home>     a scratch DSH_HOME holding the profile under test
 *   args...        extra command-line args provided via cmdlineArgs
 *                  (web: --port 0 to avoid binding 3080; headless: the task)
 */
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

const NAME = 'dsh'
const [install, name, home, ...args] = process.argv.slice(2)
if (!install || !name || !home) {
  console.error('usage: check-profile.mjs <dsh-install> <profile-name> <dsh-home> [args...]')
  process.exit(2)
}
const installAnchor = join(install, 'apps/cli/package.json')
process.env.DSH_HOME = home
const lib = (pkg) => pathToFileURL(join(install, pkg, 'lib/index.js')).href

const { boot, healProfilesModuleFallback, loadLayeredEnv, loadProfile } =
  await import(lib('packages/boot/app-boot'))
const { provideCmdline } = await import(lib('packages/boot/cmdline'))
const { DSH_LAUNCH_ENVIRONMENT_KEY } =
  await import(lib('packages/util/launch-environment'))

healProfilesModuleFallback(installAnchor, home)
const profile = loadProfile(NAME, name, installAnchor, home)
const rootConfig = join(profile.dir, 'cordis.yml')
const patches = [
  ...profile.layers.flatMap((layer) => layer.patches),
  ...profile.patches,
]
const ctx = await boot(NAME, rootConfig, patches, (hostCtx) => {
  hostCtx.provide(DSH_LAUNCH_ENVIRONMENT_KEY, loadLayeredEnv(NAME))
  provideCmdline(hostCtx, { args, exit: () => {} })
})
await ctx.fiber.dispose()
console.log('CHECK-OK')
// A one-shot surface (headless) may have scheduled a fire-and-forget run
// that outlives the tree; the check is about boot, so exit deterministically
// once boot settled and the tree disposed.
process.exit(0)
