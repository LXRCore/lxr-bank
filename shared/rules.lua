--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-BANK — Shared rules: branches, fees, who may bank for a society
     ═══════════════════════════════════════════════════════════════════════════
     Pure functions; the server decides with them, the page mirrors the fees,
     the tests exercise them.
     ═══════════════════════════════════════════════════════════════════════════
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

LXRBank = LXRBank or {}
local B = LXRBank

local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

function B.Branch(id) for _, b in ipairs(Config.Branches) do if b.id == id then return b end end end
function B.BranchByAccount(account) for _, b in ipairs(Config.Branches) do if b.account == account then return b end end end

---Every book a character can reach from this branch: the local one and the others by wire.
function B.Books(branch)
    local out = { { account = branch.account, label = branch.label, wire = false, fee = 0 } }
    local seen = { [branch.account] = true }
    for _, b in ipairs(Config.Branches) do
        if not seen[b.account] then seen[b.account] = true out[#out + 1] = { account = b.account, label = b.label, wire = true, fee = Config.Trade.wireFeePct } end
    end
    return out
end

---Fee for moving `amount` across books by wire (0 when local).
function B.WireFee(amount, local_)
    if local_ then return 0 end
    return round2(math.max(Config.Trade.wireMin, amount * Config.Trade.wireFeePct))
end

function B.DraftFee(amount) return round2(math.max(Config.Trade.draftMin, amount * Config.Trade.draftFeePct)) end

---Is an amount a valid teller amount (positive, two decimals, under the cap).
function B.ValidAmount(n, cap)
    n = tonumber(n)
    if not n or n ~= n or n <= 0 or n == math.huge then return nil end
    n = round2(n)
    if cap and n > cap then return nil end
    return n
end

---Society book name for a job or gang.
function B.SocietyName(kind, name) return (kind == 'gang' and 'gang_' or 'society_') .. name end

---May this player bank for the society: job grade with `society` perm, or a gang boss grade.
function B.MaySociety(job, gang, kind, name)
    if kind == 'gang' then
        if not Config.Society.gangs or not gang or gang.name ~= name then return false end
        local g = type(gang.grade) == 'table' and gang.grade.level or gang.grade
        return (tonumber(g) or 0) >= Config.Society.gangBossGrade or gang.isboss == true
    end
    if not job or job.name ~= name then return false end
    local def = LXRShared.Jobs and LXRShared.Jobs[name]
    if not def or not def.society then return false end
    if LXRShared.JobHasPerm then return LXRShared.JobHasPerm(job, 'society') end
    return job.isboss == true
end

---Societies a player may bank for: { { kind, name, label, book } }
function B.Societies(job, gang)
    local out = {}
    if Config.Society.enabled and job and job.name and B.MaySociety(job, gang, 'job', job.name) then
        local def = LXRShared.Jobs[job.name]
        out[#out + 1] = { kind = 'job', name = job.name, label = def.label, book = B.SocietyName('job', job.name), start = def.society and def.society.startBalance or 0 }
    end
    if Config.Society.enabled and Config.Society.gangs and gang and gang.name and gang.name ~= 'none' and B.MaySociety(job, gang, 'gang', gang.name) then
        local def = LXRShared.Gangs and LXRShared.Gangs[gang.name]
        out[#out + 1] = { kind = 'gang', name = gang.name, label = def and def.label or gang.name, book = B.SocietyName('gang', gang.name), start = 0 }
    end
    return out
end

function B.Open(hour)
    local h = Config.Trade.openHours
    if not h then return true end
    if h.from <= h.to then return hour >= h.from and hour < h.to end
    return hour >= h.from or hour < h.to
end
