-- =====================================================================
--  NOXA FA — Gestionnaire de configuration live (server-side)
--  ⭐ PANEL GESTION SERVEUR : configurer le serveur EN DIRECT, sans restart.
--
--  Principe :
--    • Chaque « domaine » de config (economy, poi, enumsJobs...) est une
--      TABLE VIVANTE déjà chargée en mémoire (Noxa.Config / Noxa.Enums).
--    • Une modification = mutation EN PLACE de cette table (les modules en
--      gardent la référence, donc voient le changement au prochain accès)
--      + persistance d'un INSTANTANÉ JSON du domaine dans `noxa_config`.
--    • Au boot, les instantanés rejouent par-dessus les valeurs statiques.
--    • Les domaines « client » sont rediffusés (POI, spawn, boutiques...).
--
--  Sécurité : ouverture + TOUTES les mutations réservées au rang superadmin,
--  revérifié serveur à chaque event ; jamais aucune donnée client de confiance.
--  Toute mutation est journalisée (noxa_logs, catégorie 'config').
-- =====================================================================

Noxa = Noxa or {}
Noxa.ConfigManager = {}

local CM  = Noxa.ConfigManager
local U   = Noxa.Utils
local E   = Noxa.Enums
local DB  = Noxa.DB
local CFG = Noxa.Config

local serverStart = os.time()

-- ---------------------------------------------------------------------
--  Helpers de table (remplacement en place pour préserver les références)
-- ---------------------------------------------------------------------

local function deepCopy(v)
    if type(v) ~= 'table' then return v end
    local t = {}
    for k, val in pairs(v) do t[k] = deepCopy(val) end
    return t
end

--- Vide `target` puis y recopie (en profondeur) le contenu de `source`,
--- SANS changer la référence de `target` (les modules la conservent).
local function replaceContents(target, source)
    for k in pairs(target) do target[k] = nil end
    if type(source) == 'table' then
        for k, v in pairs(source) do target[k] = deepCopy(v) end
    end
end

--- Les tables de grades sont indexées par ENTIER ([0],[1]...). Le passage
--- par JSON peut transformer ces clés en chaînes ("0","1") : on les rétablit
--- en entiers pour ne pas casser job.grades[grade].
local function fixGradeKeys(refTbl)
    for _, def in pairs(refTbl) do
        if type(def) == 'table' and type(def.grades) == 'table' then
            local g = {}
            for k, v in pairs(def.grades) do g[tonumber(k) or k] = v end
            def.grades = g
        end
    end
end

-- ---------------------------------------------------------------------
--  Domaines persistables : nom -> { ref = table vivante, client = bool }
--  `client` = true : le domaine est rediffusé aux joueurs après changement.
-- ---------------------------------------------------------------------
local domains = {
    economy    = { ref = CFG.Economy,      client = false },
    banking    = { ref = CFG.Banking,      client = false },
    fuel       = { ref = CFG.Fuel,         client = false },
    systems    = { ref = CFG.Systems,      client = true  },
    shops      = { ref = CFG.Shops,        client = true  },
    spawn      = { ref = CFG.DefaultSpawn, client = true  },
    poi        = { ref = CFG.POI,          client = true  },
    enumsJobs  = { ref = E.Jobs,           client = false },
    enumsGangs = { ref = E.Gangs,          client = false },
}

--- Diffuse à tous les clients le domaine modifié (refresh sans restart).
local function broadcastDomain(name)
    local d = domains[name]
    if not d or not d.client then return end
    TriggerClientEvent('noxa:cfg:domain', -1, name, d.ref)
end

--- Persiste l'instantané JSON du domaine + (option) rediffusion client.
local function persist(name, actor)
    local d = domains[name]
    if not d then return end
    DB.setConfigOverride(name, U.jsonEncode(d.ref), actor)
    broadcastDomain(name)
end

