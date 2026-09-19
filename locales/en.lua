--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-BANK — Locale: English (canonical)
     Developer   : iBoss21 | Brand : LXRCore | https://www.lxrcore.com
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

Locale.Register('en', {
    error = {
        no_cash = 'You need $%{amount} in cash.',
        rate = 'Slow down.', invalid = 'That request is not valid.', too_far = 'Step up to the teller.', closed = 'The bank is closed.', amount = 'Enter a proper amount.',
        no_cash = 'You do not carry that much. Needed: $%{amount}.', no_funds = 'The book does not hold that much. Needed: $%{amount}.', no_account = 'No account by that number.',
        self = 'You cannot draft money to yourself.', too_heavy = 'Your satchel is full.', wrong_bank = 'That cheque is drawn on %{label}.', no_notes = 'You do not carry that many notes.',
        not_yours = 'You have no say over that book.', society_poor = 'The society cannot cover that.',
    },
    info = {
        deposited = 'Deposited $%{amount}.', withdrawn = 'Withdrew $%{amount}.', drafted = 'Drafted $%{amount} to account %{number}.', cheque = 'Cheque for $%{amount} written.', cashed = 'Cashed for $%{amount}.',
    },
    ui = {
        box = 'Safe deposit box ($%{fee})', box_label = 'Deposit box — %{branch}',
        bank = 'Bank', teller = 'Talk to the teller', closed = 'Closed', hint_close = 'leave', close = 'Leave', holder = 'Account holder', account_no = 'Account no.', books = 'Your books', cash = 'Cash on you', notes = 'Bank notes',
        tab_book = 'The book', tab_draft = 'Drafts', tab_paper = 'Cheques & notes', tab_society = 'Society',
        balance = 'balance', available = 'available', local_book = 'Kept at this branch.', by_wire = 'Kept elsewhere — reached by telegraph wire, %{pct}% fee.', by_wire_short = 'by wire', here = 'this branch',
        deposit = 'Deposit', deposit_sub = 'Cash from your pocket into the book.', withdraw = 'Withdraw', withdraw_sub = 'From the book into your pocket.',
        fee_wire = 'wire fee %{pct}%, at least $%{min}', fee_draft = 'draft fee %{pct}%, at least $%{min}', recent = 'Recent movements', no_movements = 'Nothing in the book yet.',
        draft_sub = 'Move money from %{book} to another account number, here or anywhere.', send = 'Send',
        cheques = 'Cheques', cheque_sub = 'Paper drawn on %{book}. Whoever carries it cashes it here.', write_cheque = 'Write a cheque', cash_it = 'Cash it', wrong_bank = 'Elsewhere',
        notes_title = 'Bank notes', notes_sub = 'Hundred-dollar bearer notes, $%{value} each — for sums too big for a pocket.', to_notes = 'Cash → notes', to_cash = 'Notes → cash',
        society_sub = 'The society book: wages are paid from it.',
        wages = 'Wages',
    },
})
