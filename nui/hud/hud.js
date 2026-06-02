/* =====================================================================
   NOXA FA — Module HUD (argent, identité, emploi, besoins)
   Messages Lua -> NUI (app:'hud') :
     • 'update' data:{ name, citizenid, job:{label,gradeLabel,onDuty}, cash, bank,
                       needs:{ health, armor, hunger, thirst, stress } }
     • 'show' / 'hide'
   Le HUD est purement informatif : aucune donnée n'est de confiance, tout
   provient du statebag répliqué serveur.
   ===================================================================== */

(() => {
    const hud = document.getElementById('hud');
    let built = false;
    let last = { cash: null, bank: null };

    const NEEDS = [
        { key: 'health', ic: '❤', col: '#ef4444' },
        { key: 'armor',  ic: '🛡', col: '#38bdf8' },
        { key: 'hunger', ic: '🍔', col: '#f59e0b' },
        { key: 'thirst', ic: '💧', col: '#22d3ee' },
        { key: 'stress', ic: '🧠', col: '#a855f7' },
    ];

    function build() {
        hud.innerHTML = `
            <div class="hud-top">
                <div class="hud-money">
                    <div class="hud-money-pill cash"><div class="hud-money-ic">$</div><div class="hud-money-val" id="hud-cash">0 $</div></div>
                    <div class="hud-money-pill bank"><div class="hud-money-ic">🏦</div><div class="hud-money-val" id="hud-bank">0 $</div></div>
                </div>
                <div class="hud-id">
                    <div class="hud-id-avatar" id="hud-av">?</div>
                    <div class="hud-id-text">
                        <div class="hud-id-name" id="hud-name">—</div>
                        <div class="hud-id-job" id="hud-job">—</div>
                    </div>
                </div>
            </div>
            <div class="hud-needs" id="hud-needs">
                ${NEEDS.map((n) => `<div class="need-ring" id="need-${n.key}" data-ic="${n.ic}" style="--col:${n.col}"></div>`).join('')}
            </div>`;
        built = true;
    }

    function setMoney(id, value) {
        const el = document.getElementById(id);
        if (!el) return;
        el.textContent = Noxa.money(value);
        el.classList.remove('flash');
        void el.offsetWidth;          // reflow pour rejouer l'animation
        el.classList.add('flash');
    }

    function update(d) {
        if (!built) build();
        hud.classList.remove('hidden');

        if (d.name) document.getElementById('hud-name').textContent = d.name;
        if (d.name) document.getElementById('hud-av').textContent =
            d.name.split(' ').map((w) => w[0]).join('').slice(0, 2).toUpperCase();

        if (d.job) {
            const duty = d.job.onDuty ? '<span class="duty-dot on"></span>' : '<span class="duty-dot"></span>';
            const grade = d.job.gradeLabel ? ` · ${Noxa.esc(d.job.gradeLabel)}` : '';
            document.getElementById('hud-job').innerHTML = `${Noxa.esc(d.job.label || '')}${grade}${duty}`;
        }

        if (d.cash != null && d.cash !== last.cash) { setMoney('hud-cash', d.cash); last.cash = d.cash; }
        if (d.bank != null && d.bank !== last.bank) { setMoney('hud-bank', d.bank); last.bank = d.bank; }

        if (d.needs) {
            NEEDS.forEach((n) => {
                const ring = document.getElementById(`need-${n.key}`);
                if (!ring) return;
                const v = Math.max(0, Math.min(100, Math.round(n.key === 'health'
                    ? ((d.needs.health - 100) / 100) * 100   // santé GTA 100-200 -> 0-100%
                    : d.needs[n.key] ?? 100)));
                ring.style.setProperty('--val', v);
                ring.classList.toggle('low', n.key !== 'stress' ? v <= 20 : v >= 80);
            });
        }
    }

    Noxa.on('hud', 'update', update);
    Noxa.on('hud', 'show', () => { if (built) hud.classList.remove('hidden'); });
    Noxa.on('hud', 'hide', () => hud.classList.add('hidden'));
})();
