# BUGS CONNUS — NOXA FA

> Fichier lu par chaque agent au démarrage de session.
> Corriger le bug → supprimer la ligne.
> Fichier vide = aucun bug déclaré joueur (l'agent QA cherche toujours de son côté).

---

## 🔴 CRITIQUE — Bloque le jeu

_(aucun)_

---

## 🟠 MAJEUR

_(aucun)_

---

## 🟡 MINEUR

### [BUG-06] Server list query errors (hairpin NAT) — ENVIRONNEMENTAL, non corrigeable en repo
- **Erreur** : `server request failed for endpoint .../players.json`
- **Cause** : Le serveur ne peut pas joindre sa propre IP publique depuis le LAN (hairpin NAT). Cosmétique.
- **Fix** : Configurer le hairpin NAT sur le routeur, ou ignorer si serveur en dev local.
- **Note** : Aucun changement de code possible — laissé ici comme rappel d'exploitation.
