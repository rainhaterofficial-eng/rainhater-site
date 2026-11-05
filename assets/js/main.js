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

