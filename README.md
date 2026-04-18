# KoPet v2.0 - Virtual Pet for KOReader

KoPet turns your reading habit into a lightweight RPG loop inside KOReader. Read pages, care for your pet, collect items, and evolve your companion based on your real reading behavior.

## What's New in v2.0

- Reworked game loop with sickness, medicine, and stronger survival mechanics.
- Intelligent evolution branches at Level 6 (Night Owl, Speedster Fox, Scholar, Standard).
- Cleaner grouped menu (`Care`, `Pet Info`, `Settings`, `Danger Zone`) plus `Quick Action`.
- Updated full-screen `View Pet` UI with better spacing, status badges, and smoother readability.
- Optional low-impact pet animation optimized for e-ink.
- Accessories now provide small gameplay bonuses (not only cosmetic).
- Daily summary and improved journal tracking.

## Core Game Mechanics

### Vital Stats

- **Hunger (0-100%)**: decays over time and must be restored with food/treats.
- **Happiness (0-100%)**: affected by care actions and passive decay.
- **Energy (0-100%)**: drops with reading sessions and recovers while offline.
- **XP & Levels**: XP is earned per page and scales with your reading behavior.

### Dynamic States

- **Sick**: pet cannot eat normal food and stops XP gains until cured.
- **Bored**: appears after long periods without care and reduces XP gain.
- **Sleepy**: appears at low energy and reduces XP gain until rested.

Status badges are shown in `View Pet` (`SICK`, `BORED`, `SLEEPY`) for quick visibility.

## Difficulty Modes

Each mode changes economy and pacing:

| Mode | Food Discovery | Food Restore | Medicine Pages | XP/Decay Profile |
| :--- | :--- | :--- | :--- | :--- |
| **Easy** | 3-7 pages | +14 Hunger | 30 pages while sick | More XP, slower decay |
| **Normal** | 10-15 pages | +25 Hunger | 50 pages while sick | Baseline |
| **Hard** | 20-30 pages | +40 Hunger | 65 pages while sick | Less XP, faster decay |

## Sickness and Medicine

1. If your pet stays at **0 Hunger** for too long, it becomes sick.
2. While sick, your pet does not gain XP and has restricted care options.
3. Read while sick to find medicine:
   - **Easy**: 30 pages
   - **Normal**: 50 pages
   - **Hard**: 65 pages
4. Use **Give Medicine** to cure the pet and restore normal progression.

## Intelligent Evolution Branches

At **Level 6**, KoPet permanently selects an evolution path based on your reading profile:

- **Night Owl**: 50%+ more night reading pages (18:00-06:00) than day pages.
- **Speedster Fox**: average reading speed faster than 30 seconds per page.
- **Scholar**: average reading speed slower than 120 seconds per page.
- **Standard Path**: used when none of the conditions above are met.

Each path uses dedicated ASCII progression from Adult onward.

## Inventory and Customization

- **Food**: found based on current difficulty.
- **Treats**: earned at book milestones (25%, 50%, 75%).
- **Medicine**: earned by reading while sick (difficulty-based thresholds).
- **Evolution Crystals**: earned by finishing books.
- **Accessories**: rare drops you can equip via menu.

Accessory bonuses (lightweight):

- `glasses`: extra XP per page.
- `hat`: extra hunger restore when feeding.
- `ribbon`: shorter pet cooldown.
- `bowtie`: extra happiness from petting.
- `wand`: extra happiness from treats.

## Menu Overview (v2.0)

- **View Pet**: opens the full panel.
- **Quick Action**: repeats your last most-used action quickly.
- **Care**: Feed, Pet, Give Treat, Give Medicine.
- **Pet Info**: Today Summary, Statistics, Journal, Accessories, Rename.
- **Settings**: Difficulty, Panel Mode, Notifications, Pet Animation.
- **Danger Zone**: Reset Pet.

## Journal and Daily Summary

- **Journal** logs key events (level ups, sickness/cure, evolution decisions, notable finds).
- **Today Summary** shows daily counters such as pages read, care actions, books completed, and medicine found.

## Installation

1. Download the `kopet.koplugin` folder.
2. Place it in `koreader/plugins/` on your device.
3. Restart KOReader.
4. Open via **Tools** -> **KoPet**.

## Localization

KoPet auto-detects KOReader language.

- **English** (default)
- **Portuguese** (full)
- **Spanish, French, German, Italian** (partial/basic)

---

*Developed with ❤️ for the KOReader community. Turn your next book into an adventure!*
