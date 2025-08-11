## Overview
This is a **three-phase Attack & Defense mission** built around the chicken factory in Paleto.  
It was created for a development test to showcase mission flow, server/client synchronization, defender mechanics, and configurability using ox_lib.

The mission is intentionally kept modular and tweakable so new mission locations, guard setups, and entry methods can be added without rewriting core logic.

## Mission Structure
The mission is split into 2 main phases, each with variation options to keep runs fresh:

1. **Infiltration**
   - Choose the front entrance (Thermite) or the back entrance (C4).
   - Animations & effects are server synced for all players.
   
2. **Objective**
   - Once a door is breached, NPC guards spawn inside (server-synced peds).
   - Guard NPC stats (HP, armour, accuracy, weapons, perception range) are tweakable via config.
   - A search zone is created around the loot location – only one player can search it once per mission.

3. **Delivery / Escape**
   - Attacker must carry the loot box out.
   - Movement speed will be reduced to walking so defenders have a fair chance to intercept.
   - Defenders win if time runs out or the loot is recovered.

## Defender Mechanics
Defenders can be:
- Real players: receive a GPS ping when a break-in starts.
- Networked peds: guards or response NPCs spawned by the server.

Defenders can enter from:
- The front entrance
- The back entrance 
- Or same route as the attackers

## Phase Variations
Each run can feel different thanks to:
- Multiple entry methods
- Configurable NPC setups
- Adjustable loot/search location
- Multiple infiltration/objective/delivery point sets with fallback logic

## Technology Stack
- ox_lib – Menus, notifications, progress bars, input, and utility functions.
- ox_doorlock – Breachable doors with synced states.
- QBX / QBCore – Player data, jobs, and money handling, i used qbcore API, instead of QBX since i dont know how you will be testing, and if you will be testing on QBX, it has bridges that help that.
- Server-synced AI peds – Combat settings, armour, health, perception.

## Configuration Highlights
- Guard NPC tuning – HP, armour, accuracy, weapons, patrol behavior.
- Mission points – Infiltration, objective, and delivery points can be set via config (with fallback locations).
- Entry methods – Breach via C4, or thermite
- Search zone control – Radius and one-time-only search rules.
- Mission cooldowns – Prevent spam with adjustable timeout.

## Why No DUI (Yet)?
While a DUI countdown overlay would look amazingly cool:

I delayed implementing it for two reasons:
1. Performance concerns – Early testing showed DUI can cause huge resmon spikes if not optimized correctly, and i dont want to send in a uncompleted DUI.
2. Skill readiness – I want more hands-on practice with DUI rendering before using it in a formal test submission, to ensure it’s done properly.

For now, the breach phases rely on ox_lib progress bars, which are lightweight and resmon-friendly.  

New note: 11.08.2025
I got a tip from Mietek too look at textures, and i have found a solid solution to do DUI.
So right now im playing around with this prop: "v_club_roc_mscreen", exported it with OpenIV to get the texture file, and im now playing around with placing my DUI on that screen.
Right now im trying out a project where i will redo qbx_management, to be on the business managers actual PC screen.
I am still having some major client side resmon issues, but i am pretty sure that is because my threads are not optimized yet + its loading from way too far away.
Need to opimitize both threads and who it loads for, and at what distance.
