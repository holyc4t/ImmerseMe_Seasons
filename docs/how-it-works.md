# How it works

Everything Seasons shows is worked out from three things: the **real date**, the **realm time**, and
the **zone** you're in. Nothing is random and nothing is sent between players, so everyone running
the addon in the same zone sees the same season and the same frost, and `/reload` changes nothing.

## The calendar

Seasons follows the Earth's calendar, northern hemisphere: one Azerothian year per real year.

| Season | Starts |
|---|---|
| Spring | 20 March |
| Summer | 21 June |
| Autumn | 22 September |
| Winter | 21 December |

Each season is split into thirds (early, mid, late) for its name. The year is always shown as
*Year 25 after the Dark Portal*: a label, not a timeline.

Day counting works on plain calendar days (`Almanac.DayNumber`), never on clock time, so time zones and
daylight saving can't shift a date.

## Wording by land

Each of Weather's climates has a style (`ns.ClimateStyle` in `Data.lua`):

- **temperate**: Early Winter, Deep Winter, Late Winter... the usual year.
- **snowbound** (`alpine`: Dun Morogh, Winterspring, Alterac): the Long Winter and a short summer.
- **hot** (`arid`, `desert`, `jungle`, `volcanic`, `wastes`): a cool season and a hot season, never "winter".

In an instance, the season belongs to the last outdoor zone you were in: inside Zul'Farrak it's
still Tanaris's cool season.

## The sun

Sunrise and sunset use the standard solar declination formula for latitude 51.5°N, with solar noon
at 12:00 and no daylight saving: about 08:05 / 15:55 at midwinter and 03:40 / 20:20 at midsummer.
They're flavour: the game's own lighting doesn't follow them.

## Festivals

The notches are Blizzard's in-game holidays, at their usual dates (`Almanac.FESTIVALS`). Two move
each year:

- **Noblegarden** starts on Easter Sunday (the Gregorian Easter algorithm).
- **Lunar Festival** starts on the lunar new year: the second new moon after the winter solstice,
  from the same mean lunar cycle Weather uses for moon phases. It can be a day off the true date.

The Darkmoon Faire (the week from each month's first Sunday) shows in the tooltip only.

## Frost

`Climate.lua` is an exact copy of ImmerseMe: Weather's temperature model, and a test checks that it
gives Weather's outdoor temperature to the last decimal for every zone, many moments and every kind of
live game weather. Frost is decided from that temperature:

- In the **morning window**, from two hours before sunrise until midmorning (11:00 in winter, 9:30 in
  spring and autumn, 9:00 in summer), frost forms below **1°C**.
- Once on, it only clears above **2°C**, so it never flickers around one number.
- Below **−4°C** it stays all day.
- Never indoors (Ironforge, the Undercity) or in instances. Under an inn's roof it still shows: it's
  about outside, and Weather's tooltip shows the outside temperature there too.

After a login or `/reload` the addon doesn't know whether frost was already on, so it walks back
through the model until the answer no longer depends on that, and replays forward. You see the same
rim as if you had never reloaded.

The groups come out of Weather's climates on their own: snowbound zones are rimed almost every
morning, cold-winter lands (Tirisfal, Mulgore, Elwynn...) on some winter mornings, hot lands never.

## The rim

The rim is a separate layer drawn over the minimap's own gold border at partial opacity, so the
gold reads as tinted. Blizzard's texture is never changed: `/ims hide` just hides the layer. If no
round border is found (a skinned or square minimap), the layer is drawn at full strength as Seasons'
own thin ring.

Nothing on the rim takes the mouse. The tooltip appears when the cursor is on the band and over
nothing but the map, so clicks, pings, zoom and the stock buttons all work as before.

Arriving in another land plays a three-second transition: the colour slides to the new land's, the
painting cross-fades, and the frost thaws or creeps in. It runs only during those seconds. After a
login or `/reload` the land is simply there.

The painted accents follow the land as well as the season: snowbound (alpine) lands have their own
set. The drifting flakes and leaves are small sprites with looping animations: six short straight
moves that together follow the rim's curve, a gentle spin and a fade in and out. The game engine plays them; the addon runs no
code per frame, only when the season or the land changes. When the minimap is hidden, they stop.
