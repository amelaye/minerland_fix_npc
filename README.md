# minerland_fix_npc

Mod Luanti/Minetest pour le serveur Minerland.

Enrichit les entités NPC de `mobs_npc` avec un menu de configuration (skin, ordre), et ajoute un Garde Royal immortel avec des comportements avancés.

---

## Dépendances

- `mobs_redo` (ou compatible)
- `mobs_npc`
- `rangedweapons` (pour les armes et le pistolet du garde)
- `leads` (optionnel, pour la gestion des laisses)
- `sethome` (optionnel, pour le tp home via `/osecour`)

---

## Fonctionnalités

### Menu NPC (clic droit avec un bâton)

Permet au propriétaire d'un NPC (ou à un joueur avec le priv `protection_bypass`) de :
- Changer le **skin** du NPC parmi les skins disponibles
- Changer l'**ordre** du NPC : `wander`, `stand`, `follow`

Fonctionne sur : `mobs_npc:npc`, `mobs_npc:igor`, `mobs_npc:trader`, `minerland_fix_npc:guard`

---

### Garde Royal (`minerland_fix_npc:guard`)

NPC immortel avec des comportements de protection avancés.

#### Comportements

- **Salue la reine** : s'incline et envoie un message de bienvenue quand la reine s'approche
- **Menace les intrus** : brandit son arme et avertit tout joueur non autorisé qui s'approche
- **Surveille le suspect** : pointe son arme en permanence sur le joueur suspect dès qu'il entre dans le rayon de surveillance
- **Réagit aux armes** : détecte toute arme `rangedweapons` à portée, pointe son pistolet et ordonne de la baisser
- **Riposte aux tirs** : détecte les projectiles ennemis et tire en retour
- **Résiste aux laisses** : éjecte tout joueur qui tente de l'attacher avec une laisse
- **Immunité** : immortel, résistant aux knockbacks, HP forcé au maximum en permanence

#### Spawn

L'œuf de spawn n'apparaît pas dans l'inventaire créatif. Il s'obtient uniquement via :
```
/give <joueur> minerland_fix_npc:guard
```
Le placement est réservé aux joueurs avec le priv `server`.

---

### Commande `/osecour`

Disponible pour tous les joueurs **sauf le suspect**.

Appelle un Garde Royal d'urgence qui spawne directement sur le suspect, le poursuit et l'attaque jusqu'à ce qu'il sorte du rayon de poursuite.

- Un seul garde d'urgence actif à la fois
- Si le joueur appelant est en prison, il est automatiquement téléporté à son home 5 secondes après l'appel
- Le garde disparaît et rentre quand le suspect sort du rayon

---

## Configuration (`minetest.conf`)

| Paramètre | Défaut | Description |
|---|---|---|
| `minerland_guard_queen` | `amelaye` | Nom de la reine (salut et accès bâton) |
| `minerland_guard_greet_dist` | `3` | Distance de salutation de la reine |
| `minerland_guard_threat_dist` | `3` | Distance de menace des intrus |
| `minerland_guard_suspect` | `Luffy0805` | Nom du joueur suspect |
| `minerland_guard_suspect_dist` | `10` | Distance de surveillance du suspect |
| `minerland_guard_rescue_dist` | `20` | Rayon de poursuite du garde d'urgence |
| `minerland_guard_color` | `#FF0000` | Couleur des messages du garde en chat |

---

## Licence

MIT