# The Violence - vertical slice (v0.6)

A test range for the NPC CQB Bible, and the first steps toward the police command game (see "The Violence - Police Command Roadmap"). Two modes:

- **Matches and operations:** eleven maps, from a one-room cabin to an apartment block. Two teams of one to twenty operators each carry a rifle and a pistol (the untrained carry only a pistol). You place everyone, set every operator's habits and traits, and press RUN. The fight resolves itself at up to 20x speed. New in v0.6: put civilians on the map, put team A under police rules, and send officers from your department, whose experience, wounds and files carry over from one operation to the next.
- **Endless Battle:** Port Carrick, a 1 km city of about 250 lots. Four gangs fight over its buildings, six police precincts answer the gunfire, and three hospitals send out ambulances. It never ends.

Every plan is drawn as an architectural floor plan in greyscale. Operators start as clean plan symbols. Red appears only where the shooting has been: sprays, smears on walls, drip trails, pools under the fallen, stains on the figures.

## Run it

**Standalone:** double-click `TheViolence.exe`. It is the whole game in one file (Godot 4.7.2 runtime with the game data embedded), so no Godot install is needed. The first launch may show a Windows SmartScreen warning because the file is unsigned: choose "More info", then "Run anyway".

**From source:**
1. Install Godot 4.4 or newer (tested on 4.4.1 and 4.7.2, standard build, no addons).
2. Open `project.godot` in the Godot project manager (Import, select the folder).
3. Press F5. The first open imports the SVGs (a few seconds).

**Rebuild the standalone exe:**
1. In Godot 4.7.2, install the export templates (Editor > Manage Export Templates).
2. Choose Project > Export > "Windows Desktop" > Export Project. The preset embeds the game data in the exe and writes `build/TheViolence.exe`.

From a terminal: `godot --headless --path . --export-release "Windows Desktop" build/TheViolence.exe`.

## The maps

Maps climb in complexity. Pick one from the Map list at the top of the setup panel.

| # | Map | Size | What it tests |
|---|-----|------|---------------|
| 00 | Test Range 01 - Shotgun House | 36 x 24 m | the original slice: four rooms on one line, porch, yard |
| 01 | Lone Cabin | 30 x 20 m | one room, one door |
| 02 | Bunkhouse | 36 x 22 m | two rooms, three doors: the first choice of way in |
| 03 | Corner Store | 40 x 26 m | a shop floor too big to clear from the door, glass shopfront, back alley |
| 04 | Center-Hall Bungalow | 40 x 28 m | a hall with rooms off both sides, small rooms to check, four entries |
| 05 | Duplex | 44 x 30 m | two mirrored units joined by one party-wall door |
| 06 | L-Shaped Ranch | 48 x 34 m | garage, open great room, kitchen core, bedroom wing, patio doors, pool |
| 07 | Roadside Motel | 56 x 34 m | six rooms off one walkway, office, open parking lot |
| 08 | Warehouse & Offices | 64 x 44 m | a racked 32 x 24 m warehouse next to a tight office block |
| 09 | Walled Compound | 64 x 50 m | perimeter wall and gates, big main house, guard house, garage |
| 10 | Apartment Block | 60 x 36 m | 43 rooms: eight flats off one 44 m corridor, two stair halls |

## Controls

**Setup**
- Pick a map. Set each team's size (1-20 operators) and posture:
  - Assault: clear the building room by room.
  - Hold: defend.
  - Hunt: go after contacts and sounds.
- Pick an operator (A1-A20, B1-B20), then left-click the plan to place them. Right-click sets facing. Every map has default posts for all forty.
- The Echelon dropdown plus `Apply preset` loads the bible's base stats, typical habits, plates and Experience. `Plates` sets 0-4 chest plate segments.
- The habit tabs toggle all 40 good habits and 20 bad habits. Hover any habit to see what it does and what overrides it.
- The Traits tab sets Experience (tier 1-5) and the hearing traits, Tinnitus and Elephant Ears.
- `Copy to team` gives every teammate the selected operator's echelon, habits, traits and plates.
- `Seed` makes a fight repeatable. The same seed and configuration always replay the same fight.

