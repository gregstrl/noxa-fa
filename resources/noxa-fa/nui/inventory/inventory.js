/* =====================================================================
   NOXA FA — Inventaire — interface NUI custom
   Messages Lua -> NUI (app:'inventory') :
     • 'set'   data:{ slots:[{slot,name,count,label,emoji,weight,usable}], weight, maxWeight, maxSlots, hotbar }
     • 'open'  -> ouvre la grille (focus déjà posé côté Lua)
     • 'close'
   Callbacks NUI -> Lua : invUse {slot}, invDrop {slot,count}, invGive {slot,count},
                          invMove {from,to}, invClose
   Le serveur est seule autorité : la NUI n'émet que des intentions.
   ===================================================================== */

const NoxaInv = (() => {
    const root    = document.getElementById('inventory');
    const hotbar  = document.getElementById('inv-hotbar');
    let state = { slots: [], weight: 0, maxWeight: 50000, maxSlots: 30, hotbar: 5 };
    let open = false;
    let ctx = null;

    const bySlot = (n) => state.slots.find((s) => s.slot === n) || null;
    const kg = (g) => (g / 1000).toFixed(1) + ' kg';

    /* ----- Hotbar permanente (5 premiers slots) ----- */
    function renderHotbar() {
        if (!hotbar) return;
        hotbar.classList.remove('hidden');
        let html = '';
        for (let i = 1; i <= state.hotbar; i++) {
            const it = bySlot(i);
            html += `<div class="hb-slot ${it ? 'filled' : ''}">
                <span class="hb-key">${i}</span>
                ${it ? `<span class="hb-emoji">${Noxa.esc(it.emoji || '📦')}</span>
                        <span class="hb-count">${it.count}</span>` : ''}
            </div>`;
        }
        hotbar.innerHTML = html;
    }

    /* ----- Grille complète ----- */
    function render() {
        const pct = Math.min(100, Math.round((state.weight / state.maxWeight) * 100));
        let cells = '';
        for (let s = 1; s <= state.maxSlots; s++) {
            const it = bySlot(s);
            if (it) {
                const hb = s <= state.hotbar ? `<span class="s-hb">${s}</span>` : '';
                cells += `<div class="slot filled" draggable="true" data-slot="${s}">
                    ${hb}
                    <span class="s-emoji">${Noxa.esc(it.emoji || '📦')}</span>
                    <span class="s-count">${it.count}</span>
                    <span class="s-label">${Noxa.esc(it.label || it.name)}</span>
                </div>`;
            } else {
                cells += `<div class="slot empty" data-slot="${s}"></div>`;
            }
        }
        root.innerHTML = `
            <div class="inv-wrap">
                <div class="inv-panel">
                    <div class="inv-head">
                        <div class="inv-title">Inventaire<small>Glissez pour déplacer · clic droit pour agir</small></div>
                        <div class="inv-weight">
                            <div class="inv-weight-top"><span>Poids</span><span>${kg(state.weight)} / ${kg(state.maxWeight)}</span></div>
                            <div class="inv-weight-bar"><div class="inv-weight-fill ${pct >= 85 ? 'warn' : ''}" style="width:${pct}%"></div></div>
                        </div>
                    </div>
                    <div class="inv-grid" id="inv-grid">${cells}</div>
                    <div class="inv-foot">
                        <span class="inv-hint">Touches 1–${state.hotbar} : utiliser le raccourci · Échap : fermer</span>
                        <button class="btn btn-ghost" id="inv-close">Fermer</button>
                    </div>
                </div>
            </div>`;
        bind();
    }

    function bind() {
        root.querySelector('#inv-close').addEventListener('click', close);
        root.querySelectorAll('.slot').forEach((el) => {
            const slot = Number(el.getAttribute('data-slot'));

            // Drag & drop : déplacement / fusion d'emplacements.
            el.addEventListener('dragstart', (e) => {
                if (!el.classList.contains('filled')) return e.preventDefault();
                e.dataTransfer.setData('text/plain', String(slot));
            });
            el.addEventListener('dragover', (e) => { e.preventDefault(); el.classList.add('drag-over'); });
            el.addEventListener('dragleave', () => el.classList.remove('drag-over'));
            el.addEventListener('drop', (e) => {
                e.preventDefault(); el.classList.remove('drag-over');
                const from = Number(e.dataTransfer.getData('text/plain'));
                if (from && from !== slot) Noxa.post('invMove', { from, to: slot });
            });

            if (!el.classList.contains('filled')) return;
            // Double-clic = utiliser ; clic droit = menu contextuel.
            el.addEventListener('dblclick', () => use(slot));
            el.addEventListener('contextmenu', (e) => { e.preventDefault(); showCtx(e, slot); });
        });
    }

    /* ----- Menu contextuel ----- */
    function closeCtx() { if (ctx) { ctx.remove(); ctx = null; } }
    function showCtx(e, slot) {
        closeCtx();
        const it = bySlot(slot);
        if (!it) return;
        ctx = document.createElement('div');
        ctx.className = 'inv-ctx';
        const many = it.count > 1;
        // Pas de window.prompt (non fiable en CEF FiveM) : actions explicites.
        ctx.innerHTML = `
            <div class="inv-ctx-head">${Noxa.esc(it.label)} ×${it.count}</div>
            ${it.usable ? `<div class="inv-ctx-item" data-act="use">▶️ Utiliser</div>` : ''}
            <div class="inv-ctx-item" data-act="give" data-n="1">🤝 Donner${many ? ' (1)' : ''}</div>
            ${many ? `<div class="inv-ctx-item" data-act="give" data-n="all">🤝 Donner tout</div>` : ''}
            <div class="inv-ctx-item danger" data-act="drop" data-n="1">🗑️ Jeter${many ? ' (1)' : ''}</div>
            ${many ? `<div class="inv-ctx-item danger" data-act="drop" data-n="all">🗑️ Jeter tout</div>` : ''}`;
        document.body.appendChild(ctx);
        const x = Math.min(e.clientX, window.innerWidth - 170);
        const y = Math.min(e.clientY, window.innerHeight - 200);
        ctx.style.left = x + 'px'; ctx.style.top = y + 'px';
        ctx.querySelectorAll('.inv-ctx-item').forEach((item) =>
            item.addEventListener('click', () => {
                const act = item.getAttribute('data-act');
                const n = item.getAttribute('data-n') === 'all' ? it.count : 1;
                if (act === 'use') use(slot);
                else if (act === 'give') Noxa.post('invGive', { slot, count: n });
                else if (act === 'drop') Noxa.post('invDrop', { slot, count: n });
                closeCtx();
            }));
    }

    function use(slot) { Noxa.post('invUse', { slot }); }

    /* ----- Cycle d'ouverture ----- */
    function set(d) {
        state = Object.assign(state, d);
        renderHotbar();
        if (open) render();
    }
    function show() {
        open = true;
        root.classList.remove('hidden');
        render();
    }
    function close() {
        if (!open) return;
        open = false;
        closeCtx();
        root.classList.add('hidden');
        root.innerHTML = '';
        Noxa.post('invClose', {});
    }
    function hideHotbar() { if (hotbar) hotbar.classList.add('hidden'); }

    document.addEventListener('click', (e) => { if (ctx && !ctx.contains(e.target)) closeCtx(); });
    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('inventory', 'set', set);
    Noxa.on('inventory', 'open', show);
    Noxa.on('inventory', 'close', close);
    Noxa.on('inventory', 'hideHotbar', hideHotbar);

    return { handleEscape };
})();
window.NoxaInv = NoxaInv;
