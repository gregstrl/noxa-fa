# NOXA FA
> Framework custom Noxa · Compatible ESX · **MenuV** (menus unifiés) · NUI custom (HUD/notifs/banque/téléphone/inventaire) · oxmysql

## État actuel — stable-2.11 · 2026-06-05

| Système | État | Notes |
|---|---|---|
| Framework Noxa + compat ESX | ✅ | Comptes, multi-personnages, classe Player autoritaire, statebag répliqué · shim `es_extended` (getSharedObject, xPlayer, callbacks, RegisterUsableItem, events `esx:*`) délègue à noxa-fa, zéro état dupliqué |
| Spawn & Connexion | ✅ | Deferral (vérif ban), spawn robuste anti-gel (dégel garanti tout chemin) |
| Création personnage NUI | ✅ | Caméra 3/4, head-blend, traits, overlays, vêtements — édition live + persistance |
| Inventaire / Items | ✅ | Grille NUI drag&drop, hotbar 1-5, poids, use/jeter/donner — autorité serveur anti-dupe (source unique `noxa_characters.inventory`), 24 items (+ drogues, outils & butin d'activités) |
| Économie & Prix | ✅ | Doctrine salaires (bandes/h justifiées), TVA, taxe virement, loyers, entretien, amendes, plafond cash, catalogue véhicules ; **revente concession** = faucet borné (50 % du prix HT × état, anti-spéculation) |
| Véhicules (concessions, garages) | ✅ | **Menus MenuV** : concession F→S, **revente des véhicules remisés** (valeur selon l'état), garage sortir/remiser, fourrière (amende), persistance état (carburant/santé/mods) ; tuning 🟡 |
| Menu Admin (F10) | ✅ | Panneau NUI 9 sections (joueurs, véhicules, TP, éco, jobs, sanctions, annonces, logs, serveur) — **rang revérifié serveur + log par action** |
| Panel Gestion Serveur (F9) | ✅ | **Superadmin 8 onglets** : config live SANS restart — systèmes on/off, météo/heure, économie, boutiques, coordonnées (spawn/POI), jobs+grades, organisations, messages planifiés, whitelist. Mémoire + BDD + broadcast clients · **design Claude `/gestion`** (iframe lecture seule : items/véhicules/POI/jobs réels) |
| Anti-Cheat & Panel Staff (F3) | ✅ | **Détection server-side** (speed/teleport/godmode/armes/spawn/argent) + échelle alerte→freeze→kick→ban auto · panel staff NUI temps réel, spectate, screenshot, freeze, TP, kick/ban, alertes live + `noxa_anticheat_logs` · **dashboard Claude `F8`** (iframe lecture seule : joueurs/détections/watchlist/bans/logs réels, helper+ ; IP admin+) |
| Carte · Blips · POI | ✅ | 21 catégories de POI (banque, ATM, services, concession + **champs/labos/revendeurs drogue**, pêche, chasse), blips configurables, zones de proximité + prompt NUI overlay pur |
| Drogues & Trafic | ✅ | **Chaîne récolte → transformation → vente** (cannabis/cocaïne/méth) via **MenuV** aux POI · 100 % autoritaire serveur (proximité revérifiée, cooldown, possession réelle) · alerte **dispatch police** probabiliste (blip GPS) · butin dans l'inventaire anti-dupe |
| Activités légales | ✅ | **Pêche & chasse** via **MenuV** : achat d'outil, cueillette chronométrée (anim), butin probabiliste borné, **vente sur place** — proximité/outil/cooldown serveur |
| Téléphone | 🟡 | **Refonte visuelle « iOS premium » (Option C)** : dynamic island, dock translucide, grille d'apps, bulles SMS, carte de solde dégradée — calquée sur le design de référence Claude Design, **100 % vraies données FiveM** (Contacts, SMS temps réel, Canari, Banque, Carte, Réglages) ; appels à venir |
| Jobs Police/EMS/Méca | ✅ | Police (menottes/fouille/amende/prison/MDT), EMS (ranimer/soigner + état inconscient), Méca (réparer + **atelier `/atelier` migré MenuV**) — portée & rôle revérifiés serveur · **menu patron `/boss` migré MenuV** (saisies numériques ID/grade/montant restent en dialogue NUI) |
| Météo & Heure | ✅ | Horloge autoritaire + interpolation client, météo rotative verrouillée, broadcast 30s |
| Immobilier (maisons/apparts) | ✅ | Achat (confirmation MenuV), entrée/sortie, verrou, mobilier — **menus de porte & mobilier migrés MenuV** — 4 paliers, persistance BDD, **loyers cycle fiscal** (puits monétaire, bascule live F9, impayé→verrou) |
| HUD (minimap, vitesse, barres) | 🟡 | HUD permanent (besoins/argent/identité) ; minimap arrondie & compteur SVG à finaliser |
| MenuV (menus unifiés) | ✅ | Ressource **buildée & déployable** (dist NUI compilé, fxmanifest racine, démarrée dans `server.cfg`) ; **migration in-game terminée** — concession/garage/fourrière + menu patron jobs + immobilier (porte/mobilier/confirmation) + **boutique épicerie** + **atelier mécanicien `/atelier`**. NUI custom réservée à HUD/notifs/banque/téléphone/inventaire/panels (admin/staff/gestion/anti-cheat) |

> ✅ Fonctionnel · 🟡 En cours · ❌ Non démarré | Session — Vérification QA finale de fin de journée (build vert) · 2026-06-05

### Session QA — Téléphone : fil SMS tronqué sur les anciens messages (correctif)

Passe QA ciblée téléphone (chaîne complète server↔client↔NUI auditée :
contacts, SMS temps réel, Canari, banque, carte, réglages — toutes les
fonctions `DB.*` et callbacks NUI présents, contrat respecté).

- **`DB.getThread`** : la requête bornait le fil avec `ORDER BY id ASC LIMIT N`,
  ce qui renvoyait les **N plus anciens** messages. Au-delà de `maxMessages`
  (200) dans une même conversation, les messages **récents** étaient invisibles.
  Corrigé via sous-requête `ORDER BY id DESC LIMIT N` (garde les derniers) puis
  ré-ordonnancement `ASC` pour l'affichage chronologique des bulles. Aucun autre
  changement (drogues, activités, carte/POI revérifiés : cohérence config ↔
  items ↔ POI ↔ SQL intacte).

### Session QA — Vérification finale de fin de journée (zéro régression)

Passe QA finale (dernier agent du jour, zéro nouvelle feature). Audit
intégral des 18 commits de la journée — **aucun bug introduit, aucune
régression, build validé** :

- **Syntaxe Lua** : 100 % des fichiers `.lua` (noxa-fa + shim es_extended)
  passent `luac5.4 -p`. Les littéraux hash backtick `` `WEAPON_*` `` (config
  anti-cheat) sont du CfxLua valide — faux positifs écartés.
- **SQL** : toutes les tables `noxa_*` référencées côté serveur existent dans
  `install.sql` ; `CREATE TABLE IF NOT EXISTS` + `ON DUPLICATE KEY UPDATE`
  partout (réexécutable sans casse) ; les deux copies `install.sql` (racine +
  `sql/`) sont identiques.
- **fxmanifest** : chaque script et fichier NUI référencé existe sur disque.
- **Crashs connexion** : le correctif « objet `ply` sérialisé » (shim ESX
  `noxa:playerLoaded` → ré-acquisition de la référence vivante via
  `exports['noxa-fa']:GetPlayer`) est vérifié — l'export cible existe bien.
- **Focus NUI** : gestion centralisée par compteur de couches (`NUI.setFocus`),
  garde anti ré-ouverture des designs F8/`/gestion` confirmée équilibrée
  (pas de curseur bloqué).
- **Argent** : `addMoney`/`removeMoney` sont atomiques en mémoire (lecture →
  contrôle → écriture sans `yield`) — aucune fenêtre de race.
- **nil-deref** : tous les accès `CFG.getItem(...).label` (inventaire, drogues,
  activités) sont gardés `it and it.label or e.name`.
- **Events réseau** : 100 % des handlers serveur passent par `S.onNet`
  (rate-limit + joueur chargé + pcall) — aucun `RegisterNetEvent` nu.
- **Callbacks NUI** : tous résolvent leur `cb()` (aucune promesse `fetchNui`
  laissée en suspens).

### Session QA — Correctif crash potentiel sur don d'item (nil-deref)

Passe QA (zéro nouvelle feature). Chasse aux bugs sur l'ensemble des modules
server/client : nil-deref, race conditions, events non sécurisés, math.floor
oublié, requêtes N+1, fuites mémoire, index SQL.

- **🟠 Corrigé — `inv:give` nil-deref (`inventory/server.lua`)** : après un don
  d'item, les notifications émetteur/destinataire indexaient `it.label` sans
  garde alors que `CFG.getItem(e.name)` peut retourner `nil` (item devenu
  inconnu après un hot-reload de config via le panel Gestion, ou item injecté
  par une ressource ESX tierce). Cas reproduisant le pattern **déjà gardé** du
  handler `inv:drop` voisin (`it and it.label or e.name`) : la cohérence est
  rétablie. Sans le correctif, le don d'un item « orphelin » crashait le thread
  serveur (`attempt to index a nil value`).
- **Faux positifs écartés (vérifiés, aucun changement nécessaire)** :
  `GetEntityCoords` sur un ped invalide retourne `vector3(0,0,0)` en FiveM (pas
  de crash — distance énorme, rejet propre) ; `DB.getOwnedPropertyTiers` est
  déjà gardé `… or {}` (pas d'`ipairs(nil)`) ; l'ordre add→remove de `inv:give`
  n'est **pas** une race (Lua coopératif, `addItem`/`removeItem` synchrones sans
  yield, item source garanti présent).

**Audit d'optimisation (RAS) :**
- **Threads** : les 5 `Wait(0)` restants sont **légitimes** (DisableControlAction
  menottes/inconscience par frame, rendu de texte réparation, polling hotbar
  `IsControlJustPressed`). Thread de proximité POI à `Wait` adaptatif (500→200→0).
- **SQL** : `SELECT *` réservés aux chargements ligne-entière par id/boot
  (comptes, personnages, sociétés, biens) ; index présents sur toutes les
  colonnes de recherche (license, citizenid, owner_cid, plate, state, target_cid…).
- **Events** : 100 % des events réseau serveur passent par le wrapper sécurisé
  `S.onNet` (rate-limit + joueur chargé + pcall) — aucun `RegisterNetEvent` nu.

### Session MenuV — Boutique épicerie & atelier mécanicien migrés NUI → MenuV

Poursuite de la doctrine *« tout menu in-game → MenuV »* (zéro nouvelle feature).
Les **deux derniers menus d'interaction encore en NUI** basculent sur MenuV, en
reprenant à l'identique le pattern éprouvé concession/garage/drogues
(`MenuV:CreateMenu` + `:AddButton`, ressource `'menuv'`, `MenuV:CloseAll()` au
`onResourceStop`).

- **Boutique / épicerie** (`/world/shop.lua`, déclenchée par la zone POI `shop`) :
  le catalogue NUI plein écran (`nui/shop/`) est remplacé par un menu MenuV
  `noxa_shop_<key>` construit depuis `C.Shops[key].items` (un bouton par article
  avec emoji + prix). L'achat reste une **simple intention** : `noxa:shop:buy`
  est inchangé côté serveur (prix, solde et effets faim/soif **revérifiés et
  débités serveur**, zéro confiance). Le menu reste ouvert pour enchaîner les
  achats. `zones.lua` appelle désormais `Noxa.Shop.open(key, label, items)` au
  lieu d'ouvrir la NUI.
- **Atelier mécanicien** (`/atelier`, `jobs/mechanic.lua`) : le panneau NUI à deux
  boutons (Réparer / Nettoyer) devient un menu MenuV `noxa_mech_atelier`. La
  logique métier (`startRepair` validé/consommé serveur, nettoyage du véhicule le
  plus proche) est **inchangée** : seul le présentateur a basculé.
- **Nettoyage** : suppression de la NUI morte — dossier `nui/shop/` retiré, vue
  `atelier` + callbacks `mechRepair`/`mechWash` retirés de `nui/jobs/jobs.js`,
  entrées `fxmanifest`/`index.html` correspondantes nettoyées. Les `RegisterNUICallback`
  `shopClose`/`shopBuy` et le sync cash NUI de la boutique sont supprimés.

**Vérifications (aucun nouveau bug introduit) :**
- **Intégrité SQL** : 0 table référencée en code absente de `install.sql` ; les
  deux `install.sql` (racine + `resources/noxa-fa/sql/`) restent **identiques**.
- **Aucune référence résiduelle** : `grep` à blanc sur `nui/shop`, `shopBuy`,
  `shopClose`, `mechRepair`, `mechWash`, `'jobs', 'atelier'`.
- **fxmanifest** : dépendance `menuv` déjà déclarée, `@menuv/menuv.lua` chargé
  avant tout module ; entrées `nui/shop/*` retirées du bloc `files`.

### Session QA finale — Audit de fin de journée (bugfix + hotfix)

Passe **QA & hotfix, zéro nouvelle feature**. Revue des commits du jour (téléphone
iOS, branchement des designs autonomes, cooldown anti rapid-fire, loyers
immobiliers). **Un bug corrigé**, le reste validé sain.

- **🟠 Fuite de focus NUI sur ré-ouverture d'un design (Anti-Cheat F8 / Gestion
  `/gestion`).** `client/modules/designs/client.lua` — `openDesign()` appelait
  `NUI.setFocus(true)` à **chaque** octroi serveur. Comme l'anti-superposition
  ne ferme **pas** un panneau déjà actif (`prev == name`), une 2ᵉ pression F8
  (ou `/gestion`) **ré-incrémentait** le compteur de focus sans le relâcher →
  **curseur bloqué** après fermeture (même classe de bug que l'ancienne fuite de
  la banque). **Fix** : garde anti ré-ouverture — si le panneau est déjà actif,
  on se contente de **rafraîchir les données** sans ré-acquérir le focus,
  alignée sur le pattern `isOpen` de la banque et du téléphone.

**Vérifications QA (aucun nouveau bug introduit) :**
- **Syntaxe Lua** : `luac5.4 -p` OK sur les **105 fichiers** `noxa-fa` (les
  littéraux hash backtick `` `WEAPON_*` `` de FiveM, faux positifs en Lua vanilla,
  sont valides côté CfxLua).
- **Intégrité SQL** : 0 table référencée en code absente de `install.sql` ; les
  deux `install.sql` (racine + `resources/noxa-fa/sql/`) restent **identiques** ;
  les **18** `CREATE TABLE` sont **idempotents** (`IF NOT EXISTS`).
- **fxmanifest** : tous les fichiers référencés existent sur disque ; seuls
  `@menuv/menuv.lua` et `@oxmysql/lib/MySQL.lua` sont des dépendances
  **inter-ressources** (présentes : `resources/menuv`, `resources/[ox]/oxmysql`).
- **Compat ESX** : shim `es_extended` complet et **nil-safe** (`getSharedObject`
  export + event legacy, `GetPlayerFromId` retourne `nil` hors chargement,
  xPlayer money/job/inventaire, callbacks, events `esx:*` relayés).
- **Atomicité argent** : tous les flux (banque, achat/revente véhicule, amendes,
  loyers, drogues) sont **synchrones** (aucun yield entre vérif solde et
  mutation) ou en **saga débit-avant-écriture + rollback** (achat véhicule).
- **Cooldown anti rapid-fire** : les **16** sites appliquent bien
  `if not S.cooldown(...) then return end` ; dépassement **souple** (ignoré +
  notifié), jamais compté comme violation.
- **Téléphone** : contrat d'events Lua↔NUI **complet** (client⇄serveur 7/7
  triggers, 6/6 + `smsThread`/`threadData` round-trip) — aucune app morte.

