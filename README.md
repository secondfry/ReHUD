# [REP+] reHUD [Forked]
Fork of [reHUD](https://steamcommunity.com/sharedfiles/filedetails/?id=1906405707) by wofsauge updated to Repentance+. Obviously use only one of two.

Adds a more customizable smaller version of the "Extra HUD", which displays the gametime and a list of collected items on the screen.

## What this fork changes
- **Runs on Repentance+**. The original targets Afterbirth+.
- **Settings through [Mod Config Menu Impure](https://steamcommunity.com/sharedfiles/filedetails/?id=3701683951)** (Pure works too; do not enable both), saved in reHUD's own save.
- **Follows the HUD Offset option.**
- **Shows as many items as fit on screen**, newest first, grouped by floor.
- **Repentance floor names, in every game language**: Russian, Japanese, Korean and Chinese floor names no longer show up blank.
- **New filters**: active items, and temporary items (Lemegeton wisps, Zodiac, 3 Dollar Bill), which are marked with a small clock.
- **One icon per copy**: an item held twice (picked up twice, owned plus a character's innate copy like Cain's Lucky Foot, owned plus a Lemegeton wisp) shows twice. Each wisp, Zodiac or 3 Dollar Bill copy gets its own clock; when a copy goes, the oldest icon of that kind leaves.
- **Timer** shows hundredths of a second.
- **Co-op and Jacob and Esau**: lists every character's items, grouped by player within each floor and each marked with a character number when there is more than one (Esau, Strawman's Keeper, the Esau summoned by Soul of Jacob and Esau while he stays, each Tainted Lazarus form and each Esau Jr. form get their own). A dead player's items stay listed; items of players who leave stay hidden unless **Show items of players who left** is on. When Clicker turns Jacob and Esau into one character, Esau's items move to it and keep their floors (his temporary items go); Clicker into Jacob and Esau gives the new Esau his share, floors kept.
- **Characters survive swaps**: Tainted Lazarus's Flip (Birthright too), Esau Jr., Clicker and Continue keep each character's items under its own number, also for characters Esau Jr. puts on the same seed. A swapped-out form stays listed until it comes back, and a character Esau Jr. stored stays listed until the run ends, as the game keeps it; when Clicker or a type change merges Tainted Lazarus's forms, reHUD moves or drops the items the same way. Limit: after Exit and Continue, characters sharing a seed can take each other's rows (their items re-listed under the current floor) until each has played again.

## Features of original
- **Display your last collected items on the screen**. over 100 of them instead of the last 10 in the normal game.
- **Customize the display**: Position (Right, Bottom), Amount of Coloumns, Size, Transparency,..
- **Display a more accurate ingame Timer!** Precise up to milliseconds ;)
- **Filter your items**. Display Passives or only Familiars.
- **Sort your items**. Order them by the floor they are collected on.

## Support
Bugs, questions, ideas: [Discord](https://discord.gg/5KvKaUpsvR)

## Special Thanks
- wofsauge for the original reHUD!
- Piber for the Mod config menu!
- Skojanza for helping bugfix the original mod
- _Kilburn for the screen-size helper in the original mod

<details>
<summary>Original description (Afterbirth+)</summary>

Adds a more customizable smaller version of the "Extra Hud", which displays the gametime and a list of collected items on the screen.

### Features
- **Display your last collected items on the screen**. over 100 of them instead of the last 10 in the normal game
- **Customize the display**: Position (Right, Bottom), Amount of Coloumns, Size, Transparency,... (Requires [Mod Config Menu](https://steamcommunity.com/sharedfiles/filedetails/?id=1603631350)!)
- **Display a more accurate ingame Timer!** Precise up to milliseconds ;)
- **Filter your items**. Display Passives or only Familiars.
- **Sort your items**. Order them by the floor they are collected on.

**Disable "Extra HUD" in the Options menu when using this mod**

**You need ["Mod config Menu"](https://steamcommunity.com/sharedfiles/filedetails/?id=1603631350) to customize this mod!**

**This mod does *not* disable achievements!**

#### Special Thanks
to Piber for the Mod config menu!
to Skojanza for helping me bugfix this mod
</details>
