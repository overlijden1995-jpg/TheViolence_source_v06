# The Violence — Police Command Roadmap

Oct 16, 2026 · @Jaya

## Vision

The player is the newly appointed chief of the Port Carrick Police Department, 40 weeks before a three-way mayoral election, in a city that is running out of money, people and patience. The game alternates two loops. In the **department loop** the player runs the force week by week: budget, hiring, firing, training, discipline, policy. In the **operation loop** the player plans a tactical response: how many officers, which ones, what they must do and must not do. Then the player presses Run and watches through what the officers see and what their body cameras record. The v0.4 simulation plays it out; the only input left is to abort.

What happens in an operation is recorded in full and does not go away. Rounds through a wall, a shot at someone who was surrendering, a suspect who walked out the back: each becomes a file that surfaces weeks later as a complaint, a lawsuit, a news story or a lost ally. Voting happens in week 40; a one-week certification period follows, and its result decides how the game ends for the player.

&#91;embedded content: the two loops · immediate and delayed returns\]

Wounds and experience come back at the end of the operation. Everything else goes through the consequence queue and reaches the desk weeks later, directly or through the allies.

**Design pillars**

1. **The plan is the only lever.** Once Run is pressed, the player cannot issue orders. Pausing, slowing time and rewinding are viewing tools only, and the one decision left is to abort. This carries the original theme of The Violence into the new game: the gap between the briefing and what actually happens.
2. **The player sees what the officers see.** Briefings are never complete. During an operation the map shows only what officers have seen or called out over the radio. Body cameras show more, and record everything, for better and for worse.
3. **Nothing is forgotten, and nothing lands at once.** Every shot is in the record. Consequences arrive on delays that depend on the evidence and on how visible the situation was, and can always be traced back to the shot that caused them.
4. **Competence is grown, not bought.** Officers start halfway between irregulars and regular infantry. Training, experience and good sergeants close the gap slowly. Turnover, trauma and bad hires widen it.
5. **Allies are the resource that runs out.** Money, warrants, tips and labour peace all come from people who can withdraw them. Losing an ally takes a tool away for good.
6. **The city does not wait.** The endless-battle director keeps running between operations. Gangs take buildings whether or not the player is looking.
7. **There is no perfect playthrough.** Every officer sent to one situation is missing from another, every safe choice costs time or money, and every candidate wants something the others punish.

**What the player never does:** take direct control of an officer, give orders once Run is pressed, change what happened by rewinding (rewind only replays the record), reload a save to undo an operation (ironman is the default), or see a consequence's full outcome before it lands.

## Confirmed player experience and tone · 17 October 2026

**Elevator pitch.** *Ready or Not* meets *Door Kickers* meets *This Is the Police*, except the player cannot retry missions or stop an officer from pulling a trigger; cannot pause time to give troops perfect orders; and there is no record collection or fancy sports car. The game combines the grounded human horror and stakes of *Ready or Not*, the top-down CQB framing of *Door Kickers*, and the management layer plus a small piece of the satire of *This Is the Police* into a more realistic, grounded whole.

**The desk is the main game.** Day-to-day play is a spreadsheet-like chief's desk. 911 calls, anonymous tips, and calls from community leaders create time-sensitive missions; the player assigns available officers to them. The player may watch the city simulation, but does not directly command its agents. Event choices include yes/no offers, multiple choice, and Likert-scale decisions: for example, how much security to assign to an event or what level of reprimand to give an officer after civilian complaints. Unassigned work is handled by patrol or expires at a cost, rather than waiting indefinitely for the player.

**Event generation.** Random events are seeded and weighted by performance across separate categories and by relationships. Eligibility and hard gates come first; RNG chooses among events the campaign state actually permits. Event sources, deadlines, and consequences should be legible, while delayed outcomes may remain uncertain.

**Tone.** Black comedy and grounded satire, but never a celebratory or power-fantasy violence simulator. Aim the comedy at bureaucracy, political theatre, corporate interests, and euphemistic public relations—not at victims. The tactical operation can be tense and absorbing; the framing stays human, consequential, and uncomfortable.

**Candidate alignment.** Pruett's many small, compounding benefits are mainly administrative: he can defer an oversight timetable without cancelling the inquiry and use connections to expedite approved paperwork. His support depends on the player's overall performance, not pure loyalty or perfect competence. Garrow offers visible, conditional resources—anonymous donations, access to selected community leaders, and temporary contractor support—in return for loyalty and occasional specific favours; contractors never become permanent staff. Halvorsen is hardest to win: after an initial refusal to cooperate, she can provide anonymous tips and detailed local intelligence, help reduce media pressure and moderate protests, but expects officers who cross the line to be reprimanded or fired regardless of competence.

