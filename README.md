# Locu Focus for Omarchy

Focus sessions for Locu from the Omarchy bar. Click the bar widget to open the Today task picker; selecting a task starts a Locu timer for the configured session length. The bar shows the remaining countdown. When the timer ends, Locu Focus stops the timer, plays the selected sound, and sends a desktop notification with **Keep working** and **Take a break** actions. The panel and bar provide a pulsing completion animation.

## Installation

```bash
omarchy plugin add https://github.com/davidsmorais/omarchy-locu --enable
```

Then add your Locu Personal Access Token in the plugin settings (bar widget
settings or the gear icon in the panel) and press Refresh.

## Removal

```bash
omarchy plugin remove david.locu
```

This removes the plugin. Your API token lives in Omarchy's `shell.json`
and is not touched by removal; delete it there if you want it gone.

## Settings

- Locu Personal Access Token
- Session length, in minutes (1–180; default 25)
- Break length (default 5; reserved for the break workflow)
- Completion sound toggle
- Desktop animation toggle

The API token is stored in Omarchy's `shell.json`, which is mode 0600 on this system. It is sent as a Bearer token to `https://api.locu.app/api/v1`.

## API use

This plugin uses the Locu Public API OpenAPI definition:

- `GET /tasks/sections?section=today` to get today's tasks
- `GET /timer` to restore the active timer state
- `POST /timer/start` with `duration` and optional `taskId`
- `POST /timer/stop` when the countdown ends or the user stops the session

Documentation: https://registry.scalar.com/@locu-labs/apis/locu-public-api/latest

## External dependencies

- A Locu account and Personal Access Token (for `https://api.locu.app/api/v1`).
- `notify-send` for the session-complete notification (ships with most desktops).
- Optional: `canberra-gtk-play` or `paplay` for the completion sound; if
  neither is present the session still ends normally, just silently.

## License

MIT — see [LICENSE](LICENSE).
