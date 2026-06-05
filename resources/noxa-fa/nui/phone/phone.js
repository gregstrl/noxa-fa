/* =====================================================================
   NOXA FA — Smartphone NUI custom (OPTION C : style « iOS premium »)
   Visuel calqué sur le design de référence (nui/phone/index.html), mais
   100% alimenté par les VRAIES données FiveM. Contrat inchangé :

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
    let clockTimer = null;

    // Apps (vraies données) — accent par app (back, bouton envoyer, carte solde).
    const APPS = [
        { id: 'contacts', name: 'Contacts', glyph: 'user',  color: '#30b0c7' },
        { id: 'sms',      name: 'Messages', glyph: 'chat',  color: '#34c759' },
        { id: 'bank',     name: 'Banque',   glyph: 'money', color: '#2f6fe0' },
        { id: 'twitter',  name: 'Canari',   glyph: 'hash',  color: '#2aa8ee' },
        { id: 'map',      name: 'Carte',    glyph: 'pin',   color: '#f0a020' },
        { id: 'settings', name: 'Réglages', glyph: 'gear',  color: '#8e8e93' },
    ];
    const DOCK = ['contacts', 'sms', 'bank', 'settings'];

    // Glyphes SVG (tracés repris du design de référence Claude Design).
    const G = {
        user:    'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8M4.5 20a7.5 7.5 0 0 1 15 0',
        chat:    'M21 11.5a8 8 0 0 1-11.6 7.1L4 20l1.4-5.4A8 8 0 1 1 21 11.5z',
        money:   'M12 2v20M16.5 6H9.8a3.2 3.2 0 0 0 0 6.4h4.4a3.2 3.2 0 0 1 0 6.4H7',
        hash:    'M9.5 3 7.5 21M16.5 3l-2 18M4 8.5h16M3.5 15.5h16',
        pin:     'M12 21s7-6 7-11a7 7 0 1 0-14 0c0 5 7 11 7 11zM12 11.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5',
        gear:    'M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7M19.4 13a7.8 7.8 0 0 0 0-2l2-1.5-2-3.4-2.3 1a7.6 7.6 0 0 0-1.7-1l-.3-2.6h-4l-.3 2.6a7.6 7.6 0 0 0-1.7 1l-2.3-1-2 3.4 2 1.5a7.8 7.8 0 0 0 0 2l-2 1.5 2 3.4 2.3-1a7.6 7.6 0 0 0 1.7 1l.3 2.6h4l.3-2.6a7.6 7.6 0 0 0 1.7-1l2.3 1 2-3.4z',
        chevL:   'M15 5l-7 7 7 7',
        chevR:   'M9 5l7 7-7 7',
        plus:    'M12 5v14M5 12h14',
        pen:     'M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z',
        send:    'M4 12l16-8-6 16-3-7z',
        trash:   'M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13',
        card:    'M3 6h18v12H3zM3 10h18',
        info:    'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18M12 11v5M12 8h.01',
        power:   'M12 4v8M7.5 7.5a7 7 0 1 0 9 0',
    };
    function svg(name) {
        return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round"><path d="${G[name] || ''}"/></svg>`;
    }
    function appDef(id) { return APPS.find((a) => a.id === id); }

    function now() { const d = new Date(); return ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2); }

    // --- Cycle de vie -----------------------------------------------------
    function show() {
        open = true; app = null; thread = null;
        root.classList.remove('closing'); root.classList.add('open');
        render();
        clearInterval(clockTimer);
        clockTimer = setInterval(() => { const c = root.querySelector('.ph-time'); if (c) c.textContent = now(); }, 15000);
    }
    function close() {
        if (!open) return;
        open = false;
        clearInterval(clockTimer); clockTimer = null;
        root.classList.add('closing');
        setTimeout(() => { root.classList.remove('open', 'closing'); root.innerHTML = ''; }, 240);
    }
    function bootstrap(d) {
        st = Object.assign(st, d);
        st.contacts = d.contacts || []; st.convos = d.convos || []; st.tweets = d.tweets || [];
        if (open) render();
    }
    function sync(d) { st.bank = d.bank ?? st.bank; st.cash = d.cash ?? st.cash; if (open && app === 'bank') render(); }

    // --- Routeur de rendu -------------------------------------------------
    function render() {
        const accent = app ? (appDef(app)?.color || '#2f6fe0') : '#2f6fe0';
        const body = app === null ? homeScreen() : appView(app);
        root.innerHTML = `
            <div class="ph-device">
                <span class="ph-power-btn" data-power title="Verrouiller"></span>
                <div class="ph-screen" style="--ph-accent:${accent}">
                    <div class="ph-island"></div>
                    <div class="ph-statusbar">
                        <span class="ph-time">${now()}</span>
                        <span class="ph-sb-right">
                            <svg width="18" height="13" viewBox="0 0 18 13" fill="currentColor"><rect x="0" y="9" width="3" height="4" rx="1"/><rect x="5" y="6" width="3" height="7" rx="1"/><rect x="10" y="3" width="3" height="10" rx="1"/><rect x="15" y="0" width="3" height="13" rx="1"/></svg>
                            <span class="ph-battery"><i></i></span>
                        </span>
                    </div>
                    <div class="ph-viewport">${body}</div>
                    <div class="ph-home-ind" data-home><i></i></div>
                </div>
            </div>`;
        bind();
    }

    function appIcon(id) {
        const a = appDef(id);
        if (!a) return '';
        const badge = id === 'sms' && st.convos.length ? `<span class="ph-badge">${st.convos.length}</span>` : '';
        return `<div class="ph-app-ic" data-app="${a.id}">
            <div class="ph-icon" style="background:${a.color}">${svg(a.glyph)}${badge}</div>
            <div class="ph-app-label">${a.name}</div>
        </div>`;
    }

    function homeScreen() {
        const grid = APPS.map((a) => appIcon(a.id)).join('');
        const dock = DOCK.map((id) => appIcon(id)).join('');
        return `<div class="ph-home">
            <div class="ph-greet">
                <div class="ph-g-num">${Noxa.esc(st.number)}</div>
                <div class="ph-g-owner">${Noxa.esc(st.owner || 'Téléphone Noxa')}</div>
            </div>
            <div class="ph-grid">${grid}</div>
            <div class="ph-dock">${dock}</div>
        </div>`;
    }

    function header(title, actionGlyph) {
        return `<div class="ph-app-top">
            <button class="ph-back" data-back>${svg('chevL')}<span>Accueil</span></button>
            <h2>${Noxa.esc(title)}</h2>
            ${actionGlyph ? `<button class="ph-t-action" data-action>${svg(actionGlyph)}</button>` : '<span style="width:22px"></span>'}
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

    function emptyState(glyph, text) {
        return `<div class="ph-empty">${svg(glyph)}${text}</div>`;
    }

    // --- Contacts ---------------------------------------------------------
    function contactsView() {
        const body = st.contacts.length ? `<div class="ph-card">${st.contacts.map((c) => `
            <div class="ph-li" data-sms="${Noxa.esc(c.number)}">
                <div class="ph-av">${Noxa.esc((c.name || '?')[0].toUpperCase())}</div>
                <div class="ph-main"><b>${Noxa.esc(c.name)}</b><span>${Noxa.esc(c.number)}</span></div>
                <div class="ph-del" data-del="${c.id}">${svg('trash')}</div>
            </div>`).join('')}</div>`
            : emptyState('user', 'Aucun contact.<br>Touchez + pour en ajouter.');
        return `<div class="ph-appwrap">${header('Contacts', 'plus')}<div class="ph-app-body">${body}</div></div>`;
    }

    // --- Messages ---------------------------------------------------------
    function smsView() {
        const body = st.convos.length ? `<div class="ph-card">${st.convos.map((c) => {
            const name = contactName(c.peer);
            return `<div class="ph-li" data-thread="${Noxa.esc(c.peer)}">
                <div class="ph-av">${Noxa.esc(name[0].toUpperCase())}</div>
                <div class="ph-main"><b>${Noxa.esc(name)}</b><span>${Noxa.esc(c.peer)}</span></div>
                <div class="ph-chev">${svg('chevR')}</div>
            </div>`;
        }).join('')}</div>` : emptyState('chat', 'Aucune conversation.<br>Touchez ✎ pour écrire.');
        return `<div class="ph-appwrap">${header('Messages', 'pen')}<div class="ph-app-body">${body}</div></div>`;
    }

    function threadView() {
        const myNum = st.number;
        const msgs = (thread.messages || []).map((m) => {
            const out = m.from_num === myNum;
            return `<div class="ph-bub ${out ? 'me' : 'them'}">${Noxa.esc(m.body)}</div>`;
        }).join('');
        return `<div class="ph-appwrap">
            ${header(contactName(thread.peer), '')}
            <div class="ph-app-body"><div class="ph-bubbles">${msgs || emptyState('chat', 'Démarrez la conversation.')}</div></div>
            <div class="ph-composer">
                <input class="ph-inp" id="ph-msg" placeholder="Message…" maxlength="255" />
                <button class="ph-send" id="ph-send">${svg('send')}</button>
            </div></div>`;
    }

    // --- Banque -----------------------------------------------------------
    function bankView() {
        return `<div class="ph-appwrap">${header('Banque', '')}<div class="ph-app-body">
            <div class="ph-balance">
                <div class="ph-lab">Solde du compte</div>
                <div class="ph-amt">${Noxa.money(st.bank)}</div>
                <div class="ph-sub"><span>💵 Espèces</span><span>${Noxa.money(st.cash)}</span></div>
            </div>
            <div class="ph-sect">Virement rapide</div>
            <div class="ph-form">
                <input class="ph-inp" id="ph-tr-cid" placeholder="ID citoyen (NX…)" maxlength="12" />
                <input class="ph-inp" id="ph-tr-amt" type="number" min="1" placeholder="Montant" />
                <button class="ph-btn" id="ph-tr-send">Envoyer</button>
            </div></div></div>`;
    }

    // --- Canari (réseau social / tweets) ---------------------------------
    function twitterView() {
        const feed = st.tweets.length ? st.tweets.map((t) => {
            const author = String(t.author || '?');
            return `<div class="ph-post">
                <div class="ph-av">${Noxa.esc(author[0].toUpperCase())}</div>
                <div class="ph-pb">
                    <div><b>${Noxa.esc(author)}</b><span class="ph-h">· ${Noxa.esc(String(t.created_at || ''))}</span></div>
                    <div class="ph-pt">${Noxa.esc(t.body)}</div>
                </div></div>`;
        }).join('') : emptyState('hash', 'Aucun post.<br>Touchez ✎ pour publier.');
        return `<div class="ph-appwrap">${header('Canari', 'pen')}<div class="ph-app-body" id="ph-tw-feed">${feed}</div></div>`;
    }

    // --- Carte (points d'intérêt) ----------------------------------------
    function mapView() {
        const poi = [
            ['🏦', 'Banques', 'Centre-ville & comtés'],
            ['⛽', 'Stations essence', '10 emplacements'],
            ['🛒', 'Épiceries 24/7', 'Ravitaillement'],
            ['🏥', 'Hôpitaux', "Soins d'urgence"],
            ['🚓', 'Commissariats', "Forces de l'ordre"],
            ['🎣', 'Pêche · Bûcheronnage', 'Activités civiles'],
        ];
        return `<div class="ph-appwrap">${header('Carte', '')}<div class="ph-app-body">
            <div class="ph-sect">Points d'intérêt</div>
            <div class="ph-card">${poi.map((p) => `
                <div class="ph-li">
                    <div class="ph-av" style="background:rgba(255,255,255,.12);font-size:18px">${p[0]}</div>
                    <div class="ph-main"><b>${p[1]}</b><span>${p[2]}</span></div>
                </div>`).join('')}</div>
            <p style="opacity:.45;font-size:12.5px;text-align:center;margin-top:14px">Ouvre la carte du jeu (Échap → Carte) pour les repères live.</p>
        </div></div>`;
    }

    // --- Réglages ---------------------------------------------------------
    function settingsView() {
        return `<div class="ph-appwrap">${header('Réglages', '')}<div class="ph-app-body">
            <div class="ph-sect">Appareil</div>
            <div class="ph-card">
                <div class="ph-set-row"><div class="ph-set-ic" style="background:#2f6fe0">${svg('card')}</div><div class="ph-set-lbl">Mon numéro</div><div class="ph-set-val">${Noxa.esc(st.number)}</div></div>
                <div class="ph-set-row"><div class="ph-set-ic" style="background:#30b0c7">${svg('user')}</div><div class="ph-set-lbl">Propriétaire</div><div class="ph-set-val">${Noxa.esc(st.owner || '—')}</div></div>
                <div class="ph-set-row"><div class="ph-set-ic" style="background:#8e8e93">${svg('info')}</div><div class="ph-set-lbl">À propos</div><div class="ph-set-val">Noxa Phone</div></div>
            </div>
            <div class="ph-form">
                <button class="ph-btn" id="ph-power" style="background:#ff3b30">Verrouiller l'écran</button>
            </div>
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

    function goBack() {
        if (thread) { thread = null; render(); }
        else { app = null; render(); }
    }

    // --- Liaisons d'événements -------------------------------------------
    function bind() {
        root.querySelectorAll('[data-app]').forEach((el) =>
            el.addEventListener('click', () => openApp(el.getAttribute('data-app'))));

        const back = root.querySelector('[data-back]');
        if (back) back.addEventListener('click', goBack);

        // Bouton « home » (geste iOS) : remonte d'un niveau, ou ferme si à l'accueil.
        const home = root.querySelector('[data-home]');
        if (home) home.addEventListener('click', () => { if (app !== null) goBack(); else doClose(); });

        // Bouton power latéral : verrouille (ferme) le téléphone.
        const power = root.querySelector('[data-power]');
        if (power) power.addEventListener('click', doClose);

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
            const fire = () => { const v = input.value.trim(); if (v && thread) { Noxa.post('phoneSmsSend', { to: thread.peer, body: v }); input.value = ''; } };
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
        const pw = root.querySelector('#ph-power');
        if (pw) pw.addEventListener('click', doClose);
    }

    function doClose() { close(); Noxa.post('phoneClose', {}); }

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
            NoxaMenu.inputLocal({ title: 'Nouveau post Canari', fields: [
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

    function handleEscape() { if (!open) return false; doClose(); return true; }

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
