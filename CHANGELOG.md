# Changelog

## 0.7.0

- **Shields on the frames.** A gold bar across the top of each frame shows the shield left on someone (Power Word: Shield, yours or another priest's), draining as it's hit. The health bar sits just under it and keeps its place whether or not there's a shield, so nothing is covered and nothing jumps. Its height is on the Layout tab ("Shield bar height", 0 hides it). Turn off with "Show shields".
- **Shield bar under friendly nameplates:** a small gold bar with the shield's number. Needs friendly nameplates on (Shift+V). The game doesn't allow it inside dungeons and raids. Turn off with "Shield bar under nameplates".
- **Shields buy time.** Damage has to break a shield before someone loses health, so the fast heal is suggested later while they're shielded. Turn off with "Shields buy time".
- **Fixed: heals and hits on other players nearby were counted.** The game also reports combat text for every nameplate around you. Only you, your group and your target count now, so another player's heal can't be learned as yours. The game check report's numbers now mean just those.
- **Your buffs and heals over time moved to the bottom of each frame**, just left of the heal advice, so they no longer cover it. Buffs lasting over 5 minutes (Mark of the Wild, Fortitude) are hidden; change the limit in Settings ("Hide my buffs longer than").
- **Your heals over time count in the advice.** After your Rejuvenation, Renew or Regrowth lands on someone, the healing still to come counts as done, so you aren't told to cast a heal the HoT would cover. Turn off with "Count my heals over time".
- **The fast heal is only suggested when there's no time for the slow one.** The addon watches how fast each person is losing health. Your fast, expensive heal (Flash Heal, Lesser Healing Wave, Regrowth) is suggested only when they'd die before your slower, cheaper heal could finish casting. A tank knocked low by one big hit who then takes little damage gets the cheap heal. When you're being hit yourself, the addon also counts how much longer your casts really take (pushback), learned from your recent casts. "Safety margin" in Settings adds extra seconds. When the game hides damage numbers, the old "Emergency below 35%" rule is used.
- **Fixed: a heal-over-time tick could be learned as a direct heal.** Rejuvenation or Renew ticking right as your Healing Touch or Heal landed could have been recorded instead of the real heal. Heal numbers far away from the spell's tooltip are now ignored. The game check report counts them ("not matching the tooltip").
- Heal-over-time spells (Rejuvenation, Renew) keep using their tooltip number. The game doesn't say which spell a tick came from, so their Seen column stays empty.
- The game check report no longer lists Bear Form as a healing spell, and reads talents the way Forever provides them.

## 0.6.1

- Moved to the official Forever release folder.
- **Fixed: the Spells tab's Seen column stayed empty on the official release.** The release reports a heal's number just *before* saying the cast finished (the beta did it the other way round), so every heal was thrown away. Both orders work now.
- **The game check report** (`/khh probe`) has a new "measuring:" line. It shows where her heal results get lost when the Spells tab's Seen column stays empty: her heal casts, combat-text events, heals, and which of them the game hid.

## 0.6.0

Priest, Druid and Paladin prepared for beta testing (built from data, not yet played).

- **Same click idea for every healer:** Left = most mana-efficient rank of the main heal, Shift + Left = its highest rank, Right = the fast heal, cures on Shift/Ctrl + Right. The frame border colour shows which fits.
  - **Priest:** Greater Heal (Heal before 40, Lesser Heal before 16); Flash Heal; Power Word: Shield (Alt + Left), Renew (Shift + Middle), Prayer of Healing (Ctrl + Middle).
  - **Druid:** Healing Touch; Regrowth; Rejuvenation (Alt + Left), Wild Growth (Shift + Middle).
  - **Paladin:** Holy Light; Flash of Light (Holy Light before 20); Holy Shock (Alt + Left), Lay on Hands (Shift + Middle).
- **Druids never cast Rebirth by accident.** Clicking a dead player casts Forever's out-of-combat **Revive**. Rebirth can still be put on a click of its own.
- **Flash of Light is the Paladin's fast heal** (orange emergency advice).
- **Heals over time and shields** read their amount from the tooltip ("45 over 15 sec", "absorbing 44"). The Spells tab shows them, with healing per second over their duration.
- **Forever-only spells** can be put on clicks: Penance, Prayer of Mending, Binding Heal, Wild Growth. So can other useful spells: Rebirth, Innervate, Fear Ward, Power Infusion, Lay on Hands, and the Blessings of Protection, Freedom and Sacrifice.
- **The game check report** (`/khh probe`) now lists class and level, talent points per tree, and every healing spell in the spellbook that the addon doesn't know yet, with its tooltip text. That's what beta testers should send.

## 0.5.0

- **Edit mode** (`/khh edit`, or the button on the Layout tab): a box over the healer frames. Drag its edges or corners to resize every frame, drag the middle to move them. Without a group, five preview frames show the layout. Out of combat only; a fight closes it.
- **New Layout tab** (`/khh layout`):
  - frame width, height and scale;
  - gaps between frames;
  - power bar height (0 hides it);
  - name and number text sizes;
  - raid groups as columns or rows.
- **Health text:** missing (-160), percent (77%), current (540), current + percent, or none. It works in combat too: the game formats the hidden numbers.
- **Power bars for everyone:** mana in blue, rage in red, energy in yellow. Or show mana users only, or no power bar.
- **Power text:** current, percent, both or none. While the game hides power, only the current amount can be shown.
- Frame size, scale and the "Reset position" button moved from Settings to the Layout tab.

## 0.4.0

- **One click layout, built around her real heals.** The game won't let a click pick its rank by itself, so several ranks sit on modifier clicks and the frame shows which one fits. The simple/advanced switch from 0.3.0 is gone. Shaman:
  - Left = the most mana-efficient Healing Wave (rank 3 right now, worked out from her real heals);
  - Shift + Left = the biggest (rank 5);
  - Ctrl + Left = rank 1, for top-ups;
  - Right = Lesser Healing Wave (emergency);
  - Shift + Right = Cure Poison, Ctrl + Right = Cure Disease;
  - Alt + Left = Chain Heal (once learned at 40).
  Everyone's clicks are set to this once (with a chat message); later changes are kept.
- **Coloured border = the click to use.** Each click has a colour: Left green, Shift blue, Ctrl purple, Right orange. The frame's border and the heal name turn the colour of the click that fits how much health is missing. No border means don't heal yet. Works in combat and dungeons. The Clicks tab shows each click's colour.
- New rank choice **"Most mana-efficient"** for any click. It follows her real heals (the Seen column), so it changes by itself as she levels or changes gear.

## 0.3.1

- **Incoming heals on the frames:** a faint green bar after the health shows how much the heals being cast on someone will bring back. It covers her own cast as soon as it starts, and other healers' too. The game draws it, so it works in combat. It's cut off at the end of the bar, so a heal that would overheal simply fills the bar. Turn it off in Settings ("Show incoming heals").

## 0.3.0

From the second in-game test: real heal sizes, and simpler clicks.

- **Simple and advanced clicks.** Simple is the new default: Left = Healing Wave (highest rank), Right = Lesser Healing Wave (highest rank), Shift + Left = Cure Poison, Ctrl + Left = Cure Disease, Shift + Right = Chain Heal once learned. Advanced is the old layout, with several Healing Wave ranks on modifier clicks. Switch on the Clicks tab or with `/khh mode simple` / `/khh mode advanced`. Each set keeps its own changes. Clicks you changed in 0.2.x are kept in the advanced set.
- **Heal sizes no longer count +healing twice.** Forever's tooltip already includes +healing; the addon added it again.
- **The addon learns her real heal sizes.** Low ranks heal less than their tooltip says (Healing Wave 1: tooltip 88-101, real 61-74). After each heal she casts, the addon reads the heal number the game shows. Crits are left out. After 3 casts of a rank, that rank's real average replaces the tooltip in the Spells tab, the tooltips and the frames' advice. The Spells tab has a new **Seen** column. New +healing gear starts the results over; `/khh measured clear` forgets them.
- Priest, Druid and Paladin get simple sets too (untested). A click can name a backup spell for while the first isn't learned yet (Greater Heal, else Heal).

## 0.2.1

Fixes from the first in-game test (Ruins of Lordaeron, party of two).

- **"Which heal?" works inside dungeons.** There the game hides party members' maximum health even out of combat, so the advice fell back to tiny bars. The advice now works from missing health alone: the game shows or hides each heal's label itself, in and out of combat, with no maximum health needed.
- **+healing no longer drops to 0 in combat.** Changing gear or learning a spell mid-fight made the addon re-read +healing while the game hid it, and every heal amount lost its bonus. It now keeps the last known value and re-reads after the fight.
- The game check report shows how the advice is drawn, and says "blocked" instead of "error" when the game refuses to share debuffs.

## 0.2.0

Changes from studying ClickMend, VuhDo and HealBot on Forever, before the first in-game test.

- **New frame engine.** 40 click-cast frames are made at login and handed out to your party or raid between fights, the way ClickMend, VuhDo and HealBot do it on Forever. Blizzard's group header is no longer used, because it relies on secure code that's unreliable on the beta. If someone leaves mid-fight their frame hides; the frames are rearranged when the fight ends.
- **Clicks cast through a macro:** `/cast [@person] Healing Wave(Rank 3)` then `/stopspelltarget`. A heal that can't land is cancelled instead of waiting on your cursor and hitting the next person you click. Settings -> "Cast by" still offers name + rank and spell ID as backups.
- **Click a dead player to resurrect them:** any heal click on a dead frame casts Ancestral Spirit (Settings: "Click a dead player to resurrect").
- **Auto Self Cast warning:** the game's option sends heals aimed at someone out of range to you. The addon warns at login while it's on. Turn it off with `/khh selfcast off` or in Settings.
- **Frames tinted by debuff type:** a debuff you can remove colours the whole health bar (poison green, disease brown, curse purple, magic blue). The game draws it, so it works in combat.
- Debuffs use the `RAID` filter first (as ClickMend does on Forever), then the retail name. If this game build refuses the icons entirely, a simpler version takes over (works out of combat), and you're told once.
- Range fading now fades the frame's contents, not the secure button itself.
- The game check report (`/khh probe`) also shows how clicks cast, Auto Self Cast, whether health is hidden right now, and which debuff display is active.
- Spell IDs checked against the Forever beta's own rank list (bundled with ForeverAuras): all match.

## 0.1.0

First version, for in-game testing on a level 30 Shaman.

- **Healer frames** for you, your party or the raid. They show health, mana, name, missing health, dead/offline, your target, and fade when someone is out of range.
- **Click-casting** on the frames, with Shaman defaults (three Healing Wave ranks, Lesser Healing Wave, both cures, target, menu). Change them in `/khh clicks`. Bindings follow your level ("highest rank -1").
- **"Which heal?" advice** on every frame: the biggest bound heal that fits the missing health (10% overheal allowed), the fast heal below 35% health. Incoming heals from others are counted. Works in combat through the game's own health curves.
- **Cleanse icons** for debuffs you can remove, coloured by type, plus your own buffs on each frame.
- **Spells tab**: heal, mana, heal per mana, heal per second for every rank, with the most efficient rank marked. The same numbers appear on spell tooltips.
- **Game check** (`/khh probe`): records what the game hides from addons, in combat and out, for fixing things after a test.
- Priest, Druid and Paladin spell data and default clicks are included but untested.
