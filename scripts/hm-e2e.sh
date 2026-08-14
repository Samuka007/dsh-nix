#!/usr/bin/env bash
# Home Manager module end-to-end: evaluate the module, run its activation
# script against a temp HOME, boot the materialised profile with the packaged
# dsh, and assert the fixture plugin's activation + disposal markers.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
timeout_seconds=${DSH_HM_E2E_TIMEOUT_SECONDS:-30}

home=$(mktemp -d)
child=''
stderr_file="$home/stderr"

cleanup() {
  if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
    kill "$child" 2>/dev/null || true
  fi
  rm -rf "$home"
}
trap cleanup EXIT INT TERM

activation=$(nix-instantiate --eval --raw \
  --arg pkgs '(import <nixpkgs> {})' \
  tests/hm-activation.nix -A activation)
drv=$(nix-instantiate --arg pkgs '(import <nixpkgs> {})' \
  tests/hm-activation.nix -A artifact | tail -1)
nix-store -r "$drv" >/dev/null

printf '%s\n' "$activation" >"$home/activate.sh"
HOME="$home" bash "$home/activate.sh"
test -f "$home/.dsh/profiles/agent/package.json"
test -f "$home/.dsh/profiles/agent/.dsh-nix-stamp"
# Idempotence: a second activation changes nothing.
HOME="$home" bash "$home/activate.sh"

dsh_artifact=$(nix build --no-link --print-out-paths ".#packages.x86_64-linux.dsh")
marker_file="$home/.dsh/tui-fixture-lifecycle.log"

(cd "$home" && exec env HOME="$home" "$dsh_artifact/bin/dsh" --profile agent \
  >"$home/stdout" 2>"$stderr_file") &
child=$!

expected_file="$home/expected"
printf 'activated\n' >"$expected_file"
deadline=$((SECONDS + timeout_seconds))
while ! cmp -s "$expected_file" "$marker_file" 2>/dev/null; do
  if ! kill -0 "$child" 2>/dev/null; then
    set +e
    wait "$child"
    status=$?
    set -e
    child=''
    printf 'hm e2e: dsh exited before activation (status %s)\n' "$status" >&2
    cat "$stderr_file" >&2
    exit 1
  fi
  if (( SECONDS >= deadline )); then
    printf 'hm e2e: timed out waiting for activation\n' >&2
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
  printf 'hm e2e: dsh exited with status %s after SIGTERM\n' "$status" >&2
  cat "$stderr_file" >&2
  exit 1
fi

printf 'activated\ndisposed\n' >"$expected_file"
if ! cmp -s "$expected_file" "$marker_file"; then
  printf 'hm e2e: lifecycle marker mismatch; observed:\n' >&2
  cat "$marker_file" >&2 || true
  exit 1
fi

printf 'hm e2e: passed\n'
