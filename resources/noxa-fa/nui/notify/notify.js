/* =====================================================================
   NOXA FA — Module Notifications (toasts custom)
   Reçoit { app:'notify', action:'show', data:{ title, msg, type, duration } }
   ===================================================================== */

(() => {
    const stack = document.getElementById('notify-stack');

    const ICONS = {
        success: '✓',
        error: '✕',
        warning: '!',
        inform: 'i',
        announce: '📢',
    };
    const TITLES = {
        success: 'Succès',
        error: 'Erreur',
        warning: 'Attention',
        inform: 'Noxa FA',
        announce: 'Annonce',
    };

    function show({ title, msg, type, duration }) {
        type = ICONS[type] ? type : 'inform';
        duration = Number(duration) || 4500;

        const el = document.createElement('div');
        el.className = `toast ${type}`;
        el.innerHTML = `
            <div class="toast-icon">${ICONS[type]}</div>
            <div class="toast-body">
                <div class="toast-title">${Noxa.esc(title || TITLES[type])}</div>
                <div class="toast-msg">${Noxa.esc(msg || '')}</div>
            </div>
            <div class="toast-progress" style="animation-duration:${duration}ms"></div>
        `;
        stack.appendChild(el);

        const close = () => {
            el.classList.add('leaving');
            setTimeout(() => el.remove(), 280);
        };
        setTimeout(close, duration);
    }

    Noxa.on('notify', 'show', show);
})();
