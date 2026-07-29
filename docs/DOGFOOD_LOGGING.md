# Dogfood Install and Logging

Install unstripped `ReleaseFast` binaries plus local logging launchers:

```sh
./scripts/install_dogfood.sh
```

Default prefix: `~/.local`.

Installed commands:

```text
~/.local/bin/noctty
~/.local/bin/nocted
```

The commands and installed desktop entries run the staged binaries from:

```text
~/.local/libexec/noctty-dogfood/noctty-bin
~/.local/libexec/noctty-dogfood/nocted-bin
```

Override the default optimization mode when debugging a local issue:

```sh
NOCTTY_DOGFOOD_OPTIMIZE=Debug ./scripts/install_dogfood.sh
```

## Logs

Every launcher invocation records command arguments, session/backend context,
stdout, stderr, GTK/GLib debug messages, timestamp, and exit status under:

```text
~/.local/state/noctty/logs/
```

Follow current logs:

```sh
tail -F ~/.local/state/noctty/logs/*.log
```

The launcher retains the newest 20 logs per app. It enables core dumps when the
session permits them; systemd-managed crash details can then be inspected with:

```sh
coredumpctl info noctty-bin
coredumpctl info nocted-bin
```

No logs are uploaded. Logging is local only and adds no telemetry or network
behavior.

When **Open NoctEd Here** starts NoctEd, the sibling installed launcher is used,
so that editor process receives its own `nocted-*.log` file.
