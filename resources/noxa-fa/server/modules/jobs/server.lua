-- =====================================================================
--  NOXA FA — Module Emplois (server-side)
--  • Affectation de job validée serveur (whitelist DB pour les métiers
--    restreints : police, EMS).
--  • Service (duty) : les services publics ne perçoivent leur salaire
--    qu'en service.
--  • Boss-actions : embauche / licenciement / promotion, chaque action
--    revérifiée côté serveur contre les permissions de grade.
--  • Paie automatique versée DEPUIS la caisse société (pas d'argent créé
--    ex nihilo pour les sociétés ; revenu de base direct pour les citoyens).
-- =====================================================================

Noxa = Noxa or {}
Noxa.Jobs = {}

local Jobs = Noxa.Jobs
local U    = Noxa.Utils
local E    = Noxa.Enums
local DB   = Noxa.DB
local S    = Noxa.Security
local CFG  = Noxa.Config
local Soc  = Noxa.Societies

-- ---------------------------------------------------------------------
--  Affectation de job (cœur autoritaire)
-- ---------------------------------------------------------------------

--- Vérifie qu'un citoyen est autorisé (whitelist) sur un job/grade.
---@return boolean
function Jobs.isWhitelisted(citizenid, jobName, grade)
    local maxGrade = DB.getJobWhitelist(citizenid, jobName)
    if not maxGrade then return false end
    return grade <= maxGrade
end

--- Affecte un job à un joueur chargé. Applique la whitelist sauf bypass admin.
---@param target table objet Player
---@param jobName string
---@param grade integer
---@param opts? { bypassWhitelist?: boolean }
---@return boolean ok, string? err
function Jobs.setPlayerJob(target, jobName, grade, opts)
    opts = opts or {}
    local job = E.Jobs[jobName]
    if not job then return false, 'job_inconnu' end
    grade = U.clampInt(grade, 0, CFG.Jobs.maxGrade) or 0
    if not job.grades[grade] then return false, 'grade_invalide' end

    if job.whitelisted and not opts.bypassWhitelist then
        if not Jobs.isWhitelisted(target.citizenid, jobName, grade) then
            return false, 'non_whitelist'
        end
    end

    target:setJob(jobName, grade)
    target.duty = false  -- reset service au changement de métier
    target:syncState()
    DB.log('job', 'info', target.license,
        ('%s -> %s grade %d'):format(target:getName(), jobName, grade))
    return true
end

-- Export inter-ressources (toujours validé via whitelist par défaut)
exports('SetPlayerJob', function(src, jobName, grade, bypass)
    local target = Noxa.Players.get(src)
    if not target then return false end
    return Jobs.setPlayerJob(target, jobName, grade, { bypassWhitelist = bypass == true })
end)

exports('SetPlayerGang', function(src, gangName, grade)
    local target = Noxa.Players.get(src)
    if not target then return false end
    return target:setGang(gangName, grade)
end)

-- ---------------------------------------------------------------------
--  Service (duty)
-- ---------------------------------------------------------------------

S.onNet('noxa:job:toggleDuty', function(src, ply)
    local job = E.Jobs[ply.job]
    if not job or ply.job == 'unemployed' then return end
    local state = ply:setDuty(not ply.duty)
    TriggerClientEvent('noxa:notify', src,
        state and 'Vous êtes en service.' or 'Vous avez quitté le service.',
        state and 'success' or 'inform')
end)

-- ---------------------------------------------------------------------
--  Boss-actions (revalidées serveur contre les permissions de grade)
-- ---------------------------------------------------------------------

--- Garde commune : l'acteur doit posséder la permission demandée.
local function bossGuard(ply, perm)
    if not ply or not ply:hasJobPerm(perm) then return false end
    return true
end

-- Embauche : applique le job de l'acteur au joueur ciblé (grade 0).
S.onNet('noxa:job:hire', function(src, ply, targetId)
    if not bossGuard(ply, 'recruit') then return S.flag(src, 'job:hire sans permission') end
    local target = Noxa.Players.get(tonumber(targetId))
    if not target then return end

    local job = E.Jobs[ply.job]
    -- Pour les métiers whitelistés, on inscrit la whitelist avant l'affectation
    if job.whitelisted then
        DB.setJobWhitelist(target.citizenid, ply.job, 0, ply.citizenid)
    end
    local ok = Jobs.setPlayerJob(target, ply.job, 0, { bypassWhitelist = true })
    if ok then
        TriggerClientEvent('noxa:notify', src, ('%s embauché·e.'):format(target:getName()), 'success')
        TriggerClientEvent('noxa:notify', target.source,
            ('Vous avez rejoint %s.'):format(job.label), 'success')
    end
end)