-- ---------------------------------------------------------------------
--  Chargement des surcharges au démarrage (rejoue par-dessus le statique)
-- ---------------------------------------------------------------------
local function loadOverrides()
    local rows = DB.getConfigOverrides()
    local n = 0
    for _, r in ipairs(rows) do
        local d = domains[r.ckey]
        if d then
            local decoded = U.jsonDecode(r.cvalue, nil)
            if type(decoded) == 'table' then
                replaceContents(d.ref, decoded)
                if r.ckey == 'enumsJobs' or r.ckey == 'enumsGangs' then
                    fixGradeKeys(d.ref)
                end
                n = n + 1
            end
        end
    end
    -- Applique l'état météo figé éventuel (systems.forcedWeather).
    if CFG.Systems.weatherAuto == false and CFG.Systems.forcedWeather then
        if Noxa.WorldTime then Noxa.WorldTime.forceWeather(CFG.Systems.forcedWeather) end
    end
    U.print('info', 'ConfigManager : %d surcharge(s) de config appliquée(s).', n)
end

-- =====================================================================
--  CHAMPS SCALAIRES ÉDITABLES — allowlist stricte (domaine -> clé -> bornes)
--  Toute valeur hors borne est refusée + journalisée. Le client ne peut
--  modifier QUE ces clés ; rien d'autre n'est jamais écrit par scalaire.
-- =====================================================================
local fields = {
    economy = {
        maxTransaction = { type = 'int', min = 1000,  max = 1000000000, label = 'Transaction max' },
        maxBalance     = { type = 'int', min = 100000, max = 9000000000, label = 'Solde max' },
        logThreshold   = { type = 'int', min = 1000,  max = 100000000,  label = 'Seuil de log' },
    },
    banking = {
        maxWithdraw = { type = 'int',   min = 1000, max = 100000000, label = 'Retrait max' },
        maxDeposit  = { type = 'int',   min = 1000, max = 100000000, label = 'Dépôt max' },
        maxTransfer = { type = 'int',   min = 1000, max = 100000000, label = 'Virement max' },
        transferFee = { type = 'float', min = 0.0,  max = 0.25,      label = 'Frais virement (0–0.25)' },
        invoiceMax  = { type = 'int',   min = 1000, max = 100000000, label = 'Facture max' },
    },
    fuel = {
        pricePerUnit = { type = 'int', min = 1, max = 100, label = 'Prix carburant /%' },
    },
}

--- Valide & convertit une valeur selon la définition du champ.
---@return number|nil
local function coerceField(def, raw)
    local v = tonumber(raw)
    if not v then return nil end
    if def.type == 'int' then v = math.floor(v) end
    if v < def.min or v > def.max then return nil end
    return v
end

-- =====================================================================
--  Sérialisation pour la NUI (lecture seule, instantanés)
-- =====================================================================

local function buildServer()
    return {
        name       = CFG.ServerName,
        players    = Noxa.Players.count(),
        connected  = #GetPlayers(),
        maxClients = GetConvarInt('sv_maxclients', 48),
        uptime     = os.time() - serverStart,
    }
end

