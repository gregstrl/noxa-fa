/* =====================================================================
   NOXA FA — Module Sélection / Création de personnage
   Messages Lua -> NUI (app:'characters') :
     • 'open'  data:{ characters:[{id,firstname,lastname,job,cash,bank,dob}], maxSlots }
     • 'close'
   Callbacks NUI -> Lua :
     • 'charSelect' {id}   • 'charCreate' {...}   • 'charDelete' {id}
   ===================================================================== */

(() => {
    const root = document.getElementById('characters');
    let state = { characters: [], maxSlots: 4 };

    const JOB_LABELS = {
        unemployed: 'Sans emploi', police: 'LSPD', ambulance: 'EMS', mechanic: 'Mécanicien',
    };

    function open(d) {
        state.characters = d.characters || [];
        state.maxSlots = d.maxSlots || 4;
        root.classList.remove('hidden');
        Noxa.post('charFocus', { focus: true });
        renderSelect();
    }

    function close() {
        root.classList.add('hidden');
        root.innerHTML = '';
        Noxa.post('charFocus', { focus: false });
    }

    function initials(c) {
        return ((c.firstname || '?')[0] + (c.lastname || '?')[0]).toUpperCase();
    }

    function renderSelect() {
        // Place chaque personnage à son emplacement ; comble les trous par ordre.
        const bySlot = {};
        const overflow = [];
        state.characters.forEach((c) => {
            if (bySlot[c.slot] == null && c.slot < state.maxSlots) bySlot[c.slot] = c;
            else overflow.push(c);
        });
        const cards = [];
        for (let slot = 0; slot < state.maxSlots; slot++) {
            const c = bySlot[slot] || overflow.shift();
            if (c) {
                cards.push(`
                    <div class="char-card" data-id="${c.id}" style="animation-delay:${slot * 60}ms">
                        <div class="char-delete" data-del="${c.id}" title="Supprimer">🗑</div>
                        <div>
                            <div class="char-avatar">${Noxa.esc(initials(c))}</div>
                            <div class="char-name">${Noxa.esc(c.firstname)} ${Noxa.esc(c.lastname)}</div>
                            <div class="char-meta">${Noxa.esc(JOB_LABELS[c.job] || c.job || 'Citoyen')}</div>
                        </div>
                        <div class="char-stats">
                            <div><div class="char-stat-label">Espèces</div><div class="char-stat-val cash">${Noxa.money(c.cash)}</div></div>
                            <div><div class="char-stat-label">Banque</div><div class="char-stat-val bank">${Noxa.money(c.bank)}</div></div>
                        </div>
                    </div>`);
            } else {
                cards.push(`
                    <div class="char-card empty" data-new="1" style="animation-delay:${slot * 60}ms">
                        <div class="char-plus">+</div>
                        <div class="char-empty-label">Créer un personnage</div>
                    </div>`);
            }
        }

        root.innerHTML = `
            <div class="char-wrap">
                <div class="char-brand">
                    <div class="char-logo">NOXA FA</div>
                    <div class="char-tagline">Sélection du personnage</div>
                </div>
                <div class="char-grid">${cards.join('')}</div>
            </div>`;

        root.querySelectorAll('.char-card[data-id]').forEach((el) => {
            el.addEventListener('click', () => Noxa.post('charSelect', { id: Number(el.getAttribute('data-id')) }));
        });
        root.querySelectorAll('[data-new]').forEach((el) => {
            el.addEventListener('click', renderCreate);
        });
        root.querySelectorAll('[data-del]').forEach((el) => {
            el.addEventListener('click', (e) => {
                e.stopPropagation();
                confirmDelete(Number(el.getAttribute('data-del')));
            });
        });
    }

    async function confirmDelete(id) {
        const c = state.characters.find((ch) => ch.id === id);
        const ok = await NoxaMenu.confirmLocal({
            danger: true,
            title: 'Supprimer le personnage',
            message: `Supprimer définitivement <strong>${Noxa.esc(c ? c.firstname + ' ' + c.lastname : '')}</strong> ?`,
            confirmText: 'Supprimer', cancelText: 'Annuler',
        });
        if (ok) Noxa.post('charDelete', { id });
    }

    function renderCreate() {
        root.innerHTML = `
            <div class="char-create">
                <div class="char-create-head">
                    <h2>Nouveau personnage</h2>
                    <p>Donnez vie à votre identité dans Los Santos.</p>
                </div>
                <div class="char-create-body">
                    <div class="char-row">
                        <div class="modal-field">
                            <label class="field-label">Prénom</label>
                            <input class="field-input" id="cc-first" maxlength="24" placeholder="John" />
                        </div>
                        <div class="modal-field">
                            <label class="field-label">Nom</label>
                            <input class="field-input" id="cc-last" maxlength="24" placeholder="Doe" />
                        </div>
                    </div>
                    <div class="modal-field">
                        <label class="field-label">Genre</label>
                        <div class="gender-seg" id="cc-gender">
                            <div class="gender-opt active" data-g="0">Homme</div>
                            <div class="gender-opt" data-g="1">Femme</div>
                        </div>
                    </div>
                    <div class="char-row">
                        <div class="modal-field">
                            <label class="field-label">Date de naissance</label>
                            <input class="field-input" id="cc-dob" type="date" value="2000-01-01" min="1920-01-01" max="2008-12-31" />
                        </div>
                        <div class="modal-field">
                            <label class="field-label">Nationalité</label>
                            <input class="field-input" id="cc-nat" maxlength="48" placeholder="Américaine" />
                        </div>
                    </div>
                </div>
                <div class="char-create-foot">
                    <button class="btn btn-ghost" id="cc-back">Retour</button>
                    <button class="btn btn-primary" id="cc-submit">Créer le personnage</button>
                </div>
            </div>`;

        let gender = 0;
        root.querySelectorAll('.gender-opt').forEach((el) => {
            el.addEventListener('click', () => {
                root.querySelectorAll('.gender-opt').forEach((o) => o.classList.remove('active'));
                el.classList.add('active');
                gender = Number(el.getAttribute('data-g'));
            });
        });
        root.querySelector('#cc-back').addEventListener('click', renderSelect);
        root.querySelector('#cc-submit').addEventListener('click', () => {
            const firstname = root.querySelector('#cc-first').value.trim();
            const lastname = root.querySelector('#cc-last').value.trim();
            const nat = root.querySelector('#cc-nat').value.trim();
            const dob = root.querySelector('#cc-dob').value;
            if (firstname.length < 2 || lastname.length < 2) {
                window.postMessage({ app: 'notify', action: 'show', data: {
                    type: 'error', msg: 'Prénom et nom requis (2 caractères min).' } }, '*');
                return;
            }
            Noxa.post('charCreate', {
                firstname, lastname, gender,
                dob: dob || '2000-01-01',
                nationality: nat || 'Inconnue',
            });
        });
        setTimeout(() => root.querySelector('#cc-first')?.focus(), 60);
    }

    Noxa.on('characters', 'open', open);
    Noxa.on('characters', 'close', close);
})();
