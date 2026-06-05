# BUGS CONNUS — NOXA FA

> Fichier lu par chaque agent au démarrage de session.
> Corriger le bug → supprimer la ligne.
> Fichier vide = aucun bug déclaré joueur (l'agent QA cherche toujours de son côté).

---

## 🔴 CRITIQUE — Bloque le jeu

### [BUG-01] AC[spawn] faux positifs en boucle infinie
- **Erreur** : `AC[spawn] ?? : 11 entités créées en 10s (score X, alert/kick/ban)`
- **Cause** : Le seuil spawn de l'anti-cheat est trop bas. L'entité `??` = entité sans owner (PNJ/véhicules du monde natif FiveM). Le système les compte comme des spawns joueur.
- **Fix** : Filtrer les entités sans owner avant de compter : `if GetEntityOwner(entity) <= 0 then return end`. Ou monter le seuil à 50+ et n'auditer que les entités owernées par un joueur réel.
- **Fichier** : `resources/noxa-fa/server/` — module anticheat/spawn

---

### [BUG-02] Crash connexion — getName() nil (es_extended compat)
- **Erreur** : `@es_extended/server/main.lua:72: attempt to call a nil value (method 'getName')`
- **Stack** : `manager.lua:66` → `characters/server.lua:230`
- **Cause** : La couche compat ESX appelle `xPlayer:getName()` mais cette méthode n'est pas exposée dans l'objet Noxa Player.
- **Fix** : Ajouter dans la couche compat xPlayer : `getName = function(self) return self.name or (self.firstName .. ' ' .. self.lastName) end`
- **Fichier** : couche compat ESX / `es_extended/server/main.lua:72`

---

### [BUG-03] Crash connexion — addItem() nil (inventory)
- **Erreur** : `@noxa-fa/server/modules/inventory/server.lua:275: attempt to call a nil value (method 'addItem')`
- **Cause** : À la connexion, `addItem` est appelé avant que l'objet Player soit initialisé.
- **Fix** : Ajouter un guard à la ligne 275 : `if not player or not player.addItem then return end`
- **Fichier** : `resources/noxa-fa/server/modules/inventory/server.lua:275`

---

## 🟠 MAJEUR

### [BUG-04] sv_projectName / sv_projectDesc manquants
- **Erreur** : `You don't have sv_projectName/sv_projectDesc set`
- **Fix** : Ajouter dans `server.cfg` : `sets sv_projectName "Noxa FA"` et `sets sv_projectDesc "Serveur RP Noxa"`
- **Fichier** : `server.cfg`

---

## 🟡 MINEUR

### [BUG-05] menuv ne compile pas au 1er démarrage (délai yarn)
- **Erreur** : `yarn is currently busy: we are waiting to compile menuv` / `Couldn't start resource menuv`
- **Cause** : menuv a besoin d'un build webpack. Si le build n'est pas pré-compilé, yarn tourne en arrière-plan et noxa-fa + es_extended échouent au démarrage initial.
- **Fix** : S'assurer que `resources/menuv/` contient le build compilé (dossier `app/html/` avec les assets). Ajouter dans le README : "menuv doit être buildé avant le premier lancement (`cd resources/menuv && npm run build`)".
- **Note** : Au 3ème restart le serveur démarre correctement (yarn a compilé). Pas bloquant en prod, mauvaise expérience à l'install.

### [BUG-06] Server list query errors (hairpin NAT)
- **Erreur** : `server request failed for endpoint .../players.json`
- **Cause** : Le serveur ne peut pas joindre sa propre IP publique depuis le LAN (hairpin NAT). Cosmétique.
- **Fix** : Configurer le hairpin NAT sur le routeur, ou ignorer si serveur en dev local.