-- Promotion / rétrogradation : la cible doit partager le métier de l'acteur.
S.onNet('noxa:job:setGrade', function(src, ply, targetId, grade)
    if not bossGuard(ply, 'promote') then return S.flag(src, 'job:setGrade sans permission') end
    local target = Noxa.Players.get(tonumber(targetId))
    if not target or target.job ~= ply.job then return end

    -- Un boss ne peut pas attribuer un grade supérieur ou égal au sien
    grade = U.clampInt(grade, 0, math.max(0, ply.job_grade - (ply:isBoss() and 0 or 1)))
    if not grade then return end

    local job = E.Jobs[ply.job]
    if job.whitelisted then
        DB.setJobWhitelist(target.citizenid, ply.job, grade, ply.citizenid)
    end
    if Jobs.setPlayerJob(target, ply.job, grade, { bypassWhitelist = true }) then
        local g = E.getJobGrade(ply.job, grade)
        TriggerClientEvent('noxa:notify', src,
            ('%s est désormais %s.'):format(target:getName(), g and g.label or grade), 'success')
        TriggerClientEvent('noxa:notify', target.source,
            ('Nouveau grade : %s.'):format(g and g.label or grade), 'inform')
    end
end)

-- Licenciement : remet la cible au chômage et révoque sa whitelist.
S.onNet('noxa:job:fire', function(src, ply, targetId)
    if not bossGuard(ply, 'fire') then return S.flag(src, 'job:fire sans permission') end
    local target = Noxa.Players.get(tonumber(targetId))
    if not target or target.job ~= ply.job then return end
    if target.citizenid == ply.citizenid then return end  -- pas d'auto-licenciement

    local oldJob = ply.job
    DB.removeJobWhitelist(target.citizenid, oldJob)
    Jobs.setPlayerJob(target, 'unemployed', 0, { bypassWhitelist = true })
    TriggerClientEvent('noxa:notify', src, ('%s licencié·e.'):format(target:getName()), 'success')
    TriggerClientEvent('noxa:notify', target.source,
        ('Vous avez été licencié·e de %s.'):format(E.Jobs[oldJob].label), 'error')
end)

-- ---------------------------------------------------------------------
--  Gestion de la caisse société (perm manageFunds)
-- ---------------------------------------------------------------------

-- Dépôt : du compte banque perso du boss vers la caisse société.
S.onNet('noxa:job:society:deposit', function(src, ply, amount)
    if not bossGuard(ply, 'manageFunds') then return S.flag(src, 'society:deposit sans permission') end
    local society = ply:getSociety()
    if not society then return end
    amount = U.sanitizeAmount(amount)
    if not amount then return end
    if not ply:removeMoney(E.Accounts.BANK, amount, 'society:deposit') then
        return TriggerClientEvent('noxa:notify', src, 'Fonds insuffisants.', 'error')
    end
    Soc.add(society, amount, ply.citizenid, 'boss:deposit')
    TriggerClientEvent('noxa:notify', src, ('Déposé : %s'):format(U.money(amount)), 'success')
end)

-- Retrait : de la caisse société vers le compte banque perso du boss.
S.onNet('noxa:job:society:withdraw', function(src, ply, amount)
    if not bossGuard(ply, 'manageFunds') then return S.flag(src, 'society:withdraw sans permission') end
    local society = ply:getSociety()
    if not society then return end
    amount = U.sanitizeAmount(amount)
    if not amount then return end
    if not Soc.remove(society, amount, ply.citizenid, 'boss:withdraw') then
        return TriggerClientEvent('noxa:notify', src, 'Caisse insuffisante.', 'error')
    end
    ply:addMoney(E.Accounts.BANK, amount, 'society:withdraw')
    TriggerClientEvent('noxa:notify', src, ('Retiré : %s'):format(U.money(amount)), 'success')
end)

-- ---------------------------------------------------------------------
--  Paie automatique
-- ---------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(CFG.Jobs.payInterval)
        -- Bascule live (panel gestion serveur) : paie désactivable sans restart.
        if CFG.Systems and CFG.Systems.payroll == false then goto skipCycle end
        local paid, skipped = 0, 0
        for _, ply in pairs(Noxa.Players.getAll()) do
            local job = E.Jobs[ply.job]
            local salary = ply:getJobSalary()
            if job and salary > 0 then
                -- Services publics : uniquement en service
                if job.onDutyOnly and not ply.duty then
                    goto continue
                end
                local society = job.society
                if society and CFG.Jobs.payRequiresSociety then
                    -- Salaire prélevé sur la caisse société
                    if Soc.remove(society, salary, nil, 'salary:' .. ply.job) then
                        ply:addMoney(E.Accounts.BANK, salary, 'salary:' .. ply.job)
                        paid = paid + 1
                    else
                        skipped = skipped + 1
                        TriggerClientEvent('noxa:notify', ply.source,
                            'Salaire non versé : caisse de la société vide.', 'error')
                    end
                else
                    -- Revenu de base citoyen (versé directement)
                    ply:addMoney(E.Accounts.BANK, salary, 'salary:' .. ply.job)
                    paid = paid + 1
                end
            end
            ::continue::
        end
        if paid > 0 or skipped > 0 then
            U.print('info', 'Paie : %d versée(s), %d sautée(s).', paid, skipped)
        end
        ::skipCycle::
    end
end)

return Jobs
