-- =====================================================================
--  NOXA FA — Module Banque (client-side)
--  Menus ox_lib pour dépôt/retrait/virement + consultation des factures.
--  Aucune valeur de solde n'est de confiance côté client : l'affichage
--  provient du statebag répliqué par le serveur (Noxa.GetPlayerData).
-- =====================================================================

Noxa = Noxa or {}

local pendingInvoices = {}

-- Réception de la liste des factures depuis le serveur.
RegisterNetEvent('noxa:bank:invoice:setList', function(list)
    pendingInvoices = list or {}
    local options = {}
    if #pendingInvoices == 0 then
        options[1] = { title = 'Aucune facture en attente', disabled = true }
    else
        for _, inv in ipairs(pendingInvoices) do
            options[#options + 1] = {
                title = ('%s — %d $'):format(inv.label, inv.amount),
                description = ('Émetteur : %s'):format(inv.from),
                metadata = { { label = 'Date', value = inv.date } },
                onSelect = function()
                    local ok = lib.alertDialog({
                        header = inv.label,
                        content = ('Payer **%d $** à %s ?'):format(inv.amount, inv.from),
                        centered = true, cancel = true,
                    })
                    if ok == 'confirm' then
                        TriggerServerEvent('noxa:bank:invoice:pay', inv.id)
                    else
                        TriggerServerEvent('noxa:bank:invoice:refuse', inv.id)
                    end
                end,
            }
        end
    end
    lib.registerContext({ id = 'noxa_invoices', title = 'Mes factures', options = options })
    lib.showContext('noxa_invoices')
end)

-- /banque : menu bancaire principal.
RegisterCommand('banque', function()
    local data = Noxa.GetPlayerData and Noxa.GetPlayerData()
    lib.registerContext({
        id = 'noxa_bank',
        title = 'Banque Noxa',
        options = {
            { title = 'Solde', icon = 'wallet', disabled = true,
              description = data and ('Banque : %d $  |  Espèces : %d $'):format(data.bank or 0, data.cash or 0) or '—' },
            { title = 'Déposer', icon = 'arrow-down', onSelect = function()
                local input = lib.inputDialog('Dépôt', { { type = 'number', label = 'Montant', required = true, min = 1 } })
                if input then TriggerServerEvent('noxa:bank:deposit', tonumber(input[1])) end
            end },
            { title = 'Retirer', icon = 'arrow-up', onSelect = function()
                local input = lib.inputDialog('Retrait', { { type = 'number', label = 'Montant', required = true, min = 1 } })
                if input then TriggerServerEvent('noxa:bank:withdraw', tonumber(input[1])) end
            end },
            { title = 'Virement', icon = 'paper-plane', onSelect = function()
                local input = lib.inputDialog('Virement bancaire', {
                    { type = 'input',  label = 'ID citoyen destinataire (NXxxxxxx)', required = true },
                    { type = 'number', label = 'Montant', required = true, min = 1 },
                })
                if input then TriggerServerEvent('noxa:bank:transfer', input[1], tonumber(input[2])) end
            end },
            { title = 'Mes factures', icon = 'file-invoice-dollar', onSelect = function()
                TriggerServerEvent('noxa:bank:invoice:list')
            end },
        },
    })
    lib.showContext('noxa_bank')
end, false)

-- /facturer [id] [montant] [libellé...] : émission rapide pour les pros.
RegisterCommand('facturer', function(_, args)
    local id = tonumber(args[1])
    local amount = tonumber(args[2])
    if not id or not amount then
        return Noxa.UI.notify('Usage : /facturer [id] [montant] [libellé]', 'error')
    end
    local label = table.concat(args, ' ', 3)
    TriggerServerEvent('noxa:bank:invoice:create', id, amount, label ~= '' and label or nil)
end, false)
