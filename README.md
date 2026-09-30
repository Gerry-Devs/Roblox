# Monster RNG

Scripts for the Monster RNG Roblox game, synced into Roblox Studio with [Rojo](https://rojo.space) 7.7.0.

## What Rojo manages

Only the scripts listed in `default.project.json` are synced. Maps, monster rigs/models,
UI frames, ServerStorage and everything else stay as they are in the place file.

| Folder in this repo | Location in Studio |
|---|---|
| `src/ReplicatedFirst` | ReplicatedFirst |
| `src/ReplicatedStorage/MonsterRNG` | ReplicatedStorage > MonsterRNG (modules only; rigs and ClientBridge are left alone) |
| `src/ServerScriptService` | ServerScriptService |
| `src/StarterGui/<ScreenGui>` | The controller scripts inside each ScreenGui (UI frames are left alone) |
| `src/StarterPlayerScripts` | StarterPlayer > StarterPlayerScripts |

File names decide the script type: `Name.server.luau` = Script, `Name.client.luau` = LocalScript,
`Name.luau` = ModuleScript.

## Workflow

1. Pull the latest changes (GitHub Desktop: Fetch origin, then Pull).
2. In VS Code, open the Rojo menu and click `default.project.json` to start syncing.
3. In Studio: Plugins > Rojo > Connect. Check the Confirm sync list, then Accept.
4. Test, then publish the game from Studio as usual.

Edit synced scripts in these files, not in Studio. Studio edits to synced scripts are overwritten
on the next sync.
