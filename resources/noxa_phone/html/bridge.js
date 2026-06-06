/* =====================================================================
   NOXA FA — Pont de données du téléphone (design figé)
   ---------------------------------------------------------------------
   Le design (html/index.html) est un export FIGÉ : on n'y touche JAMAIS le
   visuel. Il lit ses données via `const PD = window.PD` (une seule fois) et
   rend chaque vue PARESSEUSEMENT à l'ouverture d'une app. Ce pont :
     1. remplace les données mock de window.PD par les VRAIES données serveur
        (numéro, propriétaire, contacts, conversations, tweets, solde banque) ;
     2. relaie les actions de l'UI (envoi SMS, post Canari) vers le client Lua
        via nuiCallback -> events serveur -> BDD ;
     3. applique les mises à jour live (SMS entrant, nouveau tweet) ;
     4. gère l'ouverture/fermeture (le design est un device flottant toujours
        rendu : on affiche/masque .stage selon F1).

   IMPORTANT : ce script ne modifie ni le markup ni le CSS du design. Il
   s'exécute UNE FOIS depuis l'index figé (avant que le bundler ne remplace le
   document) et installe des écouteurs au niveau `window` + un intervalle, qui
   SURVIVENT au remplacement du document (window est stable). Toute la logique
   opère ensuite sur window.PD (référence partagée avec l'app) et le DOM rendu.
   ===================================================================== */
