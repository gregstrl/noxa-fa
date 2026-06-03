# NOXA FA
> Framework custom Noxa · NUI 100% custom · oxmysql · Zéro ox_lib visuel

## État actuel — beta-1.7 · 2026-06-03

| Système | État | Notes |
|---|---|---|
| Core / Framework | ✅ | Comptes, multi-personnages, classe Player autoritaire, statebag répliqué |
| Spawn & Connexion | ✅ | Deferral (vérif ban), spawn robuste anti-gel (dégel garanti tout chemin) |
| Création personnage NUI | ✅ | Caméra 3/4, head-blend, traits, overlays, vêtements — édition live + persistance |
| Inventaire / Items | ✅ | Grille NUI drag&drop, hotbar 1-5, poids, use/jeter/donner — autorité serveur anti-dupe, 11 items |
| Économie & Prix | ✅ | Doctrine salaires (bandes/h justifiées), TVA, taxe virement, loyers, entretien, amendes, plafond cash, catalogue véhicules + flux NUI |
| Véhicules (concessions, garages) | ✅ | Concession F→S, garage sortir/remiser, fourrière (amende), persistance état (carburant/santé/mods) ; tuning 🟡 |
| Menu admin NUI (F10) | ✅ | Panneau RageUI 9 sections (joueurs, véhicules, TP, éco, jobs, sanctions, annonces, logs, serveur) — **rang revérifié serveur + log par action** |
| Panel gestion serveur | ✅ | **Panel superadmin (F9) 8 onglets** : config live SANS restart — systèmes on/off, météo/heure, économie, boutiques, coordonnées (spawn/POI), jobs+grades, organisations, messages planifiés, whitelist. Mémoire + BDD + broadcast clients |
| Anti-cheat & Panel staff | ✅ | **Détection server-side** (speed/teleport/godmode/armes/spawn/argent) + échelle alerte→freeze→kick→ban auto · **Panel staff NUI (F3)** : fiches temps réel (license/Discord/IP/ping/FPS/position/session/score AC), spectate discret, screenshot, freeze, TP discrète, kick/ban, **alertes live** + journal `noxa_anticheat_logs` |
| Map · Blips · POI | ✅ | 14 catégories de POI (+ concession), blips, zones de proximité + prompt NUI |
| Drogues & Trafic | ❌ | Non démarré (prévu prochaine session) |
| Téléphone NUI | 🟡 | Contacts, SMS temps réel, Twitter, Banque, Carte, Réglages ; appels à venir |
| Jobs actifs (Police/EMS/Méca) | ✅ | Police (menottes/fouille/amende/prison/MDT), EMS (ranimer/soigner + état inconscient), Méca (réparer + atelier) — portée & rôle revérifiés serveur |
| Immobilier (maisons/apparts) | ✅ | Achat, entrée/sortie, verrou, mobilier — 4 paliers, persistance BDD |
| Météo & Heure serveur | ✅ | Horloge autoritaire + interpolation client, météo rotative verrouillée, broadcast 30s |
| HUD premium (minimap, vitesse) | 🟡 | HUD permanent (besoins/argent/identité) ; minimap arrondie & compteur SVG à finaliser |

> ✅ Fonctionnel · 🟡 En cours · ❌ Non démarré | Session 16h anti-cheat & panel staff · 2026-06-03

### Session 16h — Anti-cheat server-side & Panel staff (F3)

Protection **100 % serveur** + boîte à outils staff. Nouveau module transverse
`anticheat` (server) + `staff-panel` (client/NUI). Aucune donnée client de confiance.

**Détection** (`server/modules/anticheat/server.lua`, scan serveur cadencé, OneSync)
- **Speed hack** — vélocité serveur ; seuil à pied (exige **2 scans consécutifs**
  pour ne pas flagger une chute/ragdoll) et seuil véhicule séparé.
