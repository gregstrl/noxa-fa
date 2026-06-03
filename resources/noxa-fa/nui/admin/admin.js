/* =====================================================================
   NOXA FA — Panneau d'administration (style RageUI, overlay staff)
   Messages Lua -> NUI (app:'admin') :
     • 'open'  data:{ rank, players[], jobs[], server{}, banDurations[] }
     • 'data'  data:{ what:'players'|'logs'|'server', list }
     • 'close'
   Callbacks NUI -> Lua :
     • adminFetch  { what, arg }            (demande de rafraîchissement)
     • adminAction { action, target, params }  (intention ; rang revérifié serveur)
     • adminClose  {}
   AUCUNE valeur n'est de confiance : le serveur revérifie le rang à chaque
   action et journalise. La NUI n'est qu'un émetteur d'intentions.
   ===================================================================== */

const NoxaAdmin = (() => {
    const root = document.getElementById('admin');
    let open = false;
    let rank = 'user';
    let jobs = [];
    let banDurations = ['perm'];
    let players = [];
    let server = {};
    let logs = [];
    let selectedId = null;     // id du joueur sélectionné
    let section = 'players';
    let logFilter = 'all';
    let search = '';
    let savedTps = JSON.parse(localStorage.getItem('noxa_admin_tps') || '[]');

    // Définition des sections (ordre = navigation flèches haut/bas).
    const SECTIONS = [
        { id: 'players',  label: 'Joueurs',       icon: '👥' },
        { id: 'vehicles', label: 'Véhicules',     icon: '🚗' },
        { id: 'teleport', label: 'Téléportation', icon: '📍' },
        { id: 'economy',  label: 'Économie',      icon: '💰' },
        { id: 'jobs',     label: 'Jobs & Grades', icon: '🧰' },
        { id: 'sanctions',label: 'Sanctions',     icon: '⚖️' },
        { id: 'announce', label: 'Annonces',      icon: '📢' },
        { id: 'logs',     label: 'Logs',          icon: '📜' },
        { id: 'server',   label: 'Serveur',       icon: '🖥️' },
    ];

    /* ---- cycle de vie ------------------------------------------------ */
    function show(d) {
        rank = d.rank || 'user';
        jobs = d.jobs || [];
        banDurations = d.banDurations || ['perm'];
        players = d.players || [];
        server = d.server || {};
        open = true;
        section = 'players';
        selectedId = null;
        root.classList.remove('hidden');
        render();
    }

    function close() {
        if (!open) return;
        open = false;
        root.innerHTML = '';
        root.classList.add('hidden');
        Noxa.post('adminClose', {});
    }

    function setData(d) {
        if (d.what === 'players') {
            players = d.list || [];
            if (selectedId != null && !players.some((p) => p.id === selectedId)) selectedId = null;
            if (open && (section === 'players' || section === 'economy' || section === 'jobs' || section === 'sanctions')) render();
        } else if (d.what === 'logs') {
            logs = d.list || [];
            if (open && (section === 'logs' || section === 'sanctions')) render();
        } else if (d.what === 'server') {
            server = d.list || {};
            if (open && section === 'server') render();
        }
    }

    /* ---- helpers ----------------------------------------------------- */
    const post = (action, params = {}) => Noxa.post('adminAction', { action, target: selectedId, params });
    const fetchData = (what, arg) => Noxa.post('adminFetch', { what, arg });

    function selected() { return players.find((p) => p.id === selectedId) || null; }

    function fmtUptime(s) {
        s = Number(s) || 0;
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    function navTo(id) { section = id; onEnter(id); render(); }

    // Récupération de données à l'ENTRÉE d'une section uniquement (jamais dans
    // render() : sinon l'arrivée des données redéclencherait un fetch en boucle).
    function onEnter(id) {
        if (id === 'logs') fetchData('logs', logFilter);
        else if (id === 'sanctions') fetchData('logs', 'admin');
        else if (id === 'server') fetchData('server');
        else if (id === 'players' || id === 'economy' || id === 'jobs') fetchData('players');
    }

    /* ---- rendu global ------------------------------------------------ */
    function render() {
        root.innerHTML = `
            <div class="adm-panel">
                <div class="adm-head">
                    <div>
                        <div class="adm-logo"><span>NOXA</span> ADMIN</div>
                        <div class="adm-head-sub">Panneau de modération</div>
                    </div>
                    <div class="adm-rank">${Noxa.esc(rank)}</div>
                    <div class="adm-close" id="adm-x">Fermer (Échap)</div>
                </div>
                <div class="adm-body">
                    <div class="adm-nav">
                        ${SECTIONS.map((s) => `
                            <div class="adm-nav-item ${s.id === section ? 'active' : ''}" data-sec="${s.id}">
                                <span class="adm-nav-ic">${s.icon}</span>${s.label}
                            </div>`).join('')}
                    </div>
                    <div class="adm-content" id="adm-content"></div>
                </div>
            </div>`;

        root.querySelector('#adm-x').addEventListener('click', close);
        root.querySelectorAll('[data-sec]').forEach((el) =>
            el.addEventListener('click', () => navTo(el.getAttribute('data-sec'))));

        const c = root.querySelector('#adm-content');
        const fn = VIEWS[section];
        if (fn) fn(c);
    }

    /* ================================================================= */
    /*  VUES PAR SECTION                                                 */
    /* ================================================================= */
    const VIEWS = {};

    /* --- Joueurs ------------------------------------------------------ */
    VIEWS.players = (c) => {
        const q = search.toLowerCase();
        const filtered = players.filter((p) =>
            !q || String(p.id).includes(q) || (p.name || '').toLowerCase().includes(q));
        c.innerHTML = `
            <div class="adm-section-title">👥 Joueurs connectés (${players.length})</div>
            <input class="field-input adm-search" id="adm-search" placeholder="Rechercher (ID ou nom)…" value="${Noxa.esc(search)}" />
            <div class="adm-players">
                ${filtered.length ? filtered.map(playerRow).join('') : '<div class="adm-empty">Aucun joueur.</div>'}
            </div>
            <div id="adm-selbar"></div>`;

        const si = c.querySelector('#adm-search');
        si.addEventListener('input', () => { search = si.value; const sb = c.querySelector('#adm-selbar'); renderSelbar(c); refreshList(c); });
        bindPlayerRows(c);
        renderSelbar(c);
    };

    function playerRow(p) {
        return `<div class="adm-player ${p.id === selectedId ? 'selected' : ''}" data-pid="${p.id}">
            <div class="adm-pid">${p.id}</div>
            <div class="adm-pinfo">
                <div class="adm-pname">${Noxa.esc(p.name)}</div>
                <div class="adm-pmeta">
                    <span>${Noxa.esc(p.jobLabel)} (${p.grade})</span>
                    ${p.duty ? '<span class="adm-badge duty">Service</span>' : ''}
                    ${p.rank !== 'user' ? `<span class="adm-badge staff">${Noxa.esc(p.rank)}</span>` : ''}
                    ${!p.loaded ? '<span class="adm-badge staff">lobby</span>' : ''}
                </div>
            </div>
            <div class="adm-ping">${p.ping} ms</div>
        </div>`;
    }

    function refreshList(c) {
        const q = search.toLowerCase();
        const filtered = players.filter((p) =>
            !q || String(p.id).includes(q) || (p.name || '').toLowerCase().includes(q));
        const box = c.querySelector('.adm-players');
        if (box) { box.innerHTML = filtered.length ? filtered.map(playerRow).join('') : '<div class="adm-empty">Aucun joueur.</div>'; bindPlayerRows(c); }
    }

    function bindPlayerRows(c) {
        c.querySelectorAll('[data-pid]').forEach((el) =>
            el.addEventListener('click', () => {
                selectedId = Number(el.getAttribute('data-pid'));
                c.querySelectorAll('.adm-player').forEach((n) => n.classList.toggle('selected', Number(n.getAttribute('data-pid')) === selectedId));
                renderSelbar(c);
            }));
    }

    // Spécifications des actions joueur (champs du formulaire inline).
    const PLAYER_ACTIONS = [
        { action: 'heal',   label: 'Soigner' },
        { action: 'revive', label: 'Réanimer' },
        { action: 'bring',  label: 'Bring' },
        { action: 'goto',   label: 'Goto' },
        { action: 'freeze', label: 'Figer',   params: { state: true } },
        { action: 'freeze', label: 'Libérer', params: { state: false }, key: 'unfreeze' },
        { action: 'kick',   label: 'Kick', danger: true, fields: [{ name: 'reason', label: 'Raison', type: 'text' }] },
        { action: 'ban',    label: 'Ban',  danger: true, fields: [
            { name: 'duration', label: 'Durée', type: 'select', options: () => banDurations.map((d) => ({ value: d, label: d })) },
            { name: 'reason', label: 'Raison', type: 'text' },
        ] },
        { action: 'warn',   label: 'Warn', fields: [{ name: 'reason', label: 'Raison', type: 'text' }] },
    ];

    function renderSelbar(c) {
        const bar = c.querySelector('#adm-selbar');
        if (!bar) return;
        const p = selected();
        if (!p) { bar.className = 'adm-selbar empty'; bar.innerHTML = 'Sélectionnez un joueur pour agir.'; return; }
        bar.className = 'adm-selbar';
        bar.innerHTML = `
            <div class="adm-sel-name">⮞ ${Noxa.esc(p.name)} <span style="color:var(--text-faint);font-weight:500">· ID ${p.id} · ${Noxa.money(p.cash)} / ${Noxa.money(p.bank)}</span></div>
            <div class="adm-actions">
                ${PLAYER_ACTIONS.map((a, i) => `<button class="adm-act ${a.danger ? 'danger' : ''}" data-ai="${i}">${a.label}</button>`).join('')}
            </div>
            <div id="adm-actform"></div>`;
        bar.querySelectorAll('[data-ai]').forEach((el) =>
            el.addEventListener('click', () => triggerPlayerAction(c, PLAYER_ACTIONS[Number(el.getAttribute('data-ai'))])));
    }

    function triggerPlayerAction(c, spec) {
        if (!selected()) return;
        if (!spec.fields) { post(spec.action, spec.params || {}); return; }
        renderInlineForm(c.querySelector('#adm-actform'), spec.label, spec.fields, (values) => {
            post(spec.action, Object.assign({}, spec.params, values));
        });
    }

    /* --- Formulaire inline générique --------------------------------- */
    function renderInlineForm(host, title, fields, onSubmit) {
        if (!host) return;
        host.innerHTML = `
            <div class="adm-form" style="margin-top:12px">
                ${fields.map((f, i) => fieldHtml(f, i)).join('')}
                <div class="adm-row">
                    <button class="btn btn-primary" data-act="ok">Valider — ${Noxa.esc(title)}</button>
                    <button class="btn btn-ghost" data-act="cancel">Annuler</button>
                </div>
            </div>`;
        const collect = () => {
            const v = {};
            host.querySelectorAll('[data-fname]').forEach((el) => { v[el.getAttribute('data-fname')] = el.value.trim(); });
            return v;
        };
        host.querySelector('[data-act=ok]').addEventListener('click', () => { onSubmit(collect()); host.innerHTML = ''; });
        host.querySelector('[data-act=cancel]').addEventListener('click', () => { host.innerHTML = ''; });
    }

    function fieldHtml(f, i) {
        if (f.type === 'select') {
            const opts = (typeof f.options === 'function' ? f.options() : f.options || [])
                .map((o) => `<option value="${Noxa.esc(o.value)}">${Noxa.esc(o.label)}</option>`).join('');
            return `<div><label class="field-label">${Noxa.esc(f.label)}</label>
                <select class="field-input" data-fname="${Noxa.esc(f.name)}">${opts}</select></div>`;
        }
        const t = f.type === 'number' ? 'number' : 'text';
        return `<div><label class="field-label">${Noxa.esc(f.label)}</label>
            <input type="${t}" class="field-input" data-fname="${Noxa.esc(f.name)}" placeholder="${Noxa.esc(f.placeholder || '')}" /></div>`;
    }

    /* --- Véhicules ---------------------------------------------------- */
    VIEWS.vehicles = (c) => {
        c.innerHTML = `
            <div class="adm-section-title">🚗 Véhicules</div>
            <div class="adm-hint">Spawn devant vous, actions sur le véhicule courant (ou le plus proche).</div>
            <div class="adm-form">
                <div><label class="field-label">Modèle (spawn name)</label>
                    <input class="field-input" id="veh-model" placeholder="adder, police, sultan…" /></div>
                <div class="adm-row">
                    <button class="btn btn-primary" id="veh-spawn">Générer</button>
                    <button class="btn" id="veh-repair">Réparer</button>
                    <button class="btn btn-danger" id="veh-del">Supprimer</button>
                </div>
                <div><label class="field-label">Couleur (RVB)</label>
                    <div class="adm-row">
                        <input class="field-input" id="veh-r" type="number" min="0" max="255" placeholder="R" />
                        <input class="field-input" id="veh-g" type="number" min="0" max="255" placeholder="V" />
                        <input class="field-input" id="veh-b" type="number" min="0" max="255" placeholder="B" />
                        <button class="btn" id="veh-color">Appliquer</button>
                    </div>
                </div>
            </div>`;
        c.querySelector('#veh-spawn').addEventListener('click', () => {
            const m = c.querySelector('#veh-model').value.trim();
            if (m) Noxa.post('adminAction', { action: 'spawnvehicle', params: { model: m } });
        });
        c.querySelector('#veh-repair').addEventListener('click', () => Noxa.post('adminAction', { action: 'repairvehicle' }));
        c.querySelector('#veh-del').addEventListener('click', () => Noxa.post('adminAction', { action: 'deletevehicle' }));
        c.querySelector('#veh-color').addEventListener('click', () => Noxa.post('adminAction', { action: 'colorvehicle', params: {
            r: Number(c.querySelector('#veh-r').value) || 0,
            g: Number(c.querySelector('#veh-g').value) || 0,
            b: Number(c.querySelector('#veh-b').value) || 0,
        } }));
    };

    /* --- Téléportation ------------------------------------------------ */
    VIEWS.teleport = (c) => {
        c.innerHTML = `
            <div class="adm-section-title">📍 Téléportation</div>
            <div class="adm-form">
                <button class="btn btn-primary" id="tp-wp">Vers le point GPS (waypoint)</button>
                <div><label class="field-label">Coordonnées XYZ</label>
                    <div class="adm-row">
                        <input class="field-input" id="tp-x" type="number" placeholder="X" />
                        <input class="field-input" id="tp-y" type="number" placeholder="Y" />
                        <input class="field-input" id="tp-z" type="number" placeholder="Z" />
                    </div>
                </div>
                <div class="adm-row">
                    <button class="btn" id="tp-go">S'y rendre</button>
                    <button class="btn btn-ghost" id="tp-save">Sauvegarder ce point</button>
                </div>
            </div>
            <div class="adm-section-title" style="margin-top:18px;font-size:14px">Points sauvegardés</div>
            <div class="adm-players" id="tp-saved"></div>`;

        c.querySelector('#tp-wp').addEventListener('click', () => Noxa.post('adminAction', { action: 'tpwaypoint' }));
        const getXYZ = () => ({ x: c.querySelector('#tp-x').value, y: c.querySelector('#tp-y').value, z: c.querySelector('#tp-z').value });
        c.querySelector('#tp-go').addEventListener('click', () => {
            const p = getXYZ();
            if (p.x && p.y && p.z) Noxa.post('adminAction', { action: 'tpcoords', params: p });
        });
        c.querySelector('#tp-save').addEventListener('click', () => {
            const p = getXYZ();
            if (!p.x || !p.y || !p.z) return;
            savedTps.push({ label: `Point ${savedTps.length + 1}`, x: Number(p.x), y: Number(p.y), z: Number(p.z) });
            localStorage.setItem('noxa_admin_tps', JSON.stringify(savedTps));
            renderSaved(c);
        });
        renderSaved(c);
    };

    function renderSaved(c) {
        const box = c.querySelector('#tp-saved');
        if (!box) return;
        if (!savedTps.length) { box.innerHTML = '<div class="adm-empty">Aucun point sauvegardé.</div>'; return; }
        box.innerHTML = savedTps.map((t, i) => `
            <div class="adm-player">
                <div class="adm-pinfo"><div class="adm-pname">${Noxa.esc(t.label)}</div>
                    <div class="adm-pmeta">${t.x.toFixed(1)}, ${t.y.toFixed(1)}, ${t.z.toFixed(1)}</div></div>
                <button class="adm-act" data-tpgo="${i}">Aller</button>
                <button class="adm-act danger" data-tpdel="${i}">✕</button>
            </div>`).join('');
        box.querySelectorAll('[data-tpgo]').forEach((el) => el.addEventListener('click', () => {
            const t = savedTps[Number(el.getAttribute('data-tpgo'))];
            Noxa.post('adminAction', { action: 'tpcoords', params: { x: t.x, y: t.y, z: t.z } });
        }));
        box.querySelectorAll('[data-tpdel]').forEach((el) => el.addEventListener('click', () => {
            savedTps.splice(Number(el.getAttribute('data-tpdel')), 1);
            localStorage.setItem('noxa_admin_tps', JSON.stringify(savedTps));
            renderSaved(c);
        }));
    }

    /* --- Économie ----------------------------------------------------- */
    VIEWS.economy = (c) => {
        const p = selected();
        c.innerHTML = `
            <div class="adm-section-title">💰 Économie</div>
            ${p ? `<div class="adm-hint">Cible : <b>${Noxa.esc(p.name)}</b> · Espèces ${Noxa.money(p.cash)} · Banque ${Noxa.money(p.bank)}</div>`
                : '<div class="adm-hint">Sélectionnez d\'abord un joueur dans la section « Joueurs ».</div>'}
            <div class="adm-form">
                <div class="adm-row">
                    <div><label class="field-label">Compte</label>
                        <select class="field-input" id="eco-acc"><option value="cash">Espèces</option><option value="bank">Banque</option></select></div>
                    <div><label class="field-label">Montant</label>
                        <input class="field-input" id="eco-amt" type="number" min="1" placeholder="0" /></div>
                </div>
                <div class="adm-row">
                    <button class="btn btn-primary" id="eco-give" ${p ? '' : 'disabled'}>Donner</button>
                    <button class="btn btn-danger" id="eco-take" ${p ? '' : 'disabled'}>Retirer</button>
                    <button class="btn" id="eco-set" ${p ? '' : 'disabled'}>Définir (set)</button>
                </div>
            </div>`;
        if (!p) return;
        const read = () => ({ account: c.querySelector('#eco-acc').value, amount: Number(c.querySelector('#eco-amt').value) });
        c.querySelector('#eco-give').addEventListener('click', () => { const v = read(); if (v.amount > 0) post('givemoney', v); });
        c.querySelector('#eco-take').addEventListener('click', () => { const v = read(); if (v.amount > 0) post('givemoney', Object.assign(v, { remove: true })); });
        c.querySelector('#eco-set').addEventListener('click', () => { const v = read(); if (v.amount >= 0) post('setmoney', v); });
    };

    /* --- Jobs & Grades ------------------------------------------------ */
    VIEWS.jobs = (c) => {
        const p = selected();
        const jobOpts = jobs.map((j) => `<option value="${Noxa.esc(j.name)}">${Noxa.esc(j.label)}</option>`).join('');
        c.innerHTML = `
            <div class="adm-section-title">🧰 Jobs & Grades</div>
            ${p ? `<div class="adm-hint">Cible : <b>${Noxa.esc(p.name)}</b> · Actuel : ${Noxa.esc(p.jobLabel)} (grade ${p.grade})</div>`
                : '<div class="adm-hint">Sélectionnez d\'abord un joueur dans la section « Joueurs ».</div>'}
            <div class="adm-form">
                <div class="adm-row">
                    <div><label class="field-label">Métier</label><select class="field-input" id="job-name">${jobOpts}</select></div>
                    <div><label class="field-label">Grade</label><select class="field-input" id="job-grade"></select></div>
                </div>
                <button class="btn btn-primary" id="job-set" ${p ? '' : 'disabled'}>Appliquer le métier</button>
            </div>`;
        const gradeSel = c.querySelector('#job-grade');
        const fillGrades = () => {
            const j = jobs.find((x) => x.name === c.querySelector('#job-name').value);
            gradeSel.innerHTML = (j ? j.grades : []).map((g) => `<option value="${g.grade}">${g.grade} — ${Noxa.esc(g.label)}</option>`).join('');
        };
        c.querySelector('#job-name').addEventListener('change', fillGrades);
        fillGrades();
        if (p) c.querySelector('#job-set').addEventListener('click', () =>
            post('setjob', { job: c.querySelector('#job-name').value, grade: Number(gradeSel.value) || 0 }));
    };

    /* --- Sanctions ---------------------------------------------------- */
    VIEWS.sanctions = (c) => {
        const p = selected();
        c.innerHTML = `
            <div class="adm-section-title">⚖️ Sanctions</div>
            ${p ? `<div class="adm-hint">Cible : <b>${Noxa.esc(p.name)}</b> (ID ${p.id})</div>`
                : '<div class="adm-hint">Sélectionnez un joueur dans « Joueurs » pour le sanctionner.</div>'}
            <div class="adm-form">
                <div><label class="field-label">Durée du ban</label>
                    <select class="field-input" id="san-dur">${banDurations.map((d) => `<option value="${d}">${d}</option>`).join('')}</select></div>
                <div><label class="field-label">Raison</label><input class="field-input" id="san-reason" placeholder="Motif…" /></div>
                <div class="adm-row">
                    <button class="btn btn-danger" id="san-kick" ${p ? '' : 'disabled'}>Kick</button>
                    <button class="btn btn-danger" id="san-ban" ${p ? '' : 'disabled'}>Ban</button>
                    <button class="btn" id="san-warn" ${p ? '' : 'disabled'}>Warn</button>
                </div>
            </div>
            <div class="adm-section-title" style="margin-top:18px;font-size:14px">Historique admin</div>
            <div class="adm-logs" id="san-logs">${logs.length ? logsHtml() : '<div class="adm-empty">Aucun historique.</div>'}</div>`;
        if (p) {
            const reason = () => c.querySelector('#san-reason').value.trim();
            c.querySelector('#san-kick').addEventListener('click', () => post('kick', { reason: reason() }));
            c.querySelector('#san-ban').addEventListener('click', () => post('ban', { duration: c.querySelector('#san-dur').value, reason: reason() }));
            c.querySelector('#san-warn').addEventListener('click', () => post('warn', { reason: reason() }));
        }
    };

    /* --- Annonces ----------------------------------------------------- */
    VIEWS.announce = (c) => {
        c.innerHTML = `
            <div class="adm-section-title">📢 Annonce serveur</div>
            <div class="adm-hint">Diffusée à tous les joueurs sous forme de toast NUI.</div>
            <div class="adm-form">
                <textarea class="adm-textarea" id="ann-msg" placeholder="Votre message…"></textarea>
                <button class="btn btn-primary" id="ann-send">Diffuser</button>
            </div>`;
        c.querySelector('#ann-send').addEventListener('click', () => {
            const msg = c.querySelector('#ann-msg').value.trim();
            if (msg) { Noxa.post('adminAction', { action: 'announce', params: { message: msg } }); c.querySelector('#ann-msg').value = ''; }
        });
    };

    /* --- Logs --------------------------------------------------------- */
    VIEWS.logs = (c) => {
        const cats = ['all', 'admin', 'security', 'economy', 'job', 'join'];
        c.innerHTML = `
            <div class="adm-section-title">📜 Logs récents</div>
            <div class="adm-filters">
                ${cats.map((cat) => `<div class="adm-chip ${cat === logFilter ? 'active' : ''}" data-cat="${cat}">${cat}</div>`).join('')}
            </div>
            <div class="adm-logs" id="logs-box">${logsHtml()}</div>`;
        c.querySelectorAll('[data-cat]').forEach((el) => el.addEventListener('click', () => {
            logFilter = el.getAttribute('data-cat');
            fetchData('logs', logFilter);
            c.querySelectorAll('.adm-chip').forEach((n) => n.classList.toggle('active', n.getAttribute('data-cat') === logFilter));
        }));
    };

    function logsHtml() {
        if (!logs.length) return '<div class="adm-empty">Aucun log.</div>';
        return logs.map((l) => `
            <div class="adm-log ${Noxa.esc(l.level || 'info')}">
                <span class="adm-log-cat">${Noxa.esc(l.category)}</span>
                <span class="adm-log-msg">${Noxa.esc(l.message)}</span>
                <span class="adm-log-time">${Noxa.esc((l.created_at || '').toString().replace('T', ' ').slice(0, 19))}</span>
            </div>`).join('');
    }

    /* --- Serveur ------------------------------------------------------ */
    VIEWS.server = (c) => {
        c.innerHTML = `
            <div class="adm-section-title">🖥️ Serveur</div>
            <div class="adm-stats">
                <div class="adm-stat"><div class="adm-stat-val">${server.players ?? '—'}</div><div class="adm-stat-label">Personnages chargés</div></div>
                <div class="adm-stat"><div class="adm-stat-val">${server.connected ?? '—'}/${server.maxClients ?? '—'}</div><div class="adm-stat-label">Connectés / Max</div></div>
                <div class="adm-stat"><div class="adm-stat-val">${fmtUptime(server.uptime)}</div><div class="adm-stat-label">Uptime</div></div>
                <div class="adm-stat"><div class="adm-stat-val" style="font-size:16px">${Noxa.esc(server.name || 'Noxa FA')}</div><div class="adm-stat-label">Serveur</div></div>
            </div>`;
    };

    /* ---- navigation clavier (flèches haut/bas entre sections) -------- */
    function handleKey(e) {
        if (!open) return;
        const idx = SECTIONS.findIndex((s) => s.id === section);
        if (e.key === 'ArrowDown') { navTo(SECTIONS[(idx + 1) % SECTIONS.length].id); e.preventDefault(); }
        else if (e.key === 'ArrowUp') { navTo(SECTIONS[(idx - 1 + SECTIONS.length) % SECTIONS.length].id); e.preventDefault(); }
    }
    window.addEventListener('keydown', handleKey);

    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('admin', 'open', show);
    Noxa.on('admin', 'data', setData);
    Noxa.on('admin', 'close', close);

    return { handleEscape };
})();
window.NoxaAdmin = NoxaAdmin;
