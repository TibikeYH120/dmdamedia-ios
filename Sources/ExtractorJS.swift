import Foundation

enum Extractor {
    static let js: String = """
// DMD Media scraper - oldal-kinyerok (elrejtett webview-ban fut, FO ablak SOHA nem tolti be az oldalt)
'use strict';

// Kiragadja az osszes hasznalhato infot az aktualis (vagy atadott) dokumentumbol.
function extractDoc(doc, pageUrl) {
  const abs = (u) => { try { return new URL(u, pageUrl).href; } catch (e) { return null; } };
  const clean = (s) => (s || '').replace(/\\s+/g, ' ').trim();
  const isAd = (u) => !u || /gatecpm|doubleclick|googlesyndication|adservice|popads|exoclick|adsterra|propeller|onclickads|effective/i.test(u);

  const out = {
    url: pageUrl,
    title: '',
    kind: 'page',
    cards: [],
    episodes: [],
    seasons: [],
    providers: [],
    iframe: null,
    iframes: [],
    desc: '',
    poster: '',
    year: '',
    cast: [],
    prev: null,
    next: null
  };

  out.title = clean(doc.title || '').replace(/\\s*\\|\\s*dmdamedia.*$/i, '').replace(/\\s+online\\s*$/i, '');

  // --- lejatszo iframe (nem reklam) ---
  const ifr = [];
  for (const f of doc.querySelectorAll('iframe')) {
    const src = abs(f.getAttribute('src') || '');
    if (src) ifr.push(src);
  }
  out.iframes = ifr;
  out.iframe = ifr.find((u) => !isAd(u)) || null;

  // --- forras-valaszto gombok (Voe / Filemoon / Streamz ...) ---
  for (const a of doc.querySelectorAll('a.provider-btn, a[href*="?a="]')) {
    const name = clean(a.textContent);
    const url = abs(a.getAttribute('href') || '');
    if (!name || !url || !/\\?a=/.test(url)) continue;
    if (/beküld|submit|feltölt|reklám|támogat/i.test(name)) continue;
    out.providers.push({ name, url: url.split('#')[0], active: /aktiv|active/.test(a.className || '') });
    if (out.providers.length > 12) break;
  }

  // --- leiras / poszter / ev ---
  const hd = doc.querySelector('.hero-desc') || doc.querySelector('[class*="hero-desc"], [class*="storyline"], [class*="plot"]');
  if (hd) out.desc = clean(hd.textContent);
  if (!out.desc) {
    const m = /(?:leírása|Tartalomleírás)[\\s\\S]{0,40}?(?:<\\/h[123]>|:)([\\s\\S]{20,1200}?)(?:<\\/div>|<\\/p>|<h[123])/i.exec(doc.body ? doc.body.innerHTML : '');
    if (m) out.desc = clean(m[1].replace(/<[^>]+>/g, ' ')).slice(0, 900);
  }
  const pimg = doc.querySelector('img[src*="_poster"], img[data-src*="_poster"], img[alt][class*="poster"]');
  if (pimg) out.poster = abs(pimg.getAttribute('data-src') || pimg.getAttribute('src') || '');
  const ym = /\\b(19|20)\\d{2}\\b/.exec(out.title);
  if (ym) out.year = ym[0];

  // --- evad gombok ---
  for (const b of doc.querySelectorAll('.season-btn, [onclick*="loadSeason"]')) {
    const m = /loadSeason\\(\\s*(\\d+)\\s*,\\s*'([^']+)'/.exec(b.getAttribute('onclick') || '');
    if (m) out.seasons.push({ n: +m[1], kod: m[2], label: clean(b.textContent) || (m[1] + '. évad') });
  }

  // --- epizodok ---
  const seenEp = new Set();
  for (const a of doc.querySelectorAll('a.episode-btn, a[href*=".resz"]')) {
    const href = abs(a.getAttribute('href') || '');
    if (!href || !/\\.resz/.test(href)) continue;
    const m = /(\\d+)\\.evad\\/(\\d+)\\.resz/.exec(href);
    const key = href.split('#')[0].split('?')[0];
    if (seenEp.has(key)) continue;
    seenEp.add(key);
    out.episodes.push({
      url: key,
      season: m ? +m[1] : null,
      ep: m ? +m[2] : null,
      title: clean(a.getAttribute('title') || a.textContent).replace(/^\\s*\\d+\\s*\\.?\\s*rész\\s*/i, '')
    });
    if (out.episodes.length > 500) break;
  }

  // --- elozo / kovetkezo ---
  for (const a of doc.querySelectorAll('a')) {
    const t = clean(a.textContent).toLowerCase();
    const href = abs(a.getAttribute('href') || '');
    if (!href) continue;
    if (t === 'előző') out.prev = href.split('#')[0];
    if (t === 'következő') out.next = href.split('#')[0];
  }

  // --- szereposztas ---
  for (const c of doc.querySelectorAll('.cast-card')) {
    const parts = c.querySelectorAll('div, span, a');
    const txt = clean(c.textContent).replace(/IMDb.*$/i, '');
    if (txt) out.cast.push(txt.slice(0, 80));
    if (out.cast.length > 12) break;
  }

  // --- kartyak (listak: filmek / sorozatok / kategoria / kereses) ---
  const cardSel = doc.querySelectorAll('a.movie-card, a[href]');
  for (const a of cardSel) {
    if (!a.querySelector) continue;
    const img = a.querySelector('img');
    if (!img) continue;
    const href = abs(a.getAttribute('href') || '');
    if (!href) continue;
    const path = href.replace(/^https?:\\/\\/[^/]+/, '');
    const isMovie = /_film$|\\/film$/.test(path);
    const isEp = /\\.resz/.test(path);
    const isSeries = !isMovie && !isEp && /^\\/[a-z0-9_\\-]+\\/?$/i.test(path) && !/^\\/(filmek|sorozatok|kategoria|szinesz|szineszek|rendezo|search|kereses)/i.test(path);
    if (!isMovie && !isEp && !isSeries) continue;
    let poster = img.getAttribute('data-src') || img.getAttribute('src') || '';
    poster = abs(poster) || '';
    if (/default\\.jpg/.test(poster) && !img.getAttribute('data-src')) {
      // placeholder csak akkor jo, ha nincs mas
      const ds = img.getAttribute('data-src');
      if (!ds) continue;
    }
    const badges = [];
    for (const b of a.querySelectorAll('.card-badge')) {
      const t = clean(b.textContent);
      if (t) badges.push(t);
    }
    const titleEl = a.querySelector('.card-title');
    const titleAttr = a.getAttribute('title') || '';
    let title = clean(titleEl ? titleEl.textContent : '') || clean(img.getAttribute('alt') || '') || clean(titleAttr);
    let sxxexx = '';
    const em = /\\bS(\\d{1,2})E(\\d{1,3})\\b/i.exec(titleAttr + ' ' + clean(a.textContent));
    if (em) { sxxexx = 'S' + em[1].padStart(2, '0') + 'E' + em[2].padStart(2, '0'); title = title.replace(/\\bS\\d{1,2}E\\d{1,3}\\b/i, '').trim(); }
    const dm = /(\\d{4}-\\d{2}-\\d{2}(?:\\s+\\d{2}:\\d{2})?)/.exec(clean(a.textContent));
    const yearEl = a.querySelector('.card-year');
    out.cards.push({
      url: href.split('#')[0],
      kind: isMovie ? 'movie' : (isEp ? 'episode' : 'series'),
      title: title.slice(0, 120),
      poster,
      badges,
      sxxexx,
      date: dm ? dm[1] : '',
      year: clean(yearEl ? yearEl.textContent : '')
    });
    if (out.cards.length > 250) break;
  }

  // tipus a lap alapjan
  if (out.iframe || out.providers.length) out.kind = 'watch';
  else if (out.episodes.length || out.seasons.length) out.kind = 'series';
  else if (out.cards.length) out.kind = 'list';
  return out;
}

// Aktualis dokumentum kinyerese (webview-ban)
function extractCurrent() {
  return extractDoc(document, location.href);
}

// Evad betoltese: POST /epizod_betoltes (a lap contextusabol, same-origin)
async function fetchSeason(kod, evad) {
  const fd = new FormData();
  fd.append('evad', String(evad));
  fd.append('sorozatKod', kod);
  const r = await fetch('/epizod_betoltes', { method: 'POST', body: fd });
  const html = await r.text();
  const doc = new DOMParser().parseFromString('<div id="x">' + html + '</div>', 'text/html');
  const eps = [];
  for (const a of doc.querySelectorAll('a.episode-btn, a[href*=".resz"]')) {
    let href = a.getAttribute('href') || '';
    try { href = new URL(href, location.href).href; } catch (e) { continue; }
    const m = /(\\d+)\\.evad\\/(\\d+)\\.resz/.exec(href);
    eps.push({
      url: href.split('#')[0].split('?')[0],
      season: m ? +m[1] : +evad,
      ep: m ? +m[2] : null,
      title: (a.getAttribute('title') || a.textContent || '').replace(/\\s+/g, ' ').trim()
    });
  }
  return { episodes: eps };
}

// Kereses: POST /search
async function fetchSearch(q) {
  const fd = new FormData();
  fd.append('search', q);
  const r = await fetch('/search', { method: 'POST', body: fd });
  const html = await r.text();
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const data = extractDoc(doc, location.origin + '/search');
  return { cards: data.cards, title: data.title };
}


"""
}