### Session — Téléphone : refonte visuelle « iOS premium » (Option C)
- **Réécriture** de `nui/phone/phone.css` + `nui/phone/phone.js` pour adopter le langage visuel du bundle React de référence (`nui/phone/index.html`, Claude Design) — laissé intact comme référence.
- Style : châssis acier sombre, **dynamic island**, barre d'état (signal/batterie), **grille d'apps iOS** (icônes arrondies dégradées + glyphes SVG), **dock translucide** (blur), cartes/listes, **bulles SMS** accent par app, **carte de solde** dégradée, bouton power latéral + geste home.
- **Données live conservées** : contrat de messages Lua→NUI (`open/close/bootstrap/sync/contacts/smsThread/smsIncoming/smsSent/tweets/tweetNew`) et callbacks (`phoneClose/ContactAdd/Delete/SmsSend/SmsThread/TweetPost/TweetsList/BankTransfer`) **inchangés** — aucune donnée mockée. F1 ouvre/ferme, Échap ferme.

### Session — Branchement des designs autonomes (Anti-Cheat F8 · Gestion serveur /gestion)

Branchement de la **logique FiveM** sur les deux designs livrés (exports React
mono-fichier « Claude Design »), **sans altérer le visuel**. Ces bundles lisent
leur jeu de données global **une seule fois au montage** (`window.DATA` pour
l'anti-cheat, `window.MDATA` pour la gestion) et leurs boutons d'action ne
rappellent pas Lua : on les branche donc en **consoles de visualisation lecture
seule** alimentées par des **données serveur réelles**. Les sanctions/mutations
restent sur les panels **fonctionnels** existants (staff **F3**, gestion **F9**).

**Hébergement NUI** (`nui/designs/`, `nui/index.html`, `nui/shell.js`)
- Une seule `ui_page` par ressource : chaque design est chargé en **`<iframe>`**
  plein écran (overlay z-index **60**), (re)chargée à chaque ouverture pour un
  montage React propre avec la donnée fraîche.
- `nui/designs/designs.js` : hôte générique (listeners `noxa:<panel>:open/close`),
  dépose la donnée réelle sur la fenêtre parente, gère l'anti-superposition et
  relaie l'Échap (l'iframe détenant le focus NUI) vers la fermeture côté Lua.

