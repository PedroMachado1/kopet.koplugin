# KoPet - Virtual Pet for KOReader

A highly customizable virtual pet plugin for KOReader that transforms your reading habit into a gamified RPG experience. Level up your companion, manage its health, and discover unique evolution paths tailored to your reading style.

## ✨ Core Game Mechanics

### 📊 Vital Stats
- **Hunger (0-100%)**: Decreases by 1% every 10 minutes of active reading.
- **Happiness (0-100%)**: Decreases by 1% every 20 minutes of inactivity. Increases by petting (+15%) or reading 30 pages (+5%).
- **Energy (0-100%)**: Drains as you read and recovers while you are offline (+2% per hour).
- **XP & Levels**: Earn 1 XP per page read. Leveling up requires more XP as you progress (Level = sqrt(XP/50)).

### ⚖️ Difficulty Modes
You can adjust the game's economy via the **Difficulty** menu:
| Mode | Discovery Rate | Nutrition Value |
| :--- | :--- | :--- |
| **Easy** | Found every 3 - 7 pages | +10% Hunger |
| **Normal** | Found every 10 - 15 pages | +25% Hunger |
| **Hard** | Found every 20 - 30 pages | +40% Hunger |

### 💊 Sickness & Medicine
KoPet introduces a high-stakes survival mechanic:
1. **The Risk**: If your pet stays at **0% Hunger for more than 24 hours**, it becomes **Severely Sick**.
2. **The Penalty**: A sick pet **stops gaining XP** from reading and cannot eat normal food or treats.
3. **The Cure**: To find a **Medicine**, you must read while the pet is sick. Every 15 pages read in this state has a chance to drop a cure.
4. **Recovery**: Use "Give Medicine" to restore your pet's health and resume XP progression.

## 🦊 Intelligent Evolution Branches
At **Level 6**, your reading history determines your pet's permanent evolution path:

- **Night Owl**: Trigged if you read 50% more pages during the night (18:00 - 06:00) than during the day.
- **Speedster Fox**: Triggered if your average reading speed is faster than 30 seconds per page.
- **Scholar**: Triggered if you are a deep reader with an average speed of over 120 seconds per page.
- **Standard Path**: If none of the conditions above are met, the pet follows the classic evolution line.

*Note: Each path features unique ASCII art frames from Adult to Legendary stages.*

## 🧤 Inventory & Customization
- **Common Food**: Earned randomly based on chosen difficulty.
- **Rare Treats**: Awarded at book progress milestones (25%, 50%, 75%). Provides +40% Hunger and +20% Happiness.
- **Evolution Crystals**: Awarded for finishing a book (100%). Provides a massive +200 XP boost.
- **Accessories**: Rare drops (0.5% chance per page) like Hats, Glasses, Wands, and Bowties. These can be equipped via the menu to customize your pet's look.

## 📓 Pet Journal
Accessed through the main menu, the Journal tracks your pet's entire history:
- Birth date and time.
- Level-up milestones.
- Sickness and cure events.
- Evolution path triggers.
- Major reading achievements.

## 🚀 Installation & Setup
1. Download the `kopet.koplugin` folder.
2. Place it in the `koreader/plugins/` directory on your device.
3. Restart KOReader.
4. Access KoPet via the **Tools (Gear/Screwdriver icon)** -> **KoPet** menu.

## 🌍 Localization
KoPet automatically detects your KOReader system language. Currently supporting:
- **English** (Default)
- **Portuguese** (Full translation)
- **Spanish, French, German, Italian** (Basic UI)

---
*Developed with ❤️ for the KOReader community. Turn your next book into an adventure!*