- **Téléportation (blink)** — saut de position **non corrélé à la vélocité**
  (distance ≫ vitesse × Δt). Faux positifs évités via **grâce** (jail, respawn,
  bring admin) et **destinations autorisées** `AC.expect` (coords **serveur**,
  jamais client — couvre l'entrée/sortie d'un bien immobilier).
- **God mode** — santé > 200 ou armure > 100 (hors bornes légitimes).
- **Armes de triche** — arme équipée dans une **liste noire** (minigun, RPG…),
  lue server-side (détecte menu de triche / spawn d'arme).
- **Spam d'entités** — débit de création réseau (`entityCreating`) au-dessus d'un seuil.
- **Injection d'argent** — pont depuis la classe `Player` (solde anormal / crédit
  hors borne) vers le flux d'alertes.

**Sanctions graduées** — score **cumulé** par joueur (décroissant dans le temps) :
`alerte+log` → `avertissement` → `freeze + alerte urgente` → `kick+log` →
`ban automatique+log`. Chaque palier n'est appliqué qu'**une fois**. Le staff
(rang ≥ `mod`) est **exempté** du scan (test/noclip légitime).

**Panel staff NUI** (`nui/staff-panel/`, z-index **60**, ouvert via **F3**, rang ≥ helper)
- **Joueurs** — table temps réel triée par score AC (suspects en tête) ; fiche
  détaillée : Nom/ID, **License, Discord, IP** (admin only), **Ping, FPS**
  (statebag répliqué), **Position, Job, Solde, Session, Score AC**.
- **Actions** — **spectate discret** (mode spectateur invisible), **screenshot**
  (best-effort `screenshot-basic`), **freeze/libérer**, **TP discrète**,
  **kick** (mod), **ban** (admin) — rang **revérifié serveur** + journalisé.
- **Alertes** — flux **temps réel** des détections (badge d'onglet, code couleur
  par sévérité) poussé à **tout staff en ligne**.
- **Logs AC** — historique `noxa_anticheat_logs` filtrable par catégorie.

**BDD** — `noxa_anticheat_logs` (migration `004_anticheat.sql`, intégrée à
`install.sql` idempotent). Réglages dans `C.AntiCheat` (seuils, sévérités, échelle
de sanction, exemption, webhook screenshot) — tout configurable, chaque seuil justifié.

### Session 12h — Panel gestion serveur in-game (F9, superadmin)

Panneau superadmin pour **configurer le serveur en direct, sans aucun restart**.
Nouveau module transverse `config-manager` (server) + `server-panel` (client/NUI).

**Architecture** (`server/modules/config-manager/server.lua`)
- Chaque **domaine** de config (economy, banking, fuel, systems, shops, spawn,
  poi, enumsJobs, enumsGangs) est une **table vivante** déjà en mémoire. Une
  modification = **mutation EN PLACE** (les modules conservent la référence,
  donc voient le changement au prochain accès) **+ instantané JSON persisté**
  dans `noxa_config`. Au boot, les instantanés **rejouent** par-dessus le code.
- **Aucune table n'est remplacée par référence** : un `replaceContents` vide et
  recopie le contenu → time.lua/security.lua/… qui ont capturé une **sous-table**
  (`Noxa.Config.World`, `.Security`) continuent de voir la bonne donnée.
- **Domaines « client »** (poi/spawn/shops/systems) **rediffusés** aux joueurs :
  la carte (blips), les zones de proximité et le **PVP** se rafraîchissent à chaud.
- Sérialisation des **grades** (clés entières `[0]`) protégée du round-trip JSON
  (`fixGradeKeys`), restaurées en entiers au boot.

**Sécurité** — ouverture **et** toutes les mutations réservées au rang
**superadmin**, revérifié serveur à chaque event (`isSuper`), jamais aucune
donnée client de confiance. Les **champs scalaires** passent par une **allowlist
stricte** (domaine → clé → bornes min/max + type). Toute mutation est
**journalisée** (`noxa_logs`, catégorie `config`). Rate-limit dédié.

