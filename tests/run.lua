--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-BANK — Offline tests: branches, fees, societies, locale parity
     Requires a sibling checkout of lxr-core (../lxr-core).
     Usage (from the lxr-bank folder):  lua tests/run.lua [--mock out.js en|ka]
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local CORE = os.getenv('LXR_CORE_PATH') or '../lxr-core'
package.path = CORE .. '/?.lua;' .. package.path
local ok = pcall(function() require('tests.lib.fxshim') end)
if not ok then print('lxr-core shim not found at ' .. CORE .. ' (set LXR_CORE_PATH)') os.exit(2) end
local Shim = require('tests.lib.fxshim')

for _, f in ipairs({ 'shared/main.lua', 'shared/locale.lua', 'locales/en.lua', 'config.lua', 'shared/catalog.lua', 'shared/items.lua', 'shared/prices.lua', 'shared/jobs.lua', 'shared/gangs.lua' }) do Shim.load(CORE .. '/' .. f) end
local CoreConfig = Config
Config = nil
Locale = nil
Shim.load('shared/locale.lua')
Shim.load('locales/en.lua')
Shim.load('locales/ka.lua')
Shim.load('config.lua')
Shim.load('shared/rules.lua')
local B = LXRBank

local passed, failed = 0, 0
local function test(name, fn)
    local okT, err = xpcall(fn, debug.traceback)
    if okT then passed = passed + 1 print('  ^ ok   ' .. name) else failed = failed + 1 print('  x FAIL ' .. name .. '\n' .. err) end
end
local function eq(a, b, msg) if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ' got ' .. tostring(a), 2) end end

print('lxr-bank offline tests')

test('every branch keeps a core money account and has a teller', function()
    local ids = {}
    for _, b in ipairs(Config.Branches) do
        assert(not ids[b.id], 'duplicate ' .. b.id) ids[b.id] = true
        assert(CoreConfig.Money.MoneyTypes[b.account] ~= nil, b.id .. ' account ' .. b.account .. ' is not a core money type')
        assert(b.teller and b.coords and b.label and b.town)
    end
    assert(CoreConfig.General.paycheck.societyResource == 'lxr-bank', 'the core pays wages through lxr-bank')
end)

test('books and wire fees', function()
    local val = B.Branch('valentine')
    local books = B.Books(val)
    eq(books[1].account, 'valbank') assert(not books[1].wire)
    assert(#books == 5, 'five books: ' .. #books)
    eq(B.WireFee(100, true), 0)
    eq(B.WireFee(100, false), 2)
    eq(B.WireFee(1, false), Config.Trade.wireMin)
    eq(B.DraftFee(50), 0.5)
    eq(B.DraftFee(1), Config.Trade.draftMin)
    eq(B.BranchByAccount('rhobank').id, 'rhodes')
end)

test('amounts', function()
    eq(B.ValidAmount('12.345'), 12.35)
    eq(B.ValidAmount(-1), nil) eq(B.ValidAmount('x'), nil) eq(B.ValidAmount(0), nil)
    eq(B.ValidAmount(1e9, 50000), nil)
    eq(B.ValidAmount(0/0), nil)
end)

test('societies: boss grade banks for the job, gang boss for the gang', function()
    local def = LXRShared.Jobs.vallaw
    local top
    for lvl, g in pairs(def.grades) do if g.isboss then top = tonumber(lvl) end end
    assert(top, 'vallaw has a boss grade')
    local boss = { name = 'vallaw', grade = { level = top }, isboss = true }
    local hand = { name = 'vallaw', grade = { level = 0 } }
    assert(B.MaySociety(boss, nil, 'job', 'vallaw'))
    assert(not B.MaySociety(hand, nil, 'job', 'vallaw'))
    assert(not B.MaySociety(boss, nil, 'job', 'rholaw'))
    local socs = B.Societies(boss, { name = 'none' })
    eq(#socs, 1) eq(socs[1].book, 'society_vallaw')
    local gangName = next(LXRShared.Gangs)
    local gboss = { name = gangName, grade = { level = Config.Society.gangBossGrade } }
    assert(B.MaySociety(nil, gboss, 'gang', gangName))
    assert(not B.MaySociety(nil, { name = gangName, grade = { level = 0 } }, 'gang', gangName))
    eq(B.SocietyName('gang', gangName), 'gang_' .. gangName)
    for _, item in ipairs({ 'cheque', 'bank_note' }) do assert(LXRShared.Items[item], item .. ' missing from the catalog') end
end)

test('hours + locale parity', function()
    Config.Trade.openHours = { from = 8, to = 18 }
    assert(B.Open(9) and not B.Open(19))
    Config.Trade.openHours = nil
    local en, ka = Locale.Bundles.en, Locale.Bundles.ka
    local missing = {}
    for k in pairs(en) do if ka[k] == nil then missing[#missing + 1] = k end end
    eq(#missing, 0, 'ka missing: ' .. table.concat(missing, ', '))
end)

print(('%d passed, %d failed'):format(passed, failed))

if arg and arg[1] == '--mock' and arg[2] then
    Config.Lang = arg[3] or 'en'
    local val = B.Branch('valentine')
    local books = B.Books(val)
    local bal = { valbank = 312.40, rhobank = 0, bank = 1250.00, blkbank = 48.10, armbank = 0 }
    for _, b in ipairs(books) do b.balance = bal[b.account] or 0 end
    local data = {
        branch = { id = val.id, label = val.label, account = val.account, town = val.town }, cash = 61.35, accountNumber = 'US1899-4471', name = 'Sadie Adler',
        books = books, societies = { { kind = 'job', name = 'vallaw', label = "Valentine Sheriff's Office", book = 'society_vallaw', balance = 2400, recent = { { amount = -45, balance_after = 2400, reason = 'Employee paycheck', created_at = '2026-09-17 14:02:00' } } } },
        recent = { { operation = 'add', amount = 120, balance_after = 312.40, reason = 'bank:deposit:valentine', created_at = '2026-09-17 18:20:00' }, { operation = 'remove', amount = 15, balance_after = 192.40, reason = 'bank:withdraw:valentine', created_at = '2026-09-16 09:12:00' }, { operation = 'add', amount = 207.40, balance_after = 207.40, reason = 'paycheck', created_at = '2026-09-15 20:00:00' } },
        notes = 3, noteValue = 100, cheques = { { slot = 4, amount = 25, bank = 'valentine', from = 'John Marston' } },
        fees = { wire = Config.Trade.wireFeePct, wireMin = Config.Trade.wireMin, draft = Config.Trade.draftFeePct, draftMin = Config.Trade.draftMin }, limits = { deposit = 50000, withdraw = 50000 }, closed = false,
    }
    local f = assert(io.open(arg[2], 'w'))
    f:write('window.__LXR_MOCK__ = ' .. json.encode({ action = 'open', data = data, locale = Lang.bundle(), lang = Config.Lang, brand = { name = 'The Land of Wolves', theme = 'night' } }) .. ';\n')
    f:close()
    print('mock written to ' .. arg[2])
end
os.exit(failed == 0 and 0 or 1)
