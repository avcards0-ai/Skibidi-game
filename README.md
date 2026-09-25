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
| `src/server/MapBuilder.server.luau` | Builds the bathroom map | **Script** named `MapBuilder` in `ServerScriptService` |
| `src/client/GameClient.client.luau` | The on-screen UI | **LocalScript** named `GameClient` in `StarterPlayer > StarterPlayerScripts` |

The scripts build everything else themselves: the plunger tool, the map and all the UI.

## Getting it into Roblox Studio

### Option A: copy and paste (easiest)

1. Open a new **Baseplate** place in Roblox Studio.
2. In the Explorer, right-click **ReplicatedStorage** → Insert Object → **Folder**. Name it `Shared`.
3. Inside `Shared`, insert two **ModuleScripts** named `Config` and `Format`. Paste in the matching files.
4. In **ServerScriptService**, insert a **Script** named `GameServer`. Paste in `GameServer.server.luau`.
   Add a second **Script** named `MapBuilder` there too, and paste in `MapBuilder.server.luau`.
5. In **StarterPlayer > StarterPlayerScripts**, insert a **LocalScript** named `GameClient`. Paste in `GameClient.client.luau`.
6. Press **Play**.

The names matter: the scripts look for `Shared`, `Config` and `Format` by name.

**Copying tip:** on GitHub, open a file and click **Raw**. Then press **Ctrl+A** and **Ctrl+C** to copy the whole thing. In Studio, delete the starter code in the script and press **Ctrl+V**.

If something is set up wrong, a red **SETUP PROBLEM** message appears on screen when you press Play and tells you what to fix.

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
- **The map:** MapBuilder builds a giant bathroom each time the game starts: a sell drain in front of spawn, the Plunger Shop on the left, the Rebirth toilet on the right, plus bobbing skibidi toilets, toilet paper towers, a bathtub, a sink and more. Walk up to the shop counter or the rebirth toilet and press **E** to open that menu.
- **Editing the map by hand:** press **Play**, find `Map` in Workspace in the Explorer, right-click it and choose **Copy**. Press **Stop**, then right-click **Workspace** and choose **Paste Into**. Now the map is saved in your place and you can move things around. MapBuilder skips building when a `Map` is already there.
- **Sell pad:** GameServer sells Flushes when a player touches any part named `SellPad`. The map has one; without the map, a plain green pad appears in front of spawn.
- **Starting over:** change `Config.DataStoreName` to wipe everyone's progress (handy while testing).

## Ideas for what to add next

- Pets (Cameraman, Speakerman, TV Man) that multiply your Flushes
- New worlds or zones that unlock with coins or rebirths
- Skibidi toilet enemies or bosses you plunge for big rewards
- Game passes (2x Flushes, auto-clicker, bigger tank)
- A global leaderboard for most Rebirths
