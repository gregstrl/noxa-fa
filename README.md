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
│   └── noxa.sql            # Schéma base de données (comptes, persos, logs)
├── shared/                 # Chargé client + serveur
│   ├── config.lua          # Configuration centrale
│   ├── enums.lua           # Référentiels (jobs, comptes, grades)
│   └── utils.lua           # Fonctions utilitaires + validation
├── server/
│   ├── core/
│   │   ├── db.lua          # Couche d'accès BDD (toutes les requêtes SQL)
│   │   ├── security.lua    # Rate-limit, validation events, anti-flood
│   │   ├── player.lua      # Classe Player (économie/job/méta autoritaires)
│   │   └── manager.lua     # Registre joueurs + cycle de vie + sauvegardes
│   ├── modules/
│   │   ├── economy/        # API économie + paie automatique
│   │   └── characters/     # Multi-personnages (création/sélection/suppression)
│   └── main.lua            # Bootstrap + exports + commandes admin
└── client/
    ├── core/spawn.lua      # Gestion du spawn
    ├── modules/characters/ # Échange sélection avec le serveur
    └── main.lua            # Init + miroir statebag lecture seule
```

## Principes

- **Logique critique 100 % server-side** : argent, jobs, métadonnées validés serveur.
- **Sécurité par défaut** : tout event réseau passe par `Security.onNet`
  (rate-limit + vérification de chargement + capture d'erreur).
- **Ownership vérifié** : impossible de charger/supprimer le personnage d'autrui.
- **Auditabilité** : transactions et incidents journalisés en base.
- **Modularité** : ajout d'un module = un dossier `server/modules/<nom>` + entrée manifest.

## Installation

1. Importer `sql/noxa.sql` dans la base de données.
2. Installer les dépendances `ox_lib` et `oxmysql`.
3. Placer la ressource et `ensure noxa-core` dans `server.cfg`.

## État du projet

> Fondation Core posée : comptes, multi-personnages, identité, métadonnées,
> économie (cash/banque) autoritaire, paie auto, couche de sécurité, logs.
> Prochaines étapes : UI NUI de sélection, sociétés/facturation, inventaire,
> immobilier, véhicules.