**Gang leverage.** Gang shooters can gain experience up to exceptional tactical competence without inheriting police equipment. Removing skilled shooters reduces a gang's ability to mount attacks; arresting a high-ranking member can additionally provide testimony and leverage against leaders. Leaders are named but hard to contact and protected by plausible deniability. They react to the player's observable Balance of Leverage (BOL): under sufficient pressure, a leader may restrain shooters, send an anonymous tip, or sacrifice a reckless street-level member. Such cooperation is tactical and unreliable, not a clean alliance or a shortcut to arresting the leader.

## What carries over from v0.4

Most of the hard work is already done: the operation loop is the v0.4 simulation with orders and civilians added, and the city layer is the endless-battle director. The new work is the campaign layer around them: persistent officers, the weekly turn, the consequence queue and politics.

| System in v0.4 | Where it lives | What it does now | What it becomes |
| --- | --- | --- | --- |
| Sim core | `world.gd` | 30 Hz world, factions with asymmetric hostility, 12 m spatial hash, dormancy | The operation sim, unchanged. Civilians are added as a new kind of faction. |
| CQB brains | `brain.gd` | Rules 1 and 2, assault, hold, hunt and support modes, elements of up to five, stacks, entries, sectors | The officers who carry out the player's orders. Orders become constraints on how elements choose and enter rooms. |
| Habits and echelons | `habits.gd` | 40 good habits, 20 bad habits, 5 echelons, experience tiers 1 to 5, quirks | The officer's skill sheet. Habits are learned through training, and experience sets how many orders a squad leader can carry. |
| Alert states and rules of engagement | `op.gd`, `world.gd` | Green, yellow and red; gangs targetable only when seen targeting someone or during a QRF clearance | A use-of-force policy the player sets. Breaking it is recorded and has consequences. |
| Wounds, bleed-out, hospitals | `world.gd`, `director.gd` | 5-minute bleed-out, ambulances and stretchers, recovery delay | Injury leave for officers. Whether a civilian survives depends on how long the ambulance takes. |
| Ledger of the dead | `ledger.gd` | Who, when, where, how and by whom, for every death | The evidence record behind every consequence, and a memorial wall for the department. |
| Director | `director.gd` | Gang captures, dominance, pushes, expansions, 911 reports, QRF dispatch, convoys | The city between operations. It generates the incidents that become operations. |
| City generator | `city_level.gd`, `roads.gd`, templates | Template lots, street graph, police stations, hospitals and schools | The campaign map of Port Carrick. Operation sites are cut from its lots. |
| Hand-built maps | `maps/m00`–`m10` | Test range, cabin, duplex, motel, warehouse, compound, apartments and others | Fixed operation sites for warrant service and barricade scenarios. |
| Names, stat variation | `names.gd`, `habits.gd` | A name and rank for everyone; form, jitter and quirks rolled every match | Rolled once at hire and kept for the officer's whole career. |
| Police replacement and hiring cap | `director.gd` | Dead officers replaced after 2 minutes, recovered officers return after 2 minutes, with a headcount cap | Replaced by the hiring pipeline and the budget. |
| Sound model | `habits.gd`, `world.gd` | Loudness by kind, halved by walls, hearing traits | Who hears the shots: which civilians call 911, flee or film. |
| Tests | `tests/` | Map checks, 40-match fuzz test, 20-minute city soak, deterministic replay | Kept, plus headless campaign runs, order tests and consequence tests. |

One behaviour has to change before anything else: stat variation is rolled fresh every match. Persistent officers need it rolled once, at hire.

## Setting: Port Carrick

Port Carrick stays the city, recast as a Great Lakes port that lost its steel mill and its parts plants and never replaced them. The city already generates 12 neighbourhoods and 6 precincts. Each precinct becomes a council ward with its own councillor, its own level of trust in the police and its own gang presence. The four gangs (Kilbride Crew, Corvino Family, Los Halcones, Zarya Bratva) carry over as they are.

**The city is on the brink.** The previous chief resigned in week 0 over a scandal the player inherits. The pension fund is underfunded, the state has threatened a fiscal oversight board, and every department is being asked to cut. Six numbers describe the city's condition and drift every week:

| Indicator | What moves it | Who watches it |
| --- | --- | --- |
| Homicides this year | Gang wars, operations, response times | Everyone, the press most |
| 911 response time (median) | Officers on patrol, overtime, fatigue | Council, residents |
| Clearance rate | Arrests that the DA can charge | DA, law-and-order candidate |
| Use-of-force incidents | Operations, policy, officer judgment | Reform candidate, community groups, press |
| Police budget gap | Salaries, overtime, settlements, grants | Mayor, council, the state |
| Trust in police, per ward | All of the above, plus what the press reports | Councillors, community groups |

**The election.** Three candidates, all fictional, none tied to a real party. Voting takes place in week 40; the game concludes after a one-week certification period in week 41:

