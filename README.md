# Skibidi Simulator

A Roblox clicker simulator:

1. **Click** with your plunger to collect **Flushes** 🚽.
2. When your tank is full, walk onto the green **SELL** pad to turn Flushes into **Coins** 💰.
3. Spend coins in the **Shop** on better plungers (more Flushes per click) and bigger tanks (hold more).
4. Once you're rich, **Rebirth** ⭐: reset your coins and upgrades for a permanent Flush multiplier.

Progress saves automatically.

## Files

| File | What it is | Where it goes in Roblox Studio |
| --- | --- | --- |
| `src/shared/Config.luau` | All the game's numbers: prices, upgrades, rebirth cost | **ModuleScript** named `Config` in `ReplicatedStorage > Shared` |
| `src/shared/Format.luau` | Turns `1500` into `1.5K` | **ModuleScript** named `Format` in `ReplicatedStorage > Shared` |
| `src/server/GameServer.server.luau` | Saving, clicking, selling, shop, rebirths | **Script** named `GameServer` in `ServerScriptService` |
| `src/client/GameClient.client.luau` | The on-screen UI | **LocalScript** named `GameClient` in `StarterPlayer > StarterPlayerScripts` |

The scripts build everything else themselves: the plunger tool, the sell pad and all the UI.

## Getting it into Roblox Studio

### Option A: copy and paste (easiest)

1. Open a new **Baseplate** place in Roblox Studio.
2. In the Explorer, right-click **ReplicatedStorage** → Insert Object → **Folder**. Name it `Shared`.
3. Inside `Shared`, insert two **ModuleScripts** named `Config` and `Format`. Paste in the matching files.
4. In **ServerScriptService**, insert a **Script** named `GameServer`. Paste in `GameServer.server.luau`.
5. In **StarterPlayer > StarterPlayerScripts**, insert a **LocalScript** named `GameClient`. Paste in `GameClient.client.luau`.
6. Press **Play**.

The names matter: the scripts look for `Shared`, `Config` and `Format` by name.

### Option B: Rojo (syncs these files into Studio automatically)

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/): the Studio plugin, plus the command-line tool or the VS Code extension.
2. In this folder, run `rojo serve`.
3. In Studio, open the Rojo plugin and click **Connect**. When you edit a file here, it updates in Studio right away.

## Saving

Saving uses DataStores, which only work in a **published** game:

1. **File → Publish to Roblox**.
2. **Game Settings → Security →** turn on **Enable Studio Access to API Services** (only needed for testing saves in Studio).

Without these, the game still works, it just won't remember progress.

## Customizing

- **Prices, upgrades, rebirths:** edit `src/shared/Config.luau`. To add a new plunger or tank, add a line to the list and the shop shows it automatically.
- **Sell pad:** by default a green pad appears 30 studs in front of spawn. To use your own, put a Part named `SellPad` in Workspace and the script uses that instead.
- **Starting over:** change `Config.DataStoreName` to wipe everyone's progress (handy while testing).

## Ideas for what to add next

- Pets (Cameraman, Speakerman, TV Man) that multiply your Flushes
- New worlds or zones that unlock with coins or rebirths
- Skibidi toilet enemies or bosses you plunge for big rewards
- Game passes (2x Flushes, auto-clicker, bigger tank)
- A global leaderboard for most Rebirths
