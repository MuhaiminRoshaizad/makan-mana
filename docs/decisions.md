# Decisions

Short records of choices that shaped the app, newest last. Each says what was
decided, why, and what it costs.

## 001: No account, no login

**Decided:** the app has no sign-up, no login and no server of its own.

**Why:** a login protects data that belongs to someone or is shared between
people. Makan Mana stores nothing about anyone: it asks Google for nearby
places and spins a wheel. An account would add sign-up friction before the
first spin and auth code to maintain, and protect nothing.

**Costs:** settings live on one phone and do not follow the user to another.

## 002: One phone, no groups or voting

**Decided:** one person spins on one phone. There are no groups, invites or
votes.

**Why:** the decision happens out loud at the table. Voting in the app would
need accounts (001) and a server, and would turn a ten-second spin into a
round of notifications.

**Costs:** nobody else sees the result unless they look at the phone or are
sent the place.

## 003: Live location, with a dropped pin as the fallback

**Decided:** search starts from the phone's live location, asked for the
first time the user searches and used only while the app is open. If location
is refused or off, the user drops a pin on the map instead. There is no saved
office pin.

**Why:** lunch is not always at the office. Asking in context rather than at
launch keeps the one permission prompt for the moment it makes sense, and the
pin keeps the app usable without it, as App Store Review Guideline 5.1.1(iv)
asks.

**Costs:** a user who always eats near the same place drops the pin again
each time location is off.

## 004: Radius as a map setting, up to 50 km

**Decided:** the search radius is set on the map and drawn there as a circle.
The largest is 50 km.

**Why:** a number in kilometres means little until you see what it covers.
50 km is the most Nearby Search accepts.

**Costs:** none known.

## 005: English only

**Decided:** plain English strings, no localisation layer.

**Why:** English is enough for the office the app is for. Adding a
localisation layer later is mechanical; carrying an unused one now is not
free.

## 006: Light mode only

**Decided:** one light theme. No dark mode.

**Why:** the app is opened for a minute at lunchtime, in daylight. A second
theme doubles every colour decision for little use.

**Costs:** the app stays light when the phone is set to dark.

## 007: Places straight from Google, with a key per platform

**Decided:** the app calls Places API (New) directly. Each platform has its
own key, restricted to that app, with a daily quota cap set in Google Cloud.
The key is never committed.

**Why:** a server only to hide the key would need hosting and upkeep for an
app with no other server work. A key in an app can be read out of it, so the
protection is the restriction and the cap, not secrecy.

**Costs:** whether Places API (New) honours an app restriction on its REST
endpoint is untested. Until it is, the quota cap is what limits misuse.

## 008: Ask Google only for what is shown

**Decided:** every Places request carries a field mask listing only the
fields on screen. Only place IDs are kept between sessions.

**Why:** Places bills by the most expensive field requested, and rating and
review count are already in the Enterprise tier; reviews add Atmosphere.
Google's terms allow caching place IDs and nothing else.

**Costs:** every search is a fresh request, so results need the internet each
time. Places shown on a map must be on a Google map, with Google's
attribution.

## 009: iOS style on both platforms

**Decided:** one look on Android and iOS, following iOS. Presses dim instead
of rippling, pages slide in from the side, and the back control is a chevron.

**Why:** one design to build and test instead of two. It is the same choice
fotos made.

**Costs:** Android users do not get the Material ripples and page motion
their other apps use.

## 010: Two tabs in a floating bar

**Decided:** Spin and Map are the two tabs, in a capsule bar that floats over
the content. Switching tabs plays no animation; only pages and sheets that
open slide or rise in.

**Why:** both screens show the same places and are switched between often.
A tab change happens many times a session, so it gets the platform's instant
switch.

**Costs:** every scrolling page must leave room under its last row for the
bar, and sheets opened from a tab must open on the root navigator or the bar
covers them.

## 011: Messages as a toast from the top

**Decided:** short messages drop in as a toast from the top of the screen,
above every page and sheet.

**Why:** a toast at the top never covers the tab bar or the Spin button.

**Costs:** none known.

## 012: Back on the Spin tab asks to be pressed again

**Decided:** Back on the Map tab goes to Spin. Back on Spin shows "Press back
again to close Makan Mana" for 2 seconds, and a second Back while it shows
closes the app.

**Why:** a stray swipe should not close the app mid-decision. A hint costs
less than a Leave dialog and is what fotos does.

**Costs:** to keep Android 14 and later from closing the app before Flutter
sees the Back, the app claims every Back, which loses Android's
back-to-home preview.