- **Mayor Dale Pruett**, the incumbent who appointed the player. Aggressively boring: his stump speech is about procurement timelines and his slogan is "Pruett: It Mostly Works". He is a competent administrator with very few reform ideas, and one of the game's few sources of comic relief.
- **Council President Victor Garrow**, a corrupt authoritarian who happens to be very pro-police. He holds the city's towing and demolition contracts, wants curfews and emergency powers, and has the union's ear.
- **Councillor Anne Halvorsen**, a democratic socialist who genuinely wants to help the city and is openly, sharply critical of the police. She has a personal vendetta against the player. Proposed backstory: years ago, as a lieutenant, the player led the raid that shut down the tenants' union she organised.

**Campaign calendar (40 campaign weeks plus one certification week)**

| Week | Event | Why it matters |
| --- | --- | --- |
| 1 | Player sworn in | Inherits the old chief's open files |
| 6 | Council budget hearing | Sets the money for the next 20 weeks |
| 12 | Union contract expires | Negotiation: pay, shifts, discipline rules |
| 20 | Candidate filing deadline | The race is set, endorsements open, rallies start appearing on the operations board |
| 26 | Mid-year budget amendment | Second chance at money, or a cut |
| 28 | Debates and union endorsement | Candidates start using the player's record |
| 34 | Early voting | Late scandals hit hardest; rallies get bigger |
| 40 | Election day | Vote count establishes the winner and official opposition; the certification week begins |
| 41 | Certification | Hard-gated, seeded events based on prior performance and choices; certification finalizes the result and ending |

## Loop A: the department

One turn is one week, played at the chief's desk. The player spends three limited things: **money**, **officer-hours** and **standing with allies**. Only the money is printed on a balance sheet.

**The weekly turn**

1. **Morning report.** Last week's numbers, the ledger, press clippings, and any consequences that came due (see Consequences).
2. **Desk.** Personnel, budget and policy decisions, in any order. Most take effect next week.
3. **Operations board.** The director has turned the week's events into situations. The player chooses which ones get a planned operation. The rest are handled by patrol at a statistical cost: slower response, more risk, no player control. There is no cap on how many officers a situation gets, but an officer sent to one is missing from every other.
4. **Operations.** Each chosen situation is planned and run (Loop B).
5. **End of week.** The city advances a week. Officers tire or recover, the consequence queue ticks, and allies react.

**Desk actions**

| Area | Actions | What it costs | Who notices |
| --- | --- | --- | --- |
| Hiring | Academy class (8 weeks, cheap, Patrol skill); lateral hire (arrives next week, costs more, comes with a skill level and a past record) | Salary, academy cost, a council vote over the budgeted headcount | Council, union |
| Assignment | Patrol, tactical team, detective, desk, field training officer; pair rookies with trainers | Officers on desk duty do not patrol | Union, if seniority is ignored |
| Promotion | Corporal, sergeant, lieutenant, by exam list or the chief's pick | Salary; a pick from outside the exam list angers the union | Union, the passed-over officers |
| Training | Courses that teach specific good habits (CQB entry, eye discipline, de-escalation, first aid); range days | Money, and the officer is off the street for 1 to 3 weeks | Council (cost), community groups (de-escalation) |
| Equipment | Rifle plates, soft armour, rifles or pistols only, less-lethal weapons, radios; body cameras, which also let the player see more during operations | Money; some items need a council vote | Reform candidate (body cameras), union (armour) |
| Scheduling | Shift pattern, overtime cap, days off | Overtime money; fatigue raises stress in operations | Union, the budget |
| Policy | Use-of-force policy, rules of engagement, pursuit policy, no-knock warrants, body camera release policy | Changing a policy costs standing with whoever opposed the change | Everyone, depending on the policy |
| Discipline | Counselling, written reprimand, suspension without pay, desk duty, administrative leave, termination | Fired officers can be reinstated by arbitration if the union grieves | Union, the press, the officer's squad |
| Internal affairs | Open, staff and close investigations; findings of sustained, not sustained, exonerated or unfounded | Investigators are officers who are not on the street | Reform candidate, DA, union |
| Union | Negotiate the contract in week 12; settle or fight grievances | Money, discipline powers, shift rules | Union, mayor |

**Firing is not the end of a problem.** A terminated officer can be reinstated by arbitration, with back pay. The player can also put them on desk duty, which costs a salary but keeps them out of operations. Officers who resign under investigation may turn up as lateral hires in neighbouring towns, or as witnesses in a lawsuit.

**The Brady list.** When an officer's honesty is found wanting (a false report or a sustained finding of lying), the DA adds them to a disclosure list. The DA stops taking cases that depend on their testimony, so their arrests no longer count towards the clearance rate. The officer can still patrol and fight, but every arrest they make is worthless.

## Loop B: the operation

An operation has five screens: briefing, force, orders, Run and the debrief. Everything the player decides happens before Run, except whether to abort. After it, the v0.4 brains carry out the plan as well as their habits, stress and experience allow.

