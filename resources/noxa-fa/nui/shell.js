/* =====================================================================
   NOXA FA — Routeur NUI & helpers (chargé avant tous les modules)
   • Centralise la réception des messages Lua -> NUI (window 'message').
   • Dispatch vers le module concerné via Noxa.on(app, handler).
   • Fournit Noxa.post() : appel sécurisé d'un callback NUI -> Lua.
   • Gère la touche Échap globale (fermeture de la couche active).
   ===================================================================== */

const Noxa = (() => {
    const handlers = {};           // { app: { action: fn } }
    let resourceName = 'noxa-core';

    // Récupère le nom de ressource parent (fourni par CEF FiveM).
    if (typeof GetParentResourceName === 'function') {
        try { resourceName = GetParentResourceName(); } catch (_) {}
    }

    /** Enregistre un handler pour un module + une action. */
    function on(app, action, fn) {
        (handlers[app] ||= {})[action] = fn;
    }

    /** Appel d'un callback NUI -> Lua (POST JSON). Retourne la réponse JSON. */
    async function post(name, data = {}) {
        try {
            const res = await fetch(`https://${resourceName}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            });
            return await res.json().catch(() => ({}));
        } catch (_) {
            return {};
        }
    }

    // Réception centralisée des messages Lua -> NUI.
    window.addEventListener('message', (event) => {
        const msg = event.data || {};
        const app = msg.app;
        if (!app || !handlers[app]) return;
        const fn = handlers[app][msg.action];
        if (fn) fn(msg.data || {});
    });

    // Échap : ferme la couche modale active (priorité décroissante).
    window.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        // Priorité décroissante par couche z-index (admin z60 > jobs z50 > …).
        if (window.NoxaAdmin && NoxaAdmin.handleEscape()) return;
        if (window.NoxaJobs && NoxaJobs.handleEscape()) return;
        if (window.NoxaMenu && NoxaMenu.handleEscape()) return;
        if (window.NoxaBanking && NoxaBanking.handleEscape()) return;
        if (window.NoxaShop && NoxaShop.handleEscape()) return;
        if (window.NoxaInv && NoxaInv.handleEscape()) return;
        if (window.NoxaVeh && NoxaVeh.handleEscape()) return;
        if (window.NoxaPhone && NoxaPhone.handleEscape()) return;
        // (la sélection de personnage ne se ferme pas à l'Échap : phase obligatoire)
    });

    /** Formate un montant en monnaie lisible (« 12 500 $ »). */
    function money(n) {
        n = Math.floor(Number(n) || 0);
        return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' $';
    }

    /** Échappe le HTML pour toute donnée d'origine joueur (anti-injection NUI). */
    function esc(s) {
        return String(s ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    }

    return { on, post, money, esc, resourceName };
})();
