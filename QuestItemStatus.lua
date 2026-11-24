-- QuestItemStatus: item tooltip -> quests that use the item + your completion status.
-- Data comes from QuestieDB (LibQuestieDB). Completion comes from the game itself.

local DB = _G.LibQuestieDB
if not DB or not DB.Quest or not DB.Item then return end

local isRu = GetLocale() == "ruRU"
local L = isRu and {
    header   = "Квесты предмета:",
    starts   = "начинает",
    goal     = "цель",
    needed   = "нужен",
    given    = "выдаётся",
    done     = "сдан",
    inlog    = "в журнале",
    ready    = "готов к сдаче",
    notTaken = "не взят",
    building = "QuestItemStatus: индекс квестов ещё строится…",
    more     = "…и ещё %d",
} or {
    header   = "Item quests:",
    starts   = "starts",
    goal     = "objective",
    needed   = "required",
    given    = "provided",
    done     = "completed",
    inlog    = "in log",
    ready    = "ready to turn in",
    notTaken = "not taken",
    building = "QuestItemStatus: quest index is still building…",
    more     = "…and %d more",
}

local MAX_LINES = 8

-- itemId -> { [questId] = roleText }
local index = {}
local indexReady = false

local function addRole(itemId, questId, role)
    if type(itemId) ~= "number" or itemId == 0 then return end
    local t = index[itemId]
    if not t then t = {}; index[itemId] = t end
    if not t[questId] then t[questId] = role end
end

local function indexQuest(questId)
    local objectives = DB.Quest.Get(questId, "objectives")
    if type(objectives) == "table" and type(objectives[3]) == "table" then
        for _, obj in pairs(objectives[3]) do
            if type(obj) == "table" then addRole(obj[1], questId, L.goal) end
        end
    end
    local required = DB.Quest.Get(questId, "requiredSourceItems")
    if type(required) == "table" then
        for _, itemId in pairs(required) do addRole(itemId, questId, L.needed) end
    end
    addRole(DB.Quest.Get(questId, "sourceItemId"), questId, L.given)
end

-- Build the reverse index in small chunks so login doesn't hitch.
local function buildIndex()
    local ids = DB.Quest.GetAllIds()
    local i, n = 1, #ids
    local ticker
    ticker = C_Timer.NewTicker(0, function()
        local stop = math.min(i + 199, n)
        for k = i, stop do
            pcall(indexQuest, ids[k])
        end
        i = stop + 1
        if i > n then
            ticker:Cancel()
            indexReady = true
        end
    end)
end

local function isCompleted(questId)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questId)
    elseif IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questId)
    end
end

local function logIndex(questId)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        return C_QuestLog.GetLogIndexForQuestID(questId)
    elseif GetQuestLogIndexByID then
        local idx = GetQuestLogIndexByID(questId)
        if idx and idx > 0 then return idx end
    end
end

local function readyToTurnIn(questId)
    if C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(questId)
    end
    local idx = logIndex(questId)
    if idx and GetQuestLogTitle then
        local _, _, _, _, _, isComplete = GetQuestLogTitle(idx)
        return isComplete == 1 or isComplete == true
    end
end

local function statusOf(questId)
    if isCompleted(questId) then
        return 0, "|cff40ff40" .. L.done .. "|r"
    elseif logIndex(questId) then
        if readyToTurnIn(questId) then
            return 1, "|cff40c0ff" .. L.ready .. "|r"
        end
        return 1, "|cffffd100" .. L.inlog .. "|r"
    end
    return 2, "|cff9d9d9d" .. L.notTaken .. "|r"
end

local function collect(itemId)
    local list = {}
    local startQuest = DB.Item.Get(itemId, "startQuest")
    if type(startQuest) == "number" and startQuest ~= 0 then
        list[#list + 1] = { id = startQuest, role = L.starts }
    end
    local roles = index[itemId]
    if roles then
        for questId, role in pairs(roles) do
            if questId ~= startQuest then
                list[#list + 1] = { id = questId, role = role }
            end
        end
    end
    for _, q in ipairs(list) do
        q.sort, q.status = statusOf(q.id)
        q.name = DB.Quest.Get(q.id, "name") or ("#" .. q.id)
        q.level = DB.Quest.Get(q.id, "questLevel")
    end
    -- Active quests first, then not taken, completed last.
    local order = { [1] = 0, [2] = 1, [0] = 2 }
    table.sort(list, function(a, b)
        if a.sort ~= b.sort then return order[a.sort] < order[b.sort] end
        return a.id < b.id
    end)
    return list
end

local function isSecret(v)
    return issecretvalue and issecretvalue(v)
end

local lastTooltip, lastItem
local function onItemTooltip(tooltip)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if not tooltip.GetItem then return end
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    if not ok or not link or isSecret(link) then return end
    local itemId = tonumber(string.match(link, "item:(%d+)"))
    if not itemId then return end

    -- Both tooltip hooks may fire for the same tooltip; add lines only once per show.
    if lastTooltip == tooltip and lastItem == itemId and tooltip.qisAdded then return end

    local list = collect(itemId)
    if #list == 0 then return end

    tooltip:AddLine(" ")
    tooltip:AddLine(L.header, 1, 0.82, 0)
    for i, q in ipairs(list) do
        if i > MAX_LINES then
            tooltip:AddLine(string.format(L.more, #list - MAX_LINES), 0.6, 0.6, 0.6)
            break
        end
        local lvl = (type(q.level) == "number" and q.level > 0) and ("[" .. q.level .. "] ") or ""
        tooltip:AddDoubleLine(
            "  " .. lvl .. q.name .. " |cff9d9d9d(" .. q.role .. ")|r",
            q.status, 1, 1, 1)
    end
    if not indexReady then
        tooltip:AddLine(L.building, 0.6, 0.6, 0.6)
    end
    lastTooltip, lastItem = tooltip, itemId
    tooltip.qisAdded = true
    tooltip:Show()
end

local function onCleared(tooltip)
    tooltip.qisAdded = nil
end

local function hookTooltips()
    local usesData = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and type(GameTooltip.GetPrimaryTooltipData) == "function"
    if usesData then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if tooltip == GameTooltip or tooltip == ItemRefTooltip then onItemTooltip(tooltip) end
        end)
    end
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt:HasScript("OnTooltipSetItem") then tt:HookScript("OnTooltipSetItem", onItemTooltip) end
        if tt:HasScript("OnTooltipCleared") then tt:HookScript("OnTooltipCleared", onCleared) end
        tt:HookScript("OnHide", onCleared)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    hookTooltips()
    -- Let Questie/QuestieDB finish their own login work first.
    C_Timer.After(5, buildIndex)
end)

-- /qis <itemId or item link> — print the same info to chat.
SLASH_QUESTITEMSTATUS1 = "/qis"
SlashCmdList.QUESTITEMSTATUS = function(msg)
    local itemId = tonumber(string.match(msg or "", "item:(%d+)") or string.match(msg or "", "(%d+)"))
    if not itemId then
        print("|cffffd100/qis|r <itemId | [item link]>")
        return
    end
    local list = collect(itemId)
    local name = DB.Item.Get(itemId, "name") or ("#" .. itemId)
    if #list == 0 then
        print("|cffffd100QIS|r " .. name .. ": —" .. (indexReady and "" or (" (" .. L.building .. ")")))
        return
    end
    print("|cffffd100QIS|r " .. name .. ":")
    for _, q in ipairs(list) do
        print(string.format("  %s (%d, %s) — %s", q.name, q.id, q.role, q.status))
    end
end
