/* =====================================================================
   NOXA FA — Smartphone NUI custom
   Messages Lua -> NUI (app:'phone') :
     open · close · bootstrap{number,owner,contacts,convos,tweets,bank,cash}
     contacts{list} · smsIncoming{from,body} · smsSent{to,body}
     smsThread{peer,messages} · tweets{list} · tweetNew{author,body,created_at}
     sync{bank,cash}
   Callbacks NUI -> Lua : phoneClose, phoneContactAdd, phoneContactDelete,
     phoneSmsSend, phoneSmsThread, phoneTweetPost, phoneTweetsList,
     phoneBankTransfer
   ===================================================================== */

const NoxaPhone = (() => {
    const root = document.getElementById('phone');
    let st = { number: '—', owner: '', contacts: [], convos: [], tweets: [], bank: 0, cash: 0 };
    let app = null;          // app courante (null = accueil)
    let thread = null;       // { peer, messages }
    let open = false;

    const APPS = [
        { id: 'contacts', name: 'Contacts', ic: 'ic-contacts', emoji: '👤' },
        { id: 'sms',      name: 'Messages', ic: 'ic-sms',      emoji: '💬' },
        { id: 'bank',     name: 'Banque',   ic: 'ic-bank',     emoji: '🏦' },
        { id: 'twitter',  name: 'Twitter',  ic: 'ic-twitter',  emoji: '🐦' },
        { id: 'map',      name: 'Carte',    ic: 'ic-map',      emoji: '🗺️' },
        { id: 'settings', name: 'Réglages', ic: 'ic-settings', emoji: '⚙️' },
    ];

    function now() { const d = new Date(); return ('0'+d.getHours()).slice(-2)+':'+('0'+d.getMinutes()).slice(-2); }

    // --- Cycle de vie -----------------------------------------------------
    function show() { open = true; app = null; thread = null; root.classList.remove('closing'); root.classList.add('open'); render(); }
    function close() {
        if (!open) return;
        open = false;
        root.classList.add('closing');
        setTimeout(() => { root.classList.remove('open', 'closing'); root.innerHTML = ''; }, 260);
    }
    function bootstrap(d) {
        st = Object.assign(st, d);
        st.contacts = d.contacts || []; st.convos = d.convos || []; st.tweets = d.tweets || [];
        if (open) render();
    }
    function sync(d) { st.bank = d.bank ?? st.bank; st.cash = d.cash ?? st.cash; if (open && app === 'bank') render(); }

    // --- Routeur de rendu -------------------------------------------------
    function render() {
        let body;
        if (app === null) body = homeScreen();
        else body = appView(app);
        root.innerHTML = `
            <div class="ph-device"><div class="ph-screen">
                <div class="ph-notch"></div>
                <div class="ph-status"><span>${now()}</span><span class="ph-sig">📶 ${Noxa.esc(st.number)}</span><span>100% 🔋</span></div>
                ${body}
            </div></div>`;
        bind();
    }

    function homeScreen() {
        return `<div class="ph-home">
            <div class="ph-clock">
                <div class="ph-clock-time">${now()}</div>
                <div class="ph-clock-num">${Noxa.esc(st.owner || '')} · ${Noxa.esc(st.number)}</div>
            </div>
            <div class="ph-grid">
                ${APPS.map((a) => `
                    <div class="ph-app" data-app="${a.id}">
                        <div class="ph-app-ic ${a.ic}">${a.emoji}</div>
                        <div class="ph-app-name">${a.name}</div>
                    </div>`).join('')}
            </div></div>`;
    }

    function header(title, actionIcon) {
        return `<div class="ph-app-head">
            <div class="ph-back" data-back>‹</div>
            <div class="ph-app-title">${Noxa.esc(title)}</div>
            ${actionIcon ? `<div class="ph-app-action" data-action>${actionIcon}</div>` : ''}
        </div>`;
    }

    function appView(id) {
        if (id === 'contacts') return contactsView();
        if (id === 'sms')      return thread ? threadView() : smsView();
        if (id === 'bank')     return bankView();
        if (id === 'twitter')  return twitterView();
        if (id === 'map')      return mapView();
        if (id === 'settings') return settingsView();
        return '';
    }

    // --- Contacts ---------------------------------------------------------
    function contactsView() {
        const rows = st.contacts.length ? st.contacts.map((c) => `
            <div class="ph-row">
                <div class="ph-avatar">${Noxa.esc((c.name||'?')[0].toUpperCase())}</div>
                <div class="ph-row-info" data-sms="${Noxa.esc(c.number)}">
                    <div class="ph-row-name">${Noxa.esc(c.name)}</div>
                    <div class="ph-row-sub">${Noxa.esc(c.number)}</div>
                </div>
                <div class="ph-row-del" data-del="${c.id}">🗑</div>
            </div>`).join('')
            : `<div class="ph-empty"><span class="ph-empty-ic">👤</span>Aucun contact.<br>Touchez + pour en ajouter.</div>`;
        return `<div class="ph-app-view">${header('Contacts', '＋')}<div class="ph-app-body">${rows}</div></div>`;
    }

    // --- Messages ---------------------------------------------------------
    function smsView() {
        const rows = st.convos.length ? st.convos.map((c) => {
            const name = contactName(c.peer);
            return `<div class="ph-row" data-thread="${Noxa.esc(c.peer)}">
                <div class="ph-avatar">${Noxa.esc(name[0].toUpperCase())}</div>
                <div class="ph-row-info">
                    <div class="ph-row-name">${Noxa.esc(name)}</div>
                    <div class="ph-row-sub">${Noxa.esc(c.peer)}</div>
                </div></div>`;
        }).join('') : `<div class="ph-empty"><span class="ph-empty-ic">💬</span>Aucune conversation.</div>`;
        return `<div class="ph-app-view">${header('Messages', '✎')}<div class="ph-app-body">${rows}</div></div>`;
    }

    function threadView() {
        const myNum = st.number;
        const msgs = (thread.messages || []).map((m) => {
            const out = m.from_num === myNum;
            return `<div class="ph-bubble ${out ? 'out' : 'in'}">${Noxa.esc(m.body)}</div>`;
        }).join('');
        return `<div class="ph-app-view">
            ${header(contactName(thread.peer), '')}
            <div class="ph-app-body"><div class="ph-msgs">${msgs || '<div class="ph-empty">Démarrez la conversation.</div>'}</div></div>
            <div class="ph-composer">
                <input class="field-input" id="ph-msg" placeholder="Message…" maxlength="255" />
                <button class="btn btn-primary" id="ph-send">➤</button>
            </div></div>`;
    }

    // --- Banque -----------------------------------------------------------
    function bankView() {
        return `<div class="ph-app-view">${header('Banque', '')}<div class="ph-app-body">
            <div class="ph-bank-card">
                <div class="ph-bank-label">Solde du compte</div>
                <div class="ph-bank-val">${Noxa.money(st.bank)}</div>
                <div class="ph-bank-cash">💵 Espèces : ${Noxa.money(st.cash)}</div>
            </div>
            <div class="ph-form">
                <div class="ph-block-title">Virement rapide</div>
                <input class="field-input" id="ph-tr-cid" placeholder="ID citoyen (NX…)" maxlength="12" />
                <input class="field-input" id="ph-tr-amt" type="number" min="1" placeholder="Montant" />
                <button class="btn btn-primary" id="ph-tr-send">Envoyer</button>
            </div></div></div>`;
    }

    // --- Twitter ----------------------------------------------------------
    function twitterView() {
        const feed = st.tweets.length ? st.tweets.map((t) => `
            <div class="ph-tweet">
                <div class="ph-tweet-head"><span class="ph-tweet-author">${Noxa.esc(t.author)}</span>
                    <span class="ph-tweet-time">${Noxa.esc(String(t.created_at||''))}</span></div>
                <div class="ph-tweet-body">${Noxa.esc(t.body)}</div>
            </div>`).join('') : `<div class="ph-empty"><span class="ph-empty-ic">🐦</span>Aucun tweet.</div>`;
        return `<div class="ph-app-view">${header('Twitter', '✎')}<div class="ph-app-body">
            <div id="ph-tw-feed">${feed}</div></div></div>`;
    }

    // --- Carte (destinations clés) ---------------------------------------
    function mapView() {
        const poi = [
            ['🏦 Banques', 'Centre-ville & comtés'],
            ['⛽ Stations essence', '10 emplacements'],
            ['🛒 Épiceries 24/7', 'Ravitaillement'],
            ['🏥 Hôpitaux', 'Soins d\'urgence'],
            ['🚓 Commissariats', 'Forces de l\'ordre'],
            ['🎣 Pêche · 🪓 Chasse', 'Activités civiles'],
        ];
        return `<div class="ph-app-view">${header('Carte', '')}<div class="ph-app-body">
            <div class="ph-block"><div class="ph-block-title">Points d\'intérêt</div>
            <div class="ph-block-sub">Ouvre la carte du jeu (Échap → Carte) pour les repères.</div></div>
            ${poi.map((p) => `<div class="ph-poi"><b>${p[0]}</b><span>${p[1]}</span></div>`).join('')}
        </div></div>`;
    }

    // --- Réglages ---------------------------------------------------------
    function settingsView() {
        return `<div class="ph-app-view">${header('Réglages', '')}<div class="ph-app-body">
            <div class="ph-block"><div class="ph-block-title">Mon numéro</div><div class="ph-block-sub">${Noxa.esc(st.number)}</div></div>
            <div class="ph-block"><div class="ph-block-title">Propriétaire</div><div class="ph-block-sub">${Noxa.esc(st.owner||'')}</div></div>
            <div class="ph-block"><div class="ph-block-title">À propos</div><div class="ph-block-sub">Noxa Phone · NUI 100% custom</div></div>
            <button class="btn btn-ghost" id="ph-power" style="width:100%">Éteindre l\'écran</button>
        </div></div>`;
    }

    // --- Helpers ----------------------------------------------------------
    function contactName(number) {
        const c = st.contacts.find((x) => x.number === number);
        return c ? c.name : number;
    }

    function openApp(id) {
        app = id; thread = null;
        if (id === 'twitter') Noxa.post('phoneTweetsList', {});
        render();
    }

    // --- Liaisons d'événements -------------------------------------------
    function bind() {
        root.querySelectorAll('[data-app]').forEach((el) =>
            el.addEventListener('click', () => openApp(el.getAttribute('data-app'))));
        const back = root.querySelector('[data-back]');
        if (back) back.addEventListener('click', () => { if (thread) { thread = null; render(); } else { app = null; render(); } });

        // Action contextuelle (+ / ✎ selon l'app)
        const action = root.querySelector('[data-action]');
        if (action) action.addEventListener('click', onAction);

        // Contacts
        root.querySelectorAll('[data-del]').forEach((el) =>
            el.addEventListener('click', (e) => { e.stopPropagation(); Noxa.post('phoneContactDelete', { id: Number(el.getAttribute('data-del')) }); }));
        root.querySelectorAll('[data-sms]').forEach((el) =>
            el.addEventListener('click', () => { app = 'sms'; openThread(el.getAttribute('data-sms')); }));

        // Conversations
        root.querySelectorAll('[data-thread]').forEach((el) =>
            el.addEventListener('click', () => openThread(el.getAttribute('data-thread'))));

        // Composer SMS
        const send = root.querySelector('#ph-send');
        if (send) {
            const input = root.querySelector('#ph-msg');
            const fire = () => { const v = input.value.trim(); if (v && thread) { Noxa.post('phoneSmsSend', { to: thread.peer, body: v }); input.value=''; } };
            send.addEventListener('click', fire);
            input.addEventListener('keydown', (e) => { if (e.key === 'Enter') fire(); });
        }

        // Banque
        const tr = root.querySelector('#ph-tr-send');
        if (tr) tr.addEventListener('click', () => {
            const cid = root.querySelector('#ph-tr-cid').value.trim();
            const amt = Number(root.querySelector('#ph-tr-amt').value);
            if (cid && amt > 0) Noxa.post('phoneBankTransfer', { target: cid, amount: amt });
        });

        // Réglages
        const power = root.querySelector('#ph-power');
        if (power) power.addEventListener('click', () => { close(); Noxa.post('phoneClose', {}); });
    }

    function onAction() {
        if (app === 'contacts') {
            NoxaMenu.inputLocal({ title: 'Nouveau contact', fields: [
                { name: 'name', label: 'Nom', required: true },
                { name: 'number', label: 'Numéro', required: true },
            ] }).then((v) => { if (v) Noxa.post('phoneContactAdd', { name: v.name, number: v.number }); });
        } else if (app === 'sms') {
            NoxaMenu.inputLocal({ title: 'Nouveau message', fields: [
                { name: 'number', label: 'Numéro', required: true },
            ] }).then((v) => { if (v) openThread(v.number); });
        } else if (app === 'twitter') {
            NoxaMenu.inputLocal({ title: 'Nouveau tweet', fields: [
                { name: 'body', label: 'Quoi de neuf ?', required: true },
            ] }).then((v) => { if (v) Noxa.post('phoneTweetPost', { body: v.body }); });
        }
    }

    function openThread(peer) {
        thread = { peer, messages: [] };
        Noxa.post('phoneSmsThread', { peer });
        render();
    }

    // --- Réceptions serveur ----------------------------------------------
    function setContacts(d) { st.contacts = d.list || []; if (open && app === 'contacts') render(); }
    function smsThreadData(d) { if (thread && d.peer === thread.peer) { thread.messages = d.messages || []; if (open) render(); } }
    function smsIncoming(m) {
        if (thread && thread.peer === m.from) { thread.messages.push({ from_num: m.from, body: m.body }); if (open) render(); }
    }
    function smsSent(m) {
        if (thread && thread.peer === m.to) { thread.messages.push({ from_num: st.number, body: m.body }); if (open) render(); }
    }
    function setTweets(d) { st.tweets = d.list || []; if (open && app === 'twitter') render(); }
    function tweetNew(t) { st.tweets.unshift(t); if (open && app === 'twitter') render(); }

    function handleEscape() { if (!open) return false; close(); Noxa.post('phoneClose', {}); return true; }

    Noxa.on('phone', 'open', show);
    Noxa.on('phone', 'close', close);
    Noxa.on('phone', 'bootstrap', bootstrap);
    Noxa.on('phone', 'sync', sync);
    Noxa.on('phone', 'contacts', setContacts);
    Noxa.on('phone', 'smsThread', smsThreadData);
    Noxa.on('phone', 'smsIncoming', smsIncoming);
    Noxa.on('phone', 'smsSent', smsSent);
    Noxa.on('phone', 'tweets', setTweets);
    Noxa.on('phone', 'tweetNew', tweetNew);

    return { handleEscape };
})();
window.NoxaPhone = NoxaPhone;
