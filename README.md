# Noxa FA — Base FiveM RP

Base FiveM RP moderne, modulaire et sécurisée, développée quotidiennement.
Référence (propriétaire, lecture seule) : base Seed (`noxa-fa-seed`).

## Stack

- **FiveM** (Lua 5.4)
- **ox_lib** — utilitaires / UI
- **oxmysql** — accès base de données

## Architecture

```
noxa-fa/
├── fxmanifest.lua          # Déclaration de la ressource & ordre de chargement
├── sql/
│   ├── noxa.sql            # Schéma de base (comptes, persos, transactions, logs)
│   └── migrations/
│       └── 001_societies_jobs_banking.sql  # Sociétés, whitelist, factures, bans, véhicules
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
└── client/
    ├── core/
    │   ├── spawn.lua       # Gestion du spawn
    │   └── ui.lua          # Notifications & annonces (ox_lib)
    ├── modules/
    │   ├── characters/     # Échange sélection avec le serveur
    │   ├── jobs/           # /service, menu patron (ox_lib)
    │   ├── banking/        # Menu banque, factures (ox_lib)
    │   └── admin/          # Handlers déclenchés serveur (revive/heal/tp)
    └── main.lua            # Init + miroir statebag lecture seule
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
- `/banque` — menu bancaire (dépôt, retrait, virement, factures)
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

1. Importer `sql/noxa.sql` **puis** `sql/migrations/001_societies_jobs_banking.sql`.
2. Installer les dépendances `ox_lib` et `oxmysql`.
3. Placer la ressource et `ensure noxa-core` dans `server.cfg`.

## État du projet

> **Core** : comptes, multi-personnages, identité, métadonnées, sécurité, logs.
> **Économie** : cash/banque autoritaires, transferts, **sociétés (caisses
> partagées)**, **banque (dépôt/retrait/virement)**, **facturation**.
> **Emplois** : whitelist serveur, **service (duty)**, **boss-actions**
> (embauche/licenciement/promotion), **paie prélevée sur la caisse société**.
> **Administration** : modération complète (kick/ban horodaté/unban),
> téléportation, soin/réanimation, gestion économie/jobs/rangs, audit.
>
> Prochaines étapes : UI NUI de sélection, inventaire (ox_inventory),
> garages & véhicules, immobilier, métiers illégaux (drogues/braquages).
