# Tactical Experience Update

## Current Revision: Comms Slots, Enemy Logistics, and Cut-ins

- Squadron-dependent advisors: picking the Takut squad swaps Lester into the tactical slot and Almo into the logistics slot, with Coco and Noah moving to the side channels. Economy and advisory lines are authored per personality in `config/economy_lines.lua`.
- Map-wide character uniqueness: random reinforcements, production and recruits skip pilots already on the field, falling back to reuse only when a role pool is exhausted.
- Menu safety: ESC in the main menu opens a quit confirmation dialog (with buttons and keyboard paths), and ESC in battle pauses first and requires a second press to leave for the menu. The menu uses the original title emblem (`assets/ui/title_logo.png`) as decoration.
- Sound coverage expanded: unit destruction, low-armor warning, production/research completion, reinforcement arrival, invalid order buzz, victory and defeat stingers. New files come from the raw `dump` audio pool and can be swapped by editing `config/audio.lua`.

- Instructor, researcher and squad logistics channels are independent FIFO slots (`systems/comms_slots.lua`): messages queue per slot instead of overwriting. Coco no longer opens every mission with a self-introduction, and her panel yields completely while Noah teaches the logistics steps, which fixes the duplicated tutorial display.
- The Takut squad has a real division of labor. Lester (021) delivers formal guidance and formation criticism, Almo (026) provides energetic encouragement, and Takut (020) appears in story and chatter only. New exchanges cover the lazy-commander banter between Takut and Lester plus squad teaching between Lester and Almo.
- Enemy logistics officer Solbe (074) joins with a red comms bubble, red avatar frame, hostile lines and threshold reactions to enemy losses and player setbacks. Friendly and enemy logistics join cheers, criticism and mid-battle reactions through their own slots.
- Enemy special attacks trigger side cut-ins too, using a smaller red panel with independent scan-line effects. Slow motion applies to both factions, and cut-ins shift left with the fleet management panel using one shared offset.
- The mothership status panel shows Kazuya's portrait, and Noah's standing art is cropped to the upper body so the researcher slot matches the instructor's scale.
- Mission lifecycle regression checks cover single-fire interludes, idempotent finish scenes, intro skipping, slot queue order and enemy faction slots. `--verify --logistics-shot` captures the three logistics slots.
- `assets/backgrounds` was slimmed from 205 MB to 9 MB. The 156 unused files (unused frames, raw BMP duplicates, unused glow maps) are archived under `dump/raw/backgrounds` with a manifest; the runtime only ever referenced eleven images plus the static menu backdrop.

## Missions, Skills, and Maintenance

- Map portraits are always visible for living ships; the lower pointer faces the ship. Friendly frames are gold/white and enemy frames are red. Clicking a map portrait selects or inspects its ship; enemy inspection no longer issues a left-click attack.
- Supply now has an explicit undocking stage that clears stale targets and moves each unit away from the mother ship.
- Skill presentation leaves the camera unchanged and uses up to three compact side cut-ins. Kazuya and Natsume standing art is corrected and renamed. Snipers charge a dodgeable piercing beam, bombers schedule area salvos, interceptors dash along a collision-tested route, repair craft offer fleet or targeted healing, and shields remain visibly animated.
- The 11 level scripts own fixed introductions, interludes, endings and tutorial text. The ten combat levels have escort, survival, flagship or wave-clear objectives. Deployment preserves existing reinforcements and adds scripted friendly/enemy support.
- Per-pilot dialogue contains event lines and contextual chatter. Following weights the corresponding pair; casual chatter and repeated interactions have cooldowns.
- Fleet management has a larger visible toggle and Noah greeting, with repeated-open feedback. Three finite mineral deposits support station construction and mining. Recruitment and research remain in the right dock.
- Pilot names are the primary unit labels. Automatic skill preferences, dock state and sound volume are stored in LÖVE's `saves/preferences.tbl`. Existing OGG effects are connected through a bounded audio mixer.
- Read `MAINTENANCE.md`, `docs/STORY_AUTHORING.md` and `docs/ASSETS.md` for the current contracts, writing examples, sources, test commands and limitations. Older entries below describe earlier revisions and may be superseded by this section.
- Verification includes Lua compilation, both squad choices on all mission objectives, supply departure, finite mining, skill impact/dodge/cancellation, map inspection, multiple cut-ins and OGG decoding. Full visual captures use 960x600 and 1280x800 LÖVE windows.

