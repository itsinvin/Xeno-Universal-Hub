# Xeno Universal Hub v2.0

A universal Roblox script hub for Xeno executor, inspired by Infinite Yield FE. Features a GUI with tabbed interface + command bar system (IY-style `;command` syntax).

## Features

### Universal (all games)
- **Movement**: Fly, Noclip, Infinite Jump, Walkspeed/Jump/Gravity sliders, Spin, Anti-Void
- **Teleport**: Goto, Tween Goto, TP to coords, Waypoints (save/load), Look At, Bring Player
- **Combat**: Fling, Anti-Fling, Kill All, Hitbox expand, Freeze/Thaw players, handlekill
- **Visual**: ESP, X-Ray, Fullbright, FOV slider, Freecam (WASD), Day/Night, No Fog
- **Player**: Invisible, God Mode, Reset, Sit, Block Head, Remove Face/Arms/Legs, Head Size
- **Chat**: Send message, Spam, Chat Flood, Fake Shutdown
- **Server**: Rejoin, Server Hop, Anti-AFK, Server Info, FPS Counter, Ping
- **Troll**: Explode, Forcefield, Loop Oof, Kill All, Freeze, Unanchor parts, Delete parts
- **Tools**: BTools, DEX Explorer, Console

### Game-Specific
- **Murder Mystery 2**: Reveal Roles, Auto-Shoot (Sheriff), Auto-Attack (Murderer), Role ESP
- **Jailbreak**: TP to Bank/Prison/Jewelry
- *(More game modules coming soon)*

### Command System
- Type `;command` in the command bar (e.g., `;fly`, `;goto bob`, `;speed 50`)
- **Player selectors**: `all`, `others`, `me`, `nearest`, `farthest`, `%team`, `alive`, `dead`, `random`, `#3`, `group:12345`, `-exclude`
- **Multi-command**: `;fly\speed 100` (separate with `\`)
- **Command looping**: `;5^0.5^spam hello` or `;inf^1^killall`
- **Command history**: Press Up/Down arrows in command bar

## Usage

1. Open Xeno executor
2. Go to File > Open > `workspace/XenoHub.lua`
3. Click Execute
4. Press **RightShift** to toggle GUI
5. Click buttons or type `;command` in the command bar

## Files

| File | Description |
|------|-------------|
| `workspace/XenoHub.lua` | Main hub script (~1650 lines) |
| `workspace/XenoHub_Loader.lua` | Quick loader script |
| `workspace/README_XenoHub.txt` | Quick usage guide |

## Commands Reference

```
;fly [speed]         ;unfly            ;noclip
;speed [num]         ;jumppower [num]  ;gravity [num]
;infinitejump         ;antivoid         ;spin [speed]
;goto [player]       ;tweengoto [p]    ;tppos X Y Z
;offset X Y Z         ;waypoint [name]  ;notifyposition [p]
;lookat [player]      ;unlookat         ;clientbring [p]
;reset                ;sit              ;god
;invisible            ;headsize [num]  ;noface
;noarms               ;nolegs           ;blockhead
;esp                  ;xray             ;fullbright
;fov [num]            ;freecam          ;day / night
;nofog                ;ambient R G B    ;hitbox [p] [size]
;fling                ;antifling        ;handlekill [p]
;killall              ;freeze [p]        ;thaw [p]
;explode              ;loopoof          ;forcefield [p]
;fakeshutdown         ;unanchor [radius]  ;delete [name]
;deleteclass [class]  ;removeterrain    ;btools
;chat [text]          ;spam [text]      ;unspam
;rejoin               ;serverhop        ;antiafk
;serverinfo           ;jobid             ;ping
;fps                  ;exit               ;togglefullscreen
;notify [text]        ;hidehub           ;console
```

## Credits

- Infinite Yield FE (Edge, Zwolf, Moon, Toon, Peyton, ATP) — command system inspiration
- Xeno executor — execution environment

## Disclaimers

- For educational purposes only
- Use at your own risk — account bans are possible on public servers
- Some features require `getrawmetatable` — may not work on all executors
- Recommended to use on alt accounts