## 013: A full wheel, with the colour in it

**Decided:** a full wheel, centred, with the arrow on top (its shape since
replaced by 021; the colours stand). The wedges cycle
through seven colours: tomato, orange, mustard, leaf green, sky, blue and
berry. Each label is white or ink, whichever passes WCAG AA on its wedge.
Everything else is ink on soft white. The same colours mark each place's pin
on the map.

**Why:** two of the most-rated wheel apps, Tiny Decisions and Spin The
Wheel, put the colour in the wheel and keep the rest of the screen plain. A
single accent colour for the app was tried in yellow and green and rejected,
as were a half wheel and a side wheel that hid half the names.

**Costs:** with seven colours in the wheel, the rest of the app cannot use
colour to mean anything; state is shown by weight, shape and words.

## 014: The spin is simulated, not scripted

**Decided:** the wheel runs on a small physics model. A peg sits between
every two wedges. The arrow is a flapper that resists each peg like a spring
over the last part of a wedge, and the wheel slows under constant friction.
The wheel starts each session at a random angle.

| Parameter         | Value              | Meaning                                         |
|-------------------|--------------------|-------------------------------------------------|
| Friction          | 2.0 segments/s²    | Steady slowdown                                 |
| Flapper reach     | 0.35 of a segment  | How far before a peg the flapper starts to resist |
| Flapper stiffness | 10                 | Spring constant                                 |
| Top speed         | 18 segments/s      | A harder throw is capped here                   |
| Throw threshold   | 3 segments/s       | A slower release coasts instead of spinning     |

**Why:** a wheel that runs out of speed against a peg is pushed back into the
previous wedge by the flapper, so the near-miss happens by itself and no spin
is rigged. A simulation of 14 wedges found no bias (chi-square 16.0 against
a 5% critical value of 22.4).

**Costs:** a spin takes about 4 to 6 seconds. The result depends on the
throw, so tests drive the model with fixed inputs rather than gestures.

**Wheel size:** the values above are for 14 places or fewer. A bigger wheel
multiplies friction, stiffness, top speed, the Spin button's speeds and the
throw threshold by places / 14, so every size turns about 2.2 times in about
5 seconds and rolls back on about a quarter of spins. Unscaled, 40 places
turned 0.8 times a spin. It stays fair at 20, 40, 100 and 300 places
(chi-square under the 5% value). Fewer places are not slowed: their pegs
would stop the wheel within a turn or two.

## 015: Keep the name Makan Mana

**Decided:** the app stays Makan Mana, with the ids `my.minned.makanmana`.

**Why:** it is the question the app answers, in the words the office
already uses. The app is made for one office, not for the stores.

**Costs:** the name is taken many times over. Maybank's MAE app has a "Wheel
of Makan Mana" that picks a place near you, and makanmana.app,
wemakanmana.com and others use it for food pickers. Should the app ever go
to the stores, Apple requires a unique name, so the store listing would need
a different one.

## 016: Portrait and landscape

**Decided:** every screen works in both orientations. In landscape the Spin
tab puts the place's name beside the wheel rather than above it.

**Why:** a phone may be on its side in a stand or a car mount, and an app
that only works one way round fails anyone who cannot turn it. Large system
text has to fit in both.

**Costs:** every screen is laid out and tested twice. In landscape a phone
is only about 400 dp tall, so the wheel is smaller there.

## 017: Places from a list built into the app

**Decided:** places, with their ratings and review counts, come from a list
prepared each month on the developer's computer, kept out of the repository
and bundled into the app when it is built there. Every screen reads places
through `PlacesRepository`, and a build-time switch picks the source
(`MAKAN_MANA_PLACES`, with `demo` for made-up places), so a live source such
as Google Places can replace the list later without touching any screen.
This replaces the live Google search of 007 for now; 007 and 008 apply again
if it returns.

**Why:** Places API needs a Cloud billing account, and with a debit card
Google asks for an RM120 deposit before any use. The list costs nothing and
still has the ratings and review counts the filters need.

**Costs:** places exist only where the list covers, 15 km round the office.
Ratings can be up to a month old, and a place's weekly hours and its five
reviews up to three months. Five, in Google's "most relevant" order, is all
Google shows a visitor who is not signed in; the rest are a link away. Places not yet given hours count as unknown, and
Open now keeps them rather than empty the wheel while the list fills in. A
new list means a new build, and a build made elsewhere, such as on CI, has no
places at all.

## 018: The map is MapLibre with OpenFreeMap tiles