--- Jobs/gangs : grades (map entiers) -> liste triée pour la NUI.
local function serializeRoles(src)
    local out = {}
    for name, def in pairs(src) do
        local grades = {}
        for g, gd in pairs(def.grades or {}) do
            grades[#grades + 1] = { grade = tonumber(g) or 0, label = gd.label, salary = gd.salary }
        end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        out[#out + 1] = { name = name, label = def.label, society = def.society,
                          whitelisted = def.whitelisted or false, grades = grades }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

--- POI : résumé éditable (catégorie -> label + liste de points).
local function serializePOI()
    local out = {}
    for cat, def in pairs(CFG.POI) do
        local pts = {}
        for i, p in ipairs(def.points or {}) do
            pts[#pts + 1] = { i = i, x = p.x, y = p.y, z = p.z }
        end
        out[#out + 1] = { cat = cat, label = def.label, count = #pts, points = pts }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function serializeSocieties()
    local out = {}
    for name, s in pairs(Noxa.Societies.getAll()) do
        out[#out + 1] = { name = name, label = s.label, type = s.type, balance = s.balance }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

--- Instantané complet servi à l'ouverture du panel.
local function buildSnapshot(ply)
    return {
        rank        = ply and ply.staffRank or 'user',
        server      = buildServer(),
        fields      = fields,
        economy     = CFG.Economy,
        banking     = CFG.Banking,
        fuel        = CFG.Fuel,
        systems     = CFG.Systems,
        weatherCycle = CFG.World.weatherCycle,
        shops       = CFG.Shops,
        spawn       = CFG.DefaultSpawn,
        poi         = serializePOI(),
        jobs        = serializeRoles(E.Jobs),
        gangs       = serializeRoles(E.Gangs),
        societies   = serializeSocieties(),
        messages    = DB.getScheduledMessages(),
        whitelist   = DB.getJobWhitelistAll(),
    }
end

-- ---------------------------------------------------------------------
--  Permission & journalisation
-- ---------------------------------------------------------------------
local function isSuper(src)
    if src == 0 then return true end
    local ply = Noxa.Players.get(src)
    if not ply then return false end
    return (E.StaffRanks[ply.staffRank] or 0) >= E.StaffRanks.superadmin
end

local function actorName(src)
    if src == 0 then return 'console' end
    local ply = Noxa.Players.get(src)
    return ply and ('%s [%s]'):format(ply:getName(), ply.citizenid) or ('src:' .. src)
end

local function logAction(src, ply, msg)
    DB.log('config', 'warn', ply and ply.license, ('%s : %s'):format(actorName(src), msg))
end

local function feedback(src, msg, kind)
    if src == 0 then U.print('info', msg)
    else TriggerClientEvent('noxa:notify', src, msg, kind or 'inform') end
end

--- Renvoie l'instantané rafraîchi au demandeur (après une mutation).
local function pushSnapshot(src)
    local ply = Noxa.Players.get(src)
    TriggerClientEvent('noxa:cfg:snapshot', src, buildSnapshot(ply))
end

-- =====================================================================
--  TABLE D'ACTIONS — chaque mutation valide, applique en mémoire,
--  persiste, (rediffuse), journalise. handler(src, ply, params) -> bool ok
-- =====================================================================
local actions = {}

-- --- Champ scalaire générique (économie / banque / carburant) -----------
actions.setField = function(src, ply, p)
    local group = fields[p.domain]
    local def   = group and group[p.key]
    if not def then return feedback(src, 'Champ non éditable.', 'error') end
    local v = coerceField(def, p.value)
    if v == nil then return feedback(src, ('Valeur hors borne (%s).'):format(def.label), 'error') end
    domains[p.domain].ref[p.key] = v
    persist(p.domain, actorName(src))
    logAction(src, ply, ('%s.%s = %s'):format(p.domain, p.key, v))
    feedback(src, ('%s mis à jour.'):format(def.label), 'success')
    return true
end

-- --- Bascules systèmes (pvp, météo auto, paie, taxes...) -----------------
local systemKeys = { pvp = true, weatherAuto = true, payroll = true,
                     economyTax = true, scheduledMsg = true }

actions.toggleSystem = function(src, ply, p)
    if not systemKeys[p.key] then return feedback(src, 'Système inconnu.', 'error') end
    CFG.Systems[p.key] = (p.on == true)
    persist('systems', actorName(src))
    logAction(src, ply, ('système %s -> %s'):format(p.key, tostring(p.on)))
    feedback(src, ('Système « %s » %s.'):format(p.key, p.on and 'activé' or 'désactivé'), 'success')
    return true
end

-- --- Météo / heure (live, via WorldTime) --------------------------------
actions.setWeather = function(src, ply, p)
    if not (Noxa.WorldTime and Noxa.WorldTime.forceWeather(p.weather)) then
        return feedback(src, 'Type météo invalide.', 'error')
    end
    CFG.Systems.weatherAuto   = false
    CFG.Systems.forcedWeather = tostring(p.weather):upper()
    persist('systems', actorName(src))
    logAction(src, ply, ('météo forcée -> %s'):format(p.weather))
    feedback(src, ('Météo : %s'):format(p.weather), 'success')
    return true
end

actions.setHour = function(src, ply, p)
    local h = U.clampInt(p.hour, 0, 23)
    if h == nil then return feedback(src, 'Heure invalide (0–23).', 'error') end
    if Noxa.WorldTime then Noxa.WorldTime.setHour(h) end
    logAction(src, ply, ('heure réglée -> %02dh'):format(h))
    feedback(src, ('Heure réglée sur %02d:00.'):format(h), 'success')
    return true
end

-- --- Boutiques : prix d'un article --------------------------------------
actions.shopPrice = function(src, ply, p)
    local shop = CFG.Shops[p.shop]
    if not shop then return feedback(src, 'Boutique inconnue.', 'error') end
    local price = U.clampInt(p.price, 1, 10000000)
    if price == nil then return feedback(src, 'Prix invalide.', 'error') end
    for _, it in ipairs(shop.items or {}) do
        if it.id == p.id then
            it.price = price
            persist('shops', actorName(src))
            logAction(src, ply, ('prix %s/%s -> %s'):format(p.shop, p.id, price))
            feedback(src, ('Prix de %s : %s'):format(it.label, U.money(price)), 'success')
            return true
        end
    end
    return feedback(src, 'Article introuvable.', 'error')
end

-- --- Coordonnées : spawn par défaut -------------------------------------
actions.setSpawn = function(src, ply, p)
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not (x and y and z) then return feedback(src, 'Coordonnées invalides.', 'error') end
    CFG.DefaultSpawn.x = x + 0.0; CFG.DefaultSpawn.y = y + 0.0; CFG.DefaultSpawn.z = z + 0.0
    CFG.DefaultSpawn.heading = (tonumber(p.heading) or CFG.DefaultSpawn.heading or 0.0) + 0.0
    persist('spawn', actorName(src))
    logAction(src, ply, ('spawn -> %.1f %.1f %.1f'):format(x, y, z))
    feedback(src, 'Point de spawn mis à jour.', 'success')
    return true
end

-- --- Coordonnées : POI (ajout / retrait d'un point) ---------------------
actions.poiAddPoint = function(src, ply, p)
    local def = CFG.POI[p.cat]
    if not def then return feedback(src, 'Catégorie POI inconnue.', 'error') end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not (x and y and z) then return feedback(src, 'Coordonnées invalides.', 'error') end
    def.points = def.points or {}
    if #def.points >= 100 then return feedback(src, 'Trop de points (max 100).', 'error') end
    def.points[#def.points + 1] = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
    persist('poi', actorName(src))
    logAction(src, ply, ('POI %s : +1 point'):format(p.cat))
    feedback(src, ('Point ajouté à « %s ».'):format(def.label), 'success')
    return true
end

actions.poiRemovePoint = function(src, ply, p)
    local def = CFG.POI[p.cat]
    if not def or type(def.points) ~= 'table' then return feedback(src, 'Catégorie POI inconnue.', 'error') end
    local idx = tonumber(p.index)
    if not idx or not def.points[idx] then return feedback(src, 'Index invalide.', 'error') end
    table.remove(def.points, idx)
    persist('poi', actorName(src))
    logAction(src, ply, ('POI %s : -1 point (#%d)'):format(p.cat, idx))
    feedback(src, 'Point supprimé.', 'success')
    return true
end

-- --- Jobs : salaire de grade / ajout / retrait de grade / libellé -------
local SALARY_MAX = 100000

local function resyncJob(jobName)
    for _, pl in pairs(Noxa.Players.getAll()) do
        if pl.job == jobName then pl:syncState() end
    end
end

actions.jobSalary = function(src, ply, p)
    local job = E.Jobs[p.job]
    if not job then return feedback(src, 'Job inconnu.', 'error') end
    local g = job.grades[tonumber(p.grade)]
    if not g then return feedback(src, 'Grade inconnu.', 'error') end
    local salary = U.clampInt(p.salary, 0, SALARY_MAX)
    if salary == nil then return feedback(src, 'Salaire invalide.', 'error') end
    g.salary = salary
    persist('enumsJobs', actorName(src))
    resyncJob(p.job)
    logAction(src, ply, ('salaire %s g%s -> %s'):format(p.job, p.grade, salary))
    feedback(src, ('Salaire mis à jour (%s).'):format(g.label), 'success')
    return true
end

actions.jobAddGrade = function(src, ply, p)
    local job = E.Jobs[p.job]
    if not job then return feedback(src, 'Job inconnu.', 'error') end
    local label  = U.sanitizeName(p.label, 2, 24) or (type(p.label) == 'string' and p.label:sub(1, 24))
    if not label or label == '' then return feedback(src, 'Libellé invalide.', 'error') end
    local salary = U.clampInt(p.salary, 0, SALARY_MAX) or 0
    -- Nouveau grade = max existant + 1.
    local maxG = -1
    for g in pairs(job.grades) do maxG = math.max(maxG, tonumber(g) or 0) end
    job.grades[maxG + 1] = { name = ('grade%d'):format(maxG + 1), label = label, salary = salary }
    persist('enumsJobs', actorName(src))
    logAction(src, ply, ('job %s : +grade %d (%s)'):format(p.job, maxG + 1, label))
    feedback(src, ('Grade « %s » ajouté.'):format(label), 'success')
    return true
end

actions.jobRemoveGrade = function(src, ply, p)
    local job = E.Jobs[p.job]
    if not job then return feedback(src, 'Job inconnu.', 'error') end
    local grade = tonumber(p.grade)
    if not job.grades[grade] then return feedback(src, 'Grade inconnu.', 'error') end
    if U.tableCount(job.grades) <= 1 then return feedback(src, 'Un job doit garder au moins un grade.', 'error') end
    job.grades[grade] = nil
    persist('enumsJobs', actorName(src))
    logAction(src, ply, ('job %s : -grade %d'):format(p.job, grade))
    feedback(src, 'Grade supprimé.', 'success')
    return true
end

actions.jobAdd = function(src, ply, p)
    local name = type(p.name) == 'string' and p.name:gsub('[^%a%d_]', ''):lower():sub(1, 24) or ''
    local label = type(p.label) == 'string' and p.label:sub(1, 24) or ''
    if name == '' or label == '' then return feedback(src, 'Nom/libellé requis.', 'error') end
    if E.Jobs[name] then return feedback(src, 'Ce job existe déjà.', 'error') end
    E.Jobs[name] = {
        label = label, defaultGrade = 0,
        grades = { [0] = { name = 'recruit', label = 'Recrue', salary = U.clampInt(p.salary, 0, SALARY_MAX) or 500 } },
    }
    persist('enumsJobs', actorName(src))
    logAction(src, ply, ('job créé : %s (%s)'):format(name, label))
    feedback(src, ('Job « %s » créé.'):format(label), 'success')
    return true
end

actions.jobRemove = function(src, ply, p)
    if p.job == 'unemployed' then return feedback(src, 'Le job « sans emploi » est protégé.', 'error') end
    if not E.Jobs[p.job] then return feedback(src, 'Job inconnu.', 'error') end
    -- Rebascule les joueurs concernés vers « sans emploi » (anti-état orphelin).
    for _, pl in pairs(Noxa.Players.getAll()) do
        if pl.job == p.job then pl:setJob('unemployed', 0) end
    end
    E.Jobs[p.job] = nil
    persist('enumsJobs', actorName(src))
    logAction(src, ply, ('job supprimé : %s'):format(p.job))
    feedback(src, 'Job supprimé.', 'success')
    return true
end

-- --- Organisations (gangs) ----------------------------------------------
actions.gangAdd = function(src, ply, p)
    local name = type(p.name) == 'string' and p.name:gsub('[^%a%d_]', ''):lower():sub(1, 24) or ''
    local label = type(p.label) == 'string' and p.label:sub(1, 24) or ''
    if name == '' or label == '' then return feedback(src, 'Nom/libellé requis.', 'error') end
    if E.Gangs[name] then return feedback(src, 'Cette organisation existe déjà.', 'error') end
    local society = 'gang_' .. name
    E.Gangs[name] = {
        label = label, society = society,
        grades = {
            [0] = { name = 'recruit', label = 'Recrue' },
            [1] = { name = 'member',  label = 'Membre' },
            [2] = { name = 'boss',    label = 'Boss', isBoss = true,
                    perms = { recruit = true, fire = true, promote = true, manageFunds = true } },
        },
    }
    Noxa.Societies.ensure(society, label, E.SocietyType.GANG, 0)
    persist('enumsGangs', actorName(src))
    logAction(src, ply, ('gang créé : %s (%s)'):format(name, label))
    feedback(src, ('Organisation « %s » créée.'):format(label), 'success')
    return true
end

actions.gangRemove = function(src, ply, p)
    if p.gang == 'none' then return feedback(src, 'L\'organisation « aucune » est protégée.', 'error') end
    if not E.Gangs[p.gang] then return feedback(src, 'Organisation inconnue.', 'error') end
    for _, pl in pairs(Noxa.Players.getAll()) do
        if pl.gang == p.gang then pl:setGang('none', 0) end
    end
    E.Gangs[p.gang] = nil
    persist('enumsGangs', actorName(src))
    logAction(src, ply, ('gang supprimé : %s'):format(p.gang))
    feedback(src, 'Organisation supprimée.', 'success')
    return true
end

-- --- Messages serveur planifiés -----------------------------------------
actions.msgAdd = function(src, ply, p)
    local body = type(p.body) == 'string' and p.body:gsub('%s+$', ''):sub(1, 512) or ''
    if #body < 2 then return feedback(src, 'Message trop court.', 'error') end
    local interval = U.clampInt(p.interval, 1, 1440) or 30
    DB.addScheduledMessage(body, interval, actorName(src))
    Noxa.ConfigManager.reloadMessages()
    logAction(src, ply, ('message planifié ajouté (%d min)'):format(interval))
    feedback(src, 'Message planifié ajouté.', 'success')
    return true
end

actions.msgToggle = function(src, ply, p)
    local id = tonumber(p.id)
    if not id then return feedback(src, 'ID invalide.', 'error') end
    DB.setScheduledMessageEnabled(id, p.on == true)
    Noxa.ConfigManager.reloadMessages()
    logAction(src, ply, ('message #%d -> %s'):format(id, tostring(p.on)))
    feedback(src, 'Message mis à jour.', 'success')
    return true
end

actions.msgRemove = function(src, ply, p)
    local id = tonumber(p.id)
    if not id then return feedback(src, 'ID invalide.', 'error') end
    DB.deleteScheduledMessage(id)
    Noxa.ConfigManager.reloadMessages()
    logAction(src, ply, ('message #%d supprimé'):format(id))
    feedback(src, 'Message supprimé.', 'success')
    return true
end

-- --- Whitelist d'emploi --------------------------------------------------
actions.wlSet = function(src, ply, p)
    local cid = type(p.citizenid) == 'string' and p.citizenid:gsub('[^%w]', ''):sub(1, 12) or ''
    if cid == '' then return feedback(src, 'Citizen ID invalide.', 'error') end
    if not E.Jobs[p.job] then return feedback(src, 'Job inconnu.', 'error') end
    local maxGrade = U.clampInt(p.maxGrade or 0, 0, CFG.Jobs.maxGrade) or 0
    DB.setJobWhitelist(cid, p.job, maxGrade, actorName(src))
    logAction(src, ply, ('whitelist %s sur %s g%d'):format(cid, p.job, maxGrade))
    feedback(src, ('Whitelist %s -> %s g%d'):format(cid, p.job, maxGrade), 'success')
    return true
end

actions.wlRemove = function(src, ply, p)
    local cid = type(p.citizenid) == 'string' and p.citizenid:gsub('[^%w]', ''):sub(1, 12) or ''
    if cid == '' or not p.job then return feedback(src, 'Paramètres invalides.', 'error') end
    DB.removeJobWhitelist(cid, p.job)
    logAction(src, ply, ('whitelist retirée %s sur %s'):format(cid, p.job))
    feedback(src, 'Whitelist retirée.', 'success')
    return true
end

-- =====================================================================
--  Events réseau sécurisés (ouverture + actions). Rang revérifié serveur.
-- =====================================================================

Noxa.Security.onNet('noxa:cfg:open', function(src, ply)
    if not isSuper(src) then
        -- Silencieux : un non-superadmin n'obtient aucune ouverture.
        return Noxa.Security.flag(src, 'cfg:open sans rang superadmin')
    end
    logAction(src, ply, 'a ouvert le panel gestion serveur')
    TriggerClientEvent('noxa:cfg:grant', src, buildSnapshot(ply))
end)

Noxa.Security.onNet('noxa:cfg:refresh', function(src, ply)
    if not isSuper(src) then return Noxa.Security.flag(src, 'cfg:refresh sans rang') end
    pushSnapshot(src)
end)

Noxa.Security.onNet('noxa:cfg:action', function(src, ply, payload)
    if not isSuper(src) then return Noxa.Security.flag(src, 'cfg:action sans rang superadmin') end
    if type(payload) ~= 'table' or type(payload.action) ~= 'string' then
        return Noxa.Security.flag(src, 'cfg:action malformée')
    end
    local fn = actions[payload.action]
    if not fn then return Noxa.Security.flag(src, ('cfg:action inconnue (%s)'):format(payload.action)) end
    fn(src, ply, payload.params or {})
    -- Renvoie l'instantané à jour (la mutation a pu changer plusieurs vues).
    pushSnapshot(src)
end)

-- =====================================================================
--  MESSAGES SERVEUR PLANIFIÉS — diffusion à intervalle (sans restart)
-- =====================================================================
local schedule = {}   -- { {id, body, interval, enabled, nextAt} }

function CM.reloadMessages()
    local rows = DB.getScheduledMessages()
    local now = GetGameTimer()
    schedule = {}
    for _, r in ipairs(rows) do
        schedule[#schedule + 1] = {
            id = r.id, body = r.body,
            interval = (tonumber(r.interval_min) or 30) * 60000,
            enabled = (tonumber(r.enabled) or 1) == 1,
            nextAt = now + (tonumber(r.interval_min) or 30) * 60000,
        }
    end
end

CreateThread(function()
    while true do
        Wait(10000)
        if CFG.Systems.scheduledMsg ~= false then
            local now = GetGameTimer()
            for _, m in ipairs(schedule) do
                if m.enabled and now >= m.nextAt then
                    TriggerClientEvent('noxa:announce', -1, m.body)
                    m.nextAt = now + m.interval
                end
            end
        end
    end
end)

-- =====================================================================
--  Initialisation au boot (après chargement de la base & des sociétés)
-- =====================================================================
CreateThread(function()
    -- Laisse les sociétés s'initialiser (le module gang peut créer des caisses).
    Wait(1500)
    loadOverrides()
    CM.reloadMessages()
    -- Diffuse l'état systèmes initial aux clients déjà connectés (hot-reload).
    broadcastDomain('systems')
end)

-- À la connexion : pousse l'état « systèmes » au nouveau client (pvp, météo...).
AddEventHandler('noxa:playerLoaded', function(src)
    TriggerClientEvent('noxa:cfg:domain', src, 'systems', CFG.Systems)
end)

return CM
