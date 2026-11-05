// rainhater — small site helpers (no libraries needed)

// Fade sections in as you scroll
(function () {
  var els = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) {
    els.forEach(function (el) { el.classList.add('in'); });
    return;
  }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    });
  }, { threshold: 0.12 });
  els.forEach(function (el) { io.observe(el); });
})();

// "Now playing" bar. Put a real song file at assets/audio/latest.mp3 to make it play.
(function () {
  var btn = document.querySelector('.np-btn');
  var audio = document.getElementById('np-audio');
  if (!btn || !audio) return;
  var playIcon = '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M1 0l9 5-9 5z" fill="currentColor"/></svg>';
  var pauseIcon = '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M1 0h3v10H1zM6 0h3v10H6z" fill="currentColor"/></svg>';
  btn.addEventListener('click', function () {
    if (audio.paused) {
      audio.play().then(function () {
        btn.innerHTML = pauseIcon; btn.setAttribute('aria-label', 'Pause');
      }).catch(function () {
        var t = document.querySelector('.np-title');
        if (t) t.textContent = 'Track coming soon';
      });
    } else {
      audio.pause();
      btn.innerHTML = playIcon; btn.setAttribute('aria-label', 'Play');
    }
  });
})();

// Footer year
(function () {
  var y = document.getElementById('year');
  if (y) y.textContent = new Date().getFullYear();
})();

// Contact form: sends through Formspree, which emails the message to rainhater.
(function () {
  var form = document.getElementById('contact-form');
  if (!form) return;
  var topic = new URLSearchParams(location.search).get('topic');
  if (topic === 'coaching') { var sel = document.getElementById('topic'); if (sel) sel.value = 'Coaching'; }
  var status = form.querySelector('.form-status');
  var btn = form.querySelector('button[type="submit"]');
  form.addEventListener('submit', function (e) {
    e.preventDefault();
    status.className = 'form-status';
    if (form.action.indexOf('YOUR_FORM_ID') !== -1) {
      status.textContent = 'The form is not connected yet. It will be before the site goes live.';
      return;
    }
    btn.disabled = true; btn.textContent = 'Sending...';
    fetch(form.action, { method: 'POST', body: new FormData(form), headers: { Accept: 'application/json' } })
      .then(function (r) {
        if (!r.ok) throw new Error();
        form.reset();
        status.textContent = 'Thanks! Your message was sent. I will get back to you soon.';
      })
      .catch(function () {
        status.className = 'form-status error';
        status.textContent = 'Something went wrong. Please try again in a minute.';
      })
      .then(function () { btn.disabled = false; btn.textContent = 'Send message'; });
  });
})();
