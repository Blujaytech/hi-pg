document.documentElement.classList.add('js');

const menuButton = document.querySelector('.menu-toggle');
const navigation = document.querySelector('.landing-nav-links');
let menuPreviouslyFocused = null;

function closeMenu({ restoreFocus = false } = {}) {
  if (!menuButton || !navigation) return;
  menuButton.setAttribute('aria-expanded', 'false');
  menuButton.querySelector('.sr-only').textContent = 'Open navigation';
  navigation.classList.remove('open');
  document.body.classList.remove('menu-open');
  if (restoreFocus && menuPreviouslyFocused) menuPreviouslyFocused.focus();
}

if (menuButton && navigation) {
  menuButton.addEventListener('click', () => {
    const opening = menuButton.getAttribute('aria-expanded') !== 'true';
    if (opening) menuPreviouslyFocused = document.activeElement;
    menuButton.setAttribute('aria-expanded', String(opening));
    menuButton.querySelector('.sr-only').textContent = opening ? 'Close navigation' : 'Open navigation';
    navigation.classList.toggle('open', opening);
    document.body.classList.toggle('menu-open', opening);
    if (opening) navigation.querySelector('a')?.focus();
  });

  navigation.querySelectorAll('a').forEach((link) => link.addEventListener('click', closeMenu));
  document.addEventListener('keydown', (event) => {
    if (menuButton.getAttribute('aria-expanded') !== 'true') return;
    if (event.key === 'Escape') {
      event.preventDefault();
      closeMenu({ restoreFocus: true });
      return;
    }
    if (event.key === 'Tab') {
      const focusable = [menuButton, ...navigation.querySelectorAll('a')];
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
  });
  window.addEventListener('resize', () => {
    if (window.innerWidth > 900) closeMenu();
  });
}

const revealItems = document.querySelectorAll('.reveal');
if ('IntersectionObserver' in window && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
  revealItems.forEach((item) => observer.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add('is-visible'));
}

const copyButton = document.querySelector('[data-copy-checksum]');
const checksum = document.querySelector('#apk-checksum');
const copyStatus = document.querySelector('[data-copy-status]');
if (copyButton && checksum) {
  copyButton.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(checksum.textContent.trim());
      copyButton.textContent = 'Copied';
      copyButton.setAttribute('aria-label', 'APK checksum copied');
      if (copyStatus) copyStatus.textContent = 'APK checksum copied to clipboard.';
      window.setTimeout(() => {
        copyButton.textContent = 'Copy';
        copyButton.setAttribute('aria-label', 'Copy APK checksum');
        if (copyStatus) copyStatus.textContent = '';
      }, 1800);
    } catch {
      const range = document.createRange();
      range.selectNodeContents(checksum);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      if (copyStatus) copyStatus.textContent = 'Checksum selected. Copy it using your device controls.';
    }
  });
}
