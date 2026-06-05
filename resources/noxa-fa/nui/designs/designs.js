/* =====================================================================
   NOXA FA — Hôte des designs autonomes (Claude Design)
   ---------------------------------------------------------------------
   Les panels « Anti-Cheat » et « Gestion serveur » sont des exports
   autonomes (bundle React mono-fichier). On ne peut pas les charger comme
   ui_page (une seule par ressource) : on les héberge dans une <iframe>.

   Branchement SANS toucher au visuel :
     • Les données réelles (poussées par le serveur) sont déposées sur la
       fenêtre PARENTE (window.__noxa<Panel>Data). Un petit pont injecté
       dans le <head> du design lit cette donnée au montage (piège sur
       window.DATA / window.MDATA) et la fusionne avec le mock de secours.
     • L'iframe est (re)chargée à chaque ouverture pour que le montage React
       lise la donnée fraîche (le bundle ne réagit pas après montage).

   Doctrine z-index 60 (overlay staff) — même couche que admin/staff.
   ===================================================================== */

const NoxaDesigns = (() => {
    // Définition des deux panels hébergés.
    const PANELS = {
        anticheat: { hostId: 'design-anticheat', src: 'anticheat/index.html',        dataKey: '__noxaAnticheatData', closeCb: 'designClose' },
        gestion:   { hostId: 'design-gestion',   src: 'gestion-serveur/index.html',   dataKey: '__noxaGestionData',    closeCb: 'designClose' },
    };

    let current = null;   // nom du panel ouvert, ou null

    function hostEl(panel) {
        const def = PANELS[panel];
        return def ? document.getElementById(def.hostId) : null;
    }

    function frameEl(panel) {
        const host = hostEl(panel);
        return host ? host.querySelector('iframe') : null;
    }

    /** Ouvre un panel : dépose la donnée réelle puis (re)charge l'iframe. */
    function open(panel, data) {
        const def = PANELS[panel];
        const host = hostEl(panel);
        const frame = frameEl(panel);
        if (!def || !host || !frame) return;

        // Ferme un éventuel autre design déjà ouvert (jamais deux à la fois).
        if (current && current !== panel) hide(current);

        // Donnée réelle lisible par le pont de l'iframe (même origine nui://).
        window[def.dataKey] = data || null;

        // Rechargement forcé : le bundle lit son global UNE fois au montage.
        // Le paramètre anti-cache garantit un remontage propre à chaque ouverture.
        frame.src = def.src + '?t=' + Date.now();

        host.classList.remove('hidden');
        current = panel;
    }

    /** Masque un panel sans toucher au focus (géré côté Lua). */
    function hide(panel) {
        const host = hostEl(panel);
        const frame = frameEl(panel);
        if (host) host.classList.add('hidden');
        if (frame) frame.removeAttribute('src');   // libère le bundle (mémoire)
        if (PANELS[panel]) window[PANELS[panel].dataKey] = null;
        if (current === panel) current = null;
    }

    /** Fermeture demandée par la NUI (Échap) : notifie Lua pour relâcher le focus. */
    function close(panel) {
        if (!panel || !PANELS[panel]) return;
        hide(panel);
        if (typeof Noxa !== 'undefined') Noxa.post(PANELS[panel].closeCb, { panel });
    }

    // Échap : ferme le design courant en priorité (overlay z60).
    function handleEscape() {
        if (!current) return false;
        close(current);
        return true;
    }

    // --- Branchement sur le routeur NUI (listeners noxa:<panel>:open/close) ---
    if (typeof Noxa !== 'undefined') {
        for (const name of Object.keys(PANELS)) {
            Noxa.on(name, 'open', (d) => open(name, d && d.data ? d.data : d));
            Noxa.on(name, 'close', () => hide(name));
        }
    }

    return { open, hide, close, handleEscape };
})();

window.NoxaDesigns = NoxaDesigns;
