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

**Decided:** a full wheel, centred, with the arrow on top. The wedges cycle
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