(function () {
  'use strict';

  var RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'noxa_phone';
  var desiredOpen = false;     // état d'ouverture voulu (piloté par F1 côté Lua)
  var currentPeer = null;      // numéro de la conversation actuellement ouverte
  var pendingTweets = [];      // { body, t } posts envoyés par nous (anti-doublon)
  var queue = [];              // messages reçus avant que window.PD existe

  /* ---- helpers ---- */
  function post(cb, data) {
    try {
      fetch('https://' + RES + '/' + cb, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
      }).catch(function () {});
    } catch (e) {}
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  }
  function initials(name) {
    name = String(name || '?').trim();
    var m = name.match(/(\S)\S*\s+(\S)/);
    if (m) return (m[1] + m[2]).toUpperCase();
    return name.slice(0, 2).toUpperCase();
  }
  function fmtTime(s) {
    if (!s && s !== 0) return '';
    s = String(s);
    var m = s.match(/(\d{1,2}):(\d{2})/);
    if (m) return m[1] + ':' + m[2];
    return s.slice(0, 5);
  }
  function PD() { return window.PD; }
  function contactName(num) {
    var pd = PD(); if (!pd || !pd.contacts) return num;
    var c = pd.contacts.find(function (x) { return x.number === num; });
    return c ? c.name : num;
  }
  function handleFrom(a) { a = String(a || ''); return a.charAt(0) === '@' ? a : '@' + a.replace(/^@/, ''); }

  /* ---- glyphes pour le rendu live d'un post Canari (repris du design) ---- */
  var G = {
    chat: 'M21 11.5a8 8 0 0 1-11.6 7.1L4 20l1.4-5.4A8 8 0 1 1 21 11.5z',
    retweet: 'M4 8l3-3 3 3M7 5v9a2 2 0 0 0 2 2h8M20 16l-3 3-3-3M17 19v-9a2 2 0 0 0-2-2H7',
    heart: 'M12 21C5 16 3 12 3 8.5A4.5 4.5 0 0 1 12 6a4.5 4.5 0 0 1 9 2.5C21 12 19 16 12 21z',
  };
  function svg(d) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'
      + d.split('M').filter(Boolean).map(function (s) { return '<path d="M' + s + '"/>'; }).join('') + '</svg>';
  }
  function postHTML(p) {
    return '<div class="post"><div class="av">' + esc(p.initials) + '</div><div class="pb" style="flex:1">'
      + '<div><b>' + esc(p.user) + '</b> <span class="h">' + esc(p.handle) + ' · ' + esc(p.time) + '</span></div>'
      + '<div class="pt">' + esc(p.text) + '</div>'
      + '<div class="pa"><span>' + svg(G.chat) + (p.rt || 0) + '</span><span>' + svg(G.retweet) + (p.rt || 0)
      + '</span><span>' + svg(G.heart) + (p.likes || 0) + '</span></div></div></div>';
  }

  /* ---- affichage / masquage (device flottant .stage) ---- */
  function stage() { return document.querySelector('.stage'); }
  function applyVisibility() {
    var s = stage(); if (!s) return;
    var want = desiredOpen ? '' : 'none';
    if (s.style.display !== want) s.style.display = want;
  }

  /* ---- mappage données serveur -> forme attendue par window.PD ---- */
  function mapThread(t, myNum) {
    var name = contactName(t.peer) || t.peer;
    return {
      id: t.peer, name: name, initials: initials(name),
      msgs: (t.messages || []).map(function (m) {
        return { me: m.from_num === myNum, text: m.body, time: fmtTime(m.created_at) };
      }),
    };
  }
  function mapTweet(t) {
    return {
      user: t.author, handle: handleFrom(t.author), initials: initials(t.author),
      text: t.body, time: fmtTime(t.created_at) || 'maintenant', likes: 0, rt: 0,
    };
  }

  function applyBootstrap(d) {
    var pd = PD(); if (!pd) return;
    pd.me = pd.me || {};
    if (d.number) pd.me.number = d.number;
    if (d.owner) pd.me.name = d.owner;

    if (Array.isArray(d.contacts)) {
      pd.contacts = d.contacts.map(function (c) {
        return { name: c.name, number: c.number, initials: initials(c.name) };
      });
    }
    if (Array.isArray(d.threads)) {
      var th = d.threads.map(function (t) { return mapThread(t, d.number); });
      // Le design accède à PD.threads[0] sur l'écran de verrouillage : on garantit
      // au moins un fil (message système de bienvenue) pour éviter tout crash si le
      // joueur n'a encore aucune conversation. Aucun visuel modifié.
      if (!th.length) {
        th = [{ id: 'noxa', name: 'NOXA', initials: 'NX',
          msgs: [{ me: false, text: 'Bienvenue sur votre téléphone NOXA.', time: fmtTime(new Date().toTimeString()) }] }];
      }
      pd.threads = th;
    }
    if (Array.isArray(d.tweets)) pd.canari = d.tweets.map(mapTweet);

    pd.bank = pd.bank || {};
    if (typeof d.bank === 'number') pd.bank.bank = d.bank;
    if (typeof d.cash === 'number') pd.bank.cash = d.cash;
    if (Array.isArray(pd.bank.tx)) pd.bank.tx = pd.bank.tx; // inchangé (pas d'historique serveur)
    else pd.bank.tx = pd.bank.tx || [];
  }

  /* ---- réceptions live ---- */
  function setContacts(list) {
    var pd = PD(); if (!pd) return;
    pd.contacts = (list || []).map(function (c) {
      return { name: c.name, number: c.number, initials: initials(c.name) };
    });
  }
  function findThread(peer) {
    var pd = PD(); if (!pd || !pd.threads) return null;
    return pd.threads.find(function (t) { return t.id === peer; }) || null;
  }
  function smsIncoming(msg) {
    var pd = PD(); if (!pd || !msg || !msg.from) return;
    var t = findThread(msg.from);
    var entry = { me: false, text: msg.body, time: 'maintenant' };
    if (t) { t.msgs.push(entry); }
    else {
      var name = contactName(msg.from) || msg.from;
      pd.threads = pd.threads || [];
      pd.threads.unshift({ id: msg.from, name: name, initials: initials(name), msgs: [entry] });
    }
    // Si la conversation est ouverte à l'écran, on ajoute la bulle directement.
    if (currentPeer === msg.from) {
      var box = document.getElementById('bubbles');
      if (box) {
        box.insertAdjacentHTML('beforeend', '<div class="bub them">' + esc(msg.body) + '</div>');
        var body = box.closest('.app-body'); if (body) body.scrollTop = body.scrollHeight;
      }
    }
  }
  function smsThread(d) {
    var pd = PD(); if (!pd || !d || !d.peer) return;
    var t = findThread(d.peer);
    var msgs = (d.messages || []).map(function (m) {
      return { me: m.from_num === (pd.me && pd.me.number), text: m.body, time: fmtTime(m.created_at) };
    });
    if (t) t.msgs = msgs;
    else {
      var name = contactName(d.peer) || d.peer;
      pd.threads = pd.threads || [];
      pd.threads.push({ id: d.peer, name: name, initials: initials(name), msgs: msgs });
    }
    if (currentPeer === d.peer) {
      var box = document.getElementById('bubbles');
      if (box) {
        box.innerHTML = msgs.map(function (m) { return '<div class="bub ' + (m.me ? 'me' : 'them') + '">' + esc(m.text) + '</div>'; }).join('');
        var body = box.closest('.app-body'); if (body) body.scrollTop = body.scrollHeight;
      }
    }
  }
  function setTweets(list) {
    var pd = PD(); if (!pd) return;
    pd.canari = (list || []).map(mapTweet);
    var feed = document.getElementById('feed');
    if (feed) feed.innerHTML = pd.canari.map(postHTML).join('');
  }
  function isOwnPending(body) {
    var now = Date.now();
    for (var i = pendingTweets.length - 1; i >= 0; i--) {
      if (now - pendingTweets[i].t > 8000) { pendingTweets.splice(i, 1); continue; }
      if (pendingTweets[i].body === body) { pendingTweets.splice(i, 1); return true; }
    }
    return false;
  }
  function tweetNew(t) {
    var pd = PD(); if (!pd || !t) return;
    // Nos propres posts ont déjà été affichés de façon optimiste par le design.
    if (isOwnPending(t.body)) return;
    var p = mapTweet(t);
    pd.canari = pd.canari || [];
    pd.canari.unshift(p);
    var feed = document.getElementById('feed');
    if (feed) feed.insertAdjacentHTML('afterbegin', postHTML(p));
  }

  /* ---- actions sortantes (interception en phase capture) ---- */
  function trySendSms() {
    var inp = document.getElementById('msgIn'); if (!inp) return;
    var v = inp.value.trim(); if (!v || !currentPeer) return;
    post('smsSend', { to: currentPeer, body: v });
  }
  function tryPostTweet() {
    var inp = document.getElementById('cariIn'); if (!inp) return;
    var v = inp.value.trim(); if (!v) return;
    pendingTweets.push({ body: v, t: Date.now() });
    post('tweetPost', { body: v });
  }

  window.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.closest) return;
    var th = t.closest('[data-thread]');
    if (th) currentPeer = th.getAttribute('data-thread');
    if (t.closest('#backBtn') || t.closest('.app-ic') || t.closest('#homeInd')) currentPeer = null;
    if (t.closest('#msgSend')) trySendSms();
    if (t.closest('#cariSend')) tryPostTweet();
  }, true);

  window.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter') return;
    var a = document.activeElement;
    if (a && a.id === 'msgIn') trySendSms();
    else if (a && a.id === 'cariIn') tryPostTweet();
  }, true);

  /* ---- messages Lua -> NUI (survivent au remplacement du document) ---- */
  function handle(fn) { if (window.PD) { try { fn(); } catch (e) {} } else { queue.push(fn); } }

  window.addEventListener('message', function (ev) {
    var d = ev.data || {};
    switch (d.action) {
      case 'open':       desiredOpen = true;  applyVisibility(); break;
      case 'close':      desiredOpen = false; applyVisibility(); currentPeer = null; break;
      case 'bootstrap':  handle(function () { applyBootstrap(d.data || {}); }); break;
      case 'contacts':   handle(function () { setContacts(d.list || []); }); break;
      case 'smsIncoming':handle(function () { smsIncoming(d.msg || {}); }); break;
      case 'smsThread':  handle(function () { smsThread(d.data || {}); }); break;
      case 'tweets':     handle(function () { setTweets(d.list || []); }); break;
      case 'tweetNew':   handle(function () { tweetNew(d.tweet || {}); }); break;
      // 'smsSent' : ignoré (le design a déjà affiché la bulle de façon optimiste)
    }
  });

  // Masque l'overlay de déballage du bundle (plein écran opaque) pour ne pas
  // cacher le jeu à la connexion. On ne touche pas au fichier : simple style
  // runtime. Les erreurs (#__bundler_err) restent visibles pour le debug.
  function hideLoader() {
    ['__bundler_thumbnail', '__bundler_loading'].forEach(function (id) {
      var el = document.getElementById(id);
      if (el && el.style.display !== 'none') el.style.display = 'none';
    });
  }

  /* ---- boucle légère : masque par défaut + vide la file dès PD prêt ---- */
  setInterval(function () {
    if (window.PD && queue.length) {
      while (queue.length) { try { queue.shift()(); } catch (e) {} }
    }
    hideLoader();
    applyVisibility();
  }, 60);
})();
