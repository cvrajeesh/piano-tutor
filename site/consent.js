/* Cookie consent for the Middle C website.
 *
 * Google Tag Manager is only loaded after the visitor accepts analytics
 * cookies. The choice is remembered in localStorage, and the "Cookie settings"
 * link in the footer shows the banner again so it can be changed.
 *
 * The banner's text comes from <template id="cookie-banner"> in the page, which
 * scripts/build-site.py renders in the page's language. The English below is only
 * a fallback for a page without it.
 */
(function () {
  var GTM_ID = 'GTM-W59JB7XW';
  var KEY = 'middlec-cookie-consent'; // "granted" or "denied"
  var gtmLoaded = false;

  function readChoice() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }

  function saveChoice(value) {
    try { localStorage.setItem(KEY, value); } catch (e) { /* storage blocked: ask again next page */ }
  }

  function loadGtm() {
    if (gtmLoaded) return;
    gtmLoaded = true;
    var w = window;
    w.dataLayer = w.dataLayer || [];
    function gtag() { w.dataLayer.push(arguments); }
    // Analytics only. The site shows no ads.
    gtag('consent', 'default', {
      analytics_storage: 'granted',
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied'
    });
    w.dataLayer.push({ 'gtm.start': new Date().getTime(), event: 'gtm.js' });
    var s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtm.js?id=' + GTM_ID;
    document.head.appendChild(s);
  }

  // Remove Google Analytics cookies left over from an earlier "Accept".
  function clearAnalyticsCookies() {
    var host = location.hostname;
    var domains = ['', host, '.' + host];
    var parts = host.split('.');
    if (parts.length > 2) domains.push('.' + parts.slice(-2).join('.'));
    document.cookie.split(';').forEach(function (c) {
      var name = c.split('=')[0].trim();
      if (!/^(_ga|_gid|_gat)/.test(name)) return;
      domains.forEach(function (d) {
        document.cookie = name + '=; Max-Age=0; path=/' + (d ? '; domain=' + d : '');
      });
    });
  }

  var banner;

  function hideBanner() {
    if (banner) banner.hidden = true;
  }

  function choose(value) {
    saveChoice(value);
    hideBanner();
    if (value === 'granted') {
      loadGtm();
    } else {
      clearAnalyticsCookies();
      // Tag Manager can't be unloaded, so reload to stop it on this page.
      if (gtmLoaded) location.reload();
    }
  }

  function showBanner() {
    if (!banner) {
      var template = document.getElementById('cookie-banner');
      if (template && template.content.firstElementChild) {
        banner = template.content.firstElementChild.cloneNode(true);
      } else {
        banner = document.createElement('section');
        banner.className = 'cookie-banner';
        banner.setAttribute('aria-label', 'Cookie consent');
        banner.innerHTML =
          '<p>This website uses Google Analytics cookies to count visits. ' +
          'They’re only set if you accept. The Middle C app never uses them. ' +
          '<a href="/privacy.html#website">Learn more</a></p>' +
          '<div class="cookie-actions">' +
          '<button type="button" class="btn small ghost" data-choice="denied">Decline</button>' +
          '<button type="button" class="btn small" data-choice="granted">Accept</button>' +
          '</div>';
      }
      banner.addEventListener('click', function (e) {
        var btn = e.target.closest('[data-choice]');
        if (btn) choose(btn.getAttribute('data-choice'));
      });
      document.body.appendChild(banner);
    }
    banner.hidden = false;
  }

  function init() {
    var settings = document.querySelectorAll('[data-cookie-settings]');
    for (var i = 0; i < settings.length; i++) {
      settings[i].addEventListener('click', function (e) {
        e.preventDefault();
        showBanner();
        var first = banner.querySelector('button');
        if (first) first.focus();
      });
    }
    var choice = readChoice();
    if (choice === 'granted') loadGtm();
    else if (choice === 'denied') clearAnalyticsCookies(); // GA can rewrite one while the page unloads
    else showBanner();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
