/* =====================================================================
   NOXA FA — NUI des jobs actifs (MDT police · atelier méca · fouille)
   Messages Lua -> NUI (app:'jobs') :
     • 'mdt'     data:{ officer, units:[{id,name,grade}] }
     • 'atelier' data:{ society }
     • 'search'  data:{ name, id, cash, items:[{name,label,emoji,count}] }
     • 'close'
   Callbacks NUI -> Lua : jobsClose, mechRepair, mechWash
   ===================================================================== */

const NoxaJobs = (() => {
    const root = document.getElementById('jobs');
    let open = false;
    let view = null;
    let data = {};

    function show(v, d) {
        view = v;
        data = d || {};
        open = true;
        root.classList.remove('hidden');
        render();
    }

    function close() {
        if (!open) return;
        open = false;
        root.classList.add('hidden');
        root.innerHTML = '';
        Noxa.post('jobsClose', {});
    }

    function frame(title, sub, bodyHtml) {
        root.innerHTML = `
            <div class="job-scrim" id="job-scrim"></div>
            <div class="job-card">
                <div class="job-head">
                    <div>
                        <div class="job-title">${Noxa.esc(title)}</div>
                        ${sub ? `<div class="job-sub">${Noxa.esc(sub)}</div>` : ''}
                    </div>
                    <div class="job-x" id="job-x">Fermer (Échap)</div>
                </div>
                <div class="job-body">${bodyHtml}</div>
            </div>`;
        root.querySelector('#job-x').addEventListener('click', close);
        root.querySelector('#job-scrim').addEventListener('click', close);
    }

    function render() {
        if (view === 'mdt') return renderMDT();
        if (view === 'atelier') return renderAtelier();
        if (view === 'search') return renderSearch();
    }

    /* --- MDT police --------------------------------------------------- */
    function renderMDT() {
        const units = data.units || [];
        const body = `
            <div class="job-stat"><span>Agent connecté</span><b>${Noxa.esc(data.officer || '—')}</b></div>
            <div class="job-section">Effectifs en service (${units.length})</div>
            ${units.length ? units.map((u) => `
                <div class="job-row">
                    <div class="job-row-ic">👮</div>
                    <div class="job-row-main">
                        <div class="job-row-label">${Noxa.esc(u.name)}</div>
                        <div class="job-row-meta">${Noxa.esc(u.grade || '')}</div>
                    </div>
                    <div class="job-row-qty">ID ${u.id}</div>
                </div>`).join('') : '<div class="job-empty">Aucun agent en service.</div>'}`;
        frame('MDT — LSPD', 'Terminal de données mobile', body);
    }

    /* --- Atelier mécanicien ------------------------------------------- */
    function renderAtelier() {
        const body = `
            <div class="job-section">Actions atelier</div>
            <div class="job-actions">
                <button class="btn btn-primary" id="atl-repair">🔧 Réparer le véhicule</button>
                <button class="btn" id="atl-wash">🧽 Nettoyer le véhicule</button>
            </div>
            <div class="job-empty">Placez-vous près d'un véhicule avant d'agir.</div>`;
        frame('Atelier', Noxa.esc(data.society || 'Mécanicien'), body);
        root.querySelector('#atl-repair').addEventListener('click', () => { Noxa.post('mechRepair', {}); close(); });
        root.querySelector('#atl-wash').addEventListener('click', () => { Noxa.post('mechWash', {}); });
    }

    /* --- Fouille (résultat lecture seule) ----------------------------- */
    function renderSearch() {
        const items = data.items || [];
        const body = `
            <div class="job-stat"><span>Espèces sur la personne</span><b>${Noxa.money(data.cash || 0)}</b></div>
            <div class="job-section">Objets (${items.length})</div>
            ${items.length ? items.map((it) => `
                <div class="job-row">
                    <div class="job-row-ic">${Noxa.esc(it.emoji || '📦')}</div>
                    <div class="job-row-main">
                        <div class="job-row-label">${Noxa.esc(it.label || it.name)}</div>
                        <div class="job-row-meta">${Noxa.esc(it.category || '')}</div>
                    </div>
                    <div class="job-row-qty">×${it.count}</div>
                </div>`).join('') : '<div class="job-empty">Aucun objet.</div>'}`;
        frame(`Fouille — ${Noxa.esc(data.name || '')}`, `ID ${data.id ?? '—'}`, body);
    }

    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('jobs', 'mdt', (d) => show('mdt', d));
    Noxa.on('jobs', 'atelier', (d) => show('atelier', d));
    Noxa.on('jobs', 'search', (d) => show('search', d));
    Noxa.on('jobs', 'close', close);

    return { handleEscape };
})();
window.NoxaJobs = NoxaJobs;