**Decided:** the Map tab draws with `maplibre_gl` and OpenFreeMap's Liberty
style, tilted back to show buildings in 3D. Pins are the places on the
wheel, each in its wedge's colour and labelled with its name, inside a ring
for the search area. Liberty's own restaurant icons are hidden so they do
not compete with the pins.

**Why:** the Google Maps SDK needs the same billing account as Places (017).
OpenFreeMap needs no key and no account, and MapLibre is the open engine
that draws its vector tiles, 3D buildings included, on Android, iOS and the
web.

**Costs:** OpenFreeMap is one developer's project, paid for by donations,
and offers no SLA (openfreemap.org, checked 24/11/2026); if it stops, the
style URL changes to another vector tile host.
3D buildings appear only from zoom 14, closer than a 2 km circle fits. The
Android build needs JDK 21, and iOS needs 15.5 or later.

**Changed (24/11/2026):** the map shows no OpenStreetMap credit. ODbL 4.3
asks for one only when the map is used publicly, that is by anyone other
than its owner, and the app is for its owner alone. If anyone else ever
uses it, the credit comes back.

## 019: The wheel starts empty, and filters are kept

**Decided:** the first time the app opens, the wheel is blank and asks what
the person is after. Filters hold everything chosen there: distance (500 m
to 15 km), kind of place, rating, reviews, open now and how many places go
on the wheel (5, 10, 20 or all, nearest first). Once chosen they are kept on
the phone with shared_preferences and used straight away on later launches.
The app always looks 15 km out; Distance narrows that, so the number of
matches is right at any distance without searching again.

**Why:** the user wanted to set the distance and the rest before the wheel
filled, rather than find defaults already applied. Keeping the choice means
asking once, not every lunch.

**Costs:** a first lunch takes one more step. Holding every place within
15 km is cheap for the bundled list; a live source such as Google Places,
which returns 20 at a time, would need its own way to count matches.

## 020: The icon is a slot machine of food, and the opening rolls its reels

**Decided:** the app icon is three reels on the app's ink, in a white frame,
stopped on a bowl, a burger and a cup in the wheel's colours, with a pointer
above and two gold sparks. Opening the app, the reels roll and stop one after
another, the sparks flash, and the whole screen rolls on like the next reel
while the app rolls up from below. Picked by the user from four concepts
drawn from their own references (demo: claude.ai/artifact/Kkx4aApjiX93VYb4qPivj9).

**How:** the drawing lives once, in `lib/app/opening/reels_art.dart`. A test
writes Android's adaptive and themed icons, the system splash and every PNG
icon from it (`--dart-define=UPDATE_ICONS=true`), and otherwise fails if a
committed vector file drifts from it. Android 12 and later show the reels,
still rolling, on their own splash; before that the launch background shows
the same. Flutter's first frame draws exactly that frame, so the reels carry
on without a jump. iPhone shows a plain ink launch screen, as Apple asks, and
the reels fade in. Reduce Motion shows them stopped and fades the opening.

**Costs:** about 1.8 s from the first frame to the app, on every cold start.
The splash never settles into the Spin tab, by the user's wish. Not yet seen
on a phone: the hand-over from the system splash to Flutter's first frame is
checked only in tests and a web build.

## 021: The wheel rises from behind the tab bar

**Decided:** on the Spin tab the wheel is a big circle, 720 dp across on a
412 dp phone, whose top meets the arrow 43% of the way down the screen and
whose centre lies far below it, so only its top shows, running on behind the
tab bar. The Spin button floats over it just above the bar. Above the arrow,
the count of places and the rating and distance of the place under the arrow
sit on fixed lines; the name between them has three lines' room at 36 and
gets smaller, down to 22, rather than move either line. Names on the wedges
read from the rim inwards, keep one size and wrap onto two lines; only a
longer name gets smaller, then takes a third line, then an ellipsis. On its
side the wheel takes the right half. Chosen by the user from their own
sketch: the flatter of three shapes, and wrapping over shrinking (demo:
claude.ai/artifact/VLCMhYA7d1bbnDa3EiZawr).

**Why:** a full wheel had to fit the screen's width, so its wedges were
short and long names were cut. A bigger wheel gives each name the length of
the screen's lower half, and the name above changes as the wheel turns
without anything around it jumping.

**Costs:** only three or four wedges show at a time, so the rest of the
wheel is seen only as it turns. Listings stuffed with keywords (the longest
is 114 characters) still end in an ellipsis on the wedge, though never above
the arrow up to about 150 characters. The "throw the wheel" hint went, as
the Spin button now names the action. Not yet seen on a phone: checked in
tests and a web build.
