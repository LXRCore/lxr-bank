--[[
    ██╗     ██╗  ██╗██████╗       ██████╗  █████╗ ███╗   ██╗██╗  ██╗
    ██║     ╚██╗██╔╝██╔══██╗      ██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝
    ██║      ╚███╔╝ ██████╔╝█████╗██████╔╝███████║██╔██╗ ██║█████╔╝
    ██║      ██╔██╗ ██╔══██╗╚════╝██╔══██╗██╔══██║██║╚██╗██║██╔═██╗
    ███████╗██╔╝ ██╗██║  ██║      ██████╔╝██║  ██║██║ ╚████║██║  ██╗
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝

    LXR Core - Bank

    Banking the way 1899 did it: money deposited in Valentine sits in
    Valentine. Each branch keeps its own book (one core account per branch);
    reaching another branch's book costs a telegraph wire. Drafts move money
    to another account number, cheques are paper you carry to the bank they
    are drawn on, bank notes are hundred-dollar bearer paper for big sums.
    Societies (jobs, gangs) bank here too — the core's payroll draws on them.

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/ZHMKVYyhBa (development)
    GitHub:      https://github.com/LXRCore

    Version: 3.0.0
    Performance Target: 0.00 ms idle (tellers are lxr-interact targets)

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

Config = Config or {}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ LANGUAGE ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Lang = 'en'

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ BRANCHES ══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
-- account: the core money account this branch keeps (Config.Money.MoneyTypes in lxr-core).
-- Set every branch to the same account (e.g. 'bank') for one national book instead.
Config.Branches = {
    { id = 'valentine',  label = 'Valentine Savings Bank',    account = 'valbank', town = 'valentine',  coords = vector3(-308.42, 775.88, 118.70), heading = 95.0,  teller = 'u_m_m_valbanker_01', blip = true },
    { id = 'rhodes',     label = 'Bank of Rhodes',            account = 'rhobank', town = 'rhodes',     coords = vector3(1292.31, -1301.54, 77.04), heading = 320.0, teller = 'u_m_m_rhdbanker_01', blip = true },
    { id = 'saintdenis', label = 'Lemoyne National Bank',     account = 'bank',    town = 'saintdenis', coords = vector3(2644.58, -1292.31, 52.25), heading = 180.0, teller = 'u_m_m_sdbanker_01',  blip = true },
    { id = 'blackwater', label = 'First National Bank',       account = 'blkbank', town = 'blackwater', coords = vector3(-813.16, -1277.49, 43.64), heading = 90.0,  teller = 'u_m_m_bwmbanker_01', blip = true },
    { id = 'armadillo',  label = 'Armadillo Bank',            account = 'armbank', town = 'armadillo',  coords = vector3(-3661.20, -2601.48, -13.85), heading = 180.0, teller = 'u_m_m_armbanker_01', blip = true },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ TRADE ═════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Trade = {
    cash = 'cash',
    wireFeePct = 0.02,           -- reaching another branch's book by telegraph (Western Union charged 1–2 %)
    wireMin = 0.25,
    draftFeePct = 0.01,          -- a draft to another account number, same book
    draftMin = 0.10,
    chequeFeePct = 0.0,          -- writing a cheque (paper, no wire)
    noteValue = 100,             -- one bank_note
    maxDeposit = 50000,
    maxWithdraw = 50000,
    openHours = nil,             -- { from = 8, to = 18 }; nil = always
    ledgerRows = 20,             -- recent movements shown per account
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ SOCIETIES ═════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
-- Jobs with `society` in the core registry and gangs get a book here (lxr_bank_societies).
-- Access needs the grade permission `society` (LXRShared.JobHasPerm) — or a gang boss grade.
Config.Society = {
    enabled = true,
    gangs = true,
    gangBossGrade = 2,           -- gang grade level that may bank for the gang
    seedFromRegistry = true,     -- open a book with the job's startBalance the first time it is touched
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ SECURITY ══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Security = {
    rateLimit = { windowMs = 2000, burst = 8 },
    maxDistance = 4.0,
    promptDistance = 2.5,
    adminAce = 'lxrcore.admin',
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ DEBUG ═════════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Debug = { printBanner = true, log = false }
