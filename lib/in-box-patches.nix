# Ordered patch-entry data for the in-box dsh bundles, extracted verbatim from
# the pinned dsh source (packages/bundle/<name>/cordis.patch.yml) — NOT
# hand-written.  Each entry is one loader patch in file order:
#
#   { kind = "override"; id = "system-prompt"; }   a top-level row: replaces
#     (or disables) the row with that id in the composed tree
#   { kind = "insert"; id = "timer"; }             a row inside an `insert`
#     block: defines a new row with that id
#
# dsh's applyEntryPatches (packages/include/src/index.ts) skips an override
# whose id is not already in the tree with a warning — a silent no-op.  The
# build-time check in lib/profiles.nix replays this exact semantics: an
# override must be preceded by a definition of its id in an earlier layer,
# otherwise the profile would boot with that patch silently dropped.
#
# Regenerate with the drift check in flake.nix (checks.in-box-patches-drift),
# which re-extracts from the dsh input and diffs against this file.
{
  inBoxPatchEntries = {
  "@deepseek-ai/dsh-base" = [
    { kind = "insert"; id = "timer"; }
    { kind = "insert"; id = "hmr"; }
    { kind = "insert"; id = "llm"; }
    { kind = "insert"; id = "session"; }
    { kind = "insert"; id = "typert"; }
    { kind = "insert"; id = "typert-loader"; }
    { kind = "insert"; id = "typert-gateway"; }
    { kind = "insert"; id = "session-title"; }
    { kind = "insert"; id = "session-title-llm"; }
    { kind = "insert"; id = "user-questions"; }
    { kind = "insert"; id = "agent"; }
    { kind = "insert"; id = "agent-default-model"; }
    { kind = "insert"; id = "jobs"; }
    { kind = "insert"; id = "llm-retry"; }
    { kind = "insert"; id = "settings"; }
    { kind = "insert"; id = "credentials"; }
    { kind = "insert"; id = "llm-pi-ai"; }
    { kind = "insert"; id = "session-persistence-jsonl"; }
    { kind = "insert"; id = "attachment-local"; }
    { kind = "insert"; id = "session-query-sqlite"; }
    { kind = "insert"; id = "session-projection"; }
    { kind = "insert"; id = "session-telemetry-otel"; }
    { kind = "insert"; id = "subprocess"; }
    { kind = "insert"; id = "sandbox"; }
    { kind = "insert"; id = "sandbox-policy"; }
    { kind = "insert"; id = "bash-sandbox"; }
    { kind = "insert"; id = "pwsh-sandbox"; }
    { kind = "insert"; id = "approval"; }
    { kind = "insert"; id = "permission"; }
    { kind = "insert"; id = "shell-env"; }
    { kind = "insert"; id = "tool-bash"; }
    { kind = "insert"; id = "tool-pwsh"; }
    { kind = "insert"; id = "tool-jobs"; }
    { kind = "insert"; id = "fs-observation-policy"; }
    { kind = "insert"; id = "tool-fs"; }
    { kind = "insert"; id = "tool-fs-search"; }
    { kind = "insert"; id = "agent-instructions"; }
    { kind = "insert"; id = "skill"; }
    { kind = "insert"; id = "skill-filesystem"; }
    { kind = "insert"; id = "skill-badge"; }
    { kind = "insert"; id = "tool-skill"; }
    { kind = "insert"; id = "commands"; }
    { kind = "insert"; id = "command-feedback"; }
    { kind = "insert"; id = "goal"; }
    { kind = "insert"; id = "goal-round-driver"; }
    { kind = "insert"; id = "command-goal"; }
    { kind = "insert"; id = "plan-mode"; }
    { kind = "insert"; id = "token-meter"; }
    { kind = "insert"; id = "compaction-basic"; }
    { kind = "insert"; id = "command-compact"; }
    { kind = "insert"; id = "subagent"; }
    { kind = "insert"; id = "subagent-spawn-in-process"; }
    { kind = "insert"; id = "subagent-fork-in-process"; }
    { kind = "insert"; id = "tool-subagent-control"; }
    { kind = "insert"; id = "tool-subagent-list-agents"; }
    { kind = "insert"; id = "tool-subagent"; }
    { kind = "insert"; id = "tool-subagent-fork"; }
    { kind = "insert"; id = "tool-subagent-report"; }
    { kind = "insert"; id = "workflow-worker-thread"; }
    { kind = "insert"; id = "tool-workflow"; }
    { kind = "insert"; id = "timeout-policy"; }
    { kind = "insert"; id = "spill-local"; }
    { kind = "insert"; id = "spill-policy"; }
    { kind = "insert"; id = "session-checkpoint-policy"; }
    { kind = "insert"; id = "tool-result-pruner"; }
    { kind = "insert"; id = "tool-todo"; }
    { kind = "insert"; id = "tool-goal"; }
    { kind = "insert"; id = "tool-ralph"; }
    { kind = "insert"; id = "tool-str-replace-editor"; }
    { kind = "insert"; id = "repeat-tool-reminder"; }
    { kind = "insert"; id = "web"; }
    { kind = "insert"; id = "web-search-deepseek"; }
    { kind = "insert"; id = "tool-web"; }
    { kind = "insert"; id = "tools"; }
    { kind = "insert"; id = "system-prompt"; }
    { kind = "insert"; id = "agent-loop"; }
    { kind = "insert"; id = "fs-sandbox"; }
    { kind = "insert"; id = "llm-deepseek"; }
  ];
  "@deepseek-ai/dsh-web-app" = [
    { kind = "override"; id = "system-prompt"; }
    { kind = "override"; id = "hmr"; }
    { kind = "override"; id = "session-query-sqlite"; }
    { kind = "override"; id = "tools"; }
    { kind = "insert"; id = "code-runtime"; }
    { kind = "insert"; id = "storage"; }
    { kind = "insert"; id = "storage-json"; }
    { kind = "insert"; id = "storage-domain"; }
    { kind = "insert"; id = "message-feedback"; }
    { kind = "insert"; id = "session-log-download"; }
    { kind = "insert"; id = "workspace"; }
    { kind = "insert"; id = "session-projection-cache"; }
    { kind = "insert"; id = "session-stats"; }
    { kind = "insert"; id = "directory-picker"; }
    { kind = "insert"; id = "plugin-inventory"; }
    { kind = "insert"; id = "api-gateway"; }
    { kind = "insert"; id = "cordis-host-runner"; }
    { kind = "insert"; id = "web-startup"; }
    { kind = "insert"; id = "webserver"; }
    { kind = "insert"; id = "web-runtime"; }
    { kind = "insert"; id = "client-hmr"; }
    { kind = "insert"; id = "modules"; }
    { kind = "insert"; id = "connection"; }
    { kind = "insert"; id = "api-remotes"; }
    { kind = "insert"; id = "client-runtime"; }
    { kind = "insert"; id = "cordis-client-runner"; }
    { kind = "insert"; id = "ui-theme"; }
    { kind = "insert"; id = "locale"; }
    { kind = "insert"; id = "ui-layout"; }
    { kind = "insert"; id = "ui-sidebar"; }
    { kind = "insert"; id = "ui-settings"; }
    { kind = "insert"; id = "ui-settings-general"; }
    { kind = "insert"; id = "ui-settings-models"; }
    { kind = "insert"; id = "ui-settings-plugin-inventory"; }
    { kind = "insert"; id = "ui-conversation"; }
    { kind = "insert"; id = "ui-tool"; }
    { kind = "insert"; id = "ui-cordis"; }
    { kind = "insert"; id = "ui-workflow-run"; }
    { kind = "insert"; id = "ui-deliverables"; }
    { kind = "insert"; id = "ui-workspace"; }
    { kind = "insert"; id = "ui-input-trigger"; }
    { kind = "insert"; id = "ui-commands"; }
    { kind = "insert"; id = "ui-skill"; }
    { kind = "insert"; id = "ui-subagent"; }
    { kind = "insert"; id = "ui-jobs"; }
    { kind = "insert"; id = "ui-goal"; }
    { kind = "insert"; id = "ui-message-feedback"; }
    { kind = "insert"; id = "ui-model-selection"; }
    { kind = "insert"; id = "ui-permission"; }
    { kind = "insert"; id = "ui-agent-preset"; }
    { kind = "insert"; id = "ui-settings-plugins"; }
    { kind = "insert"; id = "ui-plan"; }
    { kind = "insert"; id = "ui-user-questions"; }
    { kind = "insert"; id = "ui-trajectory"; }
    { kind = "override"; id = "tool-bash"; }
    { kind = "override"; id = "tool-pwsh"; }
    { kind = "override"; id = "tool-jobs"; }
    { kind = "override"; id = "tool-fs"; }
    { kind = "override"; id = "tool-fs-search"; }
    { kind = "override"; id = "tool-str-replace-editor"; }
    { kind = "override"; id = "skill-filesystem"; }
    { kind = "override"; id = "tool-skill"; }
    { kind = "override"; id = "tool-goal"; }
    { kind = "override"; id = "plan-mode"; }
    { kind = "override"; id = "compaction-basic"; }
    { kind = "override"; id = "command-compact"; }
    { kind = "override"; id = "tool-result-pruner"; }
    { kind = "override"; id = "tool-subagent-control"; }
    { kind = "override"; id = "tool-subagent-list-agents"; }
    { kind = "override"; id = "tool-subagent"; }
    { kind = "override"; id = "tool-subagent-fork"; }
    { kind = "override"; id = "workflow-worker-thread"; }
    { kind = "override"; id = "tool-workflow"; }
    { kind = "override"; id = "tool-ralph"; }
    { kind = "override"; id = "agent-instructions"; }
    { kind = "override"; id = "tool-todo"; }
    { kind = "override"; id = "tool-web"; }
    { kind = "insert"; id = "agent-presets"; }
  ];
  "@deepseek-ai/dsh-headless" = [
    { kind = "override"; id = "system-prompt"; }
    { kind = "override"; id = "hmr"; }
    { kind = "override"; id = "tools"; }
    { kind = "insert"; id = "code-runtime"; }
    { kind = "insert"; id = "headless-startup"; }
    { kind = "insert"; id = "headless-runner"; }
  ];
  };
}
