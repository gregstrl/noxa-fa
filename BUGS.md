# BUGS CONNUS — NOXA FA

> Fichier lu par chaque agent au démarrage de session.
> Corriger le bug → supprimer la ligne.
> Fichier vide = aucun bug déclaré joueur (l'agent QA cherche toujours de son côté).

---

## 🔴 CRITIQUE — Bloque le jeu

_(aucun)_

---

## 🟠 MAJEUR

### [BUG-07] Anti-cheat téléport — faux positif au spawn/chargement
- **Erreur** : `AC[teleport] Greg Baker : saut de 1747 m en 3.0s (vitesse 0 m/s) (score 2, warn)`
- **Cause** : Quand le joueur spawn ou est téléporté légitimement (sélection perso, chargement, admin TP), l'anti-cheat compte ça comme un warp.
- **Fix** : Dans le module anticheat teleport, ignorer les contrôles pendant N secondes après le spawn/chargement, et après toute téléportation serveur légitime (flag `Noxa.justTeleported[src] = true` pendant 5s). Ne pas compter de violation si vitesse = 0 (typique d'un spawn, pas d'un warp gameplay).
- **Fichier** : `resources/noxa-fa/server/modules/anticheat/` (détection teleport)

### [BUG-08] Violation "noxa:prop:request avant chargement"
- **Erreur** : `Violation #1 de LeFaignant : event noxa:prop:request avant chargement`
- **Cause** : Le client envoie `noxa:prop:request` (propriétés/immobilier) avant que le joueur soit complètement chargé côté serveur.
- **Fix** : Côté client, attendre l'event `noxa:char:selected` / `noxa:playerLoaded` avant d'envoyer `noxa:prop:request`. Côté serveur, si le joueur n'est pas chargé, répondre poliment (return silencieux) sans compter de violation anti-cheat.
- **Fichier** : `resources/noxa-fa/client/modules/properties/` + `server/modules/properties/`

---

## 🟡 MINEUR

### [BUG-05] menuv ne compile pas au 1er démarrage (yarn busy)
- **Erreur** : `yarn is currently busy: we are waiting to compile menuv` / `Couldn't start resource menuv` (au 1er boot)
- **Cause** : menuv lance un build yarn/webpack au démarrage. Tant que le build n'est pas fini, noxa-fa + es_extended échouent (dépendance menuv). Au 2e/3e restart ça démarre OK.
- **Fix** : Vérifier que `resources/menuv/dist/` contient bien le build pré-compilé ET que le `fxmanifest.lua` de menuv pointe sur `dist/` sans relancer yarn. Si menuv a un `yarn`/`webpack` dans son manifest qui force le build → le retirer puisque le dist est déjà commité. Objectif : menuv démarre instantanément sans build.
- **Fichier** : `resources/menuv/fxmanifest.lua`

### [BUG-09] Commande setgroup — pas de slash
- **Observation** : `/setgroup 1 superadmin` → "No such command". La commande s'appelle `setgroup` (sans slash en console RCON) mais le log d'usage montre `/setgroup`.
- **Cause** : En console txAdmin/RCON, taper `setgroup 1 superadmin` (sans `/`). En jeu, `/setgroup`. Documenter clairement dans le README + message d'usage cohérent.
- **Fix** : Aligner le message d'aide. Pas un vrai bug, juste de la confusion d'usage. Documenter dans README la commande console exacte pour devenir superadmin.
