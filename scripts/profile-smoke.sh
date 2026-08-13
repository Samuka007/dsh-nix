#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DSH_REPO=${DSH_REPO:-"$repo_root/dsh"}
timeout_seconds=${DSH_PROFILE_SMOKE_TIMEOUT_SECONDS:-20}

if [[ ! -f "$DSH_REPO/apps/cli/package.json" ]]; then
  printf 'profile smoke: DSH_REPO must contain apps/cli/package.json: %s\n' "$DSH_REPO" >&2
  exit 2
fi

if [[ -f "$DSH_REPO/apps/cli/lib/bin.js" ]]; then
  dsh_command=(node --expose-internals apps/cli/lib/bin.js)
elif [[ -d "$DSH_REPO/node_modules/tsx" ]]; then
  dsh_command=(node --expose-internals --import tsx/esm apps/cli/src/bin.ts)
else
  printf 'profile smoke: DSH CLI is not built and node_modules/tsx is absent; run pnpm install in %s\n' "$DSH_REPO" >&2
  exit 2
fi

home=$(mktemp -d)
child=''
stdout_file="$home/stdout"
stderr_file="$home/stderr"
marker_file="$home/tui-fixture-lifecycle.log"
expected_file="$home/expected"

cleanup() {
  if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
    kill "$child" 2>/dev/null || true
  fi
  rm -rf "$home"
}
trap cleanup EXIT INT TERM

artifact=$(nix build --print-out-paths ".#packages.x86_64-linux.tui")
mkdir -p "$home/profiles"
cp -a "$artifact" "$home/profiles/tui"
chmod -R u+w "$home/profiles/tui"

(
  cd "$DSH_REPO"
  exec env DSH_HOME="$home" "${dsh_command[@]}" --profile tui
) >"$stdout_file" 2>"$stderr_file" &
child=$!

printf 'activated\n' >"$expected_file"
deadline=$((SECONDS + timeout_seconds))
while ! cmp -s "$expected_file" "$marker_file" 2>/dev/null; do
  if ! kill -0 "$child" 2>/dev/null; then
    set +e
    wait "$child"
    status=$?
    set -e
    child=''
    printf 'profile smoke: DSH exited before activation (status %s)\n' "$status" >&2
    cat "$stderr_file" >&2
    exit 1
  fi
  if (( SECONDS >= deadline )); then
    printf 'profile smoke: timed out waiting for activation after %s seconds\n' "$timeout_seconds" >&2
    cat "$stderr_file" >&2
    exit 1
  fi
  sleep 0.1
done

kill -TERM "$child"
set +e
wait "$child"
status=$?
set -e
child=''
if (( status != 0 )); then
  printf 'profile smoke: DSH exited after SIGTERM with status %s\n' "$status" >&2
  cat "$stderr_file" >&2
  exit 1
fi

printf 'activated\ndisposed\n' >"$expected_file"
if ! cmp -s "$expected_file" "$marker_file"; then
  printf 'profile smoke: lifecycle marker mismatch; observed content follows:\n' >&2
  if [[ -e "$marker_file" ]]; then
    cat "$marker_file" >&2
  else
    printf '<missing>\n' >&2
  fi
  exit 1
fi

printf 'profile smoke: passed\n'