**1. Briefing.** A situation card with the site's floor plan, its visibility rating, what is known about who is inside, the time pressure and whose ward it is in. Floor plans come from the city's lots or the hand-built maps. **The briefing is never complete.** Each occupant appears as an estimate with a confidence. Tips from the public and from community allies turn estimates into facts: how many, which weapons, the hostage's room, the hour the suspect sleeps. A ward whose community group has broken with the department sends no tips.

| Situation | Visibility (1–5) | Time pressure | Usual occupants | Typical risk |
| --- | --- | --- | --- | --- |
| Political rally or public event (proactive patrol) | 5 | Set by the event | A crowd and a candidate; usually nobody armed | Nearly always nothing. If something happens and security was thin, a catastrophe on live TV |
| Active shooter | 4–5 | Extreme | One or two shooters, many civilians | Going slow costs lives; going fast causes mistakes |
| Hostage | 3–4 | High | Captors and hostages mixed together | Hostages hit in a crossfire |
| Barricaded suspect | 2–3 | Low | One armed suspect, sometimes others | Impatience; rounds through walls |
| Shots fired (QRF) | 1–3 | Very high | Unknown; whoever reported it is nearby | Arriving into an ongoing gang fight |
| Warrant service | 1–3 | None; the player picks the hour | A suspect, family, neighbours through the walls | Shooting the wrong person on entry |
| Gang house raid | 1–2 | Low | Several gang members, a few bystanders | A firefight in tight rooms, far from help |

**Visibility** is how many people are watching: neighbours, phones, reporters, live cameras. It multiplies the press and political weight of everything that happens, good or bad, and how likely it is that witnesses and video exist. The hardest situations sit in isolated neighbourhoods at visibility 1 or 2: more guns, fewer tips, longer ambulance runs, and mistakes that may stay quiet for months. A rally at visibility 5 will probably pass without incident. If it does not, and security was thin, and above all if police kill civilians, the damage is catastrophic and immediate.

**Proactive patrols.** Some situations are a presence rather than a response: a rally, a parade, a funeral a gang may attack, a corner the night after a shooting. The player assigns officers to posts and patrol routes for the event's duration and presses Run. Most of the time nothing happens, and the speed control lets the hours pass quickly. Whether anything will happen is hidden; tips raise or lower the estimate but never confirm it.

**2. Force.** There is no limit on how many officers the player sends, from those not injured or on leave. Every officer sent is unavailable for every other situation that week, so over-assigning an easy situation is how the hard one ends up short. More officers also cost overtime and crowd the hallways, which raises the risk of friendly fire. The player groups them into squads of up to five, matching the brain's element size. The highest-ranking member leads each squad, with ties going to the most experienced.

**3. Orders.** Every squad gets one objective for free. Further objectives and every constraint cost order points, and the squad leader's experience sets how many points the squad has:

| Leader's experience | Order points |
| --- | --- |
| Green (tier 1) | 1 |
| Blooded (tier 2) | 2 |
| Seasoned (tier 3) | 3 |
| Veteran (tier 4) | 5 |
| Exceptional (tier 5) | 7 |

A newly promoted sergeant with no experience can carry one constraint. That makes promotion decisions matter in the field, not only on the budget.

| Order | Kind | Points | How the simulation enforces it |
| --- | --- | --- | --- |
| Clear (building or listed rooms) | Objective | 0 or 1 | The element's room picker only takes those rooms; the squad is done when they are clear |
| Arrest (a named suspect) | Objective | 0 or 1 | A new arrest action: a suspect who complies is cuffed instead of shot |
| Rescue (hostages) | Objective | 0 or 1 | Hostages are escorted out to a casualty point |
| Contain (hold a perimeter) | Objective | 0 or 1 | Hold mode on the listed doors and windows; anyone leaving is challenged |
| Post (stand at a point for the event) | Objective | 0 or 1 | Hold mode at the point, facing the given sector, for the event's duration |
| Patrol route | Objective | 0 or 1 | The existing hunt mode walks the given route instead of the level's own patrol |
| Avoid (a hallway, door or room) | Constraint | 1 | That squad's path cost through it becomes infinite |
| Consolidate (room X before going on) | Constraint | 1 | The element holds in X until every door off it is covered or checked |
| Phase line (wait for a squad or a time) | Constraint | 1 | The room picker is blocked until the condition is met |
| Entry point (use door X) | Constraint | 1 | The first entry is fixed to X |
| Pace (walk or creep only) | Constraint | 1 | Movement speed is capped; quieter and slower |
| Weapons tight | Constraint | 2 | Fire only at someone firing or pointing a weapon; a stricter rule of engagement for that squad |
| Knock and announce | Constraint | 1 | Occupants are alerted at the start: suspects get time, civilians get to comply |
| Pistols only | Constraint | 1 | No rifles, so fewer rounds through walls and less reach |

