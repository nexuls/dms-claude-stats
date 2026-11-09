# Claude Stats

A DMS bar widget for Claude Code. It shows your subscription's rate limits, token use and
estimated cost, and tells you live when Claude is working or waiting for your answer.

Based on [dms-claudecode](https://github.com/titeya/dms-claudecode) by Nicolas Bellamy, with a
Material 3 redesign, layout options and live session activity. It has its own plugin id
(`claudeStats`), so it can be installed next to the original.

## Features

- **Bar icon** with the 5-hour rate limit as a ring, in one of four styles:
  ring and percentage, ring only, nested 5-hour and 7-day rings, or percentages only.
- **Live activity** from Claude Code hooks: a sweep circles the ring while Claude works, and a
  red dot pulses when it asks a question, wants a plan approved, or needs a permission.
- **Popout** built from the shell's Material widgets:
  - Active sessions by project folder: working, needs your input, or done
  - 5-hour and 7-day rate windows with reset countdown and pace ("6% over pace")
  - Tokens and estimated cost for today, this week and this month
  - Daily activity chart for the week; hover a day for its tokens and cost
  - Models used this week as a share bar
  - Refresh and settings buttons in the header
- **Two layouts**: *Compact*, or *Detailed* at the same size with more numbers: reset clock
  times, projected usage at reset, daily averages, per-day totals, model shares and all-time stats.
- **Profiles**: per-profile stats with filter chips. Detected from `~/.claude`,
  [CCS](https://github.com/kaitranntt/ccs) instances in `~/.ccs/instances/`,
  [claude-code-profiles](https://github.com/felipeadeildo/claude-code-profiles) in `~/.ccp/profiles/*.env`,
  and any directory you add under **Custom Profiles**.
- **Pricing** from [LiteLLM](https://github.com/BerriAI/litellm), so new model families need no code
  change. Costs are in EUR for French, USD otherwise (rate from the ECB via [Frankfurter](https://www.frankfurter.app/)).
- English, French and Spanish.

## Requirements

- DMS shell
- `jq`, `curl` and `flock` (util-linux)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) signed in through the CLI

## Installation

Link the plugin into your DMS plugins directory, then restart DMS and enable **Claude Stats**
in Settings > Plugins:

```bash
ln -s "$PWD/quickshell/dms-plugins/claude-stats" ~/.config/DankMaterialShell/plugins/claude-stats
```

### Live activity hooks

Live activity needs `claude-activity-hook` registered in `~/.claude/settings.json`. Add this
block, merging it with any `hooks` you already have, then start a new Claude Code session:

```json
"hooks": {
  "SessionStart":      [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }],
  "UserPromptSubmit":  [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }],
  "PreToolUse":        [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }],
  "PermissionRequest": [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }],
  "PostToolUse":       [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }],
  "Notification":      [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }],
  "Stop":              [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }],
  "SessionEnd":        [{ "hooks": [{ "type": "command", "command": "bash ~/.config/DankMaterialShell/plugins/claude-stats/claude-activity-hook" }] }]
}
```

Adjust the path if the plugin lives elsewhere, and repeat for each `CLAUDE_CONFIG_DIR` profile
you use. To check it works, send a prompt and run `cat $XDG_RUNTIME_DIR/claude-stats.json`: your
session should show as `working`.

| Bar icon | Meaning |
|----------|---------|
| A sweep circling the ring | Claude is working |
| Pulsing red dot after a red percentage | Claude is waiting for you: a question, a plan to approve, or a permission prompt |
| Plain ring | Idle or finished; the popout lists finished sessions as Done |

In the percentages-only style, a pulsing dot stands in for the sweep.

## Configuration

Settings > Plugins > Claude Stats, or the gear button in the popout:

| Setting | Options |
|---------|---------|
| Refresh interval | 2 to 15 minutes |
| Show pacing | Pace labels and the pace tick on the rings |
| Show Claude activity | Live activity in the bar and popout |
| Bar style | Ring and percentage, ring only, 5-hour and 7-day rings, percentages only |
| Popout layout | Compact or Detailed |
| Custom Profiles | Extra Claude config directories to track |

### Custom profiles

Add a name and a `CLAUDE_CONFIG_DIR`, the folder that contains `projects/` (what `~/.claude` is
for the default profile):

| Name | Config directory |
|------|------------------|
| `work` | `~/.ccp/data/work` |

The plugin reads usage from `<path>/projects/` and, when present, rate limits through
`<path>/.credentials.json`. Entries without a `projects/` folder are ignored, and a name already
taken by a detected profile is skipped.

## How it works

**Usage** comes from `get-claude-usage`, run at the refresh interval or from the refresh button:

1. Reads the OAuth token from `<config dir>/.credentials.json`
2. Asks the Anthropic usage API for the rate limit windows, cached for 2 minutes in `~/.claude/usage-cache.json`
3. Scans `<config dir>/projects/` of every profile, in parallel, for tokens, sessions and models
4. Fetches model pricing and the USD/EUR rate once a day, cached in `~/.claude/pricing-cache.json`

The cache is shared with the original plugin when both are installed.

**Live activity** comes from `claude-activity-hook`. Claude Code runs it on each hook event, and it
records each session's state in `$XDG_RUNTIME_DIR/claude-stats.json`, writing only when a state
changes. The widget watches that file, so nothing polls while Claude is idle. Sessions whose
Claude process has exited are dropped within a minute.

Pressing Esc to interrupt Claude sends no hook event, so that session shows as working until
your next prompt.

### Sign-in status

Rate limits use the Claude Code **CLI** login. The plugin only reads the credentials file and
never refreshes the token; the CLI renews it whenever it runs. When the rate limit data can't be
trusted, the popout shows a notice, dims the rings and the bar icon, and keeps the last known values:

| Notice | Meaning |
|--------|---------|
| No Claude Code CLI login found | The profile has no `.credentials.json`. Run `claude /login`. |
| Claude Code login expired | The token was rejected or is past its expiry. Run `claude` once to refresh it. |
| The usage API is rate limiting requests | The API answered HTTP 429. It recovers on its own. |
| Could not reach the usage API | Network error or an unexpected response. |

Tokens, costs and models come from local session logs and keep working in every case.

All data stays on your machine. Network requests go only to the Anthropic usage API, GitHub
(LiteLLM pricing, once a day) and Frankfurter (exchange rate, once a day).

## Tests

```bash
for t in tests/test-*.sh; do bash "$t"; done
```

## License

[MIT](LICENSE). Original work © Nicolas Bellamy.