**Pont non invasif** (injecté dans le `<head>` *externe* de chaque design)
- Piège sur `window.DATA`/`window.MDATA` (défini **avant** le bundle ; survit au
  `replaceWith` de l'unpacker car porté par `window`) : fusionne le mock de
  secours avec la donnée réelle de la fenêtre parente, **réhydrate les dates ISO**
  et conserve les helpers non sérialisables. **Fond transparent** réappliqué après
  le swap du document. Sans donnée parente, le mock d'origine s'affiche tel quel.

**Serveur (données réelles, rang revérifié)**
- `server/modules/anticheat/server.lua` : `noxa:acpanel:open` (**helper+**, IP
  réservée **admin+**) construit `window.DATA` — joueurs en ligne (trust/flags/
  statut dérivés du score AC), détections (tampon d'alertes mémoire), watchlist
  (score > 0), bans (`DB.getRecentBans`), logs (`noxa_anticheat_logs`), staff en
  ligne, stats par type.
- `server/modules/config-manager/server.lua` : `noxa:gestion:open` (**superadmin**)
  construit `window.MDATA` depuis la config vivante — items (`C.Items`), véhicules
  (`C.Vehicles` + classes), POI (`C.POI` aplati), jobs+grades (`E.Jobs`, membres
  comptés en ligne).
- `server/core/db.lua` : `DB.getRecentBans(limit)` (join `noxa_accounts` pour le
  pseudo). Aucune nouvelle table (intégrité SQL inchangée).

**Client** (`client/modules/designs/client.lua`)
- `/anticheat` (**F8**) et `/gestion` : émettent l'intention ; ouverture
  **accordée** par le serveur (grant) ; focus + anti-superposition + fermeture
  Échap relayée.

### Session 17h — Loyers immobiliers (cycle fiscal)

Branchement du **loyer d'entretien** des biens, jusqu'ici documenté mais **non
implémenté** (seul le helper BDD `DB.getOwnedPropertyTiers`, commenté *« cycle
d'entretien : loyers »*, existait — aucun appelant). Le puits monétaire est
désormais réel et cohérent avec le pattern de la paie automatique.

**Config** (`shared/config.lua`)
- `C.PropertyTiers[*].rent` : loyer/cycle par palier (≈ 1 % du prix) —
  studio 500 · appartement 1 500 · maison 4 000 · villa 12 000.
- `C.PropertyRent.interval` : 1 cycle fiscal = 1 h réelle.
- `C.Systems.propertyRent` : bascule live (désactivable sans restart).

**Serveur** (`server/modules/properties/server.lua`)
- Thread fiscal : à chaque cycle, index `citizenid → joueur connecté`, cumul du
  loyer dû par propriétaire (somme des `tier.rent` de ses biens en cache), puis
  prélèvement **bancaire** unique via `removeMoney('property:rent')`.
- **Impayé** (solde insuffisant) : verrouillage des biens du joueur (`setPropertyLocked`)
  + notification — **non destructif** (aucune saisie). `broadcastList()` au besoin.
- Seuls les **propriétaires connectés** sont prélevés (aligné sur la paie ; aucun
  écrit BDD sur balances hors-ligne).

**Panel gestion serveur** (`server/modules/config-manager/server.lua`)
- `propertyRent` ajouté à la liste blanche `systemKeys` → toggle pilotable en F9.

**Vérifs** : idiome `goto skip` en fin de bloc identique à `jobs/server.lua`
(légal Lua 5.4), intégrité SQL inchangée (`comm` table↔install vide), aucune
nouvelle table.

### Session 05h — Migration MenuV terminée (jobs + immobilier)

Achèvement de la doctrine *« tout menu in-game → MenuV »* : les **derniers menus
contextuels** encore servis par la NUI custom (`NUI.openMenu` / `NUI.confirm`) ont basculé
sur MenuV, en reprenant à l'identique le pattern de la concession/garage (création
paresseuse + `ClearItems` à chaque ouverture pour refléter l'état vivant). **Zéro nouvelle
feature** : seul le présentateur client change, toute la logique serveur (droits patron,
ownership, achats, verrou) est **inchangée**.

**Jobs — menu patron `/boss`** (`client/modules/jobs/client.lua`)
- Menu d'actions (Embaucher / Promouvoir / Licencier / Caisse Déposer / Retirer) →
  **MenuV** (`noxa_boss`).
- Les **saisies numériques** (ID joueur, grade, montant) **restent des dialogues NUI** :
  MenuV n'offre aucun champ de saisie libre, et les remplacer par des sliders à plage
  arbitraire aurait été une nouvelle feature / un changement de comportement. La sélection
  MenuV ferme le menu (`MenuV:CloseAll()`) avant d'ouvrir le dialogue de saisie.

**Immobilier** (`client/modules/properties/client.lua`)
- **Menu de porte** (Acheter / Entrer / Verrouiller) → MenuV (`noxa_property`), reconstruit
  à chaque ouverture (état propriété/verrou vivant).
- **Confirmation d'achat** → sous-menu MenuV *Acheter / Annuler* (`noxa_property_confirm`)
  en remplacement de `NUI.confirm`.
- **Menu mobilier** (`/meubles`) → MenuV (`noxa_furniture`) ; placement répété naturel
  (le menu reste ouvert), *Tout retirer* conservé.
- `onResourceStop` ferme désormais aussi tout menu MenuV ouvert.

**Reste NUI (conforme doctrine)** : HUD, notifications, banque, téléphone, inventaire,
panels admin/gestion-serveur/staff, et les **dialogues de saisie** (`NUI.input`) — aucun
équivalent MenuV. La couche `nui/menus/` n'est plus utilisée que pour ces saisies.

**Vérifs** : les deux modules **parsent** (`lua5.4 -p`), aucun appel `NUI.openMenu` /
`NUI.confirm` résiduel hors `core/nui.lua`, intégrité SQL inchangée (`comm` table↔install
vide), dépendance `menuv` déjà déclarée (ressource unique `noxa-fa`).

### Session QA — Correctifs de stabilité (crashs connexion + faux positifs AC)

Passe **QA & optimisation, zéro nouvelle feature**. Quatre bugs corrigés dont
**trois 🔴 critiques** qui bloquaient la connexion ou polluaient l'anti-cheat.

**Cause racine commune (BUG-02 & BUG-03) — sérialisation des events FiveM.**
`TriggerEvent('noxa:playerLoaded', src, ply)` fait transiter l'objet `Player`
par **msgpack** : ses *champs* survivent (`metadata`, `cash`…) mais sa
**métatable est perdue**, donc toutes ses **méthodes** (`getName`, `addItem`…)
deviennent `nil` côté handler. D'où deux crashs au chargement.

- **🔴 BUG-03 — `inventory/server.lua:275` `addItem` nil.** Le handler
  `noxa:playerLoaded` appelait `ply:addItem(...)` sur la copie sérialisée.
  **Fix** : on re-récupère la **référence vivante** via `Noxa.Players.get(src)`
  (même VM, aucune sérialisation, méthodes intactes) + guard `if not ply`.
  Le kit de départ est de nouveau distribué (l'ancien correctif « guard + return »
  proposé aurait silencieusement supprimé la dotation).
- **🔴 BUG-02 — `es_extended/server/main.lua:72` `getName` nil.** Même cause via
  l'event. **Fix** : le handler ESX récupère l'objet par l'**export**
  `exports['noxa-fa']:GetPlayer(src)` (mécanisme déjà utilisé par
  `ESX.GetPlayerFromId`) au lieu de l'argument d'event + guard nil. La couche
  compat ESX charge enfin sans planter à la connexion.
- **🔴 BUG-01 — anti-cheat : faux positifs spawn en boucle.** `entityCreating`
  comptait les **entités du monde natif** (PNJ, trafic, véhicules garés) dont le
  client devient owner réseau en les *streamant* → alertes « X entités créées »
  en boucle. **Fix** : on ne compte que les entités **script/joueur** via
  `GetEntityPopulationType` (6/7/10) ; l'ambiant (1..5) est ignoré, `nil` retombe
  sur le seuil glissant existant.
- **🟠 BUG-04 — `sv_projectName` / `sv_projectDesc` absents.** Ajoutés dans
  `server.cfg` (`sets`).
- **🟡 BUG-05 — build MenuV au 1er boot.** Vérifié : `resources/menuv/dist/`
  (`menuv.html` + assets) est **déjà committé** et le `fxmanifest` sert le build
  pré-compilé (`ui_page 'dist/menuv.html'`). Aucun `yarn`/webpack ne tourne au
  démarrage → non reproductible en l'état. Résolu.
- **🟡 BUG-06 — hairpin NAT** (server list query) : **environnemental**, aucun
  correctif repo possible — conservé dans `BUGS.md` comme rappel d'exploitation.

**Vérifications QA (aucun nouveau bug introduit) :**
- **Intégrité SQL** : 0 table référencée en code absente de `install.sql` ; les
  deux `install.sql` (racine + `resources/noxa-fa/sql/`) sont **identiques**.
- **Index SQL** : toutes les colonnes de filtrage chaud sont indexées (license,
  account_id, citizenid, created_at, owner_cid, plate…). Rien à ajouter.
- **`Wait(0)`** : les 4 boucles client restantes (menottes, inconscient,
  réparation, hotbar) sont **légitimes** (DisableControlAction / DrawText /
  IsControlJustPressed par frame) — pas de busy-loop à corriger.
- **Atomicité argent** : virement banque (`bank:transfer`) sûr —
  `maxTransfer` (5 M) < `maxTransaction` (50 M), donc `addMoney` destinataire ne
  peut pas échouer après le débit.

### Session 20h — Drogues & Trafic · Activités légales (MenuV, server-side)

Deux boucles de gameplay RP entièrement **autoritaires serveur**, présentées
100 % via **MenuV** aux POI (doctrine *« tout menu in-game → MenuV »*). Aucune
nouvelle table SQL : le butin vit dans l'**inventaire déjà persisté** (anti-dupe),
les cooldowns sont en mémoire serveur.

**Trafic de drogue** (`shared/config.lua` → `C.Drugs`, `server/modules/drugs/`,
`client/modules/drugs/`)
- **Chaîne complète** sur 3 drogues (cannabis, cocaïne, méth) :
  **récolte** au champ/dépôt (`drug_harvest`) → **transformation** au labo
  (`drug_process`, ratio matière→produit) → **vente** au revendeur (`drug_sell`).
- **Tout est recalculé serveur** : la **proximité d'un POI compatible** est
  revérifiée (`nearInteract` scanne `C.POI` + position serveur du ped), quantités
  et prix tirés serveur, **cooldown** de récolte anti-spam, **possession réelle**
  des items exigée (transfo/vente). Le client n'émet qu'une **clé de drogue**.
- **Coût RP** : la vente déclenche une **alerte dispatch police** probabiliste
  (`policeAlertChance`) → notification + **blip GPS clignotant** chez les agents en
  service, qui refroidit après 90 s.
- **Présentation** : menus MenuV par phase (champ / labo / revendeur) + **animation
  de cueillette** chronométrée, **annulable** si le joueur se déplace.
- **Items** ajoutés : `weed_bud`/`weed_bag`, `coca_leaf`/`coke_baggy`,
  `meth_chem`/`meth_crystal` (catégorie `drogue`).
- **POI** : plantations cannabis/coca, dépôt chimique (blips discrets, réglables
  `false`), labos & revendeurs **non blipés** (lieux secrets, RP de découverte).

**Activités légales** (`shared/config.lua` → `C.Activities`, `server/modules/activities/`,
`client/modules/activities/`)
- **Pêche & chasse** : achat d'outil (canne / couteau, débité serveur),
  **cueillette chronométrée** (animation propre à l'activité), **butin tiré au
  sort borné** (table de probabilités par activité), **vente sur place**.
- **Autorité serveur** : proximité du POI (`fishing`/`hunting`), **outil requis**,
  **cooldown**, butin et prix recalculés ; le client n'émet qu'une clé d'activité.
- **Items** ajoutés : `fishingrod`, `huntingknife`, `fish`/`salmon`/`shark`,
  `animal_meat`/`animal_pelt`. Les POI pêche/chasse, jusqu'ici en *« disponible
  prochainement »*, sont désormais **pleinement fonctionnels**.

### Session 00h — Économie : revente de véhicules à la concession

**Boucle économique fermée côté véhicules.** On pouvait acheter à la concession (sink :
prix + surtaxe luxe 7 % au Trésor) mais jamais revendre : l'argent immobilisé dans un
véhicule était définitivement « gelé ». Ajout d'un **faucet de revente borné**, pensé pour
ne PAS nourrir l'inflation :
- **Doctrine** (`shared/economy/vehicles.lua` → `C.Economy.Resale`) : revente = **50 % du
  prix catalogue HT**, modulé par l'**état** (moteur + carrosserie) avec un plancher de 60 %.
  Les taxes d'achat ne sont jamais remboursées ⇒ acheter puis revendre est **structurellement
  perdant** (≥ 50 % + surtaxe), ce qui tue le flip et garde le faucet sous contrôle.
- **Calcul serveur** (`Eco.vehicleResale`, exporté `GetVehicleResale`) : autoritaire, lit le
  prix catalogue + l'état BDD du véhicule. Le client n'envoie jamais de valeur.
- **Anti-dupe** : `DB.deleteOwnedVehicle` est une **suppression GARDÉE** (`DELETE … WHERE
  plate = ? AND owner_cid = ? AND state = 'stored'`) exécutée **avant** le crédit — une
  course (sortie de garage / double-revente concurrente) annule la vente sans créer d'argent.
- **Règle métier** : seuls les véhicules **remisés** sont revendables (ni sortis, ni en
  fourrière).
- **UI MenuV** : nouveau bouton *« Revendre un véhicule »* à la concession → menu listant les
  remisés avec leur valeur calculée serveur (reconstruit à l'ouverture = état vivant).
- **Flux monétaire** : nouveau libellé toast *Concession (véhicule)* côté HUD économique.

### Session 04h — MenuV opérationnel & menus véhicules migrés

**Bug d'intégration MenuV corrigé (réel, bloquant).** La ressource `menuv` avait été
committée en **source non-buildée** (ThymonA/MenuV) : pas de `fxmanifest.lua` racine, pas
de NUI compilé, et son `.gitignore` ignorait justement `dist/`, `build/` et `menuv.lua`.
Résultat : la ressource **ne pouvait pas démarrer** et n'était même pas listée dans
`server.cfg`. Corrections :
- **Build** du NUI (`npm i && node build.js --mode=production`, Vue 2/webpack) → `dist/`
  (HTML/JS/CSS compilés), `menuv.lua` (API consommateur), `menuv/components/*`, `stream/`
  (texture `menuv.ytd`), `languages/`, `config.lua`, `fxmanifest.lua` racine.
- **`.gitignore` réécrit** pour **tracker le runtime compilé** (dépôt de déploiement :
  `dist/` & co. doivent être versionnés) tout en ignorant `node_modules/` et `build/`.
- **`server.cfg`** : `ensure menuv` ajouté **avant** `noxa-fa`.
- **`noxa-fa`** déclare désormais la dépendance `menuv` et charge `@menuv/menuv.lua`.

**Véhicules migrés NUI → MenuV** (`client/modules/vehicles/client.lua`)
- **Concession** : menu racine par **catégorie** (F→S) → sous-menus de véhicules avec prix
  taxé et solde bancaire en sous-titre ; achat = `noxa:veh:buy` (serveur autoritaire).
- **Garage / Fourrière** : menu reconstruit à chaque ouverture (état vivant) — *Sortir*
  les remisés, *Remiser* les sortis (lecture carburant/santé locale), *Récupérer* la
  fourrière contre amende.
- Toute la logique serveur (ownership, transitions atomiques `stored↔out↔impound`, prix,
  plaque unique) **inchangée** : seul le présentateur client a basculé sur MenuV.
- **NUI véhicules custom supprimée** (`nui/vehicles/`, entrées `fxmanifest`/`index.html`/
  `shell.js`) — conforme à la doctrine *« tous les menus in-game → MenuV »* (la NUI custom
  reste réservée à HUD, notifications, banque, téléphone, inventaire).

### Session 20h — Couche de compatibilité ESX & intégrité SQL

Concrétisation de la **promesse d'architecture** : *« tout script ESX tourne sans
modification »*. Nouvelle ressource **`es_extended`** (shim mince) qui **délègue à
noxa-fa** — aucune logique critique dupliquée, l'autorité reste server-side.

**Pont serveur** (`resources/es_extended/server/main.lua`)
- `exports['es_extended']:getSharedObject()` **+** API legacy `TriggerEvent('esx:getSharedObject', cb)`.
- `ESX.GetPlayerFromId / GetPlayerFromIdentifier / GetPlayers / GetExtendedPlayers / GetNumPlayers`.
- **xPlayer** (closures sur l'objet `Player` **vivant** de noxa, références Lua↔Lua) :
  `getMoney/addMoney/removeMoney`, `getAccount(s)/addAccountMoney/removeAccountMoney/setAccountMoney/setMoney`
  (mapping ESX `money`↔`cash`, `bank`↔`bank`), `getJob/setJob`,
  `addInventoryItem/removeInventoryItem/getInventoryItem/getInventory/hasItem/getWeight`,
  identité/coords/kick, variables `set/get`, `showNotification/triggerEvent`.
- `ESX.RegisterServerCallback` + bridge `esx:triggerServerCallback`/`esx:serverCallback`.
- `ESX.RegisterUsableItem` branché sur le nouvel event noxa **`noxa:item:used`** (émis
  par `inventory:useSlot` après l'effet autoritaire). `ESX.RegisterCommand`, `ESX.Math/Table`.
- **Miroir d'événements** : `noxa:playerLoaded` → `esx:playerLoaded` (serveur + client,
  instantané sérialisable), `noxa:playerUnloaded` → `esx:playerDropped`, `setJob` → `esx:setJob`.

**Pont client** (`resources/es_extended/client/main.lua`)
- `getSharedObject`, `ESX.PlayerData/GetPlayerData/SetPlayerData/IsPlayerLoaded`.
- `ESX.ShowNotification/TextUI` → **NUI custom noxa** (nouvel export client `noxa-fa:Notify`,
  zéro feed GTA / zéro ox_lib), `ESX.TriggerServerCallback`, `ESX.Math`.
- Synchronisation sur `noxa:client:playerDataUpdated` (statebag répliqué) → reconstruit
  `ESX.PlayerData` (job au format ESX) et relaie `esx:setJob` / `esx:playerLoaded`.

**Intégrité SQL** — correction d'un **bug d'installation réel** : `install.sql` racine
était **périmé** (manquait `noxa_config`, `noxa_scheduled_messages`,
`noxa_anticheat_logs`) → une install fraîche plantait au boot des modules config-manager
/ anti-cheat. Resynchronisé depuis `resources/noxa-fa/sql/install.sql` (audit
référencé⊆déclaré : **0 table manquante**).

> Note de portée : `es_extended` couvre l'API ESX la plus utilisée par les scripts
> tiers. Le bridge `RegisterUsableItem` exige que l'item existe au catalogue noxa
> (`shared/items.lua`). L'argent sale ESX (`black_money`) n'est pas géré (noxa n'a
> que `cash`/`bank`).

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
- **oxmysql** — accès base de données
- **MenuV** (ThymonA) — bibliothèque de **menus in-game unifiée** (1 seule ressource)
- **NUI custom** (HTML/CSS/JS natif) — HUD, notifications, banque, téléphone, inventaire,
  sélection/création de personnage, boutique, panels admin/staff — **zéro ox_lib visuel**

> Doctrine UI : **tout menu in-game passe par MenuV** ; la NUI custom maison est
> réservée aux surfaces riches (HUD, notifs, banque, téléphone, inventaire).
> Design premium dark, typographie Inter/Poppins, animations fluides.

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
│       ├── phone/          # téléphone : numéro, contacts, SMS, réseau social
│       ├── drugs/          # trafic : récolte/transfo/vente (proximité POI server-side)
│       └── activities/     # pêche & chasse : outil/cueillette/vente (autoritaire)
├── client/
│   ├── core/               # nui (pont) · spawn · ui
│   └── modules/
│       ├── characters/ hud/ economy/ jobs/ banking/ admin/ staff-panel/
│       ├── world/          # blips · zones (proximité + prompt) · shop · fuel
│       ├── properties/     # portes interactives, intérieurs, mobilier
│       ├── phone/          # ouverture F1, pont NUI
│       ├── drugs/          # menus MenuV récolte/transfo/vente + anim + dispatch
│       └── activities/     # menus MenuV pêche/chasse (outil/cueillette/vente)
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
  (rate-limit anti-flood + vérification de chargement + capture d'erreur).
- **Cooldown anti rapid-fire** : `Security.cooldown` impose **1000 ms minimum**
  entre deux actions sensibles (achats véhicule/immobilier/boutique, dépôt/retrait/
  virement banque, factures, caisse société, ventes activités/drogues, carburant).
  Rejet souple **sans** compter de violation (un double-clic légitime n'est jamais sanctionné).
- **Ownership vérifié** : personnages, factures, biens immobiliers.
- **Anti-dupe** : achat immobilier atomique (réservation BDD avant débit).
- **Auditabilité** : transactions, incidents et achats journalisés en base.
- **Modularité** : ajouter un module = un dossier + une entrée manifest.

## Commandes & touches

### Monde
- **E** — interagir avec un POI à proximité (banque, distributeur, épicerie,
  station essence, porte d'un bien immobilier, **champ/labo/revendeur de drogue**,
  **spot de pêche / zone de chasse**) → menu **MenuV** contextuel
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
- **Dashboard Anti-Cheat (design Claude)** : **F8** (`/anticheat`) — console de
  visualisation lecture seule (joueurs/détections/watchlist/bans/logs réels), helper+
- **Gestion serveur (design Claude)** : `/gestion` — visualisation config réelle
  (items/véhicules/POI/jobs), superadmin (éditeur live fonctionnel : **F9**)
- **Menu admin NUI** : **F10** (`/adminmenu`) — 9 sections, navigation flèches + souris
- Commandes : `/kick` `/ban` `/unban` `/heal` `/revive` `/goto` `/bring` `/announce`
  `/setmoney` `/job` `/setjobwl` `/setgroup`

## Historique — durcissement sécurité (stable-2.5)

- **Cooldown sensible (anti rapid-fire)** : nouvel helper `Security.cooldown(src, key, ms)`
  garantissant **1000 ms minimum** entre deux actions sensibles, appliqué à **16 events**
  d'argent : `veh:buy/sell/retrieve`, `prop:buy`, `shop:buy`, `bank:deposit/withdraw/
  transfer/invoice:create/invoice:pay`, `society:deposit/withdraw`, `act:buyTool/sell`,
  `drug:sell`, `fuel:request`. Rejet **souple** (notify) qui n'incrémente pas le compteur
  de violations — contrairement au rate-limit anti-flood, il ne peut donc jamais
  auto-kick un joueur pour un double-clic. Complète l'anti-dupe atomique déjà en place.

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
