# TGIANN Exit Sleeping for GTA 5 FiveM

## Video Tutorial

For a detailed demonstration of the script in action, please watch the video tutorial below.

[Watch the Video](https://youtu.be/NTWIxXz9OKc)

## Introduction

When players log out, a ped version of their character spawns at their last location. This ped persists in the game world, allowing other players to interact with, move, or manipulate it. Essentially, it mirrors Rust's mechanic, where your character continues to "exist" in the world even when you're offline.

## Features

- **Full Sync:** Ensures complete synchronization across the server.
- **Highly Configurable:** Many options can be adjusted directly from the configuration file.
- **Compatibility:** Works seamlessly with both ESX, QB and QBOX frameworks.
- **Multi-Script Support:** Compatible with tgiann_clothing, illenium_appearance, crm_appearance, rcore_clothing, and qb-clothing.
- **Player Interaction:** Allows the carrying of sleeping players.
- **Dynamic Updates:** Automatically updates the last location of moved players.
- **Logout Time Filter:** Only displays players who logged out within the last 3 days (this value is configurable via the config file).

## Requirements

- **Frameworks:** Compatible with ESX, QB or QBOx.
- **tgiann-core:** This dependency is required. You can find it here: [tgiann-core Package](https://tgiann.com/en/package/5869215)

## Installation

1. Download the script from the [Releases](https://github.com/TGIANN/tgiann-exit-sleeping/releases) section.
2. Extract the downloaded files to your FiveM server's resource directory.
3. Add `ensure tgiann-exit-sleeping` to your server.cfg file.
4. Import the sql.sql file into your database to create the necessary tables and fields.
5. Restart your FiveM server.

## Usage

To test the script, use the command `exittest` (default). If your character appears sleeping on the ground, everything is working as intended. From this point on, every player who logs out will be represented as sleeping on the ground.

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.
