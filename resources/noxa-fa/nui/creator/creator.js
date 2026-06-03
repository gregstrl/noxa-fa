/* =====================================================================
   NOXA FA — Créateur de personnage (NUI)
   Messages Lua -> NUI (app:'creator') :
     • 'open'  { gender, data, limits }
     • 'reset' { gender, data }   (après bascule de genre)
     • 'close'
   Callbacks NUI -> Lua :
     • 'creatorSet'    { kind, ... }   édition live d'un attribut
     • 'creatorRotate' { dir:-1|1 }
     • 'creatorCamera' { zone:'face'|'body'|'legs' }
     • 'creatorConfirm'
   ===================================================================== */

(() => {
    const root = document.getElementById('creator');
    let data = null;

    // --- Référentiels d'étiquettes (FR) ---------------------------------
    const FACE = [
        'Largeur du nez', 'Hauteur de la pointe', 'Longueur de la pointe', 'Hauteur de l’os',
        'Abaissement pointe', 'Torsion de l’os', 'Hauteur sourcils', 'Profondeur sourcils',
        'Hauteur pommettes', 'Largeur pommettes', 'Largeur des joues', 'Ouverture des yeux',
        'Épaisseur lèvres', 'Largeur mâchoire', 'Longueur mâchoire', 'Abaissement menton',
        'Longueur menton', 'Largeur menton', 'Fossette menton', 'Épaisseur du cou',
    ];
    // Superpositions exposées : { id, label, hasColor }
    const OVERLAYS = [
        { id: 1, label: 'Barbe', color: true },
        { id: 2, label: 'Sourcils', color: true },
        { id: 0, label: 'Imperfections', color: false },
        { id: 3, label: 'Vieillissement', color: false },
        { id: 6, label: 'Teint', color: false },
        { id: 9, label: 'Taches de rousseur', color: false },
        { id: 4, label: 'Maquillage', color: true },
        { id: 5, label: 'Blush', color: true },
        { id: 8, label: 'Rouge à lèvres', color: true },
    ];
    // Vêtements de départ : { id, label }
    const COMPONENTS = [
        { id: 11, label: 'Haut / Veste' },
        { id: 8,  label: 'Sous-vêtement' },
        { id: 3,  label: 'Torse & bras' },
        { id: 4,  label: 'Pantalon' },
        { id: 6,  label: 'Chaussures' },
        { id: 1,  label: 'Masque' },
        { id: 5,  label: 'Sac à dos' },
        { id: 7,  label: 'Accessoire (cou)' },
    ];

    // --- Helpers de construction de contrôles ---------------------------
    function el(html) { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstChild; }

    function slider({ label, value, min, max, step, fmt, onChange }) {
        const wrap = el(`<div class="cr-ctl">
            <div class="cr-ctl-label"><span>${label}</span><span class="cr-ctl-val"></span></div>
            <input type="range" class="cr-slider" min="${min}" max="${max}" step="${step}" value="${value}">
        </div>`);
        const input = wrap.querySelector('input');
        const out = wrap.querySelector('.cr-ctl-val');
        const render = () => { out.textContent = fmt ? fmt(Number(input.value)) : input.value; };
        input.addEventListener('input', () => { render(); onChange(Number(input.value)); });
        render();
        return wrap;
    }

    function stepper({ label, value, min, max, onChange }) {
        let v = value;
        const wrap = el(`<div class="cr-ctl">
            <div class="cr-ctl-label"><span>${label}</span></div>
            <div class="cr-stepper">
                <button data-d="-1">‹</button>
                <div class="cr-step-val">${v}</div>
                <button data-d="1">›</button>
            </div>
        </div>`);
        const val = wrap.querySelector('.cr-step-val');
        const apply = (d) => {
            v += d; if (v < min) v = max; if (v > max) v = min;
            val.textContent = v; onChange(v);
        };
        wrap.querySelectorAll('button').forEach((b) =>
            b.addEventListener('click', () => apply(Number(b.getAttribute('data-d')))));
        return wrap;
    }

    function set(payload) { Noxa.post('creatorSet', payload); }

    // --- Construction des sections --------------------------------------
    function buildIdentity(c) {
        c.appendChild(el(`<div class="cr-group-title">Sexe</div>`));
        const seg = el(`<div class="cr-seg">
            <div class="cr-seg-opt ${data.gender === 0 ? 'active' : ''}" data-g="0">Homme</div>
            <div class="cr-seg-opt ${data.gender === 1 ? 'active' : ''}" data-g="1">Femme</div>
        </div>`);
        seg.querySelectorAll('.cr-seg-opt').forEach((o) => o.addEventListener('click', () => {
            const g = Number(o.getAttribute('data-g'));
            if (g === data.gender) return;
            set({ kind: 'gender', value: g });
        }));
        c.appendChild(seg);

        c.appendChild(el(`<div class="cr-group-title" style="margin-top:20px">Héritage du visage</div>`));
        const hb = data.headBlend;
        c.appendChild(stepper({ label: 'Visage du père', value: hb.shapeFirst, min: 0, max: 45,
            onChange: (v) => { hb.shapeFirst = v; set({ kind: 'parents', dad: v, mom: hb.shapeSecond }); } }));
        c.appendChild(stepper({ label: 'Visage de la mère', value: hb.shapeSecond, min: 0, max: 45,
            onChange: (v) => { hb.shapeSecond = v; set({ kind: 'parents', dad: hb.shapeFirst, mom: v }); } }));
        c.appendChild(slider({ label: 'Ressemblance', value: hb.shapeMix, min: 0, max: 1, step: 0.05,
            fmt: (v) => Math.round(v * 100) + '%', onChange: (v) => set({ kind: 'mix', shapeMix: v }) }));
        c.appendChild(slider({ label: 'Teint de peau', value: hb.skinMix, min: 0, max: 1, step: 0.05,
            fmt: (v) => Math.round(v * 100) + '%', onChange: (v) => set({ kind: 'mix', skinMix: v }) }));
    }

    function buildFace(c) {
        c.appendChild(el(`<div class="cr-group-title">Traits du visage</div>`));
        FACE.forEach((label, i) => {
            const cur = data.faceFeatures[i] ?? data.faceFeatures[String(i)] ?? 0;
            c.appendChild(slider({ label, value: cur, min: -1, max: 1, step: 0.1,
                fmt: (v) => v.toFixed(1), onChange: (v) => set({ kind: 'face', index: i, value: v }) }));
        });
    }

    function buildHair(c) {
        c.appendChild(el(`<div class="cr-group-title">Coiffure</div>`));
        c.appendChild(stepper({ label: 'Style', value: data.hair.style || 0, min: 0, max: 80,
            onChange: (v) => { data.hair.style = v; set({ kind: 'hair', value: v }); } }));
        c.appendChild(stepper({ label: 'Couleur', value: data.hair.color || 0, min: 0, max: 63,
            onChange: (v) => { data.hair.color = v; set({ kind: 'hairColor', color: v, highlight: data.hair.highlight }); } }));
        c.appendChild(stepper({ label: 'Reflets', value: data.hair.highlight || 0, min: 0, max: 63,
            onChange: (v) => { data.hair.highlight = v; set({ kind: 'hairColor', color: data.hair.color, highlight: v }); } }));

        c.appendChild(el(`<div class="cr-group-title" style="margin-top:18px">Pilosité & maquillage</div>`));
        OVERLAYS.forEach((o) => {
            const ov = data.overlays[o.id] || data.overlays[String(o.id)] || { value: 0, colour: 0, opacity: 1 };
            c.appendChild(stepper({ label: o.label, value: ov.value || 0, min: 0, max: 33,
                onChange: (v) => set({ kind: 'overlay', index: o.id, value: v, opacity: 1.0 }) }));
            if (o.color) {
                c.appendChild(stepper({ label: o.label + ' — couleur', value: ov.colour || 0, min: 0, max: 63,
                    onChange: (v) => set({ kind: 'overlayColor', index: o.id, colour: v }) }));
            }
        });
    }

    function buildEyes(c) {
        c.appendChild(el(`<div class="cr-group-title">Yeux</div>`));
        c.appendChild(stepper({ label: 'Couleur des yeux', value: data.eyeColor || 0, min: 0, max: 31,
            onChange: (v) => { data.eyeColor = v; set({ kind: 'eye', value: v }); } }));
    }

    function buildOutfit(c) {
        c.appendChild(el(`<div class="cr-group-title">Vêtements de départ</div>`));
        COMPONENTS.forEach((comp) => {
            const cc = data.components[comp.id] || data.components[String(comp.id)] || { drawable: 0, texture: 0 };
            c.appendChild(stepper({ label: comp.label, value: cc.drawable || 0, min: 0, max: 250,
                onChange: (v) => set({ kind: 'component', id: comp.id, drawable: v }) }));
            c.appendChild(stepper({ label: comp.label + ' — variante', value: cc.texture || 0, min: 0, max: 20,
                onChange: (v) => set({ kind: 'component', id: comp.id, texture: v }) }));
        });
    }

    const SECTIONS = {
        identite: buildIdentity, visage: buildFace, cheveux: buildHair, yeux: buildEyes, tenue: buildOutfit,
    };

    function render() {
        root.innerHTML = `
            <div class="cr-panel">
                <div class="cr-head">
                    <div class="cr-logo">NOXA FA</div>
                    <div class="cr-sub">Création de votre identité</div>
                </div>
                <div class="cr-tabs">
                    <div class="cr-tab active" data-s="identite">Identité</div>
                    <div class="cr-tab" data-s="visage">Visage</div>
                    <div class="cr-tab" data-s="cheveux">Cheveux</div>
                    <div class="cr-tab" data-s="yeux">Yeux</div>
                    <div class="cr-tab" data-s="tenue">Tenue</div>
                </div>
                <div class="cr-body">
                    <div class="cr-section active" id="cr-identite"></div>
                    <div class="cr-section" id="cr-visage"></div>
                    <div class="cr-section" id="cr-cheveux"></div>
                    <div class="cr-section" id="cr-yeux"></div>
                    <div class="cr-section" id="cr-tenue"></div>
                </div>
                <div class="cr-foot">
                    <button class="btn btn-primary" id="cr-confirm">Confirmer & entrer en jeu</button>
                </div>
            </div>
            <div class="cr-cam">
                <button class="cr-rot" data-dir="-1">⟲</button>
                <div class="cr-cam-zones">
                    <div class="cr-cam-zone active" data-z="face">Visage</div>
                    <div class="cr-cam-zone" data-z="body">Corps</div>
                    <div class="cr-cam-zone" data-z="legs">Pieds</div>
                </div>
                <button class="cr-rot" data-dir="1">⟳</button>
            </div>`;

        // Remplit chaque section.
        for (const [key, fn] of Object.entries(SECTIONS)) {
            fn(root.querySelector('#cr-' + key));
        }

        // Onglets.
        root.querySelectorAll('.cr-tab').forEach((t) => t.addEventListener('click', () => {
            root.querySelectorAll('.cr-tab').forEach((x) => x.classList.remove('active'));
            root.querySelectorAll('.cr-section').forEach((x) => x.classList.remove('active'));
            t.classList.add('active');
            root.querySelector('#cr-' + t.getAttribute('data-s')).classList.add('active');
        }));

        // Rotation + caméra.
        root.querySelectorAll('.cr-rot').forEach((b) =>
            b.addEventListener('click', () => Noxa.post('creatorRotate', { dir: Number(b.getAttribute('data-dir')) })));
        root.querySelectorAll('.cr-cam-zone').forEach((z) => z.addEventListener('click', () => {
            root.querySelectorAll('.cr-cam-zone').forEach((x) => x.classList.remove('active'));
            z.classList.add('active');
            Noxa.post('creatorCamera', { zone: z.getAttribute('data-z') });
        }));

        // Confirmation.
        root.querySelector('#cr-confirm').addEventListener('click', () => Noxa.post('creatorConfirm', {}));
    }

    Noxa.on('creator', 'open', (d) => {
        data = d.data || {};
        root.classList.remove('hidden');
        render();
    });
    Noxa.on('creator', 'reset', (d) => { data = d.data || {}; render(); });
    Noxa.on('creator', 'close', () => { root.classList.add('hidden'); root.innerHTML = ''; });
})();