**Orders can be broken.** Rule 1 (the closest visible enemy within 10 m) still overrides everything. Active bad habits can override constraints as they override good habits: an aggressive officer with Chase the contact runs down the forbidden hallway after a suspect, and one with Rush the room goes in before the room behind is consolidated. Every broken order is written into the incident record.

**4. Run.** The player sees only what the department knows. Officers' own positions are always shown. What an officer wearing a body camera can see is shown live. Everyone else, suspects and civilians alike, appears only as last-known positions from radio callouts, the existing callout and last-known-position system; the rest is fog. Pause, slow motion and rewind are viewing tools only: rewinding replays the record, and the simulation carries on from where it was.

The one real input is **Abort (cut losses)**. Every squad breaks contact and withdraws to the vehicles, still under fire until it gets there. An aborted operation counts as a failure, but a failed operation with everyone alive always scores better than one with deaths.

**5. Debrief.** Objectives met or failed, a timeline and a full replay with the fog lifted. For each officer: shots fired, hits, where the misses went, and any orders broken. Then civilians hurt, experience gained and injuries. It ends with a count of files that have been opened, but not what they contain.

## Officers

Every officer is a persistent record: rolled once at hire, changed by training, experience and harm, and kept until they leave or die. A new hire is a sixth echelon, **Patrol**, set at the midpoint between Militia / irregular and Regular infantry in every stat.

| Stat (from `habits.gd`) | Militia | **Patrol (new)** | Regular | Police tactical |
| --- | --- | --- | --- | --- |
| Recognition time, t\_rec0 (s) | 0.42 | **0.39** | 0.36 | 0.32 |
| Time on target, a / b (s) | 0.25 / 0.17 | **0.225 / 0.155** | 0.20 / 0.14 | 0.17 / 0.12 |
| Turn rate (°/s) | 360 | **450** | 540 | 540 |
| Stress resistance | 0.25 | **0.375** | 0.50 | 0.65 |
| Reload / transition (s) | 1.3 / 1.0 | **1.2 / 0.9** | 1.1 / 0.8 | 1.0 / 0.7 |
| Default good habits | 8 | **12** (Militia's 8 plus 4 of Regular's) | 17 | 25 |
| Experience tier | 1 | **1 (Green)** | 2 | 3 |
| Armour | none | **soft vest** (new: stops pistol rounds only) | 2 plates | 2 plates |

The existing form factor, jitter and one or two quirks are rolled on top at hire. Two Patrol rookies can differ as much as a good Patrol officer and a poor Regular.

**How officers get better**

- **Experience.** Surviving contact (being shot at, recognising an armed suspect, making entries) earns experience. Each tier adds one tracked enemy, and one or more order points when the officer leads a squad.
- **Training.** Courses teach named good habits: an entry course teaches PF03 and PF04, an eye-discipline course ED01 to ED03, and so on. A course takes 1 to 3 weeks off the street. A habit not used in operations for 20 weeks can be lost.
- **Field training.** A rookie paired with a field training officer can pick up one of the trainer's habits every few weeks. They can also pick up one of the trainer's trait-driven bad habits.
- **Rank.** Officer, corporal, sergeant, lieutenant, captain. Rank decides who leads a squad, and the leader's experience decides how many orders the squad can carry.

**How officers get worse**

- **Fatigue.** Overtime raises the officer's starting stress in an operation, so stress-driven bad habits switch on sooner.
- **Trauma.** Firing a fatal shot, being wounded or seeing a partner die adds trauma. High trauma raises baseline stress, can add a trait bad habit, and leads to sick leave or resignation. Counselling lowers it, at the cost of time off.
- **Traits.** The existing personality traits (Aggression, Anxiety, Ego, Complacency, Rigidity) keep driving the trait bad habits. Three new traits drive behaviour off the battlefield: **Judgment** (how long the officer takes to decide whether a person is a threat), **Temper** (force used on someone already complying) and **Integrity** (whether reports match what happened).

**The record.** Each officer carries a file the player can read at any time: operations, rounds fired and where they went, uses of force, complaints, commendations, internal affairs cases and their findings, discipline, training, injuries, and the Brady flag. Lawyers, reporters and the DA read the same file when consequences come due.

## Civilians

Civilians run on the same simulation as everyone else, as a parallel population with their own brain. They generalise the v0.4 paramedic rule: no faction targets them, but every bullet can hit them. Most collateral damage comes from three places: rounds through walls, crossfire, and an officer deciding too fast that a person is a threat.

&#91;embedded content: civilian states · 5 behaviours, 1 shared risk\]

**What a civilian does.** Each civilian starts unaware. A gunshot heard through the sound model, or a person with a gun in sight, makes them alarmed. Then they act on their personality: flee, hide, freeze, comply with an officer's commands, or film on a phone. Elderly or injured civilians move slowly. Some go back towards the scene once the shooting stops.