## Numbered Cast and Fleet Economy

- `config/characters.lua` preserves the supplied number/name catalog and special speech rules. `config/pilots.lua` now contains ship-role casting pools, filtered against local `facNNN` portraits. Unit character IDs remain stable. Missing full standing art is skipped rather than substituted with a different character.
- Instructor 025 is Coco (可可); researcher 022 is Noah (诺阿), using the supplied standing illustration. Wide screens show left/right advisors together; compact screens prioritize the active research speaker. Square portrait frames replace circles; the extra white bubble underlay is removed.
- Repair craft have low-powered guns and accept attack, attack-move, follow, and move commands. Explicit repairs remain available. Stationary collectors are excluded from fleet movement commands.
- Click the resource/production label above the roster to manage the mother-ship queue. Initial credits, passive income, kill salvage, fighter/repair production, collector construction, and three levels each of armor/fire-control research are configured in `config/economy.lua`.
- The queue holds four jobs. Paid jobs can be cancelled for a full refund. Pause freezes progress; loss of the mother ship aborts outstanding jobs with a refund. Tech applies to existing and newly produced friendly units. Collectors are built near the mother ship and provide income; free placement and enemy production are not implemented in this pass.
- Verification adds costs/refunds, production, collector income, current/new-unit tech, pause, mother-ship loss, numbered identities, and repair attack/movement. Use `--verify --compact --economy-shot` or `--verify --radio --economy-shot` for layout captures.

## Character and Battle Pacing Pass

- Fixed middle-button panning with event-driven motion and final release displacement; tested without any intervening update frame.
- Character profiles, dialogue pools, and personality live in `config/pilots.lua`. Expressions are selected from inspected filename variants, not an assumed universal suffix scheme. Active art is copied to `assets/portraits`, `assets/characters`, `assets/comms`, and `assets/effects`; source art remains intact.
- Radio uses three simultaneous short white bubbles, horizontal flip-in animation, typewriter text, expression changes, and damage interference. Map portraits use white outlined location pins. The instructor uses a separate lower channel; full standing art appears during training.
- Added `level_00.tbl`: selection, pan/zoom, movement, attack, and a guaranteed shield-skill exercise. Complete it and press Enter to return. The instructor warns about critical damage, comments on losses, praises kills, and reacts to repeated invalid orders. Idle dialogue rotates with cooldowns.
- `config/pacing.lua` controls 1.6x map spacing, 2.4x hull health, 1.3x attack cooldown, retained movement speed, limited missile steering, imperfect lead, and spread. Multi-projectile damage now shares the volley damage rather than multiplying it for missiles and beams. Passive energy regeneration prevents total inactivity after losing supply.
- Target loss can retarget nearby enemies; AI no longer chooses to defend a nonexistent mothership. Units caught below an obstacle flight layer climb out rather than permanently failing their route.
- Skills have a windup, visible charge ring, target revalidation, and SP refund on cancellation. Friendly skills trigger a full-art overlay and temporary oblique 2D scene transform. Clicking skips the presentation without cancelling the skill. This does not add true 3D models.
- The supplied stage/voice tables were inspected as Shift-JIS reference data: stage dimensions and character/face/filter/priority fields informed the small configs. They are not executed or imported wholesale.

Additional checks: `--verify --pacing`, `--verify --compact --radio`, `--verify --compact --tutorial`, `--verify --radio --skill-shot`, `--verify --radio --flip`. A 180-second first-level simulation recorded initial fire at about 43 seconds and the first loss at about 71 seconds; these values vary with random combat decisions and are not a campaign balance guarantee.

