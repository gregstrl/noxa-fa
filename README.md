# Noxa FA — Base FiveM RP

Base FiveM RP moderne, modulaire et sécurisée, développée quotidiennement.
Référence (propriétaire, lecture seule) : base Seed (`noxa-fa-seed`).

## Stack

- **FiveM** (Lua 5.4)
- **oxmysql** — accès base de données (seule dépendance)
- **UI 100 % NUI custom** (HTML/CSS/JS natif) — **zéro ox_lib visuel**

> Design premium dark, typographie Inter/Poppins, animations fluides.
> Aucun composant d'interface tiers : notifications, menus, dialogues,
> HUD, sélection de personnage et banque sont entièrement maison (`nui/`).

## Architecture

```
noxa-fa/
├── fxmanifest.lua          # Déclaration de la ressource & ordre de chargement
├── sql/
│   ├── install.sql         # ⭐ FICHIER UNIQUE à importer (tout-en-un, idempotent)
│   ├── noxa.sql            # (référence) schéma de base
│   └── migrations/
│       └── 001_societies_jobs_banking.sql  # (référence) sociétés, factures, bans, véhicules
├── shared/                 # Chargé client + serveur
│   ├── config.lua          # Configuration centrale (économie, banque, jobs, admin)
│   ├── enums.lua           # Référentiels (jobs, gangs, sociétés, comptes, grades)
│   └── utils.lua           # Fonctions utilitaires + validation
├── server/
│   ├── core/
│   │   ├── db.lua          # Couche d'accès BDD (toutes les requêtes SQL)
│   │   ├── security.lua    # Rate-limit, validation events, anti-flood
│   │   ├── player.lua      # Classe Player (économie/job/gang/méta/duty autoritaires)
│   │   └── manager.lua     # Registre joueurs + cycle de vie + sauvegardes
│   ├── modules/
│   │   ├── societies/      # Caisses partagées (jobs, gangs, État) — cache + flush différé
│   │   ├── economy/        # Primitives monétaires + transferts
│   │   ├── jobs/           # Affectation whitelistée, service, boss-actions, paie société
│   │   ├── banking/        # Dépôt/retrait/virement + facturation
│   │   ├── characters/     # Multi-personnages (création/sélection/suppression)
│   │   └── admin/          # Staff : kick, ban, revive, tp, setgroup, économie...
│   └── main.lua            # Bootstrap + exports framework
├── client/
│   ├── core/
│   │   ├── nui.lua         # Pont Lua <-> NUI (focus, menus, dialogues, callbacks)
│   │   ├── spawn.lua       # Gestion du spawn
│   │   └── ui.lua          # Notifications & annonces (NUI custom)
│   ├── modules/
│   │   ├── characters/     # Pilote l'écran NUI de sélection/création
│   │   ├── hud/            # Alimente le HUD (argent/job/besoins)
│   │   ├── jobs/           # /service, menu patron (NUI custom)
│   │   ├── banking/        # Interface bancaire & factures (NUI custom)
│   │   └── admin/          # Handlers déclenchés serveur (revive/heal/tp)
│   └── main.lua            # Init + miroir statebag lecture seule
└── nui/                    # Interface 100 % custom (dossier par module)
    ├── index.html          # Shell : monte les panneaux, route les messages
    ├── shell.css / shell.js# Thème (design system) + routeur NUI + helpers
    ├── notify/             # Toasts custom (remplace lib.notify)
    ├── menus/              # Menus contextuels, dialogues, confirmations
    ├── hud/                # HUD (argent, identité, emploi, besoins)
    ├── characters/         # Sélection & création de personnage (plein écran)
    └── banking/            # Interface bancaire premium (plein écran)
```

## Principes

- **Logique critique 100 % server-side** : argent, jobs, métadonnées validés serveur.
- **Sécurité par défaut** : tout event réseau passe par `Security.onNet`
  (rate-limit + vérification de chargement + capture d'erreur).
- **Ownership vérifié** : impossible de charger/supprimer le personnage d'autrui.
- **Auditabilité** : transactions et incidents journalisés en base.
- **Modularité** : ajout d'un module = un dossier `server/modules/<nom>` + entrée manifest.

## Commandes

### Joueur
- `/service` (ou **F6**) — prendre / quitter le service
- `/boss` — menu de gestion de société (patrons uniquement)
- `/banque` (ou **F7**) — interface bancaire NUI (dépôt, retrait, virement, factures)
- `/facturer [id] [montant] [libellé]` — émettre une facture (métiers habilités)

### Staff (rang vérifié serveur)
- `/kick [id] [raison]` *(mod)*
- `/ban [id] [1h|1d|3d|7d|30d|perm] [raison]` *(admin)* · `/unban [license]`
- `/heal [id]` *(mod)* · `/revive [id]` *(admin)*
- `/goto [id]` *(mod)* · `/bring [id]` *(admin)* · `/announce [msg]` *(mod)*
- `/setmoney [id] [cash|bank] [montant]` *(admin)*
- `/job [id] [job] [grade]` · `/setjobwl [id] [job] [gradeMax]` *(admin)*
- `/setgroup [id] [rang]` *(superadmin)*

## Installation

1. Importer **`sql/install.sql`** (fichier unique, tout-en-un, idempotent).
2. Installer la seule dépendance : **`oxmysql`** (aucun ox_lib requis).
3. Placer la ressource et ajouter `ensure noxa-core` dans `server.cfg`.
4. Démarrer : l'écran de sélection de personnage NUI s'affiche au spawn.

> Touches par défaut : **F6** service · **F7** banque (modifiables dans les
> paramètres FiveM — `RegisterKeyMapping`).

## État du projet

> **Core** : comptes, multi-personnages, identité, métadonnées, sécurité, logs.
> **Économie** : cash/banque autoritaires, transferts, **sociétés (caisses
> partagées)**, **banque (dépôt/retrait/virement)**, **facturation**.
> **Emplois** : whitelist serveur, **service (duty)**, **boss-actions**
> (embauche/licenciement/promotion), **paie prélevée sur la caisse société**.
> **Besoins vitaux** : faim/soif/stress autoritaires serveur, dégâts à 0.
> **Administration** : modération complète (kick/ban horodaté/unban),
> téléportation, soin/réanimation, gestion économie/jobs/rangs, audit.
> **Interface** : **100 % NUI custom** (notifications, menus, dialogues, HUD,
> sélection de personnage, banque) — premium dark, zéro ox_lib visuel.
>
> Prochaines étapes : inventaire custom NUI, garages & véhicules, immobilier,
> métiers illégaux (drogues/braquages), téléphone NUI.
