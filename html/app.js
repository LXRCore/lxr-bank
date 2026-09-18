/* LXR-BANK — the teller on the LXR UI Kit | © 2026 iBoss21 / LXRCore
   Works on the server's counter: { branch, cash, accountNumber, name, books[], recent[], societies[], notes, noteValue, cheques[], fees, limits, closed }. */
(function () {
  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'lxr-bank';
  let D = null, L = {}, tab = 'book', book = null;
  const t = (k, vars) => { let s = L[k] || k.split('.').pop().replace(/_/g, ' '); if (vars) for (const v in vars) s = s.replace('%{' + v + '}', vars[v]); return s; };
  const money = (n) => (Math.round((Number(n) || 0) * 100) / 100).toFixed(2);
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const post = (name, body) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).then(r => r.json()).catch(() => ({ ok: false }));
  const sound = (name, set) => post('sound', { name, set });
  const num = (v) => { const n = Number(String(v).replace(',', '.')); return isFinite(n) && n > 0 ? Math.round(n * 100) / 100 : 0; };
  const reasonLabel = (r) => { const x = String(r || ''); if (x.startsWith('bank:deposit')) return t('ui.deposit'); if (x.startsWith('bank:withdraw')) return t('ui.withdraw'); if (x.startsWith('bank:draft')) return t('ui.tab_draft') + ' ' + x.split(':').pop(); if (x.startsWith('bank:cheque')) return t('ui.cheques'); if (x.startsWith('bank:notes')) return t('ui.notes_title'); if (x.startsWith('bank:society')) return t('ui.tab_society'); if (x === 'paycheck' || /paycheck/i.test(x)) return t('ui.wages'); return x; };
  const when = (s) => { if (!s) return ''; const d = new Date(s); return isNaN(d) ? String(s).slice(0, 16) : d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + ' ' + d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }); };

  let toastEl;
  function toast(msg, bad) {
    if (!toastEl) { toastEl = document.createElement('div'); toastEl.className = 'lxr-toast bk-toast'; document.body.appendChild(toastEl); }
    toastEl.textContent = msg; toastEl.classList.toggle('is-bad', !!bad); toastEl.classList.toggle('is-ok', !bad); toastEl.classList.add('show');
    setTimeout(() => toastEl.classList.remove('show'), 2500);
  }
  function applyLocale() { document.querySelectorAll('[data-l]').forEach(el => { const k = 'ui.' + el.dataset.l; if (L[k]) el.textContent = L[k]; }); }
  const curBook = () => D.books.find(b => b.account === book) || D.books[0];
  const wireFee = (amount, b) => b.wire ? Math.max(D.fees.wireMin, amount * D.fees.wire) : 0;
  const draftFee = (amount) => Math.max(D.fees.draftMin, amount * D.fees.draft);

  // ─── pieces ────────────────────────────────────────────────────────────
  function block(title, sub) {
    const el = document.createElement('div'); el.className = 'bk-block';
    el.innerHTML = `<div><div class="bk-block__title">${esc(title)}</div>${sub ? `<div class="bk-block__sub">${esc(sub)}</div>` : ''}</div>`;
    return el;
  }
  function amountForm(label, onGo, extra) {
    const f = document.createElement('div'); f.className = 'bk-form' + (extra ? ' bk-form--two' : ' bk-form--one');
    f.innerHTML = `${extra ? `<input class="bk-in" id="f-extra" placeholder="${esc(extra)}">` : ''}<input class="bk-in" id="f-amount" type="number" min="0.01" step="0.01" placeholder="0.00"><button class="lxr-btn lxr-btn-sm">${esc(label)}</button>`;
    const inp = f.querySelector('#f-amount'), ex = f.querySelector('#f-extra');
    f.querySelector('button').addEventListener('click', () => { const n = num(inp.value); if (!n) return toast(t('error.amount'), true); onGo(n, ex ? ex.value.trim() : null); });
    inp.addEventListener('keydown', e => { if (e.key === 'Enter') f.querySelector('button').click(); });
    return f;
  }
  function chips(values, target) {
    const c = document.createElement('div'); c.className = 'bk-chips';
    values.forEach(v => { const b = document.createElement('button'); b.className = 'bk-chip'; b.textContent = '$' + v; b.addEventListener('click', () => { const i = target.querySelector('#f-amount'); i.value = v; i.focus(); }); c.appendChild(b); });
    return c;
  }
  function ledger(rows, host, societyStyle) {
    const l = document.createElement('div'); l.className = 'bk-ledger';
    if (!rows || !rows.length) { l.innerHTML = `<div class="bk-empty">${esc(t('ui.no_movements'))}</div>`; host.appendChild(l); return; }
    rows.forEach(r => {
      const amt = Number(r.amount) || 0;
      const out = societyStyle ? amt < 0 : /remove|transfer_out/.test(r.operation || '');
      const row = document.createElement('div'); row.className = 'lxr-row';
      row.innerHTML = `<span class="lxr-row-body"><span class="lxr-row-name">${esc(reasonLabel(r.reason || r.operation))}</span></span><span class="lxr-grow"></span><span class="bk-amt ${out ? 'is-out' : ''}">${out ? '−' : '+'}$${money(Math.abs(amt))}</span><span class="bk-date">${esc(when(r.created_at))}</span>`;
      l.appendChild(row);
    });
    host.appendChild(l);
  }

  // ─── tabs ──────────────────────────────────────────────────────────────
  function tabs() {
    const list = [['book', t('ui.tab_book')], ['draft', t('ui.tab_draft')], ['paper', t('ui.tab_paper')]];
    if (D.societies && D.societies.length) list.push(['society', t('ui.tab_society')]);
    const host = $('tabs'); host.innerHTML = '';
    list.forEach(([k, label]) => { const b = document.createElement('button'); b.className = 'bk-tab' + (tab === k ? ' is-on' : ''); b.textContent = label; b.addEventListener('click', () => { tab = k; sound('NAV_UP'); tabs(); main(); }); host.appendChild(b); });
  }

  function main() {
    const host = $('main'); host.innerHTML = '';
    const b = curBook();
    if (tab === 'book') {
      const bl = block(b.label, b.wire ? t('ui.by_wire', { pct: Math.round(D.fees.wire * 100) }) : t('ui.local_book'));
      bl.insertAdjacentHTML('beforeend', `<div class="bk-balance">$${money(b.balance)}<small>${esc(t('ui.balance'))}</small></div>`);
      host.appendChild(bl);
      const dep = block(t('ui.deposit'), t('ui.deposit_sub'));
      const df = amountForm(t('ui.deposit'), (n) => act('deposit', { account: b.account, amount: n }));
      dep.appendChild(df); dep.appendChild(chips([5, 25, 100, 500], df));
      if (b.wire) dep.insertAdjacentHTML('beforeend', `<div class="bk-fee">${esc(t('ui.fee_wire', { min: money(D.fees.wireMin), pct: Math.round(D.fees.wire * 100) }))}</div>`);
      host.appendChild(dep);
      const wd = block(t('ui.withdraw'), t('ui.withdraw_sub'));
      const wf = amountForm(t('ui.withdraw'), (n) => act('withdraw', { account: b.account, amount: n }));
      wd.appendChild(wf); wd.appendChild(chips([5, 25, 100, 500], wf));
      host.appendChild(wd);
      const lg = block(t('ui.recent'), ''); ledger(b.wire ? [] : D.recent, lg); host.appendChild(lg);
    } else if (tab === 'draft') {
      const local = D.books[0];
      const bl = block(t('ui.tab_draft'), t('ui.draft_sub', { book: local.label }));
      bl.insertAdjacentHTML('beforeend', `<div class="bk-balance">$${money(local.balance)}<small>${esc(t('ui.available'))}</small></div>`);
      const f = amountForm(t('ui.send'), (n, number) => { if (!number) return toast(t('error.no_account'), true); act('draft', { number, amount: n }); }, t('ui.account_no'));
      bl.appendChild(f);
      bl.insertAdjacentHTML('beforeend', `<div class="bk-fee">${esc(t('ui.fee_draft', { min: money(D.fees.draftMin), pct: Math.round(D.fees.draft * 100) }))}</div>`);
      host.appendChild(bl);
    } else if (tab === 'paper') {
      const local = D.books[0];
      const ch = block(t('ui.cheques'), t('ui.cheque_sub', { book: local.label }));
      ch.appendChild(amountForm(t('ui.write_cheque'), (n) => act('cheque', { amount: n })));
      if (D.cheques && D.cheques.length) {
        const l = document.createElement('div'); l.className = 'bk-ledger';
        D.cheques.forEach(c => {
          const row = document.createElement('div'); row.className = 'lxr-row';
          const here = c.bank === D.branch.id;
          row.innerHTML = `<span class="lxr-row-body"><span class="lxr-row-name">$${money(c.amount)}</span><span class="lxr-row-sub">${esc(c.from || '')} · ${esc(c.bank || '')}</span></span><span class="lxr-grow"></span><button class="lxr-btn lxr-btn-sm ${here ? '' : 'lxr-btn-ghost'}" ${here ? '' : 'disabled'}>${esc(t(here ? 'ui.cash_it' : 'ui.wrong_bank'))}</button>`;
          row.querySelector('button').addEventListener('click', () => act('cash', { slot: c.slot }));
          l.appendChild(row);
        });
        ch.appendChild(l);
      }
      host.appendChild(ch);
      const nt = block(t('ui.notes_title'), t('ui.notes_sub', { value: D.noteValue }));
      const f = document.createElement('div'); f.className = 'bk-form';
      f.innerHTML = `<input class="bk-in" id="n-count" type="number" min="1" step="1" value="1"><button class="lxr-btn lxr-btn-sm" id="n-buy">${esc(t('ui.to_notes'))}</button><button class="lxr-btn lxr-btn-ghost lxr-btn-sm" id="n-sell">${esc(t('ui.to_cash'))}</button>`;
      f.querySelector('#n-buy').addEventListener('click', () => act('notes', { n: Math.max(1, Math.floor(Number(f.querySelector('#n-count').value) || 1)) }));
      f.querySelector('#n-sell').addEventListener('click', () => act('notes', { n: -Math.max(1, Math.floor(Number(f.querySelector('#n-count').value) || 1)) }));
      nt.appendChild(f); host.appendChild(nt);
    } else if (tab === 'society') {
      (D.societies || []).forEach(s => {
        const bl = block(s.label, t('ui.society_sub'));
        bl.insertAdjacentHTML('beforeend', `<div class="bk-balance">$${money(s.balance)}<small>${esc(t('ui.balance'))}</small></div>`);
        const f = document.createElement('div'); f.className = 'bk-form';
        f.innerHTML = `<input class="bk-in" type="number" min="0.01" step="0.01" placeholder="0.00"><button class="lxr-btn lxr-btn-sm">${esc(t('ui.deposit'))}</button><button class="lxr-btn lxr-btn-ghost lxr-btn-sm">${esc(t('ui.withdraw'))}</button>`;
        const inp = f.querySelector('input'); const [dep, wd] = f.querySelectorAll('button');
        dep.addEventListener('click', () => { const n = num(inp.value); if (n) act('society', { book: s.book, amount: n }); });
        wd.addEventListener('click', () => { const n = num(inp.value); if (n) act('society', { book: s.book, amount: -n }); });
        bl.appendChild(f);
        const lg = block(t('ui.recent'), ''); ledger(s.recent, lg, true); bl.appendChild(lg);
        host.appendChild(bl);
      });
    }
  }

  function side() {
    $('holder').textContent = D.name; $('number').textContent = D.accountNumber;
    $('cash').textContent = money(D.cash); $('notes').textContent = D.notes || 0;
    const host = $('books'); host.innerHTML = '';
    D.books.forEach(b => {
      const row = document.createElement('button'); row.className = 'lxr-row lxr-row--compact' + (b.account === curBook().account ? ' is-active' : '');
      row.innerHTML = `<span class="lxr-row-body"><span class="lxr-row-name">${esc(b.label)}</span><span class="lxr-row-sub">${esc(b.wire ? t('ui.by_wire_short') : t('ui.here'))}</span></span><span class="lxr-grow"></span><span class="bk-amt">$${money(b.balance)}</span>`;
      row.addEventListener('click', () => { book = b.account; tab = 'book'; sound('NAV_UP'); tabs(); main(); side(); });
      host.appendChild(row);
    });
  }

  async function act(name, body) {
    const r = await post(name, body);
    if (!r.ok) { if (r.why) toast(t('error.' + r.why), true); return; }
    if (r.data) { D = Object.assign(D, r.data); tabs(); main(); side(); }
    sound('PURCHASE', 'HUD_SHOP_SOUNDSET');
  }

  $('btn-close').addEventListener('click', () => post('close'));
  document.addEventListener('keydown', (e) => { if (D && (e.key === 'Backspace' || e.key === 'Escape') && e.target.tagName !== 'INPUT') post('close'); });

  function open(m) {
    D = m.data; L = m.locale || {};
    document.body.classList.toggle('lang-ka', m.lang === 'ka');
    applyLocale();
    $('branch-label').textContent = D.branch.label;
    $('closed').classList.toggle('lxr-hidden', !D.closed);
    book = D.books[0].account; tab = 'book';
    app.classList.remove('lxr-hidden');
    tabs(); main(); side();
  }
  window.addEventListener('message', e => {
    const m = e.data || {};
    if (m.theme || (m.brand && m.brand.theme)) document.documentElement.dataset.theme = m.theme || m.brand.theme;
    if (m.action === 'open') open(m);
    if (m.action === 'close') { app.classList.add('lxr-hidden'); D = null; }
  });
  if (window.__LXR_MOCK__) open(window.__LXR_MOCK__);
})();
