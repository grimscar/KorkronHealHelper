# Kor'kron Heal Helper

Healer frames for WoW: Forever. They tell you which heal to click and who needs a cleanse. Only the healer needs the addon. Type `/khh` to open it.

Built for Shaman first. Priest, Druid and Paladin have now been played in game at low levels too. Reports from higher levels and dungeons help a lot: see "For beta testers" below.

## The healer frames

One frame per group member: you alone (when "Show my frame when solo" is on), your party, or the raid by group.

- **Click to cast.** Clicking a frame casts on that person. Shaman defaults (change them in `/khh clicks`):

  | Click | Colour | Casts |
  |---|---|---|
  | Left | green | Healing Wave, most mana-efficient rank |
  | Shift + Left | blue | Healing Wave, highest rank (big heals) |
  | Ctrl + Left | purple | Healing Wave rank 1 (top-ups) |
  | Right | orange | Lesser Healing Wave, highest rank (emergencies) |
  | Shift + Right | | Cure Poison |
  | Ctrl + Right | | Cure Disease |
  | Alt + Left | | Chain Heal, highest rank (once learned at 40) |
  | Middle | | Target them |
  | Alt + Right | | Open their menu |

  "Most mana-efficient" and "highest" follow your real heals and your level, so the clicks keep up as you level.

  The game doesn't let any addon change a click's spell during combat, or read health in dungeons. So a click can't pick its rank by itself. Instead the frame tells you which click fits (see "Which heal?").

  Any heal click on a **dead** player casts **Ancestral Spirit** instead. A click that can't land (out of range, line of sight) is cancelled instead of waiting on your cursor for the next click.
- **Turn off the game's Auto Self Cast.** With it on, a heal clicked on someone out of range lands on *you*. The addon warns you at login while it's on: type `/khh selfcast off`, or untick "Game: Auto Self Cast" in Settings.
- **Which heal?** The frame's **border turns the colour of the click to use**. The right side shows the heal and click too: `HW3` over `L` means "Healing Wave rank 3, left click". The rule:
  - the biggest of your bound Healing Waves that won't overheal by more than 10%;
  - your fast heal instead (Right, orange) only when they're losing health so fast they'd die before your slower, cheaper heal could finish casting. A tank knocked to 30% who then takes little damage still gets the cheap heal;
  - no border while they're only scratched: don't heal yet.

  Heals already on the way from other healers are counted, and so are **your own heals over time** (Rejuvenation, Renew, Regrowth): no heal is suggested that your HoT will cover anyway. **Shields** (Power Word: Shield) buy time: the damage has to break the shield first, so the fast heal is suggested later. When the game hides damage numbers, the fast heal is suggested below 35% health instead. All of this can be changed in Settings.
- **Cleanses.** When someone has a debuff your spells can remove, their health bar is **tinted** in its colour (poison green, disease brown, curse purple, magic blue) and the debuff shows as an icon. Hover the icon to see what it is. Your own buffs and heals over time show along the bottom, just left of the heal advice. Long ones (over 5 minutes, like Mark of the Wild) are left out, since those aren't a healer's job in a fight. The limit can be changed in Settings.
- **Incoming heals:** a faint green bar after the health shows how much the heals being cast on them will bring back (yours and other healers'). If it reaches the end of the bar, the heal will overheal.
- **Shields:** a gold bar across the top of each frame, above the health, shows how much shield is left on someone (Power Word: Shield, yours or another priest's). It drains as the shield is hit. With friendly nameplates on (Shift+V), a small gold bar with the shield's number also shows under other players' nameplates and follows them around. The game doesn't allow that one inside dungeons and raids, so it works in the open world only.
- **Missing health** under the name, **DEAD** / **Offline**, a light border on your target, and faded frames for people out of range.
- Move the frames by dragging the red bar above them. Lock them in Settings or with `/khh lock`.

## Layout

- **Edit mode** (`/khh edit`): drag the edges or corners of the box over the frames to resize them, and the middle to move them. Without a group you get five preview frames. Out of combat only.
- **The Layout tab** (`/khh layout`):
  - frame width, height and scale;
  - gaps between frames;
  - power bar height (0 = off);
  - name and number text sizes;
  - health text: missing / percent / current / both / none;
  - power bar: everyone / mana users only / off;
  - power text;
  - raid groups as columns or rows.
  - "Reset layout" puts it all back.

## The Spells tab

Lists every heal rank you know: how much it heals (with your +healing gear counted), its mana cost, **healing per mana** and healing per second. The most mana-efficient rank is shown in green. Spell tooltips on your action bars show the same numbers.

The game's tooltip isn't always right: low ranks heal less than it says. So the addon watches the heal numbers from your own casts (crits left out), shown in the **Seen** column. After 3 casts of a rank, the addon uses the real average for that rank instead of the tooltip. New +healing gear starts this over; `/khh measured clear` forgets it.

## In combat

The game hides health, names and debuffs from addons during combat. The frames still work, because the hidden values go straight to the game for drawing. The addon itself never reads them.

- The "which heal" advice works from how much health someone is missing, which the game passes along even while it's hidden. It works inside dungeons too, where the game hides everyone's maximum health.
- Click-casting changes made in combat apply when the fight ends.

## For beta testers

Thanks for helping! Play a healer (any level), then:

1. Heal a party member a few times with each heal you have. The **Seen** column on `/khh spells` fills in as you go.
2. Try the clicks (`/khh clicks` shows them) and the cures.
3. After a fight, type **`/khh probe`**, press **Ctrl+C** in the window that opens, and paste it to Grimscar.
4. If anything says "error", also send **`/khh errors`**.
5. Screenshots of the frames in action, and of tooltips of new Forever spells (Penance, Prayer of Mending, Wild Growth, ...), help a lot.

## Commands

- `/khh`: open the window
- `/khh clicks`: set up click-casting
- `/khh measured clear`: forget the heal sizes learned from your casts
- `/khh lock` / `/khh unlock`: lock or move the frames
- `/khh edit`: edit mode (resize the frames with the mouse)
- `/khh layout`: sizes, bars and text
- `/khh frames`: show or hide the frames
- `/khh reset`: move the frames back to their starting spot
- `/khh selfcast off`: turn off the game's Auto Self Cast
- `/khh probe`: a report of what the game is hiding right now, to send to the addon author
- `/khh errors`: problems the addon ran into
