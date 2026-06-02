/* =====================================================================
   NOXA FA — Module Banque (interface plein écran)
   Messages Lua -> NUI (app:'banking') :
     • 'open'     data:{ name, citizenid, cash, bank }
     • 'sync'     data:{ cash, bank }            (mise à jour des soldes)
     • 'invoices' data:{ list:[{id,label,from,amount,date}] }
     • 'close'
   Callbacks NUI -> Lua : bankDeposit, bankWithdraw, bankTransfer,
     bankInvoices (demande la liste), bankInvoicePay, bankInvoiceRefuse, bankClose
   Aucune valeur de solde n'est de confiance : l'affichage suit le serveur.
   ===================================================================== */

const NoxaBanking = (() => {
    const root = document.getElementById('banking');
    let data = { cash: 0, bank: 0, name: '', citizenid: '' };
    let view = 'home';
    let invoices = [];
    let open = false;

    function show(d) {
        data = Object.assign(data, d);
        open = true;
        view = 'home';
        root.classList.remove('hidden');
        Noxa.post('bankFocus', { focus: true });
        render();
    }

    function close() {
        if (!open) return;
        open = false;
        root.classList.add('hidden');
        root.innerHTML = '';
        Noxa.post('bankFocus', { focus: false });
        Noxa.post('bankClose', {});
    }

    function sync(d) {
        data.cash = d.cash ?? data.cash;
        data.bank = d.bank ?? data.bank;
        if (open && view === 'home') render();
    }

    function setInvoices(d) {
        invoices = d.list || [];
        if (open) { view = 'invoices'; render(); }
    }

    function nav(v) { view = v; if (v === 'invoices') Noxa.post('bankInvoices', {}); else render(); }

    function render() {
        root.innerHTML = `
            <div class="bank-app">
                <div class="bank-side">
                    <div class="bank-brand"><span>NOXA</span> BANK</div>
                    <div class="bank-holder">${Noxa.esc(data.name || '')}<br>${Noxa.esc(data.citizenid || '')}</div>
                    <div class="bank-nav">
                        <div class="bank-nav-item ${view === 'home' ? 'active' : ''}" data-nav="home"><span class="bank-nav-ic">🏠</span> Accueil</div>
                        <div class="bank-nav-item ${view === 'transfer' ? 'active' : ''}" data-nav="transfer"><span class="bank-nav-ic">✈</span> Virement</div>
                        <div class="bank-nav-item ${view === 'invoices' ? 'active' : ''}" data-nav="invoices"><span class="bank-nav-ic">🧾</span> Factures</div>
                    </div>
                    <div class="bank-close" id="bank-close">Quitter (Échap)</div>
                </div>
                <div class="bank-main" id="bank-main"></div>
            </div>`;

        const main = root.querySelector('#bank-main');
        if (view === 'home') main.innerHTML = homeView();
        else if (view === 'transfer') main.innerHTML = transferView();
        else if (view === 'invoices') main.innerHTML = invoicesView();

        root.querySelectorAll('[data-nav]').forEach((el) =>
            el.addEventListener('click', () => nav(el.getAttribute('data-nav'))));
        root.querySelector('#bank-close').addEventListener('click', close);
        bindView();
    }

    function homeView() {
        return `
            <div class="bank-balance-card">
                <div class="bank-balance-label">Solde du compte</div>
                <div class="bank-balance-val">${Noxa.money(data.bank)}</div>
                <div class="bank-balance-cash">💵 Espèces en poche : ${Noxa.money(data.cash)}</div>
            </div>
            <div class="bank-section-title">Opérations</div>
            <div class="bank-actions">
                <div class="bank-action" data-act="deposit">
                    <div class="bank-action-ic">↓</div>
                    <div><div class="bank-action-label">Déposer</div><div class="bank-action-desc">Espèces vers banque</div></div>
                </div>
                <div class="bank-action" data-act="withdraw">
                    <div class="bank-action-ic">↑</div>
                    <div><div class="bank-action-label">Retirer</div><div class="bank-action-desc">Banque vers espèces</div></div>
                </div>
            </div>`;
    }

    function transferView() {
        return `
            <div class="bank-section-title">Virement bancaire</div>
            <div class="modal-field"><label class="field-label">ID citoyen destinataire</label>
                <input class="field-input" id="tr-cid" placeholder="NX1A2B3C" maxlength="12" /></div>
            <div class="modal-field"><label class="field-label">Montant</label>
                <input class="field-input" id="tr-amt" type="number" min="1" placeholder="0" /></div>
            <button class="btn btn-primary" id="tr-send" style="width:100%;margin-top:8px">Envoyer le virement</button>`;
    }

    function invoicesView() {
        if (!invoices.length) {
            return `<div class="bank-section-title">Mes factures</div>
                <div class="bank-empty"><div class="bank-empty-ic">🧾</div>Aucune facture en attente.</div>`;
        }
        return `<div class="bank-section-title">Mes factures (${invoices.length})</div>` +
            invoices.map((inv) => `
            <div class="bank-invoice">
                <div class="bank-invoice-ic">🧾</div>
                <div class="bank-invoice-info">
                    <div class="bank-invoice-label">${Noxa.esc(inv.label)}</div>
                    <div class="bank-invoice-from">De ${Noxa.esc(inv.from)} · ${Noxa.esc(inv.date || '')}</div>
                </div>
                <div class="bank-invoice-amount">${Noxa.money(inv.amount)}</div>
                <div class="bank-invoice-btns">
                    <button class="btn btn-primary" data-pay="${inv.id}">Payer</button>
                    <button class="btn btn-danger" data-refuse="${inv.id}">Refuser</button>
                </div>
            </div>`).join('');
    }

    async function askAmount(title, max) {
        const values = await NoxaMenu.inputLocal({
            title,
            fields: [{ name: 'amount', label: 'Montant', type: 'number', min: 1, max, required: true }],
        });
        return values ? Number(values.amount) : null;
    }

    function bindView() {
        root.querySelectorAll('[data-act]').forEach((el) => {
            el.addEventListener('click', async () => {
                const act = el.getAttribute('data-act');
                const amt = await askAmount(act === 'deposit' ? 'Déposer' : 'Retirer');
                if (!amt) return;
                Noxa.post(act === 'deposit' ? 'bankDeposit' : 'bankWithdraw', { amount: Number(amt) });
            });
        });
        const send = root.querySelector('#tr-send');
        if (send) send.addEventListener('click', () => {
            const cid = root.querySelector('#tr-cid').value.trim();
            const amt = Number(root.querySelector('#tr-amt').value);
            if (!cid || !amt || amt < 1) return;
            Noxa.post('bankTransfer', { target: cid, amount: amt });
        });
        root.querySelectorAll('[data-pay]').forEach((el) =>
            el.addEventListener('click', () => Noxa.post('bankInvoicePay', { id: Number(el.getAttribute('data-pay')) })));
        root.querySelectorAll('[data-refuse]').forEach((el) =>
            el.addEventListener('click', () => Noxa.post('bankInvoiceRefuse', { id: Number(el.getAttribute('data-refuse')) })));
    }

    function handleEscape() { if (!open) return false; close(); return true; }

    Noxa.on('banking', 'open', show);
    Noxa.on('banking', 'sync', sync);
    Noxa.on('banking', 'invoices', setInvoices);
    Noxa.on('banking', 'close', close);

    return { handleEscape };
})();
window.NoxaBanking = NoxaBanking;
