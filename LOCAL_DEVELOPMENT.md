# Local pi-ui workflow

`sunithv/custom` is the only branch for personal changes. `origin` is your
fork; `upstream` is `hyperpuncher/pi-ui`. Do not edit the Homebrew-installed
`/Applications/pi-ui.app`—it remains a fallback and Homebrew owns it.

## Make a customization

1. Work in this checkout on `sunithv/custom`.
2. Validate it with `deno task css:build && deno task fmt && deno task lint && deno task check`.
3. Commit and push it: `git add -A && git commit -m "..." && git push`.

Committed customizations are the update boundary. The automatic updater will
never touch uncommitted files. If it finds any, encounters a replay conflict,
or cannot build, it keeps the last good `Pi UI Local.app` and sends the macOS
notification `error`.

## Automatic updates

`~/Library/LaunchAgents/dev.pi-ui.local-update.plist` runs
`scripts/update-local.sh` at login and every six hours. The script fetches
`upstream/main`, creates a disposable worktree, replays your custom commits,
then replaces the local app only after a full successful build.

To update immediately:

```sh
~/Developer/pi-ui/scripts/update-local.sh
```

Logs are in `~/Library/Logs/pi-ui-local/update.log`. The built app is
`~/Applications/Pi UI Local.app`.