**Deciding who is a threat.** Today an operator who recognises an enemy can fire at them. With civilians present, recognition gets a second step: deciding whether this person is a threat. The officer's **Judgment** trait sets how long that takes. Darkness, fast movement and something in the hand (a phone, a tool) make it harder. The existing bad habit Jumpy trigger (BH09: fires at movement within 10 m once recognition is half done, friend or foe) is how most civilians get shot by police. Fatigue and stress switch it on.

**Suspects can give up.** The same comply behaviour lets gang members and suspects surrender: hands up, weapon dropped, prone on command. Officers get a new challenge action (verbal commands) and an arrest action. A shot at someone who has already complied is recorded as excessive force. So is the existing Overkill habit (BH03: keeps firing into a downed target).

**Walls stop some rounds, not all.** Walls get a material: drywall, brick or concrete. Rifle rounds pass through drywall into the next room or the next apartment. Every round is traced to where it stops, so a miss in the kitchen can wound a neighbour two rooms away.

**Witnesses and video.** A civilian who sees or hears an event remembers it: who fired, at whom, and whether that person was armed. Some film it. Body cameras record what the officer wearing one saw, if the department has them. Witnesses, phone video and body camera footage together set how strong the evidence is for each event, and that strength sets how hard and how fast the consequences land.

**Casualties.** Wounded civilians use the existing bleed-out and ambulance system. Whether they survive depends on how quickly paramedics reach them, which operations can delay. Civilian deaths go into the ledger like everyone else's.

**On the city map,** civilian density varies by ward and hour. A night operation finds fewer people on the street and more people at home behind thin walls.

## Consequences

Every operation writes an incident record, and each finding in it lights one or more fuses that burn for weeks before they land. The player sees that a file was opened, not what will come of it. Every consequence that lands names the operation, the officer and the shot that caused it.

**The incident record** is built from the simulation, not from a summary. It holds every round (who fired, at whom, whether the target had been judged a threat, where the round stopped), every broken order, every death from the ledger, civilian injuries, property damage, objectives met or failed, and the evidence for each event: witnesses, phone video, body camera footage.

**Fuses**

| Fuse | Lit by | Delay | Faster or harder with | What lands |
| --- | --- | --- | --- | --- |
| Public-event failure | Violence at a visibility 4–5 event with thin security; police killing civilians there | Same day | Live cameras, a candidate on stage | Every ally reacts at once: the press story, the lawsuit and the council's anger land together |
| Complaint | Force on a complying person, a civilian hurt, a rude entry | 1–3 weeks | Witnesses | An internal affairs case that must be staffed |
| Press story | Any civilian death, an officer killed, a failed hostage rescue, phone video | 1–6 weeks | Visibility, video (lands in days) | Trust drops in the ward; allies react |
| Civil lawsuit | Civilian injury or death, wrongful entry, excessive force | 4–20 weeks | Strong evidence, a Brady-listed officer | A settlement or a trial; the money comes out of the police budget |
| DA review | Any fatal police shooting | 8–16 weeks | Video that contradicts the report | Charges against the officer; the union reacts |
| Protest | A death on video in a low-trust ward | Days | Low trust, earlier incidents in the same ward | A crowd situation on the operations board |
| Gang retaliation | Gang members killed or arrested | 1–4 weeks | The gang's strength in the director | A push against officers or a station |
| Federal inquiry | Several sustained excessive-force findings within a year | Months | Earlier lawsuits | A pattern-or-practice investigation, then a consent decree that locks some policies |
| Officer trauma | Fatal shots, wounds, a partner's death | 2–10 weeks | Overtime, no counselling | Sick leave, a new bad habit, or a resignation |

**Visibility scales every fuse.** The same shot can stay buried for months at visibility 1 and land the same day at visibility 5. Low visibility never erases a finding: the record still exists, and reporters, lawyers and a hostile candidate can dig it up.

**Incompetence is scored separately from force.** A clean operation that fails is its own kind of damage: the suspect escapes out the back, the hostage dies while the squad waits on a phase line, two officers shoot each other in a hallway, the team takes three hours, or rifles are left behind. An aborted operation is a failure too, but always a smaller one than a failure with dead officers or civilians. It lights its own fuses: press stories, the DA declining cases, the union blaming leadership, lost council votes.

The department therefore has two reputations, kept separately with each audience: **force** (how violent the department is) and **competence** (whether it gets results). The reform candidate and community groups weigh force most. The union and the law-and-order candidate weigh competence and officer safety. The mayor and council weigh both, and the budget.

**What the player can do while a fuse burns**

- Discipline the officer early, which costs standing with the union and gains it with reformers.
- Release the body camera footage, which speeds up the press story but takes the sting out of the lawsuit if the footage clears the officer.
- Settle early, which costs money now but avoids a trial during the campaign.
- Fight it, which saves money if the department wins and costs much more if it loses.
- **Bury it.** Hold the report back. Nothing happens now, but a hidden fuse is lit. If a witness or a video later surfaces, the original consequence lands together with a cover-up, which is worse than either.

