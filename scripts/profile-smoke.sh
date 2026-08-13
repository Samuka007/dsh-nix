#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
timeout_seconds=${DSH_PROFILE_SMOKE_TIMEOUT_SECONDS:-20}
profile_name=${DSH_PROFILE_SMOKE_PROFILE:-tui}

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

if ! dsh_artifact=$(nix build --no-link --print-out-paths ".#packages.x86_64-linux.dsh"); then
  printf 'profile smoke: nix build failed for packaged dsh\n' >&2
  exit 2
fi
if ! artifact=$(nix build --no-link --print-out-paths ".#packages.x86_64-linux.$profile_name"); then
  printf 'profile smoke: nix build failed for %s profile\n' "$profile_name" >&2
  exit 2
fi
mkdir -p "$home/profiles"
cp -a "$artifact" "$home/profiles/$profile_name"
chmod -R u+w "$home/profiles/$profile_name"

env DSH_HOME="$home" "$dsh_artifact/bin/dsh" --profile "$profile_name" >"$stdout_file" 2>"$stderr_file" &
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
