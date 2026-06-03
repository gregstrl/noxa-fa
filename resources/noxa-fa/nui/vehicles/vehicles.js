/* =====================================================================
   NOXA FA — Véhicules — interface NUI custom
   Messages Lua -> NUI (app:'vehicles') :
     • 'dealership' data:{ catalog:[{class,label,vehicles:[{spawn,label,class,price}]}], bank }
     • 'garage'     data:{ garage, vehicles:[{plate,model,label,state,fuel,engine,body}], impound:[...], impoundFee }
     • 'bank'       data:{ bank }
     • 'close'
   Callbacks NUI -> Lua : vehBuy {spawn}, vehTakeOut {plate}, vehStore {plate},
                          vehRetrieve {plate}, vehClose
   ===================================================================== */

const NoxaVeh = (() => {
    const root = document.getElementById('vehicles');
    let open = false;
    let mode = null;           // 'dealership' | 'garage'

    const pct1000 = (v) => Math.max(0, Math.min(100, Math.round((Number(v) || 0) / 10)));

    function frame(title, sub, right, body, foot) {
        root.innerHTML = `
            <div class="veh-wrap"><div class="veh-panel">
                <div class="veh-head">
                    <div class="veh-title">${Noxa.esc(title)}<small>${Noxa.esc(sub)}</small></div>
                    ${right || ''}
                </div>
                <div class="veh-body">${body}</div>
                <div class="veh-foot">${foot || '<button class="btn btn-ghost" data-close>Fermer (Échap)</button>'}</div>
            </div></div>`;
        root.classList.remove('hidden');
        root.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));
    }

    /* ----- Concession ----- */
    function dealership(d) {
        open = true; mode = 'dealership';
        const right = `<div class="veh-bank">🏦 <span id="veh-bank">${Noxa.money(d.bank || 0)}</span></div>`;
        const body = (d.catalog || []).map((cls) => `
            <div class="veh-class">
                <div class="veh-class-head">
                    <div class="veh-class-badge">${Noxa.esc(cls.class)}</div>
                    <div class="veh-class-label">${Noxa.esc(cls.label)}</div>
                </div>
                <div class="veh-grid">
                    ${cls.vehicles.map((v) => `
                        <div class="veh-card">
                            <div class="veh-card-name">${Noxa.esc(v.label)}</div>
                            <div class="veh-card-class">Classe ${Noxa.esc(v.class)}</div>
                            <div class="veh-card-bottom">
                                <span class="veh-card-price">${Noxa.money(v.price)}</span>
                                <button class="btn btn-primary" data-buy="${Noxa.esc(v.spawn)}">Acheter</button>
                            </div>
                        </div>`).join('')}
                </div>
            </div>`).join('');
        frame('Concession automobile', 'Paiement par virement bancaire', right, body);
        root.querySelectorAll('[data-buy]').forEach((b) =>
            b.addEventListener('click', () => Noxa.post('vehBuy', { spawn: b.getAttribute('data-buy') })));
    }

    function setBank(d) {
        const el = root.querySelector('#veh-bank');
        if (el) el.textContent = Noxa.money(d.bank || 0);
    }

    /* ----- Garage / fourrière ----- */
    function statBar(label, val) {
        const p = pct1000(val);
        return `<div class="veh-stat">
            <div class="veh-bar ${p <= 30 ? 'low' : ''}"><i style="width:${p}%"></i></div>
            <div class="veh-stat-lbl">${label}</div>
        </div>`;
    }
    function fuelBar(fuel) {
        const p = Math.max(0, Math.min(100, Math.round(Number(fuel) || 0)));
        return `<div class="veh-stat">
            <div class="veh-bar ${p <= 20 ? 'low' : ''}"><i style="width:${p}%"></i></div>
            <div class="veh-stat-lbl">Essence</div>
        </div>`;
    }

    function garage(d) {
        open = true; mode = 'garage';
        const vehicles = d.vehicles || [];
        const impound = d.impound || [];

        const garHtml = vehicles.length ? vehicles.map((v) => {
            const isOut = v.state === 'out';
            const action = isOut
                ? `<button class="btn btn-ghost" data-store="${Noxa.esc(v.plate)}">Remiser</button>`
                : `<button class="btn btn-primary" data-take="${Noxa.esc(v.plate)}">Sortir</button>`;
            return `<div class="veh-row">
                <div class="veh-row-main">
                    <div class="veh-row-name">${Noxa.esc(v.label || v.model)}
                        <span class="veh-badge-state state-${v.state}">${v.state === 'out' ? 'Sorti' : 'Remisé'}</span></div>
                    <div class="veh-row-plate">${Noxa.esc(v.plate)}</div>
                </div>
                <div class="veh-row-stats">${fuelBar(v.fuel)}${statBar('Moteur', v.engine)}${statBar('Carrosserie', v.body)}</div>
                ${action}
            </div>`;
        }).join('') : `<div class="veh-empty">Aucun véhicule dans ce garage.</div>`;

        const impHtml = impound.length ? `
            <div class="veh-section-title">Fourrière — amende ${Noxa.money(d.impoundFee || 0)}</div>
            ${impound.map((v) => `
                <div class="veh-row">
                    <div class="veh-row-main">
                        <div class="veh-row-name">${Noxa.esc(v.label || v.model)}
                            <span class="veh-badge-state state-impound">Fourrière</span></div>
                        <div class="veh-row-plate">${Noxa.esc(v.plate)}</div>
                    </div>
                    <button class="btn btn-primary" data-retrieve="${Noxa.esc(v.plate)}">Récupérer (${Noxa.money(d.impoundFee || 0)})</button>
                </div>`).join('')}` : '';

        frame('Garage', 'Sortez ou remisez vos véhicules', '',
            `<div class="veh-section-title">Vos véhicules</div>${garHtml}${impHtml}`);

        root.querySelectorAll('[data-take]').forEach((b) =>
            b.addEventListener('click', () => Noxa.post('vehTakeOut', { plate: b.getAttribute('data-take') })));
        root.querySelectorAll('[data-store]').forEach((b) =>
            b.addEventListener('click', () => Noxa.post('vehStore', { plate: b.getAttribute('data-store') })));
        root.querySelectorAll('[data-retrieve]').forEach((b) =>
            b.addEventListener('click', () => Noxa.post('vehRetrieve', { plate: b.getAttribute('data-retrieve') })));
    }

    function close() {
        if (!open) return;
        open = false; mode = null;
        root.classList.add('hidden');
        root.innerHTML = '';
        Noxa.post('vehClose', {});
    }

    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('vehicles', 'dealership', dealership);
    Noxa.on('vehicles', 'garage', garage);
    Noxa.on('vehicles', 'bank', setBank);
    Noxa.on('vehicles', 'close', close);

    return { handleEscape };
})();
window.NoxaVeh = NoxaVeh;
