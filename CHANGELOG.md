# Changelog

## 3.0.0 — 2026-09-19
* The safe deposit box: a box per character at every branch (an lxr-inventory stash, yours alone), a small fee each visit (`Config.DepositBox`).
* LXRCore v3 release line: every resource ships as 3.0.0 from here (the entries below are the road to it).

## 3.0.0 — 2026-09-18

Rebuilt on the LXRCore v3 native API (repository renamed from lxr-banking). Nothing of the earlier build remains; branch positions were kept as data.

* Branch books on the core money accounts, telegraph wires between books, drafts by account number (offline recipients too)
* Cheques and bank notes as catalog items
* Society and gang books with a ledger; the core payroll contract (GetAccountBalance / RemoveMoney)
* Tellers as lxr-interact targets, blips, hours; teller page on the LXR UI Kit; locales EN / KA; offline tests
