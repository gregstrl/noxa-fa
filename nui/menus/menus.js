/* =====================================================================
   NOXA FA — Module Menus / Dialogues / Confirmations (custom)
   API (messages Lua -> NUI), tous sous app:'menu' :
     • action 'context' : menu d'options       -> callback 'menuSelect' {id, option}
     • action 'input'   : formulaire de saisie -> callback 'menuInput'  {id, values|cancelled}
     • action 'confirm' : oui/non              -> callback 'menuConfirm'{id, confirmed}
     • action 'close'   : fermeture forcée
   Une seule modale active à la fois (la couche se vide à chaque ouverture).
   ===================================================================== */

const NoxaMenu = (() => {
    const layer = document.getElementById('menu-layer');
    let active = null;   // { type, id } de la modale courante

    function clear() {
        layer.classList.add('hidden');
        layer.innerHTML = '';
        active = null;
        Noxa.post('menuFocus', { focus: false });
    }

    function mount(node, type, id) {
        layer.innerHTML = '';
        const scrim = document.createElement('div');
        scrim.className = 'scrim';
        scrim.addEventListener('click', () => cancelActive());
        layer.appendChild(scrim);
        layer.appendChild(node);
        layer.classList.remove('hidden');
        active = { type, id };
    }

    /** Annule/ferme proprement la modale courante en notifiant Lua. */
    function cancelActive() {
        if (!active) return;
        const { type, id } = active;
        if (type === 'confirmLocal' || type === 'inputLocal') { if (active.resolve) active.resolve(); return; }
        if (type === 'input') Noxa.post('menuInput', { id, cancelled: true });
        else if (type === 'confirm') Noxa.post('menuConfirm', { id, confirmed: false });
        else Noxa.post('menuSelect', { id, cancelled: true });
        clear();
    }

    // --- Menu contextuel -------------------------------------------------
    function context(d) {
        const card = document.createElement('div');
        card.className = 'modal-card';
        const opts = (d.options || []).map((o, i) => `
            <div class="menu-opt ${o.disabled ? 'disabled' : ''} ${o.danger ? 'danger' : ''}" data-opt="${Noxa.esc(o.id ?? i)}">
                ${o.icon ? `<div class="menu-opt-icon">${Noxa.esc(o.icon)}</div>` : ''}
                <div class="menu-opt-text">
                    <div class="menu-opt-label">${Noxa.esc(o.label)}</div>
                    ${o.description ? `<div class="menu-opt-desc">${Noxa.esc(o.description)}</div>` : ''}
                </div>
                ${o.badge ? `<div class="menu-opt-badge">${Noxa.esc(o.badge)}</div>` : ''}
            </div>`).join('');
        card.innerHTML = `
            <div class="modal-head">
                <div class="modal-title">${Noxa.esc(d.title || 'Menu')}</div>
                ${d.subtitle ? `<div class="modal-sub">${Noxa.esc(d.subtitle)}</div>` : ''}
            </div>
            <div class="modal-body">${opts}</div>`;

        card.querySelectorAll('.menu-opt:not(.disabled)').forEach((el) => {
            el.addEventListener('click', () => {
                const opt = el.getAttribute('data-opt');
                Noxa.post('menuSelect', { id: d.id, option: opt });
                clear();
            });
        });
        mount(card, 'context', d.id);
    }

    // --- Dialogue de saisie ---------------------------------------------
    function input(d) {
        const card = document.createElement('div');
        card.className = 'modal-card';
        const fields = (d.fields || []).map((f, i) => {
            const common = `class="field-input" data-name="${Noxa.esc(f.name || i)}" ${f.required ? 'required' : ''}`;
            let control;
            if (f.type === 'select') {
                const opts = (f.options || []).map((o) =>
                    `<option value="${Noxa.esc(o.value)}">${Noxa.esc(o.label)}</option>`).join('');
                control = `<select ${common}>${opts}</select>`;
            } else {
                const t = f.type === 'number' ? 'number' : (f.type === 'password' ? 'password' : 'text');
                const attrs = [
                    f.placeholder ? `placeholder="${Noxa.esc(f.placeholder)}"` : '',
                    f.min != null ? `min="${Number(f.min)}"` : '',
                    f.max != null ? `max="${Number(f.max)}"` : '',
                    f.maxlength != null ? `maxlength="${Number(f.maxlength)}"` : '',
                    f.value != null ? `value="${Noxa.esc(f.value)}"` : '',
                ].join(' ');
                control = `<input type="${t}" ${common} ${attrs} />`;
            }
            return `<div class="modal-field">
                <label class="field-label">${Noxa.esc(f.label)}</label>${control}</div>`;
        }).join('');

        card.innerHTML = `
            <div class="modal-head"><div class="modal-title">${Noxa.esc(d.title || 'Saisie')}</div>
            ${d.subtitle ? `<div class="modal-sub">${Noxa.esc(d.subtitle)}</div>` : ''}</div>
            <div class="modal-body">${fields}</div>
            <div class="modal-foot">
                <button class="btn btn-ghost" data-act="cancel">Annuler</button>
                <button class="btn btn-primary" data-act="submit">Valider</button>
            </div>`;

        const submit = () => {
            const values = {};
            let valid = true;
            card.querySelectorAll('[data-name]').forEach((el) => {
                const v = el.value.trim();
                if (el.hasAttribute('required') && v === '') { valid = false; el.style.borderColor = 'var(--error)'; }
                values[el.getAttribute('data-name')] = v;
            });
            if (!valid) return;
            Noxa.post('menuInput', { id: d.id, values });
            clear();
        };
        card.querySelector('[data-act=submit]').addEventListener('click', submit);
        card.querySelector('[data-act=cancel]').addEventListener('click', () => cancelActive());
        card.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
        mount(card, 'input', d.id);
        setTimeout(() => card.querySelector('.field-input')?.focus(), 60);
    }

    // --- Confirmation ----------------------------------------------------
    function confirm(d) {
        const card = document.createElement('div');
        card.className = 'modal-card';
        card.style.width = '380px';
        card.innerHTML = `
            <div class="modal-head"><div class="modal-title">${Noxa.esc(d.title || 'Confirmation')}</div></div>
            <div class="modal-body"><div class="confirm-msg">${d.message || ''}</div></div>
            <div class="modal-foot">
                <button class="btn btn-ghost" data-act="no">${Noxa.esc(d.cancelText || 'Annuler')}</button>
                <button class="btn ${d.danger ? 'btn-danger' : 'btn-primary'}" data-act="yes">${Noxa.esc(d.confirmText || 'Confirmer')}</button>
            </div>`;
        card.querySelector('[data-act=yes]').addEventListener('click', () => {
            Noxa.post('menuConfirm', { id: d.id, confirmed: true }); clear();
        });
        card.querySelector('[data-act=no]').addEventListener('click', () => cancelActive());
        mount(card, 'confirm', d.id);
    }

    // --- Confirmation locale (usage 100 % NUI, sans aller-retour Lua) ----
    // Retourne une Promise<boolean>. Utilisée par d'autres modules NUI.
    function confirmLocal(d) {
        return new Promise((resolve) => {
            const card = document.createElement('div');
            card.className = 'modal-card';
            card.style.width = '380px';
            card.innerHTML = `
                <div class="modal-head"><div class="modal-title">${Noxa.esc(d.title || 'Confirmation')}</div></div>
                <div class="modal-body"><div class="confirm-msg">${d.message || ''}</div></div>
                <div class="modal-foot">
                    <button class="btn btn-ghost" data-act="no">${Noxa.esc(d.cancelText || 'Annuler')}</button>
                    <button class="btn ${d.danger ? 'btn-danger' : 'btn-primary'}" data-act="yes">${Noxa.esc(d.confirmText || 'Confirmer')}</button>
                </div>`;
            const done = (v) => { clear(); resolve(v); };
            card.querySelector('[data-act=yes]').addEventListener('click', () => done(true));
            card.querySelector('[data-act=no]').addEventListener('click', () => done(false));
            mount(card, 'confirmLocal', '__local__');
            active.resolve = () => done(false);  // Échap / scrim => false
        });
    }

    // --- Saisie locale (usage 100 % NUI). Retourne Promise<values|null> ---
    function inputLocal(d) {
        return new Promise((resolve) => {
            const card = document.createElement('div');
            card.className = 'modal-card';
            const fields = (d.fields || []).map((f, i) => {
                const t = f.type === 'number' ? 'number' : 'text';
                const attrs = [
                    f.placeholder ? `placeholder="${Noxa.esc(f.placeholder)}"` : '',
                    f.min != null ? `min="${Number(f.min)}"` : '',
                    f.max != null ? `max="${Number(f.max)}"` : '',
                ].join(' ');
                return `<div class="modal-field"><label class="field-label">${Noxa.esc(f.label)}</label>
                    <input type="${t}" class="field-input" data-name="${Noxa.esc(f.name || i)}" ${f.required ? 'required' : ''} ${attrs} /></div>`;
            }).join('');
            card.innerHTML = `
                <div class="modal-head"><div class="modal-title">${Noxa.esc(d.title || 'Saisie')}</div></div>
                <div class="modal-body">${fields}</div>
                <div class="modal-foot">
                    <button class="btn btn-ghost" data-act="cancel">Annuler</button>
                    <button class="btn btn-primary" data-act="submit">Valider</button>
                </div>`;
            const done = (v) => { clear(); resolve(v); };
            const submit = () => {
                const values = {}; let valid = true;
                card.querySelectorAll('[data-name]').forEach((el) => {
                    const v = el.value.trim();
                    if (el.hasAttribute('required') && v === '') { valid = false; el.style.borderColor = 'var(--error)'; }
                    values[el.getAttribute('data-name')] = v;
                });
                if (valid) done(values);
            };
            card.querySelector('[data-act=submit]').addEventListener('click', submit);
            card.querySelector('[data-act=cancel]').addEventListener('click', () => done(null));
            card.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
            mount(card, 'inputLocal', '__local__');
            active.resolve = () => done(null);
            setTimeout(() => card.querySelector('.field-input')?.focus(), 60);
        });
    }

    // Échap : géré par le routeur global.
    function handleEscape() {
        if (!active) return false;
        if ((active.type === 'confirmLocal' || active.type === 'inputLocal') && active.resolve) active.resolve();
        else cancelActive();
        return true;
    }

    Noxa.on('menu', 'context', context);
    Noxa.on('menu', 'input', input);
    Noxa.on('menu', 'confirm', confirm);
    Noxa.on('menu', 'close', clear);

    return { handleEscape, confirmLocal, inputLocal };
})();
window.NoxaMenu = NoxaMenu;