Portraits and standing illustrations are existing bitmap art. Instructor motion uses sway and expression changes, not a new SVG redraw or rigged model. There is no new recorded voice acting.

- Command targeting scrolls inside the window edge and releases camera follow.
- Zoom spans 0.10 to 4.0 with a 1.35 multiplier per wheel step. Distant ships receive fixed-size tactical markers.
- The roster switches between friendly and enemy fleets. Left-click friendly rows to select and follow; right-click to command. Enemy rows inspect and follow without changing friendly command selection.
- Orders use one implementation. Attack on empty space advances while engaging, then resumes its destination. Move orders distribute fleet destinations.
- Manual pause survives command menus and targeting. Global submenu clicks are handled before the parent menu.
- Every ship receives a stable pilot portrait and callsign. Shared radio reports cover orders, invalid targets, fire, skills, damage, and losses. Portrait interference is generated in code; portrait and three-piece speech frame images come from png.
- Cached obstacle routes replace per-frame random detours. Orbit angle is independent of ship heading. AI preserves active combat and resupply; friendly repair ships assist nearby damaged allies.
- Skills default to manual for friendly units; the context menu toggles automatic use. Invalid or disabled skill attempts preserve SP. Mothership skills are enabled.
- Engine animation, flight trails, muzzle flashes, projected impacts, and destruction effects improve combat feedback. Ballistic shots can miss moving targets; artillery excludes the firing team.

## Verification

### Simulation and communications update

Current asset names in `assets/characters` use readable pilot names. `config/character_assets.lua` is the only mapping used by code; source `png/fac` files remain untouched. `if_omk_cha000` was verified as Natsume and `if_omk_cha006` as Kazuya.

Skill releases now slow the battlefield briefly and use signatures by role: sniper/artillery charge beams, bomber/artillery radial barrages, and interceptor/light dash strikes. Preferences are stored under LÖVE's writable `saves/preferences.tbl`, keyed by pilot ID, including automatic skill release.

- Each ship role has a `units/<role>/logic.lua` and dialogue module. Numbered pilot dialogue lives in `teams/<team>/chara/<ID>/dialogue.lua`, with separate friendly and enemy event pools. Shared behaviors remain reusable.
- Simulation deployment offers either squad, three formations, and skippable prebattle conversations. Light, sniper, artillery, and tiger roles add weapon and mobility choices.
- Map size and hull durability increased; damage reduced. Repair ships offer fleet repair or targeted repair from a submenu. Shield and bombardment releases add world effects, camera focus, and a brief screen flash.
- Map portraits use circular clipping, one gold border, and one direction pointer. Radio portraits use rounded clipping and flip transitions. Enemy reports have a red indicator and omit command acknowledgements.
- Production, construction, and research use a right-side dock. Random reinforcement is cheaper than choosing fighter or repair production. Recruitment only chooses IDs with local portraits.
- Both sides have combat reactions and cross-squad exchanges. Noah comments on losses and successful attacks independently of research progress.
- Collection remains passive station income; mineral transport and territory-based extraction are not implemented. The balance checks are automated samples, not a completed balance pass.

Additional verification flags: `--mixed-radio`, `--deployment-shot`, `--exercise-check`, `--shield-shot`, and `--pacing` after `--verify`.

Run from the project directory with LOVE 11:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --verify
& 'C:\Program Files\LOVE\lovec.exe' . --verify --compact --enemy
& 'C:\Program Files\LOVE\lovec.exe' . --verify --far
& 'C:\Program Files\LOVE\lovec.exe' . --verify --battle
```

Verification covers camera edges, zoom limits, selection, command menus, pause restoration, enemy inspection, formation slots, attack-move resumption, obstacle arrival, skills, AI supply, projectile impacts and ten seconds of simulation on each of ten levels. PNGs and the test report are written into this project. These are regression and short simulation checks, not a full campaign balance or long-duration performance assessment.
