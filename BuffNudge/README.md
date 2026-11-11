# BuffNudge

On a ready check, tells group members which of their raid buffs you are missing.

## Install

Copy this `BuffNudge` folder into `World of Warcraft/_retail_/Interface/AddOns/`, then restart the game or `/reload`.

If the addon shows as out of date, run `/dump (select(4, GetBuildInfo()))` in game and put that number on the `## Interface:` line of `BuffNudge.toc`.

## Commands

| Command | Effect |
|---|---|
| `/bn test` | Show what you are missing without messaging anyone |
| `/bn whisper` | Whisper each player who can cast the buff (default) |
| `/bn group` | Post one message to raid/party chat instead |
| `/bn self` | Only print to your own chat |
| `/bn mine` | Toggle reacting only to your own ready checks |
| `/bn on` / `/bn off` | Enable or disable |

## Tracked buffs

Arcane Intellect, Power Word: Fortitude, Battle Shout, Mark of the Wild, Skyfury and Blessing of the Bronze. The list is at the top of `BuffNudge.lua`.

## Tests

`lua5.1 tests/buffnudge_test.lua BuffNudge/BuffNudge.lua` (from the repository root) runs the logic against a mocked WoW API.
