-- =====================================================================
--  NOXA FA — Pont Lua <-> NUI (client)
--  Couche unique d'accès à l'interface 100 % custom (zéro ox_lib visuel).
--  • Noxa.NUI.send(app, action, data) : envoi typé vers le routeur NUI.
--  • Gestion centralisée du focus souris/clavier (SetNuiFocus).
--  • API menus/dialogues pilotés serveur : openMenu / input / confirm,
--    avec registre de callbacks (résolution à la réponse de la NUI).
--  • Enregistrement de tous les NUICallbacks consommés par les modules.
-- =====================================================================

Noxa = Noxa or {}
Noxa.NUI = {}

local NUI = Noxa.NUI
local focusCount = 0           -- nombre de couches NUI réclamant le focus

-- ---------------------------------------------------------------------
--  Envoi & focus
-- ---------------------------------------------------------------------

--- Envoie un message structuré à la NUI.
---@param app string module cible (notify|hud|menu|characters|banking)
---@param action string
---@param data? table
function NUI.send(app, action, data)
    SendNUIMessage({ app = app, action = action, data = data or {} })
end

--- Acquiert / libère le focus NUI (curseur + clavier). Compteur de couches
--- pour gérer les ouvertures imbriquées sans relâcher prématurément.
---@param state boolean
function NUI.setFocus(state)
    if state then
        focusCount = focusCount + 1
    else
        focusCount = math.max(0, focusCount - 1)
    end
    local active = focusCount > 0
    SetNuiFocus(active, active)
    SetNuiFocusKeepInput(false)
end

--- Force la libération de tout focus (sécurité : fermeture totale).
function NUI.releaseAll()
    focusCount = 0
    SetNuiFocus(false, false)
end

-- ---------------------------------------------------------------------
--  Registre des callbacks de menus/dialogues pilotés Lua
-- ---------------------------------------------------------------------

local pending = {}   -- [id] = { onSelect=fn } | { onInput=fn } | { onConfirm=fn }
local seq = 0

local function nextId(prefix)
    seq = seq + 1
    return ('%s_%d'):format(prefix, seq)
end

--- Ouvre un menu contextuel custom.
---@param opts { title:string, subtitle?:string, options:table[] }
---@param onSelect fun(optionId:any)  appelé avec l'id de l'option choisie
function NUI.openMenu(opts, onSelect)
    local id = nextId('menu')
    pending[id] = { onSelect = onSelect }
    NUI.setFocus(true)
    NUI.send('menu', 'context', {
        id = id, title = opts.title, subtitle = opts.subtitle, options = opts.options,
    })
end

--- Ouvre un dialogue de saisie custom.
---@param opts { title:string, subtitle?:string, fields:table[] }
---@param onInput fun(values:table|nil)  nil si annulé
function NUI.input(opts, onInput)
    local id = nextId('input')
    pending[id] = { onInput = onInput }
    NUI.setFocus(true)
    NUI.send('menu', 'input', { id = id, title = opts.title, subtitle = opts.subtitle, fields = opts.fields })
end

--- Ouvre une confirmation custom.
---@param opts { title:string, message:string, confirmText?:string, cancelText?:string, danger?:boolean }
---@param onConfirm fun(confirmed:boolean)
function NUI.confirm(opts, onConfirm)
    local id = nextId('confirm')
    pending[id] = { onConfirm = onConfirm }
    NUI.setFocus(true)
    NUI.send('menu', 'confirm', {
        id = id, title = opts.title, message = opts.message,
        confirmText = opts.confirmText, cancelText = opts.cancelText, danger = opts.danger,
    })
end

-- ---------------------------------------------------------------------
--  NUICallbacks : résolution des menus/dialogues
-- ---------------------------------------------------------------------

RegisterNUICallback('menuSelect', function(body, cb)
    NUI.setFocus(false)
    local p = pending[body.id]; pending[body.id] = nil
    if p and p.onSelect and not body.cancelled then p.onSelect(body.option) end
    cb('ok')
end)

RegisterNUICallback('menuInput', function(body, cb)
    NUI.setFocus(false)
    local p = pending[body.id]; pending[body.id] = nil
    if p and p.onInput then p.onInput(body.cancelled and nil or body.values) end
    cb('ok')
end)

RegisterNUICallback('menuConfirm', function(body, cb)
    NUI.setFocus(false)
    local p = pending[body.id]; pending[body.id] = nil
    if p and p.onConfirm then p.onConfirm(body.confirmed == true) end
    cb('ok')
end)

-- Posts de focus internes (modales locales JS) : no-op, le focus est déjà tenu
-- par la couche parente. On répond simplement pour éviter tout warning.
for _, name in ipairs({ 'menuFocus', 'charFocus', 'bankFocus' }) do
    RegisterNUICallback(name, function(_, cb) cb('ok') end)
end

return NUI