**8 onglets** (`nui/server-panel/`, z-index 60, ouvert via **F9**)
1. **Serveur** — stats temps réel · bascules **on/off** (PVP, rotation météo,
   paie, taxes, messages) **réellement effectives** (gardes dans jobs/economy) ·
   **forcer météo** & **régler l'heure** en direct (API `WorldTime`).
2. **Coordonnées** — point de spawn + **POI** (banque, ATM, garage…) : ajout/
   retrait de points, bouton **« Ma position »** → refresh blips/zones immédiat.
3. **Économie** — bornes de transaction, banque, carburant (mémoire + BDD).
4. **Boutiques** — prix des articles (validés serveur à l'achat).
5. **Jobs** — salaires par grade, **ajout/retrait de grade**, **création/
   suppression de job** (les joueurs orphelins rebasculent « sans emploi »).
6. **Organisations** — **création/suppression de gangs** (+ caisse société
   auto), vue des soldes de toutes les sociétés.
7. **Messages planifiés** — annonces serveur diffusées à intervalle (CRUD + on/off).
8. **Whitelist** — accorder/retirer une whitelist d'emploi par Citizen ID + grade max.

**BDD** — `noxa_config` (surcharges par domaine) + `noxa_scheduled_messages`
(migration `003_config_manager.sql`, intégrées à `install.sql` idempotent).

### Session 08h — Menu Admin NUI (F10) · Jobs actifs (Police / EMS / Méca)

**Menu Admin NUI** (`nui/admin/`, `client/modules/admin/client.lua`, `server/modules/admin/server.lua`)
- Panneau **style RageUI** haut-gauche (z-index 60), slide-in, navigation **flèches + souris**,
  ouvert via **F10**. Fond `rgba(10,10,10,0.95)`, bordure accent — 100 % NUI custom.
- **9 sections** : Joueurs (liste temps réel ID/nom/ping/rang + actions kick/ban/heal/revive/
  freeze/bring/goto/setmoney/setjob), Véhicules (spawn/réparer/supprimer/couleur),
  Téléportation (waypoint/XYZ/points sauvegardés), Économie (donner/retirer/définir),
  Jobs & Grades, Sanctions (+ historique), Annonces (broadcast NUI), Logs (filtrables), Serveur.
- **Sécurité** : l'ouverture est **accordée par le serveur** (vérif rang) ; chaque action est
  une simple *intention* — le serveur **revérifie le rang minimal par action** et **journalise**
  en base (`noxa_logs`). Aucune donnée client n'est de confiance.

**Jobs actifs** (`server/modules/jobs/{police,ems,mechanic}.lua`, `client/modules/jobs/`, `nui/jobs/`)
- **Police** : `/menottes` `/fouille` `/amende [id] [montant] [raison]` `/emprisonner [id] [min]`
  + **MDT NUI** (`F11`, effectifs en service). Rôle + service + **portée vérifiés serveur** ;
  l'amende émet une **facture LSPD** ; l'emprisonnement téléporte et minute la peine
  (libération revérifiée serveur).
- **EMS** : `/ranimer` `/soigner` + **état inconscient** autoritaire (`metadata.isDead`) :
  mort détectée client → déclarée serveur → diffusée aux EMS en service (blip patient) ;
  respawn auto (bleedout) anti-blocage si aucun EMS.
- **Mécanicien** : `/reparer` (consomme un **kit de réparation** côté serveur, anim + délai 30 s)
  + **atelier NUI** (`/atelier` : réparer / nettoyer).
- **Anti-superposition** : `Noxa.NUI.activePanel` ferme tout panneau actif avant d'en ouvrir un
  autre (jamais deux panneaux simultanés ; couches z-index respectées).
- **Items** : ajout `handcuffs`, `medikit`, `repairkit` (catalogue partagé).

### Session 04h — Inventaire · Véhicules · Météo (+ audit spawn/créateur)

**Bugfix spawn & créateur (audit)** — `client/core/spawn.lua` garantit le dégel
sur tout chemin (position nil, collision non chargée, timeout) ; le créateur de
personnage gère caméra/focus proprement et `noxa:char:selected` force
`SetNuiFocus(false,false)` via `NUI.releaseAll()`. Conformes, aucune régression.

**Inventaire / Items** (`shared/items.lua`, `server/modules/inventory/`, `nui/inventory/`)
- Catalogue partagé (8 items : pain, eau, sandwich, jus, repas, bandage, téléphone, crochet).
- Modèle **slot-based** sur l'objet `Player`, persisté en JSON dans
  `noxa_characters.inventory` — **source unique en mémoire = anti-dupe**. Poids borné
  (50 kg), 30 slots. API serveur complète + exports inter-modules.
- Effets d'usage branchés sur Besoins (faim/soif/stress), soin client, hooks d'action.
- NUI : grille drag&drop (déplacement/fusion), **hotbar permanente 1-5**, jauge de poids,
  menu contextuel (Utiliser/Donner/Jeter). Touche **I**. Dotation de départ unique.

**Véhicules** (`server/modules/vehicles/`, `client/modules/vehicles/`, `nui/vehicles/`)
- **Concession** : catalogue par classe (prix taxés), achat par virement, plaque serveur
  **unique**, livraison au garage ; débit + rollback atomiques.
- **Garage** : sortir/remiser (spawn + mods, lecture carburant/santé, persistance BDD).
- **Fourrière** : récupération contre amende (banque puis espèces).
- Anti-vol : ownership vérifié partout ; transitions `stored↔out↔impound`
  **atomiques en SQL** (anti double-sortie). Orphelins « sortis » → fourrière au boot.

**Météo & Heure** (`server/modules/world/time.lua`, `client/modules/world/sync.lua`)
- Horloge **autoritaire** (journée = 48 min réelles), interpolée client chaque seconde.
- Météo **rotative déterministe** (8 paliers), verrouillée client (pas de cycle GTA),
  broadcast 30s + synchro à la connexion. `noxa:setweather <TYPE>` (admin).

**BDD** — table miroir `noxa_items` + migration `002_items.sql`.

### Session 00h — Économie : conception, implémentation & équilibrage

Système économique complet, **chaque chiffre justifié en commentaire**.
Doctrine centralisée dans `shared/economy/` (source unique, lue serveur).

**Doctrine des salaires** (`shared/economy/wages.lua`)
- Bandes horaires cibles : civil **500–1500 $/h**, légal qualifié **2000–4000 $/h**,
  illégal **4000–10000 $/h**. Dole citoyen volontairement sous-bande (~100 $/h).
- Conversion automatique « par cycle de paie » ⟷ « par heure » dérivée de
  `Jobs.payInterval` (2 cycles/h) — change l'intervalle, les bornes suivent.
- `Eco.audit()` (debug) compare enums.lua à la grille de référence et signale
  toute dérive : aucun salaire ne glisse sans justification.

**Catalogue véhicules** (`shared/economy/vehicles.lua`)
- 7 classes **F→S** aux bornes imposées (F 5–20k … S 2–8M$), 32 modèles tarifés.
- **Invariant tenu** : une hypercar (S) = 250–1000 h de jeu légitime
  (vérifié au boot : S d'entrée 2,2M$ ≈ 275 h au revenu haut de 8000 $/h).
- Prix justifiés par durée d'acquisition (revenu médian 2500 $/h pour F→C,
  revenu haut 8000 $/h pour B→S). `Eco.checkVehicles()` borne chaque prix à sa classe.

**Anti-inflation — puits monétaires** (`shared/economy/antiinflation.lua`)
- **TVA 5 %** sur consommables (épicerie, carburant) → Trésor Public.
- **Taxe de virement 3 %** (câblée sur `Banking.transferFee`) → limite blanchiment.
- **Surtaxe luxe 7 %** sur les achats de concession.
- **Loyers** ≈ 0,5 %/cycle de la valeur du bien · **Entretien** 150 $/véhicule/cycle
  (cycle fiscal = 60 min, débité aux propriétaires en ligne, banque puis espèces).
- **Amendes** : barème police borné (250 $ → 5000 $, plafond 25k) versé au Trésor.
- **Plafond d'espèces** : 100k$ max sur soi, excédent viré auto en banque (argent
  tracé, butin de braquage futur plafonné).

