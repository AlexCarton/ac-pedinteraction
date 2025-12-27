Police Ped Interaction Script

This resource adds a police interaction system for non-player pedestrians (NPCs).
Officers can interact with pedestrians, check identification, search for items, and arrest suspects.
The script is designed to be server-authoritative, multiplayer-safe, and exploit-resistant.

Features:

- Interaction with random NPC pedestrians
- ID card display with generated name, gender, and mugshot
- Pedestrian search with legal and illegal items
- Arrest scenarios (compliant or fleeing suspect)
- Synchronized animations using networked scenes
- NPC locking system to prevent multiple players interacting with the same NPC
- Server-side validation for all sensitive actions
- Support for multiple target and inventory systems

Target Systems:
Supported target systems:

- qb-target
- ox_target

Selectable in config.lua.

Inventory Systems:
Supported inventory systems:

- qb-inventory
- ox_inventory

Police officers receive a stun gun only when:

- The player has the police job
- The pedestrian contains illegal items
- The player does not already have a stun gun
- The interaction is validated by the server

Configuration:

config.lua contains the main configuration options:

- Config.target = 'ox-target'       -- qb-target or ox-target
- Config.inventory = 'ox-inventory' -- qb-inventory or ox-inventory


Additional configuration includes:

- Item pools for NPC inventories
- Legal and illegal item definitions
- Male and female first names
- Last names
- Security Design
- The script is designed with security in mind:
- No trust in client-provided data
- All critical logic handled server-side
- NPC interaction locking by network ID
- Validation of player job and interaction ownership
- No client-side item granting or entity deletion

This prevents common exploits such as:

- Interacting with NPCs already in use
- Deleting arbitrary entities
- Triggering rewards without valid interaction

Dependencies:

- qb-core
- qb-menu

Depending on configuration:

- qb-target or ox_target
- qb-inventory or ox_inventory

Notes:

- NPCs are detected dynamically using the game ped pool
- The script is intended for police roleplay
- Interaction cleanup is handled when the menu is closed or the NPC is arrested
- Networked scenes are stopped safely before further actions

License:

Free to use and modify for personal or server use.
Redistribution or resale may require permission from the author.