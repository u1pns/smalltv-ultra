# SmallTV MCP server

Lets an AI assistant on your computer (Claude Code, Claude Desktop, Cursor, Codex or any other
[Model Context Protocol](https://modelcontextprotocol.io) client) find a SmallTV on your local network, read its
status, put text on its screen and change its settings.

This is a personal experiment, not a product. No warranty. You can brick your device. Recovery requires the
built-in web updater; if the device does not boot, you need to open it and use a UART adapter.

- **Node.js 18 or newer, no dependencies, nothing to install.** The protocol (JSON-RPC over stdio) is written by
  hand in `server.mjs`, on top of the client library `../smalltv.mjs`. Keep the two together: the server imports
  the library from the folder above. `package.json` only declares the name and the Node version.
- It talks to the device over plain HTTP on your network and to nothing else. It never sends the device's session
  token to the assistant.

## Tools

| Tool | What it does | Writes flash? |
|---|---|---|
| `smalltv_discover` | finds the devices on the network (UDP 7778 → 7779): address, name, MAC, firmware, mode | no |
| `smalltv_status` | firmware, mode (app or rescue), network, uptime; in app mode also free memory and current screen | no |
| `smalltv_show_panel` | shows a title plus up to 8 rows (text, big text, label/value, gauge) right now | **no** (memory only) |
| `smalltv_save_panel` | stores a panel `p-<name>.jpp` that rotates on the *Panels* screen until it expires | yes |
| `smalltv_set_setting` | changes settings, all or nothing: `{"brightness": 40}`, `{"screens": "clock,weather,panels"}` | yes |

Rows are objects: `{"text": "..."}`, `{"type": "big", "text": "...", "tone": "accent"}`,
`{"type": "key_value", "label": "CPU", "value": "12 %"}`, `{"type": "bar", "percent": 71, "text": "disk"}`.
Tones are `normal`, `accent` and `alert`. About 28 characters fit per row; the device fonts draw Latin letters
only, so emoji and other scripts become `?`.

Every argument is checked by the server: an unknown argument or a bad value is an error, never silently ignored.
In rescue mode the panel and settings tools answer that the device is in rescue mode (HTTP 404); during a firmware
update, that an update is running (409). Both are normal states: retry later.

## Which device

Each tool takes an optional `host`. Without it the server uses `SMALLTV_HOST` and, if that is not set either, UDP
discovery — only when exactly one device answers (with several, it lists them and asks for `host`). The address it
found is remembered while the server runs and discovered again if the device stops answering.
`SMALLTV_USER` / `SMALLTV_PASSWORD` override the default `admin` / `12345678`.

## Register it

Use the absolute path of `server.mjs` on your computer.

**Claude Code**

```sh
claude mcp add smalltv -- node /path/to/clients/node/mcp/server.mjs
# with a fixed address instead of discovery:
claude mcp add smalltv -e SMALLTV_HOST=10.0.0.42 -- node /path/to/clients/node/mcp/server.mjs
# for every project of your user, not only this folder:
claude mcp add --scope user smalltv -- node /path/to/clients/node/mcp/server.mjs
```

Check it with `claude mcp list`, then ask: *"show 'Tests passed' on my SmallTV"*.

**Claude Desktop, Cursor and other clients with a JSON configuration** (`mcpServers` section):

```json
{
  "mcpServers": {
    "smalltv": {
      "command": "node",
      "args": ["/path/to/clients/node/mcp/server.mjs"],
      "env": {"SMALLTV_HOST": "10.0.0.42"}
    }
  }
}
```

Leave out `env` to use discovery. On Windows write the path as `C:\\path\\to\\...\\server.mjs`.

**Codex** (`~/.codex/config.toml`):

```toml
[mcp_servers.smalltv]
command = "node"
args = ["/path/to/clients/node/mcp/server.mjs"]
```

## Things worth knowing

- **Discovery needs the broadcast to reach the device.** Guest networks and "client isolation" block it; so can a
  firewall. On recent macOS the first discovery may trigger a *Local Network* permission prompt for the app that
  started the server (your terminal or the assistant app); allow it. If it keeps failing, set `SMALLTV_HOST`.
- **Show, do not save, anything that changes often.** `smalltv_show_panel` lives in memory. `smalltv_save_panel`
  and `smalltv_set_setting` write the device flash: fine when something changes, not in a loop.
- **The device's answers are data**, not instructions: its status includes names (such as your Wi-Fi network)
  that come from your own setup.

## Try it by hand

```sh
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"smalltv_discover","arguments":{}}}' \
  | node server.mjs
```