- Each team's alert option sets how it starts: Yellow (weapons drawn) or Green (relaxed, for an ambush).
- `ENDLESS BATTLE` opens the city. It uses the seed above it. `Gang cap` and `Police cap` set the most members a gang can have and the police headcount at which hiring stops.

**Operation (section 3, new in v0.6)**
- `Civilians` (0-40) places that many civilians from the seed, about two in three indoors. They appear on the plan before you run.
- `Police rules` puts team A under police rules: every recognized person is judged before an officer may fire, suspects can give up, and officers cuff them.
- `Night` slows recognition and judgment and makes misjudgments more likely.
- `Team A: department` replaces team A with the officers you picked in the department (always under police rules). Team B becomes a gang house of four relaxed suspects, which you can change.
- `Body cameras` equips the department: what officers see is recorded as evidence.
- `Department ...` opens the roster (see "The department" below).
- When the run ends, the panel shows the **incident record**: suspects, officers and civilians, rounds fired and rounds through walls, misjudgments, excessive force, and every finding with its evidence.

**Run**
- Speed buttons run from 0.25x to 20x, or use keys 1-7. Space pauses, Esc returns to setup. Big fights may run slower than the target; the panel shows the real rate.
- Overlay toggles:
  - vision cones;
  - recognition bars: one per target, showing the enemy closest to recognizing it;
  - aim traverse arcs;
  - planned paths.
- Small arcs flash beside an operator who has just heard an enemy.
- Mouse wheel zooms; middle-drag or right-drag pans; Home refits the view.
- `Rerun same seed` replays the fight exactly; `Rerun new seed` rolls a new one.
- The ledger of the dead runs down the left side: when, who, how, by whom and where.
- The small dot beside each figure is their alert state: green, yellow or red.

## New in v0.6: civilians, judgment, the department

