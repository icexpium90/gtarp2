// LUSO RP : statut en direct, copie de l'adresse, menu mobile, apparitions au defilement
(function () {
  const toast = document.querySelector('[data-toast]');
  function message(t) {
    if (!toast) return;
    toast.textContent = t;
    toast.classList.add('visible');
    clearTimeout(message.t);
    message.t = setTimeout(() => toast.classList.remove('visible'), 2200);
  }

  // copier "connect ip:port"
  document.querySelectorAll('[data-copier]').forEach((b) => {
    b.addEventListener('click', async () => {
      const texte = b.getAttribute('data-copier');
      try {
        await navigator.clipboard.writeText(texte);
      } catch (e) {
        const zone = document.createElement('textarea');
        zone.value = texte;
        document.body.appendChild(zone);
        zone.select();
        document.execCommand('copy');
        zone.remove();
      }
      message('Copié : ' + texte);
    });
  });

  // statut du serveur toutes les 30 s
  async function statut() {
    try {
      const r = await fetch('api/status.php', { cache: 'no-store' });
      const s = await r.json();
      document.querySelectorAll('[data-statut-joueurs]').forEach((e) => (e.textContent = s.en_ligne ? s.joueurs : '--'));
      document.querySelectorAll('[data-statut-max]').forEach((e) => (e.textContent = s.max));
      document.querySelectorAll('[data-statut-texte]').forEach((e) => (e.textContent = s.en_ligne ? 'Serveur en ligne' : 'Serveur injoignable pour le moment'));
      document.querySelectorAll('[data-statut-court]').forEach((e) => (e.textContent = s.en_ligne ? s.joueurs + ' en ville' : 'Hors ligne'));
      document.querySelectorAll('[data-statut-pastille]').forEach((e) => {
        e.classList.toggle('ok', !!s.en_ligne);
        e.classList.toggle('off', !s.en_ligne);
      });
    } catch (e) { /* statut indisponible : on garde l'affichage actuel */ }
  }
  setInterval(statut, 30000);

  // menu mobile
  const nav = document.querySelector('.nav');
  const burger = document.querySelector('[data-burger]');
  if (burger && nav) {
    burger.addEventListener('click', () => nav.classList.toggle('ouvert'));
    nav.querySelectorAll('.liens a').forEach((a) => a.addEventListener('click', () => nav.classList.remove('ouvert')));
  }

  // apparitions au defilement
  const blocs = document.querySelectorAll('.statut, .ville-visuel, .ville-texte, .activite, .vignette, .appel, .questions details, .titre-section');
  if ('IntersectionObserver' in window) {
    const obs = new IntersectionObserver((entrees) => {
      entrees.forEach((en) => {
        if (en.isIntersecting) {
          en.target.classList.add('vu');
          obs.unobserve(en.target);
        }
      });
    }, { threshold: 0.12 });
    blocs.forEach((b) => { b.classList.add('revele'); obs.observe(b); });
  }
})();
