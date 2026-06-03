/* =====================================================================
   NOXA FA — Panel gestion serveur (overlay superadmin, z-index 60)
   Messages Lua -> NUI (app:'serverpanel') :
     • 'open'     data: snapshot complet (cf. config-manager serveur)
     • 'snapshot' data: snapshot rafraîchi (après une action)
     • 'close'
   Callbacks NUI -> Lua :
     • cfgAction   { action, params }   (INTENTION ; rang revérifié serveur)
     • cfgRefresh  {}
     • cfgGetCoords {}                  (position courante, pré-remplissage)
     • cfgClose    {}
   AUCUNE valeur n'est de confiance : le serveur revalide rang + bornes et
   journalise. La NUI n'est qu'un émetteur d'intentions.
   ===================================================================== */

const NoxaServerPanel = (() => {
    const root = document.getElementById('serverpanel');
    let open = false;
    let data = {};
    let tab = 'serveur';

    const TABS = [
        { id: 'serveur',   label: 'Serveur',     icon: '🖥️' },
        { id: 'coords',    label: 'Coordonnées', icon: '📍' },
        { id: 'economy',   label: 'Économie',    icon: '💰' },
        { id: 'shops',     label: 'Boutiques',   icon: '🛒' },
        { id: 'jobs',      label: 'Jobs',        icon: '🧰' },
        { id: 'orgs',      label: 'Organisations', icon: '🏴' },
        { id: 'messages',  label: 'Messages',    icon: '📢' },
        { id: 'whitelist', label: 'Whitelist',   icon: '🔑' },
    ];

    const esc = Noxa.esc;
    const money = Noxa.money;

    /* ---- cycle de vie ------------------------------------------------ */
    function show(d) {
        data = d || {};
        open = true;
        if (!TABS.some((t) => t.id === tab)) tab = 'serveur';
        root.classList.remove('hidden');
        render();
    }

    function update(d) {
        if (!open) return;
        data = d || {};
        render();
    }

    function close() {
        if (!open) return;
        open = false;
        root.innerHTML = '';
        root.classList.add('hidden');
        Noxa.post('cfgClose', {});
    }

    function act(action, params) {
        Noxa.post('cfgAction', { action, params: params || {} });
    }

    /* ---- helpers de rendu ------------------------------------------- */
    function jobOptions(selected) {
        return (data.jobs || []).map((j) =>
            `<option value="${esc(j.name)}" ${j.name === selected ? 'selected' : ''}>${esc(j.label)}</option>`).join('');
    }

    function fieldRow(domain, key, def, val) {
        const id = `f-${domain}-${key}`;
        const step = def.type === 'float' ? '0.01' : '1';
        return `<div class="sp-field"><label>${esc(def.label)}</label>
            <div class="row">
                <input id="${id}" class="sp-input" type="number" step="${step}" value="${val ?? ''}">
                <button class="sp-btn primary sm" data-act="setField"
                    data-params='${JSON.stringify({ domain, key })}' data-vals="${id}>value">✓</button>
            </div></div>`;
    }

    function fieldCard(title, domain) {
        const defs = (data.fields || {})[domain] || {};
        const vals = data[domain] || {};
        const rows = Object.keys(defs).map((k) => fieldRow(domain, k, defs[k], vals[k])).join('');
        return `<div class="sp-card"><h4>${esc(title)}</h4><div class="sp-grid">${rows}</div></div>`;
    }

    /* ---- onglet : Serveur (stats + systèmes + monde) ----------------- */
    function tabServeur() {
        const s = data.server || {};
        const up = s.uptime || 0;
        const upStr = `${Math.floor(up / 3600)}h ${Math.floor((up % 3600) / 60)}m`;
        const sys = data.systems || {};
        const toggle = (key, title, sub) => {
            const on = sys[key] !== false;
            return `<div class="sp-toggle-row">
                <div class="meta"><b>${esc(title)}</b><span>${esc(sub)}</span></div>
                <div class="sp-switch ${on ? 'on' : ''}" data-act="toggleSystem"
                    data-params='${JSON.stringify({ key, on: !on })}'></div>
            </div>`;
        };
        const weatherOpts = (data.weatherCycle || []).map((w) =>
            `<option value="${esc(w)}">${esc(w)}</option>`).join('');
        const hourOpts = Array.from({ length: 24 }, (_, h) =>
            `<option value="${h}">${String(h).padStart(2, '0')}:00</option>`).join('');

        return `
        <div class="sp-section-title">Tableau de bord serveur</div>
        <div class="sp-section-sub">État temps réel · bascules globales · contrôle du monde (sans restart).</div>

        <div class="sp-card"><h4>État</h4>
            <div class="sp-stats">
                <div class="sp-stat"><div class="v">${s.connected ?? 0}<span style="font-size:15px;color:var(--text-faint)">/${s.maxClients ?? 48}</span></div><div class="k">Connectés</div></div>
                <div class="sp-stat"><div class="v">${s.players ?? 0}</div><div class="k">Personnages chargés</div></div>
                <div class="sp-stat"><div class="v">${esc(upStr)}</div><div class="k">Uptime</div></div>
                <div class="sp-stat"><div class="v" style="font-size:17px">${esc(s.name || 'Noxa FA')}</div><div class="k">Serveur</div></div>
            </div>
        </div>

        <div class="sp-card"><h4>Systèmes — activer / désactiver</h4>
            ${toggle('pvp', 'PVP global', 'Autoriser les tirs entre joueurs')}
            ${toggle('weatherAuto', 'Rotation météo auto', 'Cycle météo automatique (sinon figé)')}
            ${toggle('payroll', 'Versement des salaires', 'Paie automatique des employés')}
            ${toggle('economyTax', 'Taxes & puits monétaires', 'Prélèvements anti-inflation')}
            ${toggle('scheduledMsg', 'Messages planifiés', 'Diffusion des annonces périodiques')}
        </div>

        <div class="sp-card"><h4>Monde — heure & météo</h4>
            <div class="sp-actions-row">
                <div class="sp-field"><label>Forcer la météo</label>
                    <div class="row">
                        <select id="cfg-weather" class="sp-input">${weatherOpts}</select>
                        <button class="sp-btn primary sm" data-act="setWeather" data-vals="cfg-weather>weather">Appliquer</button>
                    </div>
                </div>
                <div class="sp-field"><label>Régler l'heure</label>
                    <div class="row">
                        <select id="cfg-hour" class="sp-input">${hourOpts}</select>
                        <button class="sp-btn primary sm" data-act="setHour" data-vals="cfg-hour>hour">Appliquer</button>
                    </div>
                </div>
            </div>
        </div>`;
    }

    /* ---- onglet : Coordonnées (spawn + POI) -------------------------- */
    function tabCoords() {
        const sp = data.spawn || {};
        const poi = data.poi || [];
        const curCat = panelState.poiCat || (poi[0] && poi[0].cat);
        const catOpts = poi.map((c) =>
            `<option value="${esc(c.cat)}" ${c.cat === curCat ? 'selected' : ''}>${esc(c.label)} (${c.count})</option>`).join('');
        const sel = poi.find((c) => c.cat === curCat) || poi[0] || { points: [] };
        const ptRows = (sel.points || []).map((p) =>
            `<tr>
                <td>#${p.i}</td><td>${p.x.toFixed(2)}</td><td>${p.y.toFixed(2)}</td><td>${p.z.toFixed(2)}</td>
                <td style="text-align:right"><button class="sp-btn danger sm" data-act="poiRemovePoint"
                    data-params='${JSON.stringify({ cat: sel.cat, index: p.i })}'>Suppr.</button></td>
            </tr>`).join('') || `<tr><td colspan="5" class="sp-empty">Aucun point.</td></tr>`;

        return `
        <div class="sp-section-title">Coordonnées</div>
        <div class="sp-section-sub">Point de spawn et points d'intérêt (banque, ATM, garage…). Modifiable en direct.</div>

        <div class="sp-card"><h4>Point de spawn par défaut</h4>
            <div class="sp-grid">
                <div class="sp-field"><label>X</label><input id="spawn-x" class="sp-input" type="number" step="0.01" value="${sp.x ?? ''}"></div>
                <div class="sp-field"><label>Y</label><input id="spawn-y" class="sp-input" type="number" step="0.01" value="${sp.y ?? ''}"></div>
                <div class="sp-field"><label>Z</label><input id="spawn-z" class="sp-input" type="number" step="0.01" value="${sp.z ?? ''}"></div>
                <div class="sp-field"><label>Cap</label><input id="spawn-heading" class="sp-input" type="number" step="0.1" value="${sp.heading ?? ''}"></div>
            </div>
            <div class="sp-actions-row">
                <button class="sp-btn" data-act="coords" data-into="spawn">📍 Ma position</button>
                <button class="sp-btn primary" data-act="setSpawn"
                    data-vals="spawn-x>x,spawn-y>y,spawn-z>z,spawn-heading>heading">Enregistrer le spawn</button>
            </div>
        </div>

        <div class="sp-card"><h4>Points d'intérêt (POI)</h4>
            <div class="sp-actions-row" style="margin-bottom:14px">
                <div class="sp-field"><label>Catégorie</label>
                    <select id="poi-cat" class="sp-input" data-act="poiSelect">${catOpts}</select>
                </div>
            </div>
            <table class="sp-table">
                <thead><tr><th>#</th><th>X</th><th>Y</th><th>Z</th><th></th></tr></thead>
                <tbody>${ptRows}</tbody>
            </table>
            <div class="sp-actions-row" style="margin-top:16px">
                <div class="sp-field"><label>X</label><input id="poi-x" class="sp-input" type="number" step="0.01"></div>
                <div class="sp-field"><label>Y</label><input id="poi-y" class="sp-input" type="number" step="0.01"></div>
                <div class="sp-field"><label>Z</label><input id="poi-z" class="sp-input" type="number" step="0.01"></div>
                <button class="sp-btn" data-act="coords" data-into="poi">📍 Ma position</button>
                <button class="sp-btn primary" data-act="poiAddPoint"
                    data-params='${JSON.stringify({ cat: sel.cat })}'
                    data-vals="poi-x>x,poi-y>y,poi-z>z">Ajouter le point</button>
            </div>
        </div>`;
    }

    /* ---- onglet : Économie ------------------------------------------- */
    function tabEconomy() {
        return `
        <div class="sp-section-title">Économie en direct</div>
        <div class="sp-section-sub">Bornes de transaction, banque et carburant. Appliqué en mémoire + BDD.</div>
        ${fieldCard('Bornes économiques', 'economy')}
        ${fieldCard('Banque', 'banking')}
        ${fieldCard('Carburant', 'fuel')}`;
    }

    /* ---- onglet : Boutiques ------------------------------------------ */
    function tabShops() {
        const shops = data.shops || {};
        const cards = Object.keys(shops).map((key) => {
            const shop = shops[key];
            const rows = (shop.items || []).map((it) => {
                const id = `shop-${key}-${it.id}`;
                return `<tr>
                    <td>${esc(it.emoji || '')} ${esc(it.label)}</td>
                    <td class="num"><input id="${id}" class="sp-input" type="number" min="1" value="${it.price}"></td>
                    <td style="text-align:right"><button class="sp-btn primary sm" data-act="shopPrice"
                        data-params='${JSON.stringify({ shop: key, id: it.id })}' data-vals="${id}>price">✓</button></td>
                </tr>`;
            }).join('');
            return `<div class="sp-card"><h4>${esc(shop.label || key)}</h4>
                <table class="sp-table"><thead><tr><th>Article</th><th>Prix</th><th></th></tr></thead>
                <tbody>${rows}</tbody></table></div>`;
        }).join('') || `<div class="sp-empty">Aucune boutique configurée.</div>`;
        return `<div class="sp-section-title">Boutiques</div>
            <div class="sp-section-sub">Tarifs des articles (validés serveur à l'achat).</div>${cards}`;
    }

    /* ---- onglet : Jobs ----------------------------------------------- */
    function tabJobs() {
        const jobs = data.jobs || [];
        const cards = jobs.map((j) => {
            const rows = j.grades.map((g) => {
                const id = `job-${j.name}-${g.grade}`;
                const sal = g.salary == null ? '' : g.salary;
                return `<tr>
                    <td>g${g.grade}</td><td>${esc(g.label)}</td>
                    <td class="num"><input id="${id}" class="sp-input" type="number" min="0" value="${sal}"></td>
                    <td style="text-align:right">
                        <button class="sp-btn primary sm" data-act="jobSalary"
                            data-params='${JSON.stringify({ job: j.name, grade: g.grade })}' data-vals="${id}>salary">✓</button>
                        <button class="sp-btn danger sm" data-act="jobRemoveGrade"
                            data-params='${JSON.stringify({ job: j.name, grade: g.grade })}'>✕</button>
                    </td>
                </tr>`;
            }).join('');
            const ng = `ng-${j.name}`;
            return `<div class="sp-card">
                <h4>${esc(j.label)} ${j.whitelisted ? '<span class="sp-pill wl">WL</span>' : ''}
                    ${j.name !== 'unemployed' ? `<button class="sp-btn danger sm" style="float:right" data-act="jobRemove" data-params='${JSON.stringify({ job: j.name })}'>Supprimer le job</button>` : ''}</h4>
                <table class="sp-table"><thead><tr><th>Grade</th><th>Libellé</th><th>Salaire</th><th></th></tr></thead>
                <tbody>${rows}</tbody></table>
                <div class="sp-actions-row" style="margin-top:14px">
                    <div class="sp-field"><label>Nouveau grade</label><input id="${ng}-label" class="sp-input" placeholder="Libellé"></div>
                    <div class="sp-field"><label>Salaire</label><input id="${ng}-salary" class="sp-input" type="number" min="0" value="0"></div>
                    <button class="sp-btn primary" data-act="jobAddGrade"
                        data-params='${JSON.stringify({ job: j.name })}'
                        data-vals="${ng}-label>label,${ng}-salary>salary">Ajouter le grade</button>
                </div>
            </div>`;
        }).join('');
        return `<div class="sp-section-title">Jobs & grades</div>
            <div class="sp-section-sub">Salaires, grades et création/suppression de métiers (sans restart).</div>
            <div class="sp-card"><h4>Créer un job</h4>
                <div class="sp-actions-row">
                    <div class="sp-field"><label>Identifiant</label><input id="newjob-name" class="sp-input" placeholder="ex: taxi"></div>
                    <div class="sp-field"><label>Libellé</label><input id="newjob-label" class="sp-input" placeholder="ex: Taxi LS"></div>
                    <div class="sp-field"><label>Salaire grade 0</label><input id="newjob-salary" class="sp-input" type="number" min="0" value="500"></div>
                    <button class="sp-btn primary" data-act="jobAdd"
                        data-vals="newjob-name>name,newjob-label>label,newjob-salary>salary">Créer</button>
                </div>
            </div>
            ${cards}`;
    }

    /* ---- onglet : Organisations (gangs + sociétés) ------------------- */
    function tabOrgs() {
        const gangs = data.gangs || [];
        const socs = data.societies || [];
        const gangCards = gangs.map((g) => {
            const grades = g.grades.map((gr) => `g${gr.grade} ${esc(gr.label)}`).join(' · ');
            return `<div class="sp-toggle-row">
                <div class="meta"><b>${esc(g.label)}</b><span>${esc(grades)}</span></div>
                ${g.name !== 'none' ? `<button class="sp-btn danger sm" data-act="gangRemove" data-params='${JSON.stringify({ gang: g.name })}'>Supprimer</button>` : ''}
            </div>`;
        }).join('');
        const socRows = socs.map((s) =>
            `<tr><td>${esc(s.label)}</td><td><span class="sp-pill">${esc(s.type)}</span></td><td style="text-align:right">${money(s.balance)}</td></tr>`).join('')
            || `<tr><td colspan="3" class="sp-empty">Aucune caisse.</td></tr>`;
        return `<div class="sp-section-title">Organisations</div>
            <div class="sp-section-sub">Gangs (création/suppression) et caisses des sociétés.</div>
            <div class="sp-card"><h4>Créer une organisation</h4>
                <div class="sp-actions-row">
                    <div class="sp-field"><label>Identifiant</label><input id="newgang-name" class="sp-input" placeholder="ex: vagos"></div>
                    <div class="sp-field"><label>Libellé</label><input id="newgang-label" class="sp-input" placeholder="ex: Vagos"></div>
                    <button class="sp-btn primary" data-act="gangAdd"
                        data-vals="newgang-name>name,newgang-label>label">Créer</button>
                </div>
            </div>
            <div class="sp-card"><h4>Organisations existantes</h4>${gangCards || '<div class="sp-empty">Aucune.</div>'}</div>
            <div class="sp-card"><h4>Caisses des sociétés</h4>
                <table class="sp-table"><thead><tr><th>Société</th><th>Type</th><th style="text-align:right">Solde</th></tr></thead>
                <tbody>${socRows}</tbody></table>
            </div>`;
    }

    /* ---- onglet : Messages planifiés --------------------------------- */
    function tabMessages() {
        const msgs = data.messages || [];
        const rows = msgs.map((m) => {
            const on = (Number(m.enabled) || 0) === 1;
            return `<tr>
                <td style="max-width:420px">${esc(m.body)}</td>
                <td>${m.interval_min} min</td>
                <td><div class="sp-switch ${on ? 'on' : ''}" data-act="msgToggle"
                    data-params='${JSON.stringify({ id: m.id, on: !on })}'></div></td>
                <td style="text-align:right"><button class="sp-btn danger sm" data-act="msgRemove"
                    data-params='${JSON.stringify({ id: m.id })}'>Suppr.</button></td>
            </tr>`;
        }).join('') || `<tr><td colspan="4" class="sp-empty">Aucun message planifié.</td></tr>`;
        return `<div class="sp-section-title">Messages serveur planifiés</div>
            <div class="sp-section-sub">Annonces diffusées automatiquement à intervalle régulier.</div>
            <div class="sp-card"><h4>Nouveau message</h4>
                <div class="sp-field" style="margin-bottom:12px"><label>Texte</label>
                    <input id="msg-body" class="sp-input" placeholder="Bienvenue sur Noxa FA — pensez à lire le règlement !"></div>
                <div class="sp-actions-row">
                    <div class="sp-field"><label>Intervalle (min)</label><input id="msg-interval" class="sp-input" type="number" min="1" value="30"></div>
                    <button class="sp-btn primary" data-act="msgAdd" data-vals="msg-body>body,msg-interval>interval">Planifier</button>
                </div>
            </div>
            <div class="sp-card"><h4>Messages actifs</h4>
                <table class="sp-table"><thead><tr><th>Message</th><th>Fréquence</th><th>Actif</th><th></th></tr></thead>
                <tbody>${rows}</tbody></table>
            </div>`;
    }

    /* ---- onglet : Whitelist ------------------------------------------ */
    function tabWhitelist() {
        const wl = data.whitelist || [];
        const rows = wl.map((w) =>
            `<tr>
                <td><code>${esc(w.citizenid)}</code></td>
                <td>${esc(w.job)}</td>
                <td>g${w.max_grade}</td>
                <td>${esc(w.granted_by || '—')}</td>
                <td style="text-align:right"><button class="sp-btn danger sm" data-act="wlRemove"
                    data-params='${JSON.stringify({ citizenid: w.citizenid, job: w.job })}'>Retirer</button></td>
            </tr>`).join('') || `<tr><td colspan="5" class="sp-empty">Aucune whitelist.</td></tr>`;
        return `<div class="sp-section-title">Whitelist d'emploi</div>
            <div class="sp-section-sub">Autoriser un citoyen (Citizen ID) à un métier restreint, jusqu'à un grade max.</div>
            <div class="sp-card"><h4>Accorder une whitelist</h4>
                <div class="sp-actions-row">
                    <div class="sp-field"><label>Citizen ID</label><input id="wl-cid" class="sp-input" placeholder="NXAB12CD"></div>
                    <div class="sp-field"><label>Job</label><select id="wl-job" class="sp-input">${jobOptions()}</select></div>
                    <div class="sp-field"><label>Grade max</label><input id="wl-grade" class="sp-input" type="number" min="0" value="0"></div>
                    <button class="sp-btn primary" data-act="wlSet"
                        data-vals="wl-cid>citizenid,wl-job>job,wl-grade>maxGrade">Accorder</button>
                </div>
            </div>
            <div class="sp-card"><h4>Whitelists actives</h4>
                <table class="sp-table"><thead><tr><th>Citizen ID</th><th>Job</th><th>Grade max</th><th>Par</th><th></th></tr></thead>
                <tbody>${rows}</tbody></table>
            </div>`;
    }

    const RENDERERS = {
        serveur: tabServeur, coords: tabCoords, economy: tabEconomy, shops: tabShops,
        jobs: tabJobs, orgs: tabOrgs, messages: tabMessages, whitelist: tabWhitelist,
    };

    // État local de navigation (sélections non persistées côté serveur).
    const panelState = { poiCat: null };

    /* ---- rendu global ------------------------------------------------ */
    function render() {
        const tabsHtml = TABS.map((t) =>
            `<div class="sp-tab ${t.id === tab ? 'active' : ''}" data-act="tab" data-tab="${t.id}">
                <span class="ic">${t.icon}</span>${t.label}</div>`).join('');
        const body = (RENDERERS[tab] || tabServeur)();
        root.innerHTML = `
            <div class="sp-window">
                <div class="sp-head">
                    <div class="sp-title"><b>Gestion du serveur</b><span>Configuration en direct — aucun redémarrage</span></div>
                    <div class="sp-spacer"></div>
                    <div class="sp-badge">${esc(data.rank || 'superadmin')}</div>
                    <div class="sp-close" data-act="close">✕</div>
                </div>
                <div class="sp-body">
                    <div class="sp-tabs">${tabsHtml}</div>
                    <div class="sp-content">${body}</div>
                </div>
            </div>`;
    }

    /* ---- remplissage des coordonnées depuis la position du joueur ---- */
    async function fillCoords(prefix) {
        const c = await Noxa.post('cfgGetCoords', {});
        ['x', 'y', 'z', 'heading'].forEach((k) => {
            const el = document.getElementById(`${prefix}-${k}`);
            if (el && c[k] != null) el.value = c[k];
        });
    }

    /* ---- gestion centralisée des clics (délégation) ------------------ */
    root.addEventListener('click', (e) => {
        const t = e.target.closest('[data-act]');
        if (!t || !open) return;
        const a = t.dataset.act;

        if (a === 'tab') { tab = t.dataset.tab; render(); return; }
        if (a === 'close') { close(); return; }
        if (a === 'coords') { fillCoords(t.dataset.into); return; }
        if (a === 'poiSelect') return;  // géré sur 'change'

        // Construit les paramètres : statiques (data-params) + valeurs d'inputs.
        let params = {};
        try { params = JSON.parse(t.dataset.params || '{}'); } catch (_) {}
        (t.dataset.vals || '').split(',').filter(Boolean).forEach((pair) => {
            const [id, key] = pair.split('>');
            const el = document.getElementById(id);
            if (el) params[key] = el.type === 'checkbox' ? el.checked : el.value;
        });
        act(a, params);
    });

    // Changement de catégorie POI (re-render local sans aller-retour serveur).
    root.addEventListener('change', (e) => {
        const sel = e.target.closest('[data-act="poiSelect"]');
        if (!sel) return;
        panelState.poiCat = sel.value;
        render();
    });

    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('serverpanel', 'open', show);
    Noxa.on('serverpanel', 'snapshot', update);
    Noxa.on('serverpanel', 'close', close);

    return { handleEscape };
})();

window.NoxaServerPanel = NoxaServerPanel;