**The Patrol echelon.** A new police hire sits at the midpoint of Militia and Regular in every stat: recognition 0.39 s, stress resistance 0.375, twelve habits (Militia's eight plus PF01, GD01, ED01, ED02), experience tier 1, and a soft vest that stops pistol rounds to the chest from any side but not rifle rounds.

**Civilians.** A parallel population with its own, much cheaper brain. Nobody targets a civilian on purpose (the paramedic rule), but every bullet can hit them.
- They start unaware. A gunshot heard, a drawn gun in sight, a near miss or someone falling alarms them.
- Then they act on their personality (panic, curiosity, defiance, mobility, a phone): flee to somewhere far and out of sight, hide, freeze, film the shooting from 7-26 m, or comply when an officer close by aims at them or shouts.
- Wounded civilians use the five-minute bleed-out like everyone else.

**Judgment (police rules).** An officer who has recognized a person must judge them before firing:
- threat (showing a weapon, or attacking): fire is allowed;
- unknown (no weapon in sight): the officer covers them and challenges, "Police! Show me your hands!", every 2.5 s;
- civilian, or someone who has given up: let go of, and not judged again for 10 s.

Judging takes about 0.3 s at Judgment 50, longer under stress and in the dark, much shorter when the person is pointing a gun at you. A civilian can be judged a threat by mistake, more often under stress, in the dark, with a phone in their hand, running, close, or with poor Judgment; raised hands make it rare. ED04 (threat discrimination) halves the chance and WD09 (trigger discipline) cuts it by 30%. Civilians use up attention too: an officer with Experience 1 who is looking at a civilian is not tracking the gunman behind them. Bad habit BH09 (Jumpy trigger) fires at half-recognized movement within 10 m before any judgment, civilians included.

Default Judgment by echelon: untrained 35, militia 40, Patrol 50, regular 50, police tactical 65, special operations 70.

**Surrender and arrest.** A suspect covered or challenged by police may give up: hands up, weapon dropped, kneeling. It is more likely when wounded, out of ammunition, under several officers' guns, untrained or stressed, and less likely with friends close by. An officer who was firing at them takes a moment to stop (reaction, plus Temper and stress; more with Overkill active). Those rounds are recorded as excessive force. The nearest free officer walks up and cuffs them (3 s). Under police rules the operation runs on until everyone who gave up is cuffed.

**Walls and rounds.** Rounds now go through some walls. Partitions (up to 0.15 m) are drywall, house exterior walls (up to 0.25 m) are timber frame, and yard fences are fences. A rifle round goes through all three, losing energy each time. A pistol round goes through drywall three times in four, timber one time in four. Anything thicker stops everything. A round slowed by walls is less likely to kill. This applies in the city too.

**The incident record.** Every operation records every round (who fired, at whom, what they had judged that person to be, who it hit, through how many walls), every person who went down, surrenders and arrests. Findings are the events that will become consequences in the campaign: a civilian killed or hit by police, excessive force, a misjudgment, friendly fire, an officer killed. Each finding carries its evidence:
- body cameras of officers within 30 m who were facing it;
- phone video from civilians filming it;
- eyewitnesses (civilians within 35 m with a line of sight);
- or only people who heard it.

**The department.** Port Carrick PD keeps persistent officers, saved after every operation (one save slot):
- Twelve officers to start: a sergeant, a corporal and ten officers, all Patrol. Each is rolled once at hire (form, strengths and weaknesses, habits, personality, Judgment, Temper, Integrity) and keeps that roll for their whole career.
- Tick who goes on the next operation. Hover a name to read their file.
- After the operation, each officer gets experience: contact +2, under fire +2, +1 per hit on a threat (up to 3), +1 per arrest, +1 for coming back hurt. Tiers come at 6, 18, 40 and 80 xp.
- Wounded officers are out 2-5 weeks, or 8-14 if they went down. The dead stay in the roster as killed. Trauma from taking a life, being hit, losing a partner or hitting a civilian raises the stress they bring into later operations, and eases by half a point a week.
- Every finding that names an officer goes into their file.
- `Hire a recruit`, `Next week` (wounds heal) and `New department` (from a seed) are in the panel.

## What is simulated

Everything follows the NPC CQB Bible.

- **Plan plus height:** 2D geometry with analytic height.
  - Half cover hides a ducked body, but a standing head shows over it.
  - Windows pass sight between 0.9 and 2.1 m.
  - Concealment hides you but doesn't stop rounds: sofas, beds, hedges, shelving, plastic bins, railings.
  - Cover hides you and stops rounds: walls, cars, counters, racks, drums, sandbags.
- **Low cover (up to 1.3 m):** someone right beside it sees and shoots over it with no penalty. Its effect grows with their distance from it, reaching its full height at 3 m. Cover close to the target still protects fully against a distant shooter. A ducked operator stays behind it.
- **Recognition:** slows with eccentricity in a 120 degree cone. It is followed by Fitts-law time on target, with separate precision and accuracy.
- **Experience (a trait, tiers 1-5):** how many enemies an operator tracks at once.
  - Only tracked enemies are recognized. They are the closest ones in the cone with a line of sight.
  - Every tracked enemy is recognized, and the aim set up, in parallel.
  - Switching to an enemy already acquired takes 0.06 s on the pistol and 0.08 s on the rifle, plus 4 ms per plate.
  - Tier 1 takes one enemy at a time, from scratch.
  - Presets: untrained 1, militia 1, Patrol 1, regular 2, police 3, special operations 4.
- **Sound (a mechanic; nothing is played yet):** each sound has a fixed loudness:
  - rifle 45 m, pistol 35 m;
  - footsteps: sprint 8 m, run 5 m, walk 3 m, room-clearing pace 2 m; creeping is silent;
  - reloads and stoppage clearing: 4 m.

  Walls halve it. Hearing is the same for everyone unless a trait changes it: Tinnitus x0.5, Elephant Ears x1.5. Hearing gives a rough position.

  With ED07, an operator turns their eyes to any sound within 0.3 s; without it, only to gunfire, after 1 s. Aggressive operators go after what they hear: a hunting team, or anyone with the Aggression personality. A holding squad covers the door or window of its room closest to the sound.
- **Damage:** a head hit kills from any weapon, and plates break one segment per hit.
  - A chest hit that no plate stops kills outright one time in five. Otherwise it downs (65%) or wounds, as before.
  - Someone downed has five minutes to get aboard an ambulance, or dies of wounds. In a match, that only matters in long fights.
- **Alert states:** every operator is green, yellow or red.
  - Green: relaxed.
    - A rifle is carried low and takes 0.45 s to bring up.
    - A holstered pistol takes 0.9 s to draw (1.2 s for the untrained).
    - Recognition is 30% slower.
  - Yellow: weapon drawn and ready.
  - Red: engaging (aiming at or firing on someone).
  - Hearing an enemy, seeing one, a callout or incoming fire raises an operator to yellow.
  - Red relaxes to yellow after 5 s without engaging. Yellow relaxes to green after a quiet minute, never below the starting state or a tasking's floor (assaults and hunts stay at least yellow).
- **Melee:** two enemies in body contact (0.8 m). The quicker reaction kills; it comes from the echelon, habits and stress. It is half again slower against someone not yet recognized, and 30% slower in green.
- **Every operator is an individual.** Each match rolls (a department officer was rolled once, at hire, instead):
  - a form within about 6% of their echelon, moving every time-based stat;
  - a little jitter on each stat;
  - one or two named strengths and one or two named weaknesses of 15-25% each (Quick eyes, Fast hands, Steady aim, Snap shooter, Cool head, Recoil master, Quick to settle; Slow eyes, Fumbles reloads, Shaky aim, Slow on target, Jittery, Flincher, Slow to settle).

  The roster shows them: hover an operator's name in a match, or select anyone in the city.
- **Names:** every operator gets a name from a bank of 18 cultures (hundreds of thousands of combinations). Team B and each gang draw about four in five from one culture; police, paramedics and team A draw from all of them.
- **Stress:** near misses, hits and casualties raise it. It widens dispersion, narrows the cone and switches on stress-triggered bad habits.
- **Rules 1 and 2:**
  - Rule 1: the closest visible enemy within 10 m overrides everything; fire until dry or the threat is eliminated.
  - Rule 2: a dry primary means switch to the pistol; when both are dry, break line of sight with cover before reloading.
- **Habits:** every good habit changes behaviour and gives the 0.5% speed bonus. Bad habits override the good habits they contradict, never Rules 1 and 2.

Bad habits present on an operator:
- Stress habits switch on when stress x (1 - resistance) passes their threshold.
- Personality habits are always on.

## Teams of up to twenty

A team of more than five splits into elements (fire teams) of up to five, as balanced contiguous blocks of slots: 6 = 3+3, 7 = 4+3, 11 = 4+4+3, 20 = 5x4.

**Elements on the attack:**
- Each element picks its own room: the nearest uncleared room reachable through a door from outside or from a cleared room, by path length. No other element may have claimed it.
- A small room off the room just cleared goes first.
- Small rooms (10.5 m2 or less, not halls) are checks. Someone with PF10 looks in; if nobody on the team has PF10, they are skipped.
- An element with no room open to it waits a few metres behind the nearest element working a door.
- Once an element is clearing a corridor or stair hall, others can peel off it into the rooms along it.
- Rooms of 60 m2 or more, or big L-shaped rooms, are swept: a lattice of points about 5 m apart must each be seen from within 12 m.
- Entry runs are capped at 4.5 m. Rooms of 40 m2 or more seat five entrants.
- An element cut down to one joins the nearest element that still has people. An element wiped out releases its room.

**Inside each element**, the five-person rules from bible section 7.1 hold:
- Sectors: 110 degrees each for two or three, 360/N for four or five.
- Stacks: run along the wall, split across the door when the wall runs out, then form a second row.
- Rooms: each seats two to four entrants by floor area. Anyone else holds rear security at the stack.
- Bounding: odd and even slots bound as two halves.
- Hunting: followers take wedge slots.
- Callouts only turn the eyes of teammates within 25 m of the contact whose sector covers the bearing.
- Reload cover: only the nearest free teammate covers a reloader.

**Defence (Hold):** each squad consolidates in one room, one squad per room. It takes the room where most of its members already are, if that room is big enough. Members already inside keep their posts; the rest move to posts covering the room's doors (outside doors first) and windows. Default defender posts follow the same rule: B1-B5 in one room, B6-B10 in another, and so on, picking big, deep rooms with few windows.

## Endless Battle: Port Carrick

**The city.** A grid of 30 blocks between 18 m streets, about 1,026 x 608 m.
- Each block holds two rows of lots, back to back.
- Every lot is a full floor plan:
  - the eleven maps, turned to face their street;
  - a police station, a hospital and a school;
  - pocket parks and car parks.
- Lots are fenced at the sides and back and open on the sidewalk.
- Streets have sidewalks, parking lanes with parked cars (cover) and two traffic lanes.
- The blocks form twelve neighbourhoods and six police precincts.
- There are about 200 buildings: six police stations, three hospitals, six schools and the rest homes, shops, motels, warehouses, compounds and apartment blocks.

**The gangs.** Kilbride Crew (dots), Corvino Family (bands), Los Halcones (diagonal hatch) and Zarya Bratva (cross-hatch). The pattern on a member's shoulders is the pattern that hatches the gang's buildings on the map.
- Recruits are 70% untrained, 20% militia and 10% regulars ("soldiers").
- Each gang starts with a home neighbourhood holding a school, plus one next to it. The rest of the city is unclaimed.
- Squads of up to five hold one room each: one room in a house, up to three in the biggest buildings.
- **Capture:** a building changes hands after a minute of domination, meaning only one gang has living members inside. Police inside, or a rival, stop the clock. Only a gang member can take a building; police clearing a building does not change its owner. Police stations can't be taken.
- **Recruiting:**
  - The gang holding the most buildings in a neighbourhood dominates it by its share of them.
  - A gang recruits 0.15 x the sum of (its dominance x the number of buildings) for each neighbourhood it dominates, per minute.
  - Recruits appear at the hospitals and schools it holds; these spawn points can be captured.
  - A gang stops recruiting at its cap.
- **Pushes:** every two minutes, each gang sends everyone at its spawn points, beyond five kept there, out to the buildings on the edge of its territory, five to a room.
- **Expansions:** when the edge is full (or the gang is near its cap), its soldiers and militia form an assault team. The best ten are taken, and the garrisons they leave are refilled by the untrained.
  - The team attacks the nearest building it doesn't hold, unclaimed ones first.
  - It clears the building room by room, holds it through the minute's domination, and becomes its garrison.
- **Holding gangs don't shoot at each other.** Gang against gang only happens when one side is an assault team.

**The police.** Each precinct station holds:
- a QRF of ten special-operations officers with two vans;
- two patrol convoys, each two cars with two officers per car;
- a police ambulance with two police paramedics.

All vehicles drive on rails: the right-hand lane of every street, turning at intersections.
- **Reports:** gang gunfire is called in.
  - A report within 500 m of an original report from the last five minutes is a duplicate of that incident.
  - Anything else opens a new incident.
  - Incidents are answered in the order they came in, each by the nearest QRF at its station.
- **The QRF:**
  - boards its vans and drives to the scene;
  - searches the three buildings nearest the report point, nearest first (chosen when the report came in);
  - reports all clear, walks back to the vans and drives home.
- **Patrol convoys** drive their precinct at random. A convoy within earshot of gang gunfire stops, gets out and hunts the shooter. After a quiet spell it goes back to the cars.
- **Rules of engagement.** Police may fire on a gang member only:
  - once police have seen him targeting someone (the sighting goes out over the radio and lasts 90 s), or
  - while their QRF is clearing its search buildings.

  Holding gang members fire on police only once police have engaged their squad, and then for 45 s. Assault teams and anyone out hunting fire on police at will.
- **Retreat:** a gang member in combat who sees tactical police or the QRF makes a stress check and may break and run for the nearest building his gang holds. The check happens once per officer every 15 s. Rule 1 (the closest visible enemy within 10 m) still comes first.
- **Replacements:** every officer killed is replaced by a new hire at their station two minutes later. An officer who reaches the hospital alive is back on duty two minutes after that. Nobody is hired while on duty + recovering + hires due reaches the police cap (108 is full strength).

**Paramedics.**
- Every faction treats paramedics as friendly: nobody targets them, but bullets still hit them.
- Police paramedics drive out at once for any downed officer.
- The hospitals' ambulances (two each, two paramedics apiece) go in only after a QRF reports all clear. They collect every casualty within 120 m of the incident's report points, the living first.
- Two paramedics carry each casualty on a stretcher, up to two per ambulance, to the nearest hospital.
- The living are saved. The dead go to the morgue.
- Bodies nobody collects are cleared after 15 minutes.

**Watching it.**
- The camera:
  - Mouse wheel zooms from the whole city down to a single room.
  - Right- or middle-drag pans.
  - `Home` fits the city.
  - `Follow the fighting` (or `F`) keeps the camera on the busiest gunfight of the last 20 seconds.
- Left-click anyone to see their card in the panel. It shows:
  - name and rank;
  - echelon, form, strengths and weaknesses;
  - alert state and ammunition;
  - what they are doing and where.
- The panel shows:
  - each gang's strength, buildings, neighbourhoods, recruiting rate and current attack;
  - each QRF's state and its incident;
  - the patrols and the ambulances;
  - the feed of captures, pushes, assaults, reports and hires.
- What the map shows:
  - Far out, neighbourhoods show their dominant gang and its share.
  - Capture bars show who is taking a building.
  - Incidents pulse at the report point, and their search buildings are outlined.
- Speeds run 0.25x to 20x. A big city fight runs at roughly 2-3x real time on a typical desktop, and the panel shows the real rate.
- `Esc` returns to setup.

## Simplifications in this slice

- **The original house:** it is the 14 x 32 ft sketch scaled up to 5 x 13 m and turned on its side so two-person teams fit through it.
- **Doors:** every door opening is at least 0.9 m, the narrowest gap a body fits on the 0.25 m navigation grid. Doors are always open. Roll-up, dock and garage doors are open arches.
- **Path exposure (PF02):** counts doors and windows only. It is precomputed per map (on a 1 m lattice for the big maps), not updated live.
- **Perception:** pairs more than 15 m apart re-trace sight every 0.2 s, and pairs more than 30 m apart every 0.4 s.
- **Stoppages:** rates are raised (4 per 1,000 rounds for the rifle, 3 for the pistol) so stoppage drills show up in a short test.
- **Ducked stance:** an extra stance, "ducked", is fully behind half cover, with the eye at 0.8 m. The bible's crouched head (1.00-1.25 m) would otherwise show over 0.9-1.1 m cover.
- **City:**
  - The city's lots are walkable only from their street front: fenced back gardens are scenery.
  - Vehicles are drawn but don't block anyone or stop bullets.
  - Nobody fires from a vehicle.
  - Gang members go everywhere on foot.
  - Away from any possible enemy, people skip perception and think every third tick; standing posts sleep until something comes near.
- **Civilians and the department:** the city has no civilians yet, and its police do not judge or arrest (both come with the campaign map, v0.10). The department has no budget, training or discipline yet (v0.8). Orders, briefings and the fog of war are v0.7.
- **Out of scope:**
  - grenades;
  - multiple floors (the apartment stairs are scenery).

## Files

```
scripts/data/habits.gd    habits, traits, Experience, sound, echelons, weapons, individual variation
scripts/data/names.gd     the name bank (18 cultures)
scripts/city/*.gd         the city: generator, templates (police, hospital, school, parks), navigation, roads and vehicles, the director
scripts/city_main.gd      the Endless Battle scene
scripts/sim/geom.gd       obstacles, sight lines (with the low-cover rule), bullet traces with height
scripts/sim/level.gd      map base: walls from room rectangles, doors, room graph, posts for 20 a side
scripts/maps/*.gd         the eleven maps and the registry
scripts/sim/nav.gd        AStarGrid2D x4 (PF01/PF02 cost layers), cover spots, cached per map
scripts/sim/op.gd         operator state, stances and body zones
scripts/sim/world.gd      perception, tracking, hearing, aiming, shooting, wounds, stress, bad habits
scripts/sim/brain.gd      priorities P1-P8, elements, assault/hold/hunt, consolidation, habit hooks, arrests
scripts/sim/civ_brain.gd  civilians: alarm, flee, hide, freeze, comply, film
scripts/sim/incident.gd   the incident record: every round, findings and their evidence
scripts/campaign/department.gd  persistent officers: hiring, rolls, experience, wounds, files, saving
scripts/campaign/operation.gd   civilians' placement; team A from the department
scripts/view/*            floor plan, blood and residue, operators, overlays, the ledger, the city's layers
scripts/ui/ui.gd          setup, run, debrief and department panels
assets/svg/               all sprites, generated by tools/make_placeholders.py
tests/                    headless tests and an art gallery
```

## Headless tests

```
godot --headless --path . -s res://tests/maps_test.gd -- --run=1           # validate every map, then 5v5 and 20v20 on each
godot --headless --path . -s res://tests/stall_test.gd                     # six matchups per map; flags time-limit stalls
godot --headless --path . -s res://tests/scale_playtest.gd -- --n=4        # Playtest 02: big fights on every map, CSV
godot --headless --path . -s res://tests/perf.gd -- --map=10 --t=40        # where the time goes in a 20v20 fight
godot --headless --path . -s res://tests/fuzz_test.gd -- --n=60            # random maps, sizes, habits, traits, postures
godot --headless --path . -s res://tests/sim_test.gd -- --n=12             # matchups by echelon (map 00, 2v2)
godot --headless --path . -s res://tests/sim_test.gd -- --ablation         # 40 habits vs none, same reflexes
godot --headless --path . -s res://tests/playtest.gd -- --n=40 --cells=all # Playtest 01 matrix (map 00), CSV rows
godot --headless --path . -s res://tests/city_test.gd -- --seed=3          # build the city, check every room is reachable
godot --headless --path . -s res://tests/city_sim.gd -- --seed=3 --min=10  # the endless battle headless, with timings
godot --headless --path . -s res://tests/civ_test.gd -- --n=40             # v0.6 gate: operations with civilians, Patrol vs police tactical
godot --headless --path . -s res://tests/dept_test.gd                      # v0.5 gate: save, load, carry-over, replay
TR_STEP=1 godot --headless --path . -s res://tests/trace.gd -- --map=4 --a=sof --na=8 --b=militia --nb=8   # step-by-step trace
```

Every test takes `--map=N`. Playtest 01 results and recommended system improvements are in the second tab of the NPC CQB Bible.

Regenerate the art with `python3 tools/make_placeholders.py`. All art is original and project-owned.
