# Xeno Universal Hub v1.0

## How to Use with Xeno Executor

### Method 1: Direct Execution
1. Open Xeno executor
2. Launch any supported Roblox game
3. Paste the contents of `workspace/XenoHub.lua` into Xeno
4. Click Execute
5. Press **RightShift** to toggle the GUI

### Method 2: Using Loader
1. Open Xeno
2. Load the `workspace/XenoHub_Loader.lua` file
3. It will automatically detect and run the hub

### Method 3: One-Liner Load
Paste this into Xeno:
```lua
loadstring(game:HttpGet("https://pastebin.com/raw/..."))()
```
(Replace with your hosted pastebin/GitHub raw URL)

## Supported Games & Features

| Game | Features |
|------|----------|
| **Murder Mystery 2** | ESP, Aimbot, Auto-Shoot, Auto-Attack, Wallbang, Reveal Roles, Auto-Grab Gun |
| **Jailbreak** | Infinite Jump, No Fall, Car Speed Boost, Teleports (Bank/Prison/Jewelry) |
| **Arsenal** | Silent Aim, No Recoil, ESP, Big Hitbox, Auto-Fire |
| **Blox Fruits** | Auto Farm, Auto Chest, Teleport to Islands, Auto Farm Level |
| **Doors** | No Darkness, No Monsters, Instant Open Doors |
| **Pet Simulator 99** | Auto Tap, Auto Open, Auto Chest |
| **Tower Defense Sim** | Auto Place, Auto Sell, Auto Skip Waves |
| **Bedwars** | Auto Spawn, No Fall, Fly |

## Universal Features (All Games)

### Combat
- Aimbot (mouse/cframe)
- Silent Aim
- Triggerbot
- Wallbang

### Movement
- Fly (Space=Up, Shift=Down)
- Noclip
- Infinite Jump
- Walk Speed / Jump Power sliders
- No Fall Damage

### Visual
- ESP (Highlight all players)
- Fullbright
- X-Ray
- FOV slider
- FPS Counter

## Controls
- **RightShift** - Toggle GUI
- **Hold Space** (while flying) - Fly Up
- **Hold Shift** (while flying) - Fly Down
- **X** - Close GUI

## Notes
- Some features require `getrawmetatable` which may not work on all executors
- The hub auto-detects which game you're in and shows relevant tabs
- All features are toggleable - click ON/OFF buttons to enable/disable

## File Structure
- `workspace/XenoHub.lua` - Main hub script
- `workspace/XenoHub_Loader.lua` - Quick loader script
- Place in Xeno's `workspace` folder for easy access via File > Open

## Disclaimer
This is for educational purposes. Use at your own risk. Account bans are possible if used in public servers. Use on alt accounts.