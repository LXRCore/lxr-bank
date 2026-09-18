--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-BANK — Server: the teller
     ═══════════════════════════════════════════════════════════════════════════
     Personal money stays in the core's accounts (one per branch); this file
     only moves it — deposit, withdraw, wire, draft, cheque, notes — and keeps
     the society books in lxr_bank_societies. Every movement is checked
     here (distance, hours, amounts, balances) and lands in the core ledger.
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local B = LXRBank
local RES = GetCurrentResourceName()
local buckets = {}
local CASH = Config.Trade.cash

local function limited(src)
    local b = buckets[src]
    local now = GetGameTimer()
    if not b or now - b.at > Config.Security.rateLimit.windowMs then b = { at = now, n = 0 } buckets[src] = b end
    b.n = b.n + 1
    return b.n > Config.Security.rateLimit.burst
end
local function player(src) return LXRCore.Functions.GetPlayer(src) end
local function near(src, branch)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - branch.coords) <= Config.Security.maxDistance
end
local function hour() return tonumber(GlobalState.hour) or 12 end
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function money(P, acc) return tonumber(P.PlayerData.money[acc]) or 0 end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 💾 SOCIETY BOOKS
-- ═══════════════════════════════════════════════════════════════════════════════
LXRCore.DB.RegisterMigration(RES, '0001_bank', [[
CREATE TABLE IF NOT EXISTS `lxr_bank_societies` (
  `name` VARCHAR(64) NOT NULL,
  `balance` DECIMAL(18,2) NOT NULL DEFAULT 0,
  `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `lxr_bank_society_ledger` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `book` VARCHAR(64) NOT NULL,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `amount` DECIMAL(18,2) NOT NULL,
  `balance_after` DECIMAL(18,2) NOT NULL,
  `reason` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `book_created` (`book`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

local books = {}   -- book → balance (cache)

local function seedBalance(book)
    if not Config.Society.seedFromRegistry then return 0 end
    local name = book:gsub('^society_', '')
    local def = LXRShared.Jobs and LXRShared.Jobs[name]
    return def and def.society and tonumber(def.society.startBalance) or 0
end

local function bookBalance(book)
    if books[book] ~= nil then return books[book] end
    local row = LXRCore.DB.Single('SELECT balance FROM lxr_bank_societies WHERE name = ?', { book })
    if row then books[book] = tonumber(row.balance) or 0
    else
        books[book] = seedBalance(book)
        LXRCore.DB.Insert('INSERT INTO lxr_bank_societies (name, balance) VALUES (?, ?)', { book, books[book] })
    end
    return books[book]
end

local function bookMove(book, delta, citizenid, reason)
    local before = bookBalance(book)
    local after = round2(before + delta)
    if after < 0 then return false, 'society_poor' end
    books[book] = after
    LXRCore.DB.UpdateAsync('UPDATE lxr_bank_societies SET balance = ? WHERE name = ?', { after, book })
    LXRCore.DB.InsertAsync('INSERT INTO lxr_bank_society_ledger (book, citizenid, amount, balance_after, reason) VALUES (?, ?, ?, ?, ?)', { book, citizenid, delta, after, reason })
    LXRCore.Emit('lxr:bank:society', nil, book, delta, after, citizenid, reason)
    return true, after
end

-- the core's payroll contract (Config.General.paycheck.societyExports)
exports('GetAccountBalance', function(_, name) return bookBalance(B.SocietyName('job', name)) end)
exports('AddMoney', function(_, name, amount, reason) local ok = bookMove(B.SocietyName('job', name), math.abs(tonumber(amount) or 0), nil, reason or 'deposit') return ok end)
exports('RemoveMoney', function(_, name, amount, reason) local ok = bookMove(B.SocietyName('job', name), -math.abs(tonumber(amount) or 0), nil, reason or 'withdraw') return ok end)
exports('GetBook', bookBalance)
exports('MoveBook', function(book, delta, citizenid, reason) return bookMove(book, tonumber(delta) or 0, citizenid, reason) end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 🧾 THE TELLER
-- ═══════════════════════════════════════════════════════════════════════════════
local function recent(citizenid, account)
    return LXRCore.DB.Query('SELECT operation, amount, balance_after, reason, counterparty, created_at FROM lxr_ledger WHERE citizenid = ? AND account = ? ORDER BY id DESC LIMIT ?', { citizenid, account, Config.Trade.ledgerRows }) or {}
end

local function counter(src, branch)
    local P = player(src)
    local pd = P.PlayerData
    local booksOut = {}
    for _, bk in ipairs(B.Books(branch)) do
        bk.balance = money(P, bk.account)
        booksOut[#booksOut + 1] = bk
    end
    local socs = {}
    for _, s in ipairs(B.Societies(pd.job, pd.gang)) do
        s.balance = bookBalance(s.book)
        s.recent = LXRCore.DB.Query('SELECT amount, balance_after, reason, citizenid, created_at FROM lxr_bank_society_ledger WHERE book = ? ORDER BY id DESC LIMIT ?', { s.book, Config.Trade.ledgerRows }) or {}
        socs[#socs + 1] = s
    end
    local notes = LXRCore.Inventory.GetItemCount(src, 'bank_note')
    local cheques = {}
    for slot, it in pairs(pd.items or {}) do
        if it and it.name == 'cheque' and it.info then cheques[#cheques + 1] = { slot = tonumber(slot), amount = tonumber(it.info.amount) or 0, bank = it.info.bank, from = it.info.from } end
    end
    return {
        branch = { id = branch.id, label = branch.label, account = branch.account, town = branch.town },
        cash = money(P, CASH), accountNumber = pd.charinfo.account, name = pd.charinfo.firstname .. ' ' .. pd.charinfo.lastname,
        books = booksOut, recent = recent(pd.citizenid, branch.account), societies = socs,
        notes = notes, noteValue = Config.Trade.noteValue, cheques = cheques,
        fees = { wire = Config.Trade.wireFeePct, wireMin = Config.Trade.wireMin, draft = Config.Trade.draftFeePct, draftMin = Config.Trade.draftMin },
        limits = { deposit = Config.Trade.maxDeposit, withdraw = Config.Trade.maxWithdraw }, closed = not B.Open(hour()),
    }
end

local function gate(src, branchId)
    if limited(src) then return nil, 'rate' end
    local P, branch = player(src), B.Branch(branchId)
    if not P or not branch then return nil, 'invalid' end
    if not near(src, branch) then return nil, 'too_far' end
    if not B.Open(hour()) then return nil, 'closed' end
    return P, branch
end

LXR.RPC.Register('lxr-bank:open', function(src, branchId)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    return true, counter(src, branch), Lang.bundle(), LXRCore.Brand
end)

-- deposit cash into a book (wire fee when the book is not this branch's)
LXR.RPC.Register('lxr-bank:deposit', function(src, branchId, account, amount)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    local target = B.BranchByAccount(account)
    if not target then return false, 'invalid' end
    amount = B.ValidAmount(amount, Config.Trade.maxDeposit)
    if not amount then return false, 'amount' end
    local fee = B.WireFee(amount, target.account == branch.account)
    if money(P, CASH) < amount + fee then return false, 'no_cash', round2(amount + fee) end
    if not P.Functions.RemoveMoney(CASH, round2(amount + fee), 'bank:deposit:' .. branch.id) then return false, 'no_cash' end
    if not P.Functions.AddMoney(account, amount, 'bank:deposit:' .. branch.id) then P.Functions.AddMoney(CASH, round2(amount + fee), 'bank:refund') return false, 'invalid' end
    LXRCore.Emit('lxr:bank:deposit', nil, src, branch.id, account, amount, fee)
    return true, counter(src, branch), fee
end)

-- withdraw from a book to cash (wire fee when the book is not this branch's)
LXR.RPC.Register('lxr-bank:withdraw', function(src, branchId, account, amount)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    local target = B.BranchByAccount(account)
    if not target then return false, 'invalid' end
    amount = B.ValidAmount(amount, Config.Trade.maxWithdraw)
    if not amount then return false, 'amount' end
    local fee = B.WireFee(amount, target.account == branch.account)
    if money(P, account) < amount + fee then return false, 'no_funds', round2(amount + fee) end
    if not P.Functions.RemoveMoney(account, round2(amount + fee), 'bank:withdraw:' .. branch.id) then return false, 'no_funds' end
    P.Functions.AddMoney(CASH, amount, 'bank:withdraw:' .. branch.id)
    LXRCore.Emit('lxr:bank:withdraw', nil, src, branch.id, account, amount, fee)
    return true, counter(src, branch), fee
end)

-- a draft: this branch's book → another account number (online or not), same book
local function findByAccountNumber(number)
    local online = LXRCore.Functions.GetPlayerByAccount(number)
    if online then return online, false end
    local cid = LXRCore.DB.Scalar("SELECT citizenid FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.account')) = ? LIMIT 1", { number })
    if not cid then return nil end
    return LXRCore.Functions.GetOfflinePlayerByCitizenId(cid), true
end

LXR.RPC.Register('lxr-bank:draft', function(src, branchId, number, amount)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    amount = B.ValidAmount(amount, Config.Trade.maxWithdraw)
    if not amount or type(number) ~= 'string' then return false, 'amount' end
    if number == P.PlayerData.charinfo.account then return false, 'self' end
    local target, offline = findByAccountNumber(number)
    if not target then return false, 'no_account' end
    local fee = B.DraftFee(amount)
    if money(P, branch.account) < amount + fee then return false, 'no_funds', round2(amount + fee) end
    if not P.Functions.RemoveMoney(branch.account, round2(amount + fee), 'bank:draft:' .. number) then return false, 'no_funds' end
    target.Functions.AddMoney(branch.account, amount, 'bank:draft:' .. P.PlayerData.charinfo.account)
    if offline then target.Functions.Save() end
    LXRCore.Emit('lxr:bank:draft', nil, src, branch.id, number, amount, fee)
    return true, counter(src, branch), fee
end)

-- cheques: paper drawn on this branch; cashing needs the branch it names
LXR.RPC.Register('lxr-bank:cheque', function(src, branchId, amount)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    amount = B.ValidAmount(amount, Config.Trade.maxWithdraw)
    if not amount then return false, 'amount' end
    local fee = round2(amount * Config.Trade.chequeFeePct)
    if money(P, branch.account) < amount + fee then return false, 'no_funds', round2(amount + fee) end
    if not LXRCore.Inventory.CanCarry(src, 'cheque', 1) then return false, 'too_heavy' end
    if not P.Functions.RemoveMoney(branch.account, round2(amount + fee), 'bank:cheque:' .. branch.id) then return false, 'no_funds' end
    P.Functions.AddItem('cheque', 1, nil, { amount = amount, bank = branch.id, from = P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname }, 'bank:cheque')
    return true, counter(src, branch), fee
end)

LXR.RPC.Register('lxr-bank:cash', function(src, branchId, slot)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    local it = P.PlayerData.items[tonumber(slot) or -1]
    if not it or it.name ~= 'cheque' or not it.info then return false, 'invalid' end
    if it.info.bank ~= branch.id then return false, 'wrong_bank', B.Branch(it.info.bank) and B.Branch(it.info.bank).label or it.info.bank end
    local amount = B.ValidAmount(it.info.amount)
    if not amount then return false, 'invalid' end
    if not P.Functions.RemoveItem('cheque', 1, it.slot, 'bank:cashed') then return false, 'invalid' end
    P.Functions.AddMoney(CASH, amount, 'bank:cheque:cashed')
    return true, counter(src, branch), amount
end)

-- bank notes: hundred-dollar bearer paper ↔ cash
LXR.RPC.Register('lxr-bank:notes', function(src, branchId, n)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    n = math.floor(tonumber(n) or 0)
    if n == 0 or math.abs(n) > 500 then return false, 'amount' end
    local v = Config.Trade.noteValue
    if n > 0 then
        if money(P, CASH) < n * v then return false, 'no_cash', n * v end
        if not LXRCore.Inventory.CanCarry(src, 'bank_note', n) then return false, 'too_heavy' end
        if not P.Functions.RemoveMoney(CASH, n * v, 'bank:notes') then return false, 'no_cash' end
        P.Functions.AddItem('bank_note', n, nil, nil, 'bank:notes')
    else
        n = -n
        if LXRCore.Inventory.GetItemCount(src, 'bank_note') < n then return false, 'no_notes' end
        if not P.Functions.RemoveItem('bank_note', n, nil, 'bank:notes') then return false, 'no_notes' end
        P.Functions.AddMoney(CASH, n * v, 'bank:notes')
    end
    return true, counter(src, branch)
end)

-- societies
LXR.RPC.Register('lxr-bank:society', function(src, branchId, book, amount)
    local P, branch = gate(src, branchId)
    if not P then return false, branch end
    local pd = P.PlayerData
    local allowed
    for _, s in ipairs(B.Societies(pd.job, pd.gang)) do if s.book == book then allowed = s end end
    if not allowed then return false, 'not_yours' end
    amount = tonumber(amount)
    if not amount or amount == 0 then return false, 'amount' end
    local abs = B.ValidAmount(math.abs(amount), Config.Trade.maxWithdraw)
    if not abs then return false, 'amount' end
    if amount > 0 then
        if money(P, CASH) < abs then return false, 'no_cash', abs end
        if not P.Functions.RemoveMoney(CASH, abs, 'bank:society:' .. book) then return false, 'no_cash' end
        bookMove(book, abs, pd.citizenid, 'deposit')
    else
        local ok, why = bookMove(book, -abs, pd.citizenid, 'withdraw')
        if not ok then return false, why end
        P.Functions.AddMoney(CASH, abs, 'bank:society:' .. book)
    end
    return true, counter(src, branch)
end)

CreateThread(function()
    if Config.Debug.printBanner then print(('^1[lxr-bank]^7 v%s — %d branches, societies %s'):format(GetResourceMetadata(RES, 'version', 0), #Config.Branches, Config.Society.enabled and 'on' or 'off')) end
end)
AddEventHandler('playerDropped', function() buckets[source] = nil end)
