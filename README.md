# minerland_fix_npc

Mod Minetest qui enrichit les PNJ du mod `mobs_npc` (TenPlus1).

## Fonctionnalités

- Désactive le spawn automatique des PNJ dans le monde (`mobs.custom_spawn_npc`)
- Remplace la formspec du stick+owner par une interface enrichie :
  - Choix du skin (NPC : 6, Igor : 8, Trader : 4)
  - Choix de l'ordre (wander / stand / follow)

## Utilisation

Tenir un bâton (`default:stick`) et faire un clic droit sur un PNJ dont on est owner (ou avoir le priv `protection_bypass`).

## Dépendances

- `mobs_npc` (TenPlus1)

## Note

Ce mod nécessite également le correctif de `mtobjid` si ce mod est installé sur le serveur.
Le correctif corrige un stack overflow au shutdown causé par une récursion infinie dans `get_staticdata`.

## Licence

MIT
