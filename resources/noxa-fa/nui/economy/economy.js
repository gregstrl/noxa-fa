/* =====================================================================
   NOXA FA — Module Économie (flux de transactions)
   Messages Lua -> NUI (app:'economy') :
     • 'tx' data:{ sign:'+'/'-', amount, account:'cash'|'bank',
                   label, cat:'income'|'expense'|'transfer'|'fine'|'neutral' }
   Affiche un toast monétaire éphémère près du HUD argent. 100 % informatif.
   ===================================================================== */

(() => {
    const feed = document.getElementById('economy-feed');
    if (!feed) return;

    const MAX = 5;          // toasts simultanés (les plus anciens sont retirés)
    const TTL = 3800;       // durée d'affichage (ms)

    const ICON = {
        income:   '▲',
        expense:  '▼',
        transfer: '⇄',
        fine:     '⚖',
        neutral:  '•',
    };
    const ACCOUNT = { cash: '$', bank: '🏦' };

    function tx(d) {
        const cat = ICON[d.cat] ? d.cat : 'neutral';
        const sign = d.sign === '+' ? '+' : '−';
        const amount = Math.floor(Number(d.amount) || 0);

        const el = document.createElement('div');
        el.className = `eco-tx ${cat} ${d.sign === '+' ? 'pos' : 'neg'}`;
        el.innerHTML = `
            <div class="eco-tx-ic">${ICON[cat]}</div>
            <div class="eco-tx-body">
                <div class="eco-tx-amt">${sign} ${Noxa.money(amount)}</div>
                <div class="eco-tx-label">${Noxa.esc(d.label || 'Mouvement')}</div>
            </div>
            <div class="eco-tx-acc">${ACCOUNT[d.account] || ''}</div>`;

        feed.prepend(el);
        // Limite la pile : retire les plus anciens au-delà de MAX.
        while (feed.children.length > MAX) feed.lastElementChild.remove();

        // Cycle de vie : entrée -> maintien -> sortie.
        requestAnimationFrame(() => el.classList.add('in'));
        setTimeout(() => {
            el.classList.add('out');
            setTimeout(() => el.remove(), 320);
        }, TTL);
    }

    Noxa.on('economy', 'tx', tx);
})();