## Politics and the election

Seven allies each give the department one thing it cannot get elsewhere. Each has a standing from 0 to 100 that moves with the department's record and the player's choices. Below its break point, the ally stops cooperating and the tool it provided is gone for the rest of the campaign. Above the break point, standing can always be rebuilt.

| Ally | What they give | Break point | When they break |
| --- | --- | --- | --- |
| Mayor Pruett | The player's job, emergency money, cover with the press | 25 | No emergency money. At 10 he fires the player before election day. |
| Council public safety chair | Budget votes, extra headcount, equipment purchases | 30 | Hiring freeze and an overtime cap imposed by council |
| Police union | Flexible shifts, no grievance over minor discipline, its endorsement | 30 | Every discipline grieved, arbitration reinstates fired officers, a sick-out takes some officers off duty for a week, endorsement goes to Garrow |
| District Attorney | Search and arrest warrants, charges that count towards clearance | 30 | Warrant operations take two weeks to approve, fewer cases charged, the Brady list grows |
| Community groups (one per ward) | Tips that reveal more in the briefing, witnesses who cooperate, calm after an incident | 25 | No tips from that ward (more unknowns in the briefing), protests more likely |
| The Carrick Herald | The benefit of the doubt: press fuses are slower and smaller | 30 | Reporters dig into old files and can surface buried reports |
| The state | Grants for cameras and training, state police for large operations | 20 | The fiscal oversight board takes control of the police budget |

**How the election is decided.** Each ward has its own mix of voters. Each week, the three candidates' support in each ward moves with the six city indicators, the department's force and competence reputations, endorsements, and whatever the press is running that week. The player is not on the ballot, but the department's record is the main issue in the race. The player can read polling once a week, with noise. Each candidate's rallies appear on the operations board: a rally that goes wrong moves votes against whoever was meant to keep it safe, which means the player and the mayor who appointed them. Garrow's rallies draw counter-protesters, and Halvorsen's draw officers' resentment.

**Completed-election endings and personal epilogues**

Only a player who reaches and completes certification gets one of the completed-election outcomes. Earlier dismissal, resignation, or loss of authority is a separate campaign ending.

- **Six campaign-level completions:** the election winner paired with the candidate who forms the official opposition. With three candidates, these are the six ordered winner/opposition pairs.
- **Nine personal epilogues:** the winning candidate paired with the player's relationship band with that candidate: below 30, 30–70, or above 70. At the boundaries, 30 and 70 belong to the neutral band.
- Compose the campaign-level result and the personal epilogue rather than writing a separate monolithic ending for every combination. Voting is in week 40; hard-gated, seeded certification events occur in week 41 and depend on the player's prior performance and choices.

The **neutral relationship band is the best personal epilogue**: the player remains an imperfect, moderating influence—too valuable to replace, too principled to trust blindly. High relationship looks materially good for the player but hints at political loyalty, growing cynicism, and collusion. Low relationship ends in a respectful request for early retirement, leaving the player with a sense of integrity. None is a clean victory. Every completed ending accounts for everyone who died during the player's tenure: officers, suspects, gang members, and civilians.

## Roadmap

Seven milestones take v0.4 to a first full campaign. Planned operations become playable at v0.7, before the department exists, so the heart of the game can be tested and tuned early.

&#91;embedded content: milestones v0.5 to v1.0 · 7 phases, 7 gates\]

The order is chosen so each milestone can be played on its own: v0.5 and v0.6 use the existing maps, v0.7 adds the planning screens, and only v0.8 onwards needs the campaign layer. Versions are listed in order, not against dates.

**Status, 16 October: v0.5 and v0.6 are built** and both gates pass. Department officers keep their roll from hire, and experience, wounds and files survive a save. An operation run from a reloaded save replays exactly. Over 40 operations with 8 civilians each, Patrol officers put 36 rounds into civilians and Police tactical 18. Misjudgments were 14 against 3, and shots after someone gave up or went down 29 against 0. One tuning point for v0.8: Patrol officers hit each other about once per operation (19 hits in 20 operations), some of it through partition walls, while Police tactical never did. Training in lines of fire (GD03, WD10) is the intended fix.

## Technical plan

The game becomes three layers that talk through two small records. The **campaign layer** is new: pure data, advanced once per week. The **city layer** is the existing director. The **operation layer** is the existing world and brains. An operation takes an *operation spec* in and gives an *incident record* back. Nothing in the operation layer reads campaign state directly.

