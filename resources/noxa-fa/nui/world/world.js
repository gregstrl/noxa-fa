/* =====================================================================
   NOXA FA — Monde : prompt d'interaction + jauge carburant
   Messages Lua -> NUI :
     • app:'world' action 'prompt' data:{ show:boolean, label:string }
     • app:'fuel'  action 'show'   data:{ percent }
     • app:'fuel'  action 'update' data:{ percent }
     • app:'fuel'  action 'hide'
   Couches purement informatives : aucune saisie, aucun focus requis.
   ===================================================================== */

const NoxaWorld = (() => {
    const prompt = document.getElementById('world-prompt');
    const gaugeRoot = document.getElementById('fuel-gauge');

    // --- Prompt -----------------------------------------------------------
    function setPrompt(d) {
        if (d.show) {
            prompt.innerHTML =
                `<div class="wp-key">E</div><div class="wp-label">${Noxa.esc(d.label || 'Interagir')}</div>`;
            prompt.classList.add('show');
        } else {
            prompt.classList.remove('show');
        }
    }

    // --- Jauge carburant --------------------------------------------------
    function renderGauge(percent) {
        const p = Math.max(0, Math.min(100, Math.round(percent || 0)));
        gaugeRoot.innerHTML = `
            <div class="fg-head">
                <span class="fg-title"><span class="fg-icon">⛽</span> Carburant</span>
                <span class="fg-pct">${p}%</span>
            </div>
            <div class="fg-bar"><div class="fg-fill" style="width:${p}%"></div></div>`;
    }

    function showGauge(d) {
        gaugeRoot.classList.remove('hidden', 'hide');
        renderGauge(d.percent);
    }
    function updateGauge(d) {
        if (gaugeRoot.classList.contains('hidden')) showGauge(d);
        const fill = gaugeRoot.querySelector('.fg-fill');
        const pct = gaugeRoot.querySelector('.fg-pct');
        const p = Math.max(0, Math.min(100, Math.round(d.percent || 0)));
        if (fill) fill.style.width = p + '%';
        if (pct) pct.textContent = p + '%';
    }
    function hideGauge() {
        gaugeRoot.classList.add('hide');
        setTimeout(() => gaugeRoot.classList.add('hidden'), 250);
    }

    Noxa.on('world', 'prompt', setPrompt);
    Noxa.on('fuel', 'show', showGauge);
    Noxa.on('fuel', 'update', updateGauge);
    Noxa.on('fuel', 'hide', hideGauge);

    return {};
})();
window.NoxaWorld = NoxaWorld;
