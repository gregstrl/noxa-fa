/* =====================================================================
   NOXA FA — Boutique (épicerie) — interface NUI custom
   Messages Lua -> NUI (app:'shop') :
     • 'open' data:{ shop, label, items:[{id,label,price,emoji,hunger,thirst}], cash }
     • 'sync' data:{ cash }
     • 'close'
   Callbacks NUI -> Lua : shopBuy {shop, item}, shopClose
   N'émet que des intentions : le serveur valide prix + effets.
   ===================================================================== */

const NoxaShop = (() => {
    const root = document.getElementById('shop');
    let state = { shop: '', label: '', items: [], cash: 0 };
    let open = false;

    function show(d) {
        state = Object.assign({ items: [], cash: 0 }, d);
        open = true;
        root.classList.remove('hidden');
        Noxa.post('menuFocus', { focus: true });
        render();
    }

    function close() {
        if (!open) return;
        open = false;
        root.classList.add('hidden');
        root.innerHTML = '';
        Noxa.post('shopClose', {});
    }

    function sync(d) {
        state.cash = d.cash ?? state.cash;
        const el = root.querySelector('.shop-cash');
        if (el) el.textContent = '💵 ' + Noxa.money(state.cash);
    }

    function effects(it) {
        const out = [];
        if (it.hunger) out.push(`<span>🍔 +${it.hunger}</span>`);
        if (it.thirst) out.push(`<span>💧 +${it.thirst}</span>`);
        return out.join('');
    }

    function render() {
        root.innerHTML = `
            <div class="shop-panel">
                <div class="shop-head">
                    <div class="shop-title">${Noxa.esc(state.label || 'Boutique')}<small>Paiement en espèces</small></div>
                    <div class="shop-cash">💵 ${Noxa.money(state.cash)}</div>
                </div>
                <div class="shop-grid">
                    ${state.items.map((it) => `
                        <div class="shop-item">
                            <div class="shop-item-emoji">${Noxa.esc(it.emoji || '🛒')}</div>
                            <div class="shop-item-info">
                                <div class="shop-item-label">${Noxa.esc(it.label)}</div>
                                <div class="shop-item-effects">${effects(it)}</div>
                            </div>
                            <div>
                                <div class="shop-item-price">${Noxa.money(it.price)}</div>
                                <button class="btn btn-primary shop-item-buy" data-buy="${Noxa.esc(it.id)}">Acheter</button>
                            </div>
                        </div>`).join('')}
                </div>
                <div class="shop-foot"><button class="btn btn-ghost" id="shop-close">Quitter (Échap)</button></div>
            </div>`;

        root.querySelectorAll('[data-buy]').forEach((el) =>
            el.addEventListener('click', () =>
                Noxa.post('shopBuy', { shop: state.shop, item: el.getAttribute('data-buy') })));
        root.querySelector('#shop-close').addEventListener('click', close);
    }

    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('shop', 'open', show);
    Noxa.on('shop', 'sync', sync);
    Noxa.on('shop', 'close', close);

    return { handleEscape };
})();
window.NoxaShop = NoxaShop;
