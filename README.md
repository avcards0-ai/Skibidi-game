# Skibidi Simulator

A Roblox clicker simulator:

1. **Click** with your plunger to collect **Flushes** 🚽.
2. When your tank is full, walk onto the green **SELL** pad to turn Flushes into **Coins** 💰.
3. Spend coins in the **Shop** on better plungers (more Flushes per click) and bigger tanks (hold more).
4. Once you're rich, **Rebirth** ⭐: reset your coins and upgrades for a permanent Flush multiplier.
5. Hatch **eggs** 🥚 at the Egg Hatchery for **pets** 🐾 that follow you around and boost your Flushes.
6. Unlock **the Sewers** ☣️ through the manhole: a world underground where every click gives 2x Flushes.

Progress saves automatically, including your pets.

## Eggs and pets

| Egg | Price | What's inside |
| --- | --- | --- |
| Common Egg | 2.5K | Rubber Ducky 50%, Soap Bunny 35%, Plunger Pup 13%, Cameraman 2% |
| Rare Egg | 5K | Soap Bunny 35%, Plunger Pup 35%, Sewer Rat 25%, Speakerman 5% |
| Epic Egg | 10K | Sewer Rat 40%, Cameraman 35%, Speakerman 20%, TV Man 5% |
| Legendary Egg | 20K | Cameraman 40%, Speakerman 30%, TV Man 25%, Titan Cameraman 5% |

Each pet adds a boost to your Flushes per click: Rubber Ducky +10%, Soap Bunny +15%, Plunger Pup +30%, Sewer Rat +40%, Cameraman +75%, Speakerman +100%, TV Man +200%, Titan Cameraman +400%. You can equip 3 pets at once and hold up to 50. Pets are kept when you rebirth.

## Files

| File | What it is | Where it goes in Roblox Studio |
| --- | --- | --- |
| `src/shared/Config.luau` | All the game's numbers: prices, upgrades, rebirth cost | **ModuleScript** named `Config` in `ReplicatedStorage > Shared` |
| `src/shared/Format.luau` | Turns `1500` into `1.5K` | **ModuleScript** named `Format` in `ReplicatedStorage > Shared` |
| `src/server/GameServer.server.luau` | Saving, clicking, selling, shop, rebirths, eggs, pets, the Sewers | **Script** named `GameServer` in `ServerScriptService` |
| `src/server/MapBuilder.server.luau` | Builds the map | **Script** named `MapBuilder` in `ServerScriptService` |
| `src/client/GameClient.client.luau` | The on-screen UI, egg hatching, pets following players | **LocalScript** named `GameClient` in `StarterPlayer > StarterPlayerScripts` |

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

### Option C: the Update Game button (easiest for updates)

`tools/SkibidiUpdater.luau` is a Studio plugin that adds an **Update Game** button to the **Plugins** tab. Clicking it downloads the newest scripts from this repo and puts each one in the right place with the right name. It also fixes mistakes like a lowercase `shared` folder or a LocalScript where a Script should be. You can undo an update with **Ctrl+Z**.

Install it once:

1. In Studio, insert a **Script** anywhere (ServerStorage is fine) and paste in the code from `tools/SkibidiUpdater.luau`.
2. Right-click the Script → **Save as Local Plugin...** → **Save**.
3. Delete that Script.
4. Open the **Plugins** tab and click **Update Game**. The first time, Studio asks whether the plugin can access the internet. Click **Allow**.

After that, whenever the code on GitHub changes, stop the game and click **Update Game**.

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

- **Prices, upgrades, rebirths, eggs, pets, the Sewers:** edit `src/shared/Config.luau`. To add a new plunger or tank, add a line to the list and the shop shows it automatically. Egg prices and chances, pet boosts, how many pets you can equip, and the Sewers' unlock price and multiplier are all there too.
- **The map:** MapBuilder builds a sunny grass field each time the game starts: a stone plaza with flower planters at spawn, the SELL pad (with its sign on an arch above it) straight ahead, the Egg Hatchery front-left, the manhole down to the Sewers front-right, the Plunger Shop on the left, the Rebirth shrine with a floating crystal on the right, and a pond behind. Oak, pine and birch trees, flower patches, bushes, grass tufts, rocks, lamp posts and grassy hills fill in the rest. It also adds soft haze, glow (Bloom), richer colors and moving clouds, but only if your place doesn't already have its own Atmosphere, Bloom, ColorCorrection or Clouds. Walk up to things and press **E**: the shop counter and rebirth altar open their menus, the glowing egg bases under the PETS sign hatch eggs, and the manhole and the EXIT sign take you down to the Sewers and back.
- **Editing the map by hand:** press **Play**, find `Map` in Workspace in the Explorer, right-click it and choose **Copy**. Press **Stop**, then right-click **Workspace** and choose **Paste Into**. Now the map is saved in your place and you can move things around. MapBuilder skips building when a `Map` is already there. (The hills are Terrain, which MapBuilder only adds when the place has no Terrain yet.)
- **The Sewers:** built 300 studs under the map (`Config.SewerDepth`): a big room with sludge channels, four long tunnels, its own sell pad, and a ladder with an EXIT sign. Unlocking costs coins once.
- **Sell pads:** GameServer sells Flushes when a player touches any part named `SellPad`. The map has one up top and one in the Sewers; without the map, a plain green pad appears in front of spawn.
- **Starting over:** change `Config.DataStoreName` to wipe everyone's progress (handy while testing).

## Ideas for what to add next

- More worlds after the Sewers (Skibidi City? Toilet Lab?)
- Pet trading, or fusing 5 of the same pet into a golden one
- Skibidi toilet enemies or bosses you plunge for big rewards
- Game passes (2x Flushes, auto-clicker, bigger tank)
- A global leaderboard for most Rebirths
