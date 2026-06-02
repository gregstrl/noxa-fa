# NOXA FA
> Framework custom Noxa · NUI 100% custom · oxmysql · Zéro ox_lib visuel

## État actuel — beta-1.1 · 2026-06-02

| Système | État | Notes |
|---|---|---|
| Core / Framework | ✅ | Comptes, multi-personnages, classe Player autoritaire, statebag répliqué |
| Spawn & Connexion | ✅ | Deferral (vérif ban), spawn contrôlé serveur |
| Création personnage NUI | ✅ | Sélection/création plein écran custom |
| Inventaire / Items | ❌ | Champ `inventory` réservé, système à venir |
| Économie & Prix | ✅ | Cash/banque bornés, virements, sociétés, boutique épicerie |
| Véhicules (concessions, garages) | 🟡 | Table `noxa_vehicles` + carburant persistant ; garages/concession à venir |
| Menu admin NUI (F10) | 🟡 | Commandes staff complètes ; panneau NUI F10 à venir |
| Panel gestion serveur | ❌ | Non démarré |
| Anti-cheat & Panel staff | 🟡 | Rate-limit, flag/violations, autoban, logs BDD ; panneau à venir |
| Map · Blips · POI | ✅ | 13 catégories de POI, blips, zones de proximité + prompt NUI |
| Drogues & Trafic | ❌ | Non démarré (prévu prochaine session) |
| Téléphone NUI | 🟡 | Contacts, SMS temps réel, Twitter, Banque, Carte, Réglages ; appels à venir |
| Jobs actifs (Police/EMS/Méca) | 🟡 | Whitelist, service, boss-actions, paie société ; gameplay métier à venir |
| Immobilier (maisons/apparts) | ✅ | Achat, entrée/sortie, verrou, mobilier — 4 paliers, persistance BDD |
| Météo & Heure serveur | ❌ | Non démarré |

> ✅ Fonctionnel · 🟡 En cours · ❌ Non démarré | Session 20h · 2026-06-02

---

Base FiveM RP moderne, modulaire et sécurisée, développée quotidiennement.
Référence (propriétaire, lecture seule) : base Seed (`noxa-fa-seed`).

## Stack

- **FiveM** (Lua 5.4)
- **oxmysql** — accès base de données (seule dépendance)
- **UI 100 % NUI custom** (HTML/CSS/JS natif) — **zéro ox_lib visuel**

> Design premium dark, typographie Inter/Poppins, animations fluides.
> Aucun composant d'interface tiers : notifications, menus, dialogues, HUD,
> sélection de personnage, banque, **boutique, téléphone, immobilier** sont
> entièrement maison (`nui/`).

## Architecture

```
noxa-fa/
├── fxmanifest.lua          # Déclaration de la ressource & ordre de chargement
├── sql/install.sql         # ⭐ FICHIER UNIQUE à importer (tout-en-un, idempotent)
├── shared/                 # config.lua (POI, shops, immobilier, phone) · enums · utils
├── server/
│   ├── core/               # db · security · player · manager
│   └── modules/
│       ├── societies/ economy/ jobs/ banking/ characters/ needs/ admin/
│       ├── world/          # shop.lua (épicerie) · fuel.lua (station essence)
│       ├── properties/     # immobilier : achat/entrée/verrou/mobilier (autoritaire)
│       └── phone/          # téléphone : numéro, contacts, SMS, réseau social
├── client/
│   ├── core/               # nui (pont) · spawn · ui
│   └── modules/
│       ├── characters/ hud/ jobs/ banking/ admin/
│       ├── world/          # blips · zones (proximité + prompt) · shop · fuel
│       ├── properties/     # portes interactives, intérieurs, mobilier
│       └── phone/          # ouverture F1, pont NUI
└── nui/                    # Interface 100 % custom (dossier par module)
    ├── shell.css/js        # Thème (design system) + routeur NUI + helpers
    ├── notify/ menus/ hud/ characters/ banking/
    ├── world/              # prompt d'interaction + jauge carburant
    ├── shop/               # boutique épicerie premium
    └── phone/              # smartphone (accueil + 6 applications)
```

## Principes

- **Logique critique 100 % server-side** : argent, jobs, immobilier, achats validés serveur.
- **Sécurité par défaut** : tout event réseau passe par `Security.onNet`
  (rate-limit + vérification de chargement + capture d'erreur).
- **Ownership vérifié** : personnages, factures, biens immobiliers.
- **Anti-dupe** : achat immobilier atomique (réservation BDD avant débit).
- **Auditabilité** : transactions, incidents et achats journalisés en base.
- **Modularité** : ajouter un module = un dossier + une entrée manifest.

## Commandes & touches

### Monde
- **E** — interagir avec un POI à proximité (banque, distributeur, épicerie,
  station essence, porte d'un bien immobilier)
- **F1** — ouvrir/fermer le téléphone
- `/meubles` — gérer le mobilier (à l'intérieur de son bien)

### Joueur
- `/service` (**F6**) · `/boss` · `/banque` (**F7**) · `/facturer [id] [montant] [libellé]`

### Staff (rang vérifié serveur)
- `/kick` `/ban` `/unban` `/heal` `/revive` `/goto` `/bring` `/announce`
- `/setmoney` `/job` `/setjobwl` `/setgroup`

## Nouveautés session (beta-1.1)

- **Carte & POI** : 13 catégories (bank, atm×16, grocery, clothing, barber,
  hospital, police, garage, fuel×10, mairie, fishing, hunting, casino), blips
  configurables et zones de proximité natives (thread adaptatif, prompt NUI).
- **Boutique épicerie** : eau/sandwich/jus/repas — prix & effets faim/soif
  validés serveur, NUI premium.
- **Station essence** : 2 $/% débité serveur, jauge NUI animée, persistance
  `noxa_vehicles.fuel`.
- **Immobilier** : 7 biens (studio/appartement/maison/villa), achat atomique,
  entrée/sortie instanciée, verrouillage propriétaire, mobilier plaçable.
- **Téléphone NUI** : accueil + Contacts, Messages (SMS temps réel), Twitter,
  Banque (virement rapide), Carte, Réglages.

## Installation

1. Importer **`sql/install.sql`** (fichier unique, tout-en-un, idempotent).
2. Installer la seule dépendance : **`oxmysql`** (aucun ox_lib requis).
3. Placer la ressource et ajouter `ensure noxa-core` dans `server.cfg`.
4. Démarrer : l'écran de sélection de personnage NUI s'affiche au spawn.

> Touches par défaut : **F6** service · **F7** banque · **F1** téléphone ·
> **E** interactions monde (modifiables — `RegisterKeyMapping`).
