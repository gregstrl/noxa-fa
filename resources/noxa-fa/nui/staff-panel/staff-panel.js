/* =====================================================================
   NOXA FA — Panel staff & anti-cheat (overlay latéral, z-index 60)
   Messages Lua -> NUI (app:'staff') :
     • 'open'  data:{ rank, canSeeIp, players[], server{}, alerts[], banDurations[] }
     • 'data'  data:{ what:'players'|'server'|'aclogs', list }
     • 'alert' data:{ kind, severity, detail, name, src, score, action, pos, time }
     • 'screenshot' data:{ src, url }
     • 'close'
   Callbacks NUI -> Lua :
     • staffFetch  { what, arg }
     • staffAction { action, target, params }   (intention ; rang revérifié serveur)
     • staffClose  {}
   AUCUNE valeur n'est de confiance : le serveur revérifie le rang à chaque
   action et journalise. La NUI n'émet que des intentions.
   ===================================================================== */

const NoxaStaff = (() => {
    const root = document.getElementById('staffpanel');
    let open = false;
    let rank = 'user';
    let canSeeIp = false;
    let players = [];
    let server = {};
    let alerts = [];
    let aclogs = [];
    let banDurations = ['perm'];
    let selectedId = null;
    let section = 'players';
    let search = '';
    let acFilter = 'all';
    let unseen = 0;             // alertes non vues (badge onglet)
    let specTarget = null;      // cible actuellement spectée (toggle bouton)
    const shots = {};           // { src: url|texte } captures reçues

    const TABS = [
        { id: 'players', label: 'Joueurs' },
        { id: 'alerts',  label: 'Alertes' },
        { id: 'aclogs',  label: 'Logs AC' },
        { id: 'server',  label: 'Serveur' },
    ];

    const AC_TYPES = ['all', 'speedhack', 'teleport', 'godmode', 'weapon', 'spawn', 'money'];
    const TYPE_ICON = { speedhack: '🏎️', teleport: '🌀', godmode: '🛡️', weapon: '🔫', spawn: '📦', money: '💸' };

    /* ---- cycle de vie ------------------------------------------------ */
    function show(d) {
        rank = d.rank || 'user';
        canSeeIp = d.canSeeIp === true;
        players = d.players || [];
        server = d.server || {};
        alerts = (d.alerts || []).slice().reverse();   // plus récentes en tête
        banDurations = d.banDurations || ['perm'];
        open = true;
        section = 'players';
        selectedId = null;
        unseen = 0;
        root.classList.remove('hidden');
        render();
    }

    function close() {
        if (!open) return;
        open = false;
        root.innerHTML = '';
        root.classList.add('hidden');
        Noxa.post('staffClose', {});
    }

    function setData(d) {
        if (d.what === 'players') {
            players = d.list || [];
            if (selectedId != null && !players.some((p) => p.id === selectedId)) selectedId = null;
            if (open && section === 'players') render();
        } else if (d.what === 'server') {
            server = d.list || {};
            if (open && section === 'server') render();
        } else if (d.what === 'aclogs') {
            aclogs = d.list || [];
            if (open && section === 'aclogs') render();
        }
    }

    // Alerte temps réel : on la pousse en tête, met à jour le score joueur, le badge.
    function onAlert(a) {
        if (!a || !a.kind) return;
        alerts.unshift(a);
        if (alerts.length > 80) alerts.pop();
        const p = players.find((x) => x.id === a.src);
        if (p) p.acScore = a.score;
        if (!open) return;
        if (section === 'alerts') render();
        else { unseen += 1; refreshBadge(); if (section === 'players') render(); }
    }

    function onScreenshot(d) {
        if (!d || d.src == null) return;
        shots[d.src] = d.url || '';
        if (open && section === 'players' && selectedId === d.src) render();
    }

    /* ---- helpers ----------------------------------------------------- */
    const post = (action, params = {}) => Noxa.post('staffAction', { action, target: selectedId, params });
    const fetchData = (what, arg) => Noxa.post('staffFetch', { what, arg });
    const selected = () => players.find((p) => p.id === selectedId) || null;

    function fmtDur(s) {
        s = Number(s) || 0;
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m ${s % 60}s`;
    }
    function fmtTime(t) {
        const d = new Date((Number(t) || 0) * 1000);
        return d.toLocaleTimeString('fr-FR');
    }
    function scoreClass(s) { s = Number(s) || 0; return s === 0 ? 's0' : (s < 4 ? 's1' : 's2'); }

    function navTo(id) {
        section = id;
        if (id === 'alerts') { unseen = 0; }
        onEnter(id);
        render();
    }
    function onEnter(id) {
        if (id === 'players') fetchData('players');
        else if (id === 'server') fetchData('server');
        else if (id === 'aclogs') fetchData('aclogs', acFilter);
    }

    function refreshBadge() {
        const b = root.querySelector('#stf-badge-alerts');
        if (b) { b.textContent = unseen; b.style.display = unseen > 0 ? '' : 'none'; }
    }

    /* ---- rendu global ------------------------------------------------ */
    function render() {
        root.innerHTML = `
            <div class="stf-panel">
                <div class="stf-head">
                    <div>
                        <div class="stf-logo"><span>NOXA</span> STAFF</div>
                        <div class="stf-head-sub">Anti-cheat &amp; modération</div>
                    </div>
                    <div class="stf-ac-dot ${server.acEnabled === false ? 'off' : ''}">${server.acEnabled === false ? 'AC OFF' : 'AC actif'}</div>
                    <div class="stf-rank">${Noxa.esc(rank)}</div>
                    <div class="stf-close" id="stf-x">Fermer ✕</div>
                </div>
                <div class="stf-tabs">
                    ${TABS.map((t) => `
                        <div class="stf-tab ${t.id === section ? 'active' : ''}" data-tab="${t.id}">
                            ${t.label}${t.id === 'alerts' ? `<span class="stf-tab-badge" id="stf-badge-alerts" style="display:${unseen > 0 ? '' : 'none'}">${unseen}</span>` : ''}
                        </div>`).join('')}
                </div>
                <div class="stf-content" id="stf-content"></div>
            </div>`;
        root.querySelector('#stf-x').addEventListener('click', close);
        root.querySelectorAll('[data-tab]').forEach((el) =>
            el.addEventListener('click', () => navTo(el.getAttribute('data-tab'))));
        const c = root.querySelector('#stf-content');
        (VIEWS[section] || (() => {}))(c);
    }

    const VIEWS = {};

    /* --- Joueurs ------------------------------------------------------ */
    VIEWS.players = (c) => {
        const q = search.toLowerCase();
        const filtered = players.filter((p) =>
            !q || String(p.id).includes(q) || (p.name || '').toLowerCase().includes(q));
        c.innerHTML = `
            <div class="stf-title">👥 Joueurs connectés (${players.length})</div>
            <input class="field-input stf-search" id="stf-search" placeholder="Rechercher (ID ou nom)…" value="${Noxa.esc(search)}" />
            <div class="stf-players">
                ${filtered.length ? filtered.map(playerRow).join('') : '<div class="stf-empty">Aucun joueur.</div>'}
            </div>
            <div id="stf-detail"></div>`;
        const si = c.querySelector('#stf-search');
        si.addEventListener('input', () => { search = si.value; refreshList(c); });
        bindRows(c);
        renderDetail(c);
    };

    function playerRow(p) {
        return `<div class="stf-player ${p.id === selectedId ? 'selected' : ''}" data-pid="${p.id}">
            <div class="stf-pid">${p.id}</div>
            <div class="stf-pinfo">
                <div class="stf-pname">${Noxa.esc(p.name)}</div>
                <div class="stf-pmeta">
                    <span>${Noxa.esc(p.jobLabel)} · ${p.ping}ms · ${p.fps || '—'} fps</span>
                    ${p.rank !== 'user' ? `<span class="stf-badge staff">${Noxa.esc(p.rank)}</span>` : ''}
                    ${!p.loaded ? '<span class="stf-badge lobby">lobby</span>' : ''}
                </div>
            </div>
            <div class="stf-score ${scoreClass(p.acScore)}">${p.acScore || 0}</div>
        </div>`;
    }

    function refreshList(c) {
        const q = search.toLowerCase();
        const filtered = players.filter((p) =>
            !q || String(p.id).includes(q) || (p.name || '').toLowerCase().includes(q));
        const box = c.querySelector('.stf-players');
        if (box) {
            box.innerHTML = filtered.length ? filtered.map(playerRow).join('') : '<div class="stf-empty">Aucun joueur.</div>';
            bindRows(c);
        }
    }

    function bindRows(c) {
        c.querySelectorAll('[data-pid]').forEach((el) =>
            el.addEventListener('click', () => {
                selectedId = Number(el.getAttribute('data-pid'));
                c.querySelectorAll('.stf-player').forEach((n) =>
                    n.classList.toggle('selected', Number(n.getAttribute('data-pid')) === selectedId));
                renderDetail(c);
            }));
    }

    function renderDetail(c) {
        const host = c.querySelector('#stf-detail');
        if (!host) return;
        const p = selected();
        if (!p) { host.innerHTML = ''; return; }
        const cell = (k, v) => `<div class="stf-cell"><div class="stf-cell-k">${k}</div><div class="stf-cell-v">${Noxa.esc(v)}</div></div>`;
        const shot = shots[p.id];
        host.innerHTML = `
            <div class="stf-detail">
                <div class="stf-detail-head">
                    <div class="stf-detail-name">${Noxa.esc(p.name)} <span style="font-weight:500;color:var(--text-faint)">· ID ${p.id}</span></div>
                    <div class="stf-detail-sub">${Noxa.esc(p.jobLabel)} (grade ${p.grade}) · Score AC <b>${p.acScore || 0}</b></div>
                </div>
                <div class="stf-grid">
                    ${cell('License', p.license || '—')}
                    ${cell('Discord', p.discord || '—')}
                    ${cell('IP', canSeeIp ? (p.ip || '—') : 'admin requis')}
                    ${cell('Ping / FPS', `${p.ping} ms · ${p.fps || '—'} fps`)}
                    ${cell('Position', p.pos || '—')}
                    ${cell('Session', fmtDur(p.session))}
                    ${cell('Espèces', Noxa.money(p.cash))}
                    ${cell('Banque', Noxa.money(p.bank))}
                </div>
                <div class="stf-actions">
                    <button class="stf-act ${specTarget === p.id ? 'on' : ''}" data-a="spectate">${specTarget === p.id ? '⏹ Stop spectate' : '👁 Spectate'}</button>
                    <button class="stf-act" data-a="screenshot">📸 Screenshot</button>
                    <button class="stf-act" data-a="freeze">❄ Figer</button>
                    <button class="stf-act" data-a="unfreeze">☀ Libérer</button>
                    <button class="stf-act" data-a="tp">📍 TP discret</button>
                    <button class="stf-act danger" data-a="kick">⛔ Kick</button>
                    <button class="stf-act danger" data-a="ban">🔨 Ban</button>
                </div>
                <div id="stf-actform" class="stf-form"></div>
                ${shot !== undefined ? `<div class="stf-shot">${
                    /^https?:\/\//.test(shot) ? `<img src="${Noxa.esc(shot)}" alt="capture" />`
                    : `<div class="stf-shot-txt">📸 ${Noxa.esc(shot || 'En attente…')}</div>`}</div>` : ''}
            </div>`;
        host.querySelectorAll('[data-a]').forEach((el) =>
            el.addEventListener('click', () => onAction(c, el.getAttribute('data-a'))));
    }

    function onAction(c, a) {
        const p = selected();
        if (!p) return;
        const form = c.querySelector('#stf-actform');
        if (a === 'spectate') {
            const on = specTarget !== p.id;
            specTarget = on ? p.id : null;
            post('spectate', { state: on });
            renderDetail(c);
        } else if (a === 'screenshot') {
            shots[p.id] = 'En attente…';
            post('screenshot'); renderDetail(c);
        } else if (a === 'freeze') { post('freeze', { state: true }); }
        else if (a === 'unfreeze') { post('freeze', { state: false }); }
        else if (a === 'tp') { post('tp'); }
        else if (a === 'kick') {
            inlineForm(form, 'Kick', [{ name: 'reason', label: 'Raison' }], (v) => post('kick', v));
        } else if (a === 'ban') {
            inlineForm(form, 'Ban', [
                { name: 'duration', label: 'Durée', type: 'select', options: banDurations.map((d) => ({ value: d, label: d })) },
                { name: 'reason', label: 'Raison' },
            ], (v) => post('ban', v));
        }
    }

    function inlineForm(host, title, fields, onSubmit) {
        if (!host) return;
        host.innerHTML = `
            ${fields.map(fieldHtml).join('')}
            <div class="stf-row">
                <button class="btn btn-primary" data-ok>Valider — ${Noxa.esc(title)}</button>
                <button class="btn btn-ghost" data-cancel>Annuler</button>
            </div>`;
        host.querySelector('[data-ok]').addEventListener('click', () => {
            const v = {};
            host.querySelectorAll('[data-fn]').forEach((el) => { v[el.getAttribute('data-fn')] = el.value.trim(); });
            onSubmit(v); host.innerHTML = '';
        });
        host.querySelector('[data-cancel]').addEventListener('click', () => { host.innerHTML = ''; });
    }

    function fieldHtml(f) {
        if (f.type === 'select') {
            const opts = (f.options || []).map((o) => `<option value="${Noxa.esc(o.value)}">${Noxa.esc(o.label)}</option>`).join('');
            return `<div><label class="field-label">${Noxa.esc(f.label)}</label><select class="field-input" data-fn="${Noxa.esc(f.name)}">${opts}</select></div>`;
        }
        return `<div><label class="field-label">${Noxa.esc(f.label)}</label><input class="field-input" data-fn="${Noxa.esc(f.name)}" placeholder="${Noxa.esc(f.placeholder || '')}" /></div>`;
    }

    /* --- Alertes ------------------------------------------------------ */
    VIEWS.alerts = (c) => {
        c.innerHTML = `
            <div class="stf-title">🚨 Alertes anti-triche temps réel</div>
            <div class="stf-hint">Flux des détections (le plus récent en haut). Score = cumul du joueur.</div>
            <div class="stf-alerts">${alerts.length ? alerts.map(alertRow).join('') : '<div class="stf-empty">Aucune alerte pour le moment.</div>'}</div>`;
    };

    function alertRow(a) {
        const sev = ['low', 'medium', 'high', 'critical'].includes(a.severity) ? a.severity : 'low';
        return `<div class="stf-alert ${sev}">
            <div class="stf-alert-ic">${TYPE_ICON[a.kind] || '⚠️'}</div>
            <div class="stf-alert-body">
                <div class="stf-alert-top">
                    <span class="stf-alert-type">${Noxa.esc(a.kind)}</span>
                    <span class="stf-alert-name">${Noxa.esc(a.name)} · ID ${a.src}</span>
                    <span class="stf-actbadge ${Noxa.esc(a.action || 'alert')}" style="margin-left:auto">${Noxa.esc(a.action || 'alert')}</span>
                </div>
                <div class="stf-alert-detail">${Noxa.esc(a.detail)}</div>
                <div class="stf-alert-meta">
                    <span>Score ${a.score || 0}</span>
                    <span>${Noxa.esc(a.pos || '—')}</span>
                    <span>${fmtTime(a.time)}</span>
                </div>
            </div>
        </div>`;
    }

    /* --- Logs AC ------------------------------------------------------ */
    VIEWS.aclogs = (c) => {
        c.innerHTML = `
            <div class="stf-title">📜 Journal anti-triche (BDD)</div>
            <div class="stf-filters">
                ${AC_TYPES.map((t) => `<div class="stf-chip ${t === acFilter ? 'active' : ''}" data-f="${t}">${t}</div>`).join('')}
            </div>
            <div class="stf-logs">${aclogs.length ? aclogs.map(logRow).join('') : '<div class="stf-empty">Aucune entrée.</div>'}</div>`;
        c.querySelectorAll('[data-f]').forEach((el) => el.addEventListener('click', () => {
            acFilter = el.getAttribute('data-f');
            fetchData('aclogs', acFilter);
            c.querySelectorAll('.stf-chip').forEach((n) => n.classList.toggle('active', n.getAttribute('data-f') === acFilter));
        }));
    };

    function logRow(l) {
        const sev = ['low', 'medium', 'high', 'critical'].includes(l.severity) ? l.severity : 'low';
        return `<div class="stf-log ${sev}" title="${Noxa.esc(l.detail)}">
            <span class="stf-log-type">${Noxa.esc(l.type)}</span>
            <span class="stf-log-msg">${Noxa.esc(l.name || '?')} — ${Noxa.esc(l.detail)}</span>
            <span class="stf-log-time">${Noxa.esc((l.created_at || '').toString().replace('T', ' ').slice(0, 19))}</span>
        </div>`;
    }

    /* --- Serveur ------------------------------------------------------ */
    VIEWS.server = (c) => {
        c.innerHTML = `
            <div class="stf-title">🖥️ Serveur</div>
            <div class="stf-stats">
                <div class="stf-stat"><div class="stf-stat-val">${server.connected ?? '—'}/${server.maxClients ?? '—'}</div><div class="stf-stat-label">Connectés / Max</div></div>
                <div class="stf-stat"><div class="stf-stat-val">${fmtDur(server.uptime)}</div><div class="stf-stat-label">Uptime</div></div>
                <div class="stf-stat"><div class="stf-stat-val">${server.acEnabled === false ? 'OFF' : 'ON'}</div><div class="stf-stat-label">Anti-cheat</div></div>
                <div class="stf-stat"><div class="stf-stat-val">${server.flags24h ?? 0}</div><div class="stf-stat-label">Alertes récentes</div></div>
            </div>`;
    };

    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('staff', 'open', show);
    Noxa.on('staff', 'data', setData);
    Noxa.on('staff', 'alert', onAlert);
    Noxa.on('staff', 'screenshot', onScreenshot);
    Noxa.on('staff', 'close', close);

    return { handleEscape };
})();
window.NoxaStaff = NoxaStaff;