| Piece | Where | Work |
| --- | --- | --- |
| Campaign state | new `scripts/campaign/` | Week, budget lines, roster, allies, wards, the six indicators, policies, the fuse queue, the campaign seed. Plain dictionaries saved as versioned JSON, matching the code's existing style. |
| Officer record | new `officer.gd` | Everything in the officer's file, plus the stat roll made at hire. `Op` objects are built from the record at the start of an operation and written back at the end. |
| Operation spec | new | Site (a city lot or a hand-built map), visibility, officers and squads, orders, suspects and civilians with what the briefing reveals about them, time of day, seed. |
| Incident record | new recorder in `world.gd` | Built from the world's existing events (shots, hits, blood, deaths) plus the new ones: threat judgments, broken orders, rounds through walls, what each witness saw, what each body camera recorded. |
| Intelligence and tips | campaign layer | Each occupant has a true state and a briefed estimate; tips from the public and community allies reveal facts one at a time. |
| Orders | `brain.gd`, `nav.gd` | A per-team cost overlay in the nav graph (Avoid, Entry point); objective and phase-line filters in the element's room picker; Consolidate as a hold before the next task; a pace cap; Weapons tight as a per-squad hostility rule; Post and Patrol route on the existing hold and hunt modes. |
| Abort | `brain.gd` | A withdraw posture: break contact, fall back along the entry route, mount up. |
| Fog of war view | new view layer | Drawn from the department's knowledge, not the world: officer positions, the vision cones of officers with body cameras, and last-known positions from the existing callout system. |
| Pause, slow motion, rewind | `world.gd`, view | A snapshot of the world every second while running. Rewind shows snapshots; the simulation itself never goes back, so it stays a viewing tool. |
| Civilians | new `civ_brain.gd` | A small state machine, much cheaper than the CQB brain, dormant until alarmed. Uses the existing sound model and the paramedic targeting rule. |
| Threat judgment | `op.gd`, `brain.gd` | A second recognition stage after the existing one, timed by Judgment. |
| Wall penetration | `level.gd`, `geom.gd` | A material per wall; a round continues through with less energy instead of stopping. |
| Week resolution | `director.gd` | The director runs headless for a slice of city time each week to move territory and produce reports. Situations the player does not take are resolved with rates calibrated from headless operation runs. |
| Desk UI | new scenes | Tabs: morning report, roster, budget, policy, operations board, allies and press. |

**Determinism stays a hard rule.** Each operation is seeded from the campaign seed and its index, so any operation can be replayed exactly from its spec. That gives the debrief a full replay, and the game can show the reconstructed footage that reporters or lawyers would see.

**Saves.** One ironman slot, saved at the start of every turn, with a schema version and a migration step for each change.

**Tests to add**, beside the existing map check, fuzz test, soak and replay test:

- A headless 40-week campaign played by a scripted chief, which must finish without errors and without the budget going negative silently.
- One test map per order, where obeying the order and ignoring it give measurably different outcomes.
- Consequence tests: the same operation with and without video must produce different fuses.
- A save and load round trip that gives the same next week.

## Risks and open questions

The biggest risk is that watching without control feels helpless, so the debrief and replay carry most of the design weight. The open questions below should be settled before v0.7, because they change the planning screens.

**Risks**

| Risk | Why it matters | How the plan handles it |
| --- | --- | --- |
| Watching without control feels helpless | The player cannot fix a mistake once Run is pressed | Abort is always available, rewind lets the player see what they missed, and the debrief and replay show why each thing happened |
| Delayed consequences feel random | A lawsuit in week 30 means nothing if the player cannot trace it | Every consequence names the operation, officer and shot, and links to the replay |
| Quiet patrols are dull | A rally where nothing happens is most rallies | Fast speeds while nothing happens; the tension is in the assignment decision, not the watching |
| Two games' worth of scope | A management game and a tactics game, each a full project | Each milestone ends with something playable; the operation loop is playable before the department loop exists |
| Balance between Patrol officers and gangs | Gang squads are 70% untrained, 20% militia and 10% regular, so Patrol officers may win too easily or lose too often | Headless batches of each situation type before tuning anything by hand |
| Performance with civilians | Hundreds of extra agents in the city, and crowds at rallies | Civilian brains stay dormant until alarmed, and the city slice each week runs headless |
| Tone | Police violence and elections are real and current subjects | A fictional city, candidates and parties; satire aimed at all three candidates; the simulation shows outcomes without taking a side |

**Open questions**

- [ ] Is the player appointed by Pruett, or an acting chief he can pass over?
- [ ] How often should a rally turn violent: 1 in 10, 1 in 20?
- [ ] Without body cameras, should the player see anything beyond radio callouts?
- [ ] Do minors appear among civilians, which affects the game's rating and tone?
- [ ] Is ironman the only mode, or is there a save-anywhere difficulty?

Settled on 17 October: 40 campaign weeks followed by one certification week; pausing, slow motion, and rewind are viewing tools only; the player cannot retry or issue orders after Run; any abort is a mission-level withdrawal, never an individual hold-fire command.
