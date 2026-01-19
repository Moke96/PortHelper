# PortHelper

A World of Warcraft Classic Era addon to help Warlocks manage raid summoning by tracking which raid members need to be summoned to the raid instance or your current location.

![WoW Classic Era](https://img.shields.io/badge/WoW-Classic%20Era-yellow)
![AI Generated](https://img.shields.io/badge/AI-Generated-blue)

> ⚠️ **Note:** This addon was entirely generated using AI (GitHub Copilot / Claude) as an experiment in AI-assisted addon development.

## Features

- **Raid Instance Tracking**: Select from all Classic Era raids (Molten Core, BWL, Onyxia, ZG, AQ20, AQ40, Naxxramas)
- **Smart Detection**: Automatically detects who is NOT at the raid instance or entrance zones
- **Proximity Check**: Also checks if players are nearby (within ~28 yards)
- **"Other" Mode**: Ignore instance checks entirely - just show everyone who isn't close to you (great for world bosses, meeting spots, etc.)
- **One-Click Targeting**: Left-click a name to target that player
- **One-Click Summoning**: Right-click to cast Ritual of Summoning (Warlocks only)
- **Meeting Stone Support**: Middle-click to announce port when using Meeting Stones (any class)
- **Auto-Announce**: Automatically sends raid and whisper messages when summoning
- **Visual Feedback**: Players being summoned are highlighted to prevent accidental double-summons
- **Class Colors**: Names are displayed in their class colors for easy identification
- **Multi-Language Support**: Works across all WoW client languages (uses map/instance IDs instead of localized zone names)

## Supported Raids

| Raid | Entrance Zone |
|------|---------------|
| Molten Core | Blackrock Mountain |
| Blackwing Lair | Blackrock Mountain |
| Onyxia's Lair | Dustwallow Marsh |
| Zul'Gurub | Stranglethorn Vale |
| Ruins of Ahn'Qiraj | Silithus |
| Temple of Ahn'Qiraj | Silithus |
| Naxxramas | Eastern Plaguelands |
| Other (Nearby Check) | Any location |

## Installation

1. Download or clone this repository
2. Copy the `PortHelper` folder to your WoW Classic Era addons directory:
   ```
   World of Warcraft\_classic_era_\Interface\AddOns\
   ```
3. Restart WoW or type `/reload` if already in-game

## Usage

### Slash Commands
- `/porthelper` or `/ph` - Toggle the PortHelper window
- `/ph show` - Show the window
- `/ph hide` - Hide the window
- `/ph scan` - Scan raid members

### Basic Workflow

1. Open PortHelper with `/ph`
2. Select your destination raid from the dropdown (or "Other" for any location)
3. Click **Scan Raid** to find members who need summons
4. **Left-click** a name to target that player
5. **Right-click** a name to:
   - Cast Ritual of Summoning (Warlock only)
   - Send a raid announcement
   - Whisper the player being summoned
6. **Middle-click** a name to:
   - Announce the port (for Meeting Stone / Summoning Stone usage)
   - Send a raid announcement
   - Whisper the player being summoned
   - (Does NOT cast Ritual of Summoning - any class can use this)

### Visual Indicators

- **Normal**: Dark background - ready to be summoned
- **Orange/Highlighted**: Being summoned via Ritual of Summoning
- **Blue/Highlighted**: Being summoned via Meeting Stone

## Configuration

The addon automatically saves your settings including:
- Last selected raid
- Window position
- Auto-scan preference

## Requirements

- World of Warcraft Classic Era (1.15.x)
- Must be in a raid group to scan members
- Warlock class required for Ritual of Summoning functionality (right-click)
- Any class can use Meeting Stone announcements (middle-click)

## Known Limitations

- Proximity detection only works for players you can see (within render distance)
- Zone detection may not work for players who are too far away
- Ritual of Summoning requires two other players to click the portal
- Meeting Stones require two other players to click the portal

## Credits

This addon was created entirely through AI-assisted development using:
- **GitHub Copilot** (Claude model)
- Inspired by [RaidSummon](https://github.com/isitLoVe/RaidSummon) addon's secure button implementation

## License

MIT License - Feel free to use, modify, and distribute.

---

*This addon is not affiliated with or endorsed by Blizzard Entertainment.*