**Serveur** (`server/modules/economy/server.lua`)
- `chargeWithTax`, `Fine`, `GetVehiclePrice/Total` exportés (interop inter-ressources).
- Thread d'entretien (loyers + maintenance) ; toutes les recettes au Trésor Public.

**NUI** (`nui/economy/`) — flux de transactions temps réel : chaque mouvement
d'argent (salaire, achat, amende, virement…) affiche un toast **+/−** contextualisé
sous le HUD argent, piloté par l'événement serveur `noxa:economy:tx`.

À surveiller (signalé, non modifié) :

- Concession : catalogue & prix prêts (autoritaires) ; le **spawn/garage** des
  véhicules achetés reste à implémenter (achat de bout-en-bout en attente).
- Entretien : un débiteur insolvable est **alerté, jamais endetté** (pas de solde
  négatif) ; un futur système de saisie pourra s'appuyer sur cet état.

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
│   └── economy/            # wages (doctrine salaires) · vehicles (catalogue) · antiinflation
├── server/
│   ├── core/               # db · security · player · manager
│   └── modules/
│       ├── societies/ economy/ jobs/ banking/ characters/ needs/ admin/
│       ├── anticheat/        # détection server-side + endpoints panel staff
│       ├── world/          # shop.lua (épicerie) · fuel.lua (station essence)
│       ├── properties/     # immobilier : achat/entrée/verrou/mobilier (autoritaire)
│       └── phone/          # téléphone : numéro, contacts, SMS, réseau social
├── client/
│   ├── core/               # nui (pont) · spawn · ui
│   └── modules/
│       ├── characters/ hud/ economy/ jobs/ banking/ admin/ staff-panel/
│       ├── world/          # blips · zones (proximité + prompt) · shop · fuel
│       ├── properties/     # portes interactives, intérieurs, mobilier
│       └── phone/          # ouverture F1, pont NUI
└── nui/                    # Interface 100 % custom (dossier par module)
    ├── shell.css/js        # Thème (design system) + routeur NUI + helpers
    ├── notify/ menus/ hud/ economy/ characters/ banking/
    ├── world/              # prompt d'interaction + jauge carburant
    ├── shop/               # boutique épicerie premium
    ├── phone/              # smartphone (accueil + 6 applications)
    ├── jobs/               # jobs actifs : MDT police · atelier méca · fouille
    ├── admin/              # panneau d'administration (F10, style RageUI)
    └── staff-panel/        # panel staff & anti-cheat (F3, alertes live)
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

### Jobs actifs
- **Police** : `/menottes [id]` · `/fouille [id]` · `/amende [id] [montant] [raison]` ·
  `/emprisonner [id] [minutes]` · `/mdt` (**F11**)
- **EMS** : `/ranimer [id]` · `/soigner [id]` · `/respawn` (**G**, si inconscient)
- **Mécanicien** : `/reparer` · `/atelier`

### Staff (rang vérifié serveur)
- **Panel staff & anti-cheat NUI** : **F3** (`/staffpanel`) — joueurs temps réel,
  alertes anti-triche live, logs AC, spectate/freeze/TP/kick/ban (helper+)
- **Menu admin NUI** : **F10** (`/adminmenu`) — 9 sections, navigation flèches + souris
- Commandes : `/kick` `/ban` `/unban` `/heal` `/revive` `/goto` `/bring` `/announce`
  `/setmoney` `/job` `/setjobwl` `/setgroup`

## Historique — apports beta-1.1

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
