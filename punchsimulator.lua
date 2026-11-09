if not ({[14236123211] = true, [11948073670] = true})[game.PlaceId] then return nil end
Players = game:GetService("Players")
LP = Players.LocalPlayer
PG = LP:WaitForChild("PlayerGui")
RS = game:GetService("ReplicatedStorage")
RunService = game:GetService("RunService")
GuiService = game:GetService("GuiService")
VIM = game:GetService("VirtualInputManager")
UIS = game:GetService("UserInputService")
Lighting = game:GetService("Lighting")
Events = RS:WaitForChild("Events")
Modules = RS:WaitForChild("Modules")
BossData = {}
BossReq = {}
IslandFallback = {}
HttpService = game:GetService("HttpService")
DATA_DIR = "pnka"
toggleObjs = {}
ctrlRegistry = {}
function regCtrl(key, getter, setter, obj)
    ctrlRegistry[key] = { get = getter, set = setter, obj = obj }
end
SETTINGS_FILE = DATA_DIR .. "/" .. LP.Name .. "-setting.json"
function collectSettings()
    local toggles = {}
    local controls = {}
    for key, c in pairs(ctrlRegistry) do
        local ok, v = pcall(c.get)
        if ok and v ~= nil then controls[key] = v end
    end
    for flag in pairs(toggleObjs) do
        toggles[flag] = _G[flag] == true
    end
    return {
        version = 1,
        toggles = toggles,
        controls = controls,
        values = {
            bossMethod = bossMethod,
            hatchSpeed = hatchSpeed,
            hatchCheap = hatchCheap,
            customWalkspeed = customWalkspeed,
            customJumppower = customJumppower,
            selectedTempleFate = selectedTempleFate,
            selectedIslandStage = selectedIslandStage,
            selectedIslandName = selectedIslandName,
        },
        notifyRarities = notifyRarities,
        deleteRarities = deleteRarities,
    }
end
function applySettings(data)
    if type(data) ~= "table" then return false end
    local v = type(data.values) == "table" and data.values or {}
    if type(v.bossMethod) == "string" then bossMethod = v.bossMethod end
    if type(v.hatchSpeed) == "number" then hatchSpeed = v.hatchSpeed end
    if type(v.hatchCheap) == "boolean" then hatchCheap = v.hatchCheap end
    if type(v.customWalkspeed) == "number" then customWalkspeed = v.customWalkspeed end
    if type(v.customJumppower) == "number" then customJumppower = v.customJumppower end
    if type(v.selectedTempleFate) == "number" then selectedTempleFate = v.selectedTempleFate end
    if type(v.selectedIslandStage) == "number" then selectedIslandStage = v.selectedIslandStage end
    if type(v.selectedIslandName) == "string" then selectedIslandName = v.selectedIslandName end
    if type(data.notifyRarities) == "table" then
        notifyRarities = {}
        for k, b in pairs(data.notifyRarities) do
            if b == true then notifyRarities[k] = true end
        end
    end
    if type(data.deleteRarities) == "table" then
        deleteRarities = {}
        for k, b in pairs(data.deleteRarities) do
            if b == true then deleteRarities[k] = true end
        end
    end
    local saved = type(data.toggles) == "table" and data.toggles or {}
    for flag, entry in pairs(toggleObjs) do
        local want = saved[flag] == true
        if (_G[flag] == true) ~= want then
            local ok = pcall(function() entry.obj:Set(want) end)
            if not ok then
                _G[flag] = want
                local fn = want and entry.onStart or entry.onStop
                if fn then pcall(fn) end
            end
        end
    end
    local ctrls = type(data.controls) == "table" and data.controls or {}
    for key, c in pairs(ctrlRegistry) do
        local v = ctrls[key]
        if v ~= nil then
            pcall(c.set, v)
            if c.obj then pcall(function() c.obj:Set(v) end) end
        end
    end
    return true
end
function saveSettingsFile()
    if _G.PnkaStopSave then return end
    local ok, json = pcall(function() return HttpService:JSONEncode(collectSettings()) end)
    if ok and json then pcall(writefile, SETTINGS_FILE, json) end
end
function loadSettingsFile()
    local ok, raw = pcall(readfile, SETTINGS_FILE)
    if not ok or type(raw) ~= "string" then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then return false end
    return applySettings(data)
end
DATA_FILE = DATA_DIR .. "/" .. LP.Name .. "-databoss.json"
haveData, badStage = {}, {}
dataBusy = false
syncStarted = false
BOSS_BACKUP_FILE = DATA_DIR .. "/pnka-bossdatabackup.json"
ISLAND_BACKUP_FILE = DATA_DIR .. "/pnka-islandlistbackup.json"
function readJsonFile(path)
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then return nil end
    local ok, decoded = pcall(function()
        if not isfile(path) then return nil end
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and type(decoded) == "table" then return decoded end
    return nil
end
function writeJsonFile(path, data)
    if typeof(writefile) ~= "function" then return end
    pcall(function()
        if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(DATA_DIR) then
            makefolder(DATA_DIR)
        end
        writefile(path, HttpService:JSONEncode(data))
    end)
end
function validItems(items)
    if type(items) ~= "table" then return false end
    for i = 1, 4 do
        local it = items[i]
        if type(it) ~= "table" or type(it.name) ~= "string" or type(it.req) ~= "string" or not num(it.req) then
            return false
        end
    end
    return true
end
function applyStage(sn, items)
    BossData[sn] = BossData[sn] or {}
    BossReq[sn] = BossReq[sn] or {}
    for i = 1, 4 do
        BossData[sn][i] = { items[i].name, items[i].req }
        BossReq[sn][i] = num(items[i].req)
    end
    haveData[sn] = true
end
function loadBossFile(path)
    local decoded = readJsonFile(path or DATA_FILE)
    if not decoded then return end
    for key, items in pairs(decoded) do
        local sn = tonumber(key)
        if sn and validItems(items) then applyStage(sn, items) end
    end
end
function saveBossFile()
    local out = {}
    for sn in pairs(haveData) do
        local items = {}
        for i = 1, 4 do
            items[i] = { name = BossData[sn][i][1], req = BossData[sn][i][2] }
        end
        out[tostring(sn)] = items
    end
    writeJsonFile(DATA_FILE, out)
    local bk = readJsonFile(BOSS_BACKUP_FILE) or {}
    for k, v in pairs(out) do bk[k] = v end
    bk.bossdatabackup = bk.bossdatabackup or DG_BACKUP
    writeJsonFile(BOSS_BACKUP_FILE, bk)
end
function ensureDungeonBackup()
    local bk = readJsonFile(BOSS_BACKUP_FILE) or {}
    if bk.bossdatabackup == nil then
        bk.bossdatabackup = DG_BACKUP
        writeJsonFile(BOSS_BACKUP_FILE, bk)
    end
end
function loadBackupFile()
    loadBossFile(BOSS_BACKUP_FILE)
    local isl = readJsonFile(ISLAND_BACKUP_FILE)
    if isl then
        for _, it in ipairs(isl) do
            if type(it) == "table" and tonumber(it.stage) and type(it.name) == "string" then
                IslandFallback[#IslandFallback + 1] = { stage = tonumber(it.stage), name = it.name }
            end
        end
    end
end
MainUI = PG:WaitForChild("MainUi")
Top = MainUI:WaitForChild("Top")
FightUI = PG:WaitForChild("FightingMainUi")
Btn = FightUI:WaitForChild("ClickButton")
Countdown = FightUI:WaitForChild("Countdown")
Scroll = PG:WaitForChild("TeleportUI"):WaitForChild("Frame"):WaitForChild("ScrollingFrame")
Arenas = workspace:WaitForChild("Arenas")
Breakable = workspace:WaitForChild("BreakableParts")
BuyRemote = Events:WaitForChild("LevelGUIBuyButtonPressed")
PunchRemote = Events:WaitForChild("DamageIncreaseOnClickEvent")
GloveRemote = Events:WaitForChild("ClickedGlovesButton")
FightEvent = Events:WaitForChild("AutoFight")
QuestEvent = Events:WaitForChild("QuestEvent")
PushEvent = Events:FindFirstChild("PushEvent") or Events:WaitForChild("PushEvent", 5)
HatchEvent = Events:FindFirstChild("PlayerPressedKeyOnEgg") or Events:WaitForChild("PlayerPressedKeyOnEgg", 5)
GenerateInventory = Events:FindFirstChild("GenerateInventory") or Events:WaitForChild("GenerateInventory", 5)
DeletePetRemote = Events:FindFirstChild("DeletePet") or Events:WaitForChild("DeletePet", 5)
ClaimDailyRemote = Events:WaitForChild("ClaimDailyReward")
UpdateDailyRemote = Events:WaitForChild("UpdateDailyRewards")
RobuxShop = Events:FindFirstChild("RobuxShop") or Events:WaitForChild("RobuxShop", 5)
LevelData = require(Modules:WaitForChild("LevelData"))
EnemyData = require(Modules:WaitForChild("EnemyData"))
EggVendorData = {}
pcall(function()
    EggVendorData = require(Modules:WaitForChild("EggVendorData", 5))
end)
pcall(function()
    PetStatsData = require(Modules:WaitForChild("PetStats", 5))
    PetCalc = require(Modules:WaitForChild("PetCalculations", 5))
end)
pcall(function()
    UGCEvents = require(Modules:WaitForChild("CurrentUGCEvents", 5))
end)
pcall(function()
    TeleportData = require(Modules:WaitForChild("TeleportData", 5))
end)
for _, v in ipairs(PG:GetChildren()) do
    if v:FindFirstChild("Frame") and v.Frame:FindFirstChild("LoadingBG") then
        v:Destroy()
    end
end
pcall(function()
    local Event = game:GetService("ReplicatedStorage").Events.SettingsEvent
    Event:FireServer({
        OtherBullets = true,
        TradeInvites = true,
        PetBullets = true,
        Music = false,
        PetsVisible = false
    })
end)
_G.Color = _G.Color or Color3.fromRGB(240, 62, 62)
UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/emaandthw/my-Ui-Library/refs/heads/main/SwitchHub.lua"))()
do
    local lib = UI
    local rawNotify = lib.Notify
    local rawDestroy = lib.Destroy
    local rawWindow = lib.Window
    function lib:Notify(o)
        o = o or {}
        rawNotify(lib, tostring(o.Title or ""), tostring(o.Content or ""), o.Duration or 3)
        return {}
    end
    function lib:DestroyUI()
        pcall(rawDestroy, lib)
    end
    local function makeTab(rawTab)
        local tab = {}
        function tab:CreateStatus(title)
            if rawTab.Status then
                return rawTab:Status(tostring(title or "Status"))
            end
            local para = rawTab:Paragraph(tostring(title or "Status"), "Loading...")
            local st = {}
            function st:Set(newtitle, rows)
                if rows == nil then return end
                local lines = {}
                for _, r in ipairs(rows) do
                    lines[#lines + 1] = type(r) == "table" and tostring(r.text or "") or tostring(r)
                end
                pcall(function() para:Set(newtitle or title, table.concat(lines, "\n")) end)
            end
            return st
        end
        function tab:CreateSection(name, icon)
            return rawTab:Section(tostring(name or "Section"), icon)
        end
        function tab:CreateToggle(o)
            local t = rawTab:Toggle(o.Title, nil, nil, o.Callback)
            if o.Default then pcall(function() t:SetStage(true) end) end
            return t
        end
        function tab:CreateButton(o)
            rawTab:Button(o.Title, o.Callback)
            return {}
        end
        function tab:CreateSlider(o)
            local raw = rawTab:Slider(o.Title, o.Min, o.Max, o.Default, o.Callback)
            local s = {}
            function s:Set(v) pcall(function() raw:SetValue(v) end) end
            function s:Get() return raw:GetValue() end
            return s
        end
        function tab:CreateParagraph(o)
            local title = tostring(o.Title or "")
            local para = rawTab:Paragraph(title, tostring(o.Content or ""))
            local p = {}
            function p:Set(text)
                if type(self) == "string" then text = self end
                pcall(function() para:Set(title, tostring(text)) end)
            end
            return p
        end
        local function wrapDropdown(raw, baseTitle)
            local d = {}
            function d:Set(value, keep) pcall(function() raw:SetSelected(value) end) end
            function d:SetOptions(list, keep) pcall(function() raw:SetOptions(list, keep) end) end
            function d:Get() return raw:GetValue() end
            function d:SetTitle(t)
                t = tostring(t)
                if not d._label and baseTitle and not d._searched then
                    local roots = {}
                    pcall(function() if gethui then roots[#roots + 1] = gethui() end end)
                    pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
                    pcall(function() roots[#roots + 1] = game:GetService("Players").LocalPlayer.PlayerGui end)
                    local prefix = baseTitle .. " : "
                    for _, root in ipairs(roots) do
                        pcall(function()
                            for _, v in ipairs(root:GetDescendants()) do
                                if v.Name == "DropTitle" and v:IsA("TextLabel")
                                    and v.Text:sub(1, #prefix) == prefix and not v:GetAttribute("PerkTitled") then
                                    v:SetAttribute("PerkTitled", true)
                                    d._label = v
                                    break
                                end
                            end
                        end)
                        if d._label then break end
                    end
                    if not d._label then d._searched = true end
                end
                local lb = d._label
                if not lb or not lb.Parent then return false end
                d._title = t
                local function apply()
                    local want = d._title .. " : " .. tostring(raw:GetValue() or "")
                    if lb.Text ~= want then lb.Text = want end
                end
                apply()
                if not d._hooked then
                    d._hooked = true
                    lb:GetPropertyChangedSignal("Text"):Connect(function()
                        task.defer(function() pcall(apply) end)
                    end)
                end
                return true
            end
            return d
        end
        function tab:CreateDropdown(o)
            local raw = rawTab:Dropdown(o.Title, o.Default, o.Options or {}, o.Callback)
            return wrapDropdown(raw, o.Title)
        end
        function tab:CreateMultiDropdown(o)
            local raw
            local cb = o.Callback
            raw = rawTab:MultiDropdown(o.Title, o.Options or {}, o.Default or {}, function()
                if cb and raw then
                    local ok, list = pcall(function() return raw:GetValue() end)
                    cb(ok and list or {})
                end
            end)
            return wrapDropdown(raw)
        end
        return tab
    end
    TAB_ICONS = {}
    local function makeSharingan(raw)
        local CoreGui = game:GetService("CoreGui")
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local UIS = game:GetService("UserInputService")
        local teal = CoreGui:FindFirstChild("RippleToggleBtn")
        if teal then teal.Enabled = false end
        local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
        if not isMobile then return nil end
        local old = CoreGui:FindFirstChild("PnkaSharingan")
        if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "PnkaSharingan"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = CoreGui
        local btn = Instance.new("TextButton")
        btn.Name = "SharinganBtn"
        btn.Parent = gui
        btn.AnchorPoint = Vector2.new(0, 1)
        btn.Size = UDim2.new(0, 50, 0, 50)
        btn.Position = UDim2.new(0, 15, 1, -15)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.AutoButtonColor = false
        local IMAGES = {
            "rbxassetid://129621581849239",
            "rbxassetid://76829292090480",
            "rbxassetid://104188192963138",
        }
        local tomoe = {}
        for i = 1, 3 do
            local img = Instance.new("ImageLabel")
            img.Name = "Tomoe" .. i
            img.Parent = btn
            img.Size = UDim2.fromScale(1, 1)
            img.BackgroundTransparency = 1
            img.BorderSizePixel = 0
            img.Image = IMAGES[i]
            img.ScaleType = Enum.ScaleType.Fit
            img.Visible = i == 1
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = img
            tomoe[i] = img
        end
        local curTomoe = 1
        local busy = false
        local lastClick = 0
        local COOLDOWN = 0.9
        local function setTomoe(n)
            curTomoe = n
            for i, img in ipairs(tomoe) do
                img.Visible = (i == n)
            end
        end
        local function spin()
            local target = curTomoe == 1 and 3 or 1
            local dir = target > curTomoe and 1 or -1
            local steps = math.abs(target - curTomoe)
            local tw = TweenService:Create(btn, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Rotation = btn.Rotation + 180
            })
            tw:Play()
            task.spawn(function()
                for _ = 1, steps do
                    task.wait(0.8 / (steps + 1))
                    setTomoe(curTomoe + dir)
                end
            end)
            tw.Completed:Wait()
        end
        local dragging, dragInput, dragStart, startPos, holdStarted = false, nil, nil, nil, 0
        local dragged = false
        local HOLD = 0.1
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                holdStarted = tick()
                dragged = false
                dragStart = input.Position
                startPos = btn.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        holdStarted = 0
                        dragInput = nil
                    end
                end)
            end
        end)
        btn.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        RunService.RenderStepped:Connect(function()
            if holdStarted > 0 and not dragging and tick() - holdStarted >= HOLD then
                dragging = true
            end
            if dragging and dragInput and dragStart then
                local d = dragInput.Position - dragStart
                if d.Magnitude > 6 then dragged = true end
                btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if dragged then dragged = false return end
            local now = tick()
            if busy or now - lastClick < COOLDOWN then return end
            lastClick = now
            busy = true
            raw:Toggle()
            task.spawn(function()
                spin()
                busy = false
            end)
        end)
        return gui
    end
    function lib:CreateWindow(setting)
        setting = setting or {}
        if setting.Size then
            lib.WinW = setting.Size.X.Offset
            lib.WinH = setting.Size.Y.Offset
        end
        local raw = rawWindow(lib, tostring(setting.Title or setting.Name or "pnka"), tostring(setting.Subtitle or ""), tostring(setting.Version or ""), "lucide-hand-metal", Enum.KeyCode.RightControl)
        local win = {}
        local destroyed = false
        local sharinganGui = makeSharingan(raw)
        function win:CreateTab(name)
            local icon = TAB_ICONS[tostring(name)]
            return makeTab(raw:Tab(tostring(name), icon))
        end
        function win:IsDestroyed()
            return destroyed
        end
        function win:Destroy()
            destroyed = true
            pcall(function() sharinganGui:Destroy() end)
            pcall(function() raw:Close() end)
        end
        return win
    end
end
_G.FarmPunch = false
_G.AutoEquipBestGlove = false
_G.AutoOpenDoor = false
_G.AutoMagnet = false
_G.AutoAscend = false
_G.AutoFarmBoss = false
_G.AutoHatchEgg = false
_G.AutoHatchIsland = false
_G.AutoEquipBestPet = false
_G.AutoDeleteWeak = false
_G.AutoMerge = false
_G.AntiEggLag = false
_G.AntiEggLag2 = false
_G.SkipEggAnim = false
_G.NotifyEgg = false
_G.AutoUGCQuest = false
_G.AutoClaimUGCItem = false
_G.JoinDungeon = false
_G.AutoDungeon = false
_G.AutoInviteAllDungeon = false
_G.AutoClaimTask = false
_G.AutoClaimDaily = false
_G.AutoClaimGift = false
_G.AutoClaimSeasonPass = false
_G.AutoSpin = false
_G.AutoPowerCore = false
_G.AutoPowerCoreV2 = false
_G.AutoWishingWell = false
_G.AutoPetLevel = false
_G.AutoHackStation = false
_G.AutoJester = false
_G.AutoJesterUnlock = false
_G.AutoMiner = false
_G.AutoClaimChests = false
_G.AutoBuyPerks = false
_G.AutoChoosePerk = false
_G.AutoClaimMilestones = false
_G.AutoUseBoost = false
_G.AutoBuyEquipment = false
_G.AutoBuyGemShop = false
_G.AutoClaimTrophyShop = false
_G.AutoEquipBestEquipment = false
_G.DestroyNotification = false
_G.AttackNoAnimation = false
_G.FPSBoost = false
_G.FPSBoostPlus = false
_G.AntiAFK = false
_G.AutoHalloweenQuest = false
_G.AutoHalloweenShop = false
_G.AutoHalloweenBundle = false
_G.AutoEquipBestHalloweenGlove = false
_G.AutoOpenHalloweenEgg = false
_G.AutoEquipBestHalloweenPet = false
_G.AutoFarmBossHalloween = false
_G.AutoFarmPunchHalloween = false
_G.AutoHalloweenUpgrade = false
Suffix = {
    K=1e3, M=1e6, B=1e9, T=1e12, Qa=1e15,
    Qi=1e18, Sx=1e21, Sp=1e24, Oc=1e27, No=1e30, Dc=1e33,
    Ud=1e36, Dd=1e39, Td=1e42
}
DIFF = {"Easy", "Medium", "Hard", "Expert"}
RARITIES = {"Common", "Uncommon", "Rare", "Mythic", "Legendary", "Secret"}
deleteRarities = { Common = true, Uncommon = true }
notifyRarities = {}
for _, r in ipairs(RARITIES) do notifyRarities[r] = true end
bossMethod = "Instant"
bossOverride = nil
bossRun = 0
hatchSpeed = 0.1
hatchCheap = false
customWalkspeed = 16
loopWalkspeed = false
customJumppower = 50
loopJumppower = false
infJump = false
noclip = false
OriginalPunch = _G.punchAnimation
PunchAnimations = {
    ["13880699214"] = true,
    ["13880687626"] = true,
    ["13880701389"] = true
}
function isRunning()
    if not Window then return false end
    local ok, gone = pcall(function() return Window:IsDestroyed() end)
    if ok then return not gone end
    local g = PG:FindFirstChild("pnkalib GUI")
    return g ~= nil and g.Parent ~= nil
end
function num(text)
    local cleaned = (text or ""):gsub("[,%s]", "")
    local n, s = cleaned:match("^%$?([%d%.]+)(%a*)$")
    n = tonumber(n)
    return n and n * (Suffix[s] or 1)
end
function damage()
    local ok, text = pcall(function()
        return Top.Damage.TextLabel.Text
    end)
    return ok and num(text) or 0
end
function coins()
    local ok, text = pcall(function()
        return Top.Coins.TextLabel.Text
    end)
    return ok and num(text) or 0
end
function gems()
    local ok, text = pcall(function()
        return Top.Gems.TextLabel.Text
    end)
    return ok and num(text) or nil
end
unlockedCache = {}
function isUnlocked(level)
    if level <= 1 or unlockedCache[level] then return true end
    local barriers = workspace:FindFirstChild("LevelBarriers")
    local door = barriers and barriers:FindFirstChild(tostring(level))
    local open
    if door then
        open = door:FindFirstChild("TouchInterest") ~= nil or door:FindFirstChildWhichIsA("TouchTransmitter", true) ~= nil
    else
        local f = Scroll:FindFirstChild("Level" .. level)
        local locked = f and f:FindFirstChild("Locked")
        open = locked ~= nil and not locked.Visible
    end
    if open then unlockedCache[level] = true end
    return open
end
function fightVisible()
    local ok, visible = pcall(function()
        return FightUI.Visible
    end)
    if ok and type(visible) == "boolean" then
        return visible
    end
    local ok2, en = pcall(function() return FightUI.Enabled end)
    return ok2 and en or false
end
function islandCFrame(sn)
    local pos, ori
    if TeleportData then
        for _, info in ipairs(TeleportData) do
            if info.stageUnlockRequired == sn then
                pos, ori = info.position, info.orientation
                break
            end
        end
    end
    if not pos then
        local loc = RS:FindFirstChild("TeleportLocations")
        loc = loc and loc:FindFirstChild(tostring(sn))
        if loc then
            pos, ori = loc.Position, loc.Orientation
        end
    end
    if not pos then
        return nil
    end
    ori = ori or Vector3.zero
    return CFrame.new(pos + Vector3.new(0, 3, 0))
        * CFrame.fromOrientation(math.rad(ori.X), math.rad(ori.Y), math.rad(ori.Z))
end
function fixCharacterMove()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    hum.PlatformStand = false
    hum.AutoRotate = true
    hum.Sit = false
    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    local animate = char:FindFirstChild("Animate")
    if animate then
        animate.Disabled = true
        task.wait()
        animate.Disabled = false
    end
end
do
function startPunch()
    task.spawn(function()
        while _G.FarmPunch and isRunning() do
            PunchRemote:FireServer()
            task.wait(0.003)
        end
    end)
end
function startGlove()
    task.spawn(function()
        local stats = require(Modules:WaitForChild("GloveStats"))
        local last
        while _G.AutoEquipBestGlove and isRunning() do
            local dmg = damage()
            local best, multiplier
            for name, data in pairs(stats) do
                if type(data) == "table"
                    and type(data.requirement) == "number"
                    and type(data.damageMultiplier) == "number"
                    and not data.robuxPrice
                    and dmg >= data.requirement
                    and (not multiplier or data.damageMultiplier > multiplier) then
                    best = name
                    multiplier = data.damageMultiplier
                end
            end
            if best and best ~= last then
                GloveRemote:FireServer(best)
                last = best
                UI:Notify({
                    Title = "Glove",
                    Content = "Equipping: " .. best,
                    Duration = 3,
                    Type = "Success"
                })
            end
            task.wait(2)
        end
    end)
end
function openDoors()
    local levels = {}
    for level in pairs(LevelData) do
        if type(level) == "number" then
            levels[#levels + 1] = level
        end
    end
    table.sort(levels)
    local c = coins()
    for _, level in ipairs(levels) do
        if not _G.AutoOpenDoor then break end
        local data = LevelData[level]
        local cost = data.cost or math.huge
        if not isUnlocked(level) and c >= cost then
            BuyRemote:FireServer(level)
            task.wait(0.75)
            c = coins()
        end
    end
end
function startDoors()
    task.spawn(function()
        while _G.AutoOpenDoor and isRunning() do
            pcall(openDoors)
            task.wait(2)
        end
    end)
end
function startMagnet()
    task.spawn(function()
        local folder = workspace:FindFirstChild("ClientCoinsGems")
        while _G.AutoMagnet and isRunning() do
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and folder then
                for _, child in ipairs(folder:GetChildren()) do
                    if child:IsA("BasePart") then
                        child.CFrame = hrp.CFrame
                        if child:FindFirstChild("TouchInterest") and typeof(firetouchinterest) == "function" then
                            pcall(firetouchinterest, child, hrp, 0)
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end
function startAscend()
    task.spawn(function()
        local rem = Events:FindFirstChild("AscendEvent") or Events:WaitForChild("AscendEvent", 5)
        while _G.AutoAscend and isRunning() do
            if rem then
                pcall(function() rem:FireServer(true) end)
            end
            task.wait(1.5)
        end
    end)
end
reqCache = {}
function readStage(sn)
    local stage = Arenas:FindFirstChild("Stage" .. sn)
    if not stage then return false end
    local items = {}
    for i = 1, 4 do
        local ok, text = pcall(function()
            return stage[tostring(i)].SuggestedPart.BillboardGui.Frame.Number.Text
        end)
        local clean = ok and type(text) == "string" and (text:gsub("[,%s]", "")) or nil
        if not clean or not num(clean) then return false end
        local enemy = EnemyData[sn] and EnemyData[sn][i]
        local old = BossData[sn] and BossData[sn][i]
        items[i] = { name = (enemy and enemy.DisplayName) or (old and old[1]) or ("Boss " .. i), req = clean }
    end
    applyStage(sn, items)
    return true
end
function collectStage(sn)
    if readStage(sn) then
        saveBossFile()
        return true
    end
    dataBusy = true
    local ok = false
    pcall(function()
        local quiet = 0
        while isRunning() and quiet < 2.5 do
            if fightVisible() then quiet = 0 else quiet = quiet + 0.25 end
            task.wait(0.25)
        end
        if not isRunning() then return end
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local dest = islandCFrame(sn)
        if not root or not dest then return end
        local back = root.CFrame
        root.CFrame = dest
        pcall(function() LP:RequestStreamAroundAsync(dest.Position) end)
        local t = 0
        while isRunning() and t < 10 do
            if readStage(sn) then ok = true break end
            task.wait(0.25)
            t = t + 0.25
        end
        local r2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if r2 then r2.CFrame = back end
    end)
    dataBusy = false
    if ok then
        saveBossFile()
        UI:Notify({ Title = "Boss Data", Content = "Saved Stage " .. sn .. " -> " .. DATA_FILE, Duration = 3, Type = "Success" })
    else
        badStage[sn] = tick() + 30
    end
    return ok
end
loadBackupFile()
loadBossFile()
function startDataSync()
    if syncStarted then return end
    syncStarted = true
    task.spawn(function()
        while isRunning() do
            local list = {}
            for _, stage in ipairs(Arenas:GetChildren()) do
                local sn = tonumber(stage.Name:match("^Stage(%d+)$"))
                if sn then list[#list + 1] = sn end
            end
            table.sort(list)
            for _, sn in ipairs(list) do
                if not isRunning() then break end
                if not haveData[sn] and tick() >= (badStage[sn] or 0) and isUnlocked(sn) then
                    collectStage(sn)
                end
            end
            task.wait(3)
        end
    end)
end
function req(stage, mode)
    local ok, text = pcall(function()
        return Arenas[stage][mode].SuggestedPart.BillboardGui.Frame.Number.Text
    end)
    local v = ok and num(text) or nil
    local sn = tonumber(tostring(stage):match("(%d+)$"))
    local mn = tonumber(mode)
    if v then
        if sn and mn then
            reqCache[sn] = reqCache[sn] or {}
            reqCache[sn][mn] = v
        end
        return v
    end
    if sn and mn then
        local c = reqCache[sn] and reqCache[sn][mn]
        if c then return c end
        return BossReq[sn] and BossReq[sn][mn] or nil
    end
    return nil
end
function listBosses()
    local list = {}
    for _, stage in ipairs(Breakable:GetChildren()) do
        local sn = tonumber(stage.Name:match("^Stage(%d+)$"))
        if sn then
            for _, mode in ipairs(stage:GetChildren()) do
                local root = mode:FindFirstChild("HumanoidRootPart")
                local prompt = root and root:FindFirstChildOfClass("ProximityPrompt")
                local r = prompt and req(stage.Name, mode.Name)
                if r then
                    local mn = tonumber(mode.Name) or 0
                    local enemy = EnemyData[sn] and EnemyData[sn][mn]
                    list[#list + 1] = {
                        key = stage.Name .. "-" .. mode.Name,
                        label = ("%s | %s - %s | Damage: %s"):format(
                            stage.Name,
                            DIFF[mn] or ("Mode " .. mn),
                            (BossData[sn] and BossData[sn][mn] and BossData[sn][mn][1]) or (enemy and enemy.DisplayName) or "?",
                            tostring(r)
                        ),
                        sn = sn,
                        mn = mn,
                        req = r,
                        part = root,
                        prompt = prompt
                    }
                end
            end
        end
    end
    return list
end
function pickBoss()
    local list, dmg, best = listBosses(), damage(), nil
    for _, boss in ipairs(list) do
        if bossOverride then
            if boss.sn == bossOverride.sn and boss.mn == bossOverride.mn and isUnlocked(boss.sn) and boss.req <= dmg then
                return boss
            end
        elseif isUnlocked(boss.sn) and boss.req <= dmg and (not best or boss.req > best.req) then
            best = boss
        end
    end
    return best
end
lastHop, badIsland = {}, {}
function scanReqs()
    for _, stage in ipairs(Arenas:GetChildren()) do
        for _, mode in ipairs(stage:GetChildren()) do
            req(stage.Name, mode.Name)
        end
    end
end
function targetIsland()
    local dmg = damage()
    if bossOverride then
        local sn = bossOverride.sn
        if not isUnlocked(sn) then return nil end
        local r = req("Stage" .. sn, tostring(bossOverride.mn))
        if r and r > dmg then return nil end
        return sn
    end
    scanReqs()
    local list = {}
    for _, stage in ipairs(Arenas:GetChildren()) do
        local sn = tonumber(stage.Name:match("^Stage(%d+)$"))
        if sn then list[#list + 1] = sn end
    end
    table.sort(list, function(x, y) return x > y end)
    for _, sn in ipairs(list) do
        if isUnlocked(sn) and tick() >= (badIsland[sn] or 0) then
            local modes = reqCache[sn] or BossReq[sn]
            if not modes then return sn end
            for _, r in pairs(modes) do
                if r <= dmg then return sn end
            end
        end
    end
    return nil
end
function islandReady(sn)
    local stage = Breakable:FindFirstChild("Stage" .. sn)
    if not stage then return false end
    for _, mode in ipairs(stage:GetChildren()) do
        local root = mode:FindFirstChild("HumanoidRootPart")
        if root and root:FindFirstChildOfClass("ProximityPrompt") and req("Stage" .. sn, mode.Name) then
            return true
        end
    end
    return false
end
function hopNewIsland(current)
    if dataBusy or fightVisible() then return false end
    local sn = targetIsland()
    if not sn or (current and current.sn >= sn) then return false end
    if tick() - (lastHop[sn] or 0) < 8 then return false end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local dest = islandCFrame(sn)
    if not root or not dest then return false end
    lastHop[sn] = tick()
    UI:Notify({ Title = "Boss", Content = "Jumping to Stage " .. sn, Duration = 3, Type = "Info" })
    root.CFrame = dest
    pcall(function() LP:RequestStreamAroundAsync(dest.Position) end)
    local t = 0
    while _G.AutoFarmBoss and not islandReady(sn) and t < 10 do
        task.wait(0.25)
        t = t + 0.25
    end
    scanReqs()
    if not islandReady(sn) then badIsland[sn] = tick() + 30 end
    task.wait(0.3)
    return true
end
function pickBossHop()
    local boss = pickBoss()
    if hopNewIsland(boss) then boss = pickBoss() end
    return boss
end
function selectButton(on)
    if on then
        GuiService.SelectedObject = Btn
    elseif GuiService.SelectedObject == Btn then
        GuiService.SelectedObject = nil
    end
end
function tap()
    selectButton(true)
    VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    if typeof(firesignal) == "function" and Btn then
        pcall(firesignal, Btn.MouseButton1Click)
        pcall(firesignal, Btn.Activated)
    end
end
function stopFight()
    selectButton(false)
    pcall(function() FightEvent:FireServer("StopFight") end)
    task.wait(0.75)
    local char = LP.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) elseif char then char:BreakJoints() end
end
function startBossTap(id)
    task.spawn(function()
        local fired, lastTarget = false, nil
        while _G.AutoFarmBoss and bossRun == id do
            if fightVisible() then
                fired = false
                if Countdown.Text == "Tap!" then tap() else selectButton(false) end
                task.wait()
            elseif dataBusy then
                selectButton(false)
                task.wait(0.3)
            else
                selectButton(false)
                local boss = not fired and pickBossHop()
                if boss then
                    if lastTarget ~= boss.key then
                        UI:Notify({ Title = "Boss", Content = "Targeting: " .. boss.label, Duration = 3, Type = "Info" })
                        lastTarget = boss.key
                    end
                    local char = LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and boss.part.Parent then
                        root.CFrame = boss.part.CFrame * CFrame.new(0, 0, 4)
                        task.wait(0.3)
                        if _G.AutoFarmBoss then
                            FightEvent:FireServer("Fight", tonumber(boss.sn), tonumber(boss.mn))
                            fired = true
                            task.wait(1.5)
                        end
                    else
                        task.wait(1)
                    end
                else
                    lastTarget = nil
                    task.wait(fired and 0.2 or 1)
                end
            end
        end
        if not _G.AutoFarmBoss then stopFight() end
    end)
end
function startBossInstant(id)
    local function alive() return _G.AutoFarmBoss and bossRun == id end
    local function waitFight(timeout)
        local t = 0
        while alive() and not fightVisible() and t < timeout do
            task.wait(0.1)
            t = t + 0.1
        end
        return fightVisible()
    end
    task.spawn(function()
        while alive() do pcall(fixCharacterMove) task.wait(0.5) end
    end)
    task.spawn(function()
        local lastTarget = nil
        while alive() do
            if fightVisible() or dataBusy then
                task.wait(0.3)
            else
                local boss = pickBossHop()
                if boss then
                    if lastTarget ~= boss.key then
                        UI:Notify({ Title = "Boss", Content = "Targeting: " .. boss.label, Duration = 3, Type = "Info" })
                        lastTarget = boss.key
                    end
                    local char = LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and boss.part.Parent and alive() then
                        root.CFrame = boss.part.CFrame * CFrame.new(0, 0, 4)
                        task.wait(0.3)
                        FightEvent:FireServer("Fight", tonumber(boss.sn), tonumber(boss.mn))
                        if waitFight(5) then
                            pcall(function() PushEvent:FireServer(true) end)
                            while alive() and fightVisible() do
                                task.wait(0.2)
                            end
                            task.wait(0.5)
                        else
                            task.wait(0.5)
                        end
                    else
                        task.wait(1)
                    end
                else
                    lastTarget = nil
                    task.wait(1)
                end
            end
        end
    end)
end
function startBossFarm()
    bossRun = bossRun + 1
    if bossMethod == "Instant" then
        startBossInstant(bossRun)
    else
        startBossTap(bossRun)
    end
end
end
do
function buildEggOptions()
    local keys = {}
    for key, data in pairs(EggVendorData) do
        if type(data) == "table" and not data.robuxAmount and not tostring(key):find("Robux") then
            keys[#keys + 1] = tostring(key)
        end
    end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        if na then return true end
        if nb then return false end
        return a < b
    end)
    local names, toKey, toName = {}, {}, {}
    for _, key in ipairs(keys) do
        local data = EggVendorData[key]
        local name = type(data) == "table" and data.name or key
        if toKey[name] then name = name .. " (" .. key .. ")" end
        names[#names + 1] = name
        toKey[name] = key
        toName[key] = name
    end
    return names, toKey, toName
end
EggNames, EggNameToKey, EggKeyToName = buildEggOptions()
selectedEgg = EggNameToKey[EggNames[1]]
function petModels()
    local cam = workspace.CurrentCamera
    local map = cam and cam:FindFirstChild("EggOpenMap")
    return map and map:FindFirstChild("PetOpeningModels")
end
function startAntiEgg1()
    task.spawn(function()
        while _G.AntiEggLag and isRunning() do
            pcall(function()
                local models = petModels()
                local model = models and models:FindFirstChildOfClass("Model")
                if model then model:Destroy() end
            end)
            task.wait(0.05)
        end
    end)
end
function startAntiEgg2()
    task.spawn(function()
        while _G.AntiEggLag2 and isRunning() do
            pcall(function()
                local models = petModels()
                if models then
                    for _, child in ipairs(models:GetChildren()) do
                        if child:IsA("Model") then child:Destroy() end
                    end
                end
            end)
            task.wait(0.05)
        end
    end)
end
function startSkipAnim()
    task.spawn(function()
        while _G.SkipEggAnim and isRunning() do
            task.wait(0.05)
            local petUI = PG:FindFirstChild("PetOpenUI")
            if petUI and petUI.Enabled then
                petUI.Enabled = false
                pcall(function()
                    local cam = workspace.CurrentCamera
                    local egg = cam and cam:FindFirstChild("EggOpenMap")
                    if egg then egg:Destroy() end
                end)
                pcall(function()
                    PG.MainUi.Enabled = true
                    PG.OnScreenButtons.Enabled = true
                    PG.QuestDescription.Enabled = true
                    PG.FriendBoost.Enabled = true
                    PG.Reload.Enabled = true
                end)
                pcall(function()
                    if _G.returnCameraToPlayer then _G.returnCameraToPlayer() end
                end)
            end
        end
    end)
end
function startNotifyEgg()
    task.spawn(function()
        local rank = {}
        for i, name in ipairs(RARITIES) do rank[name] = i end
        local seen
        while _G.NotifyEgg and isRunning() do
            if GenerateInventory then
                local ok, _, inv = pcall(function() return GenerateInventory:InvokeServer() end)
                if ok and type(inv) == "table" then
                    local fresh = {}
                    if seen then
                        for id, pet in pairs(inv) do
                            if not seen[id] and type(pet) == "table" then fresh[#fresh + 1] = pet end
                        end
                    end
                    seen = {}
                    for id in pairs(inv) do seen[id] = true end
                    local shown, hidden = 0, 0
                    for _, pet in ipairs(fresh) do
                        local stats = PetStatsData and PetStatsData[pet.name]
                        local rarity = stats and stats.rarity or "Common"
                        if notifyRarities[rarity] then
                            if shown < 6 then
                                shown = shown + 1
                                local kind = (pet.petType and pet.petType ~= "normal") and (" [" .. tostring(pet.petType) .. "]") or ""
                                UI:Notify({
                                    Title = "Egg Hatched",
                                    Content = ("%s%s | %s"):format(tostring(pet.name), kind, rarity),
                                    Duration = 4,
                                    Type = (rank[rarity] or 1) >= 3 and "Success" or "Info"
                                })
                            else
                                hidden = hidden + 1
                            end
                        end
                    end
                    if hidden > 0 then
                        UI:Notify({ Title = "Egg Hatched", Content = "+" .. hidden .. " more pets", Duration = 2, Type = "Info" })
                    end
                end
            end
            task.wait(1.5)
        end
    end)
end
function startHatch()
    task.spawn(function()
        while _G.AutoHatchEgg and isRunning() do
            if selectedEgg and HatchEvent then
                pcall(function() HatchEvent:FireServer(selectedEgg) end)
            end
            task.wait(hatchSpeed)
        end
    end)
end
function bestIslandEgg()
    local c, best = coins(), nil
    for key, data in pairs(EggVendorData) do
        if type(data) == "table" and type(data.costAmount) == "number"
            and not data.robuxAmount and not data.gemsAmount and not data.otherCurrencyCostData and not data.isEventEgg then
            local stage = tonumber(key) or (key == "Forest2" and 1) or nil
            if stage and isUnlocked(stage) and c >= data.costAmount then
                local better
                if hatchCheap then
                    better = not best or data.costAmount < best.cost or (data.costAmount == best.cost and stage > best.stage)
                else
                    better = not best or stage > best.stage or (stage == best.stage and data.costAmount > best.cost)
                end
                if better then
                    best = { key = tostring(key), stage = stage, cost = data.costAmount, name = data.name }
                end
            end
        end
    end
    return best
end
function startHatchIsland()
    task.spawn(function()
        local lastKey, lastEquip = nil, 0
        while _G.AutoHatchIsland and isRunning() do
            local egg = bestIslandEgg()
            if egg and HatchEvent then
                if egg.key ~= lastKey then
                    lastKey = egg.key
                    UI:Notify({ Title = "Hatch", Content = "Hatching: " .. tostring(egg.name or egg.key), Duration = 3, Type = "Info" })
                end
                pcall(function() HatchEvent:FireServer(egg.key) end)
                if tick() - lastEquip >= 2 then
                    lastEquip = tick()
                    local remote = Events:FindFirstChild("EquipBest")
                    if remote then task.spawn(pcall, function() remote:InvokeServer() end) end
                end
                task.wait(hatchSpeed)
            else
                lastKey = nil
                task.wait(1)
            end
        end
    end)
end
function startPet()
    task.spawn(function()
        while _G.AutoEquipBestPet and isRunning() do
            local remote = Events:FindFirstChild("EquipBest")
            if remote then pcall(function() remote:InvokeServer() end) end
            task.wait(3)
        end
    end)
end
function weakPetIds(inv)
    local minEquipped, dmgs = nil, {}
    for id, pet in pairs(inv) do
        local stats = type(pet) == "table" and PetStatsData[pet.name]
        if stats and stats.damageMultiplier then
            local ok, dmg = pcall(PetCalc.CalculateDamage, pet.name, pet.level or 1, pet.petType)
            if ok and type(dmg) == "number" then
                dmgs[id] = dmg
                if pet.equipped == true and (not minEquipped or dmg < minEquipped) then minEquipped = dmg end
            end
        end
    end
    local ids = {}
    if not minEquipped then return ids end
    for id, dmg in pairs(dmgs) do
        local pet = inv[id]
        local stats2 = pet and PetStatsData[pet.name]
        local rarity = stats2 and stats2.rarity or "Common"
        if pet and pet.equipped ~= true and pet.petType == "normal" and (pet.level or 1) <= 1
            and not tostring(pet.name):find("^HUGE") and deleteRarities[rarity] and dmg < minEquipped then
            ids[#ids + 1] = tostring(id)
        end
    end
    return ids
end
function startDeleteWeak()
    task.spawn(function()
        while _G.AutoDeleteWeak and isRunning() do
            pcall(function()
                if not (GenerateInventory and DeletePetRemote and PetStatsData and PetCalc) then return end
                local equip = Events:FindFirstChild("EquipBest")
                if equip then pcall(function() equip:InvokeServer() end) task.wait(0.5) end
                local _, inv = GenerateInventory:InvokeServer()
                if type(inv) ~= "table" then return end
                local ids = weakPetIds(inv)
                local deleted = 0
                for i = 1, #ids, 10 do
                    if not _G.AutoDeleteWeak then break end
                    local batch = {}
                    for j = i, math.min(i + 9, #ids) do batch[#batch + 1] = ids[j] end
                    DeletePetRemote:InvokeServer("Delete", batch)
                    deleted = deleted + #batch
                    task.wait(0.3)
                end
                if deleted > 0 then
                    UI:Notify({ Title = "Delete Pets", Content = "Deleted " .. deleted .. " weak pet(s)", Duration = 3, Type = "Info" })
                end
            end)
            task.wait(3)
        end
    end)
end
MergeTypes = {
    { key = "Golden",  source = "normal", remote = "PlayerGoldenMerge",  calc = "GetGoldenCostAndChance",  gems = 30 },
    { key = "Rainbow", source = "golden", remote = "PlayerRainbowMerge", calc = "GetRainbowCostAndChance", gems = 240 },
    { key = "Demonic", source = "normal", remote = "PlayerDemonicMerge", calc = "GetDemonicCostAndChance", gems = 600 },
    { key = "Frosted", source = "normal", remote = "PlayerFrostedMerge", calc = "GetFrostedCostAndChance", gems = 900 },
}
mergeSel = { type = MergeTypes[1], name = nil, level = nil }
function mergeTypeLabel(t)
    local gems = t.gems
    if PetCalc and PetCalc[t.calc] then
        local ok, data = pcall(PetCalc[t.calc], 6)
        if ok and type(data) == "table" and data.cost then
            gems = data.cost
        end
    end
    return ("%s (%s gems)"):format(t.key, tostring(gems))
end
function mergeInventory()
    local remote = GenerateInventory or Events:FindFirstChild("GenerateInventory")
    if not remote then
        return nil
    end
    local ok, inv = pcall(function()
        local _, res = remote:InvokeServer()
        return res
    end)
    return ok and type(inv) == "table" and inv or nil
end
function mergeGroups(inv, source)
    local grouped = {}
    for id, pet in pairs(inv) do
        if type(pet) == "table" and pet.name and pet.petType == source and not pet.equipped then
            local stats = PetStatsData and PetStatsData[pet.name]
            if not PetStatsData or (stats and stats.damageMultiplier) then
                local g = grouped[pet.name]
                if not g then
                    g = {}
                    grouped[pet.name] = g
                end
                g[#g + 1] = { id = id, data = pet }
            end
        end
    end
    return grouped
end
function mergePetRows()
    local rows, seen, counts = {}, {}, {}
    local inv = mergeInventory()
    if inv then
        for name, list in pairs(mergeGroups(inv, mergeSel.type.source)) do
            for _, item in ipairs(list) do
                local petType = tostring(item.data.petType)
                local level = item.data.level or 1
                local key = name .. "|" .. petType .. "|" .. level
                counts[key] = (counts[key] or 0) + 1
                if not seen[key] then
                    seen[key] = true
                    rows[#rows + 1] = {
                        name = name,
                        petType = petType,
                        level = level,
                        key = key
                    }
                end
            end
        end
        for _, row in ipairs(rows) do
            row.count = counts[row.key]
            row.label = ("%s | %s | Lv %d | x%d"):format(row.name, row.petType, row.level, row.count)
        end
        table.sort(rows, function(a, b)
            if a.name ~= b.name then
                return a.name < b.name
            end
            return a.level > b.level
        end)
    end
    return rows
end
function mergePetName(label)
    local name, _, level = tostring(label or ""):match("^(.-) | (%S+) | Lv (%d+)")
    return name, level and tonumber(level)
end
function startAutoMerge()
    task.spawn(function()
        while _G.AutoMerge and isRunning() do
            pcall(function()
                local mt, name, selLevel = mergeSel.type, mergeSel.name, mergeSel.level
                local remote = Events:FindFirstChild(mt.remote)
                local inv = name and remote and mergeInventory()
                local list = inv and mergeGroups(inv, mt.source)[name]
                if list and #list >= 6 then
                    local ordered, selected = {}, nil
                    for _, item in ipairs(list) do
                        if not selected and selLevel and (item.data.level or 1) == selLevel then
                            selected = item
                        else
                            ordered[#ordered + 1] = item
                        end
                    end
                    table.sort(ordered, function(a, b)
                        return (a.data.level or 1) < (b.data.level or 1)
                    end)
                    if selected then
                        table.insert(ordered, 1, selected)
                    end
                    local i = 1
                    while i + 5 <= #ordered and _G.AutoMerge do
                        local batch = {}
                        for k = i, i + 5 do
                            batch[ordered[k].id] = ordered[k].data
                        end
                        remote:FireServer(batch)
                        i = i + 6
                        task.wait(0.5)
                    end
                end
                if mergeHook then
                    mergeHook()
                end
            end)
            task.wait(3)
        end
    end)
end
PET_MAX_LEVEL = 50
PET_LEVEL_BATCH = 40
petLevelSel = { name = nil, petType = nil }
petLevelStats = { batches = 0, pets = 0, last = "Idle", lastCount = nil }
function petXPTable()
    if not (PetCalc and PetCalc.GetPetXPLevels) then return nil end
    local ok, t = pcall(PetCalc.GetPetXPLevels)
    return ok and type(t) == "table" and t or nil
end
function levelFromXP(xp, tbl)
    if not tbl then return nil end
    for k, need in ipairs(tbl) do
        if xp < need then return math.min(k - 1, PET_MAX_LEVEL) end
    end
    return PET_MAX_LEVEL
end
function petLevelEligible(inv, name, petType)
    local list, equipped = {}, 0
    local stats = PetStatsData and PetStatsData[name]
    if stats and stats.hugeMultiplier then return list, equipped end
    for id, pet in pairs(inv) do
        if type(pet) == "table" and pet.name == name and pet.petType == petType
            and (pet.level or 1) < PET_MAX_LEVEL then
            if pet.equipped then
                equipped = equipped + 1
            else
                list[#list + 1] = { id = id, level = pet.level or 1, xp = pet.currentXP or 0 }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.xp ~= b.xp then return a.xp > b.xp end
        return a.level > b.level
    end)
    return list, equipped
end
function planPetBatch(list, tbl)
    if #list < 2 then return nil end
    local batch, total = { list[1] }, 10 + list[1].xp
    local cap = tbl and tbl[PET_MAX_LEVEL] or math.huge
    for i = #list, 2, -1 do
        if #batch >= PET_LEVEL_BATCH or total >= cap then break end
        batch[#batch + 1] = list[i]
        total = total + 10 + list[i].xp
    end
    if #batch < 2 then return nil end
    return batch, total
end
function petLevelRows()
    local rows, groups = {}, {}
    local inv = mergeInventory()
    if inv then
        for _, pet in pairs(inv) do
            if type(pet) == "table" and pet.name and not pet.equipped and (pet.level or 1) < PET_MAX_LEVEL then
                local stats = PetStatsData and PetStatsData[pet.name]
                if not (stats and stats.hugeMultiplier) then
                    local key = pet.name .. "|" .. tostring(pet.petType)
                    local g = groups[key]
                    if not g then
                        g = { name = pet.name, petType = pet.petType, count = 0 }
                        groups[key] = g
                        rows[#rows + 1] = g
                    end
                    g.count = g.count + 1
                end
            end
        end
        table.sort(rows, function(a, b)
            if a.name ~= b.name then return a.name < b.name end
            return tostring(a.petType) < tostring(b.petType)
        end)
        for _, r in ipairs(rows) do
            r.label = ("%s | %s | x%d"):format(r.name, tostring(r.petType), r.count)
        end
    end
    return rows
end
function petLevelParse(label)
    local name, petType = tostring(label or ""):match("^(.-) | (%S+) | x%d+$")
    return name, petType
end
function petLevelStatus()
    local sel = petLevelSel
    local lines = {}
    local have = gems()
    if not sel.name then
        lines[#lines + 1] = "Select a pet group first"
    else
        lines[#lines + 1] = ("Pet: %s (%s)"):format(sel.name, tostring(sel.petType))
        local inv = mergeInventory()
        if not inv then
            lines[#lines + 1] = "Inventory unavailable"
        else
            local tbl = petXPTable()
            local list, equipped = petLevelEligible(inv, sel.name, sel.petType)
            lines[#lines + 1] = ("Eligible: %d pets (%d equipped skipped)"):format(#list, equipped)
            if list[1] then
                local best = list[1]
                local nextNeed = tbl and tbl[best.level + 1]
                lines[#lines + 1] = nextNeed
                    and ("Best: Lv %d | XP %d/%d"):format(best.level, best.xp, nextNeed)
                    or ("Best: Lv %d | XP %d"):format(best.level, best.xp)
            end
            local batch, total = planPetBatch(list, tbl)
            if batch then
                local lv = levelFromXP(total, tbl)
                lines[#lines + 1] = ("Next batch: %d pets -> Lv %s"):format(#batch, lv and tostring(lv) or "?")
            else
                lines[#lines + 1] = "Next batch: need 2+ unequipped pets"
            end
        end
    end
    lines[#lines + 1] = "Gems: " .. (have and PCore.fmt(have) or "?")
    lines[#lines + 1] = ("Done: %d batches (%d pets used) | %s"):format(
        petLevelStats.batches, petLevelStats.pets, petLevelStats.last)
    return table.concat(lines, "\n")
end
function startPetLevel()
    task.spawn(function()
        while _G.AutoPetLevel and isRunning() do
            local delay = 2
            pcall(function()
                local sel, st = petLevelSel, petLevelStats
                local remote = Events:FindFirstChild("PetLevelEvent")
                if not sel.name then st.last = "Select a pet first"; return end
                if not remote then st.last = "PetLevelEvent not found"; return end
                local inv = mergeInventory()
                if not inv then st.last = "Inventory unavailable"; return end
                local tbl = petXPTable()
                local list = petLevelEligible(inv, sel.name, sel.petType)
                if st.lastCount and #list >= st.lastCount then
                    st.lastCount = nil
                    st.last = "No change - not enough gems?"
                    delay = 5
                    return
                end
                local batch, total = planPetBatch(list, tbl)
                if not batch then
                    st.lastCount = nil
                    st.last = "Need 2+ unequipped pets"
                    return
                end
                local ids = {}
                for _, p in ipairs(batch) do ids[p.id] = true end
                remote:FireServer(ids)
                local lv = levelFromXP(total, tbl)
                st.lastCount = #list
                st.batches = st.batches + 1
                st.pets = st.pets + #batch
                st.last = ("Fed %d pets -> Lv %s"):format(#batch, lv and tostring(lv) or "?")
                delay = 1.5
            end)
            task.wait(delay)
        end
    end)
end
end
do
BossKeywords = {
    noobBoss = { "buff noob", "noob" },
    cowboyBoss = { "cowboy noob", "cowboy" }
}
ugcBossCache = {}
ugcStatus = "Idle"
ugcOwned = { boss = false, hatch = false }
ugcTry = nil
ugcFights, ugcFightEnd = 0, 0
ugcWatching = false
function islandName(sn)
    if TeleportData then
        for _, info in ipairs(TeleportData) do
            if info.stageUnlockRequired == sn then return info.name end
        end
    end
    return "Stage " .. sn
end
function findQuestBoss(metric)
    if ugcBossCache[metric] ~= nil then return ugcBossCache[metric] or nil end
    local result = false
    for _, keyword in ipairs(BossKeywords[metric] or {}) do
        local best
        for sn, modes in pairs(EnemyData) do
            if type(sn) == "number" and type(modes) == "table" then
                for mn, data in pairs(modes) do
                    local name = type(data) == "table" and data.DisplayName
                    if type(mn) == "number" and type(name) == "string" and name:lower():find(keyword, 1, true) then
                        local isBoss = name:lower():find("boss", 1, true) ~= nil
                        local rank = (isBoss and 1000000 or 0) + mn * 1000 + sn
                        if not best or rank > best.rank then best = { sn = sn, mn = mn, name = name, rank = rank } end
                    end
                end
            end
        end
        if best then result = best break end
    end
    ugcBossCache[metric] = result
    return result or nil
end
function normName(text) return (tostring(text or ""):lower():gsub("[^%w]", "")) end
function findBossesByLabel(label)
    local text = tostring(label or ""):gsub("^%s*[Dd]efeat%s+", "")
    local want = normName(text)
    local list = {}
    if want == "" or want == "nextboss" then return list end
    for sn, modes in pairs(EnemyData) do
        if type(sn) == "number" and type(modes) == "table" then
            for mn, data in pairs(modes) do
                local name = type(data) == "table" and data.DisplayName
                if type(mn) == "number" and type(name) == "string" and normName(name) == want then
                    list[#list + 1] = { sn = sn, mn = mn, name = name, rank = mn * 1000 + sn }
                end
            end
        end
    end
    table.sort(list, function(x, y) return x.rank > y.rank end)
    return list
end
function canFightBoss(boss)
    if not isUnlocked(boss.sn) then return false end
    local need = req("Stage" .. boss.sn, tostring(boss.mn))
    return not (need and need > damage())
end
function pickNextBoss(label, value)
    local list = findBossesByLabel(label)
    if #list == 0 then ugcTry = nil return nil end
    local key = normName(label)
    if not ugcTry or ugcTry.key ~= key then
        ugcTry = { key = key, idx = 1, since = tick(), base = value, locked = false, fights = ugcFights }
    end
    if ugcTry.idx > #list then ugcTry.idx = 1 end
    if not ugcTry.locked and value ~= ugcTry.base then ugcTry.locked = true end
    if not ugcTry.locked then
        local fightDone = ugcFights > ugcTry.fights and tick() - ugcFightEnd >= 3
        local timedOut = tick() - ugcTry.since >= 120
        if fightDone or timedOut then
            ugcTry.idx = ugcTry.idx % #list + 1
            ugcTry.since = tick()
            ugcTry.fights = ugcFights
        end
        for _ = 1, #list do
            if canFightBoss(list[ugcTry.idx]) then break end
            ugcTry.idx = ugcTry.idx % #list + 1
            ugcTry.since = tick()
            ugcTry.fights = ugcFights
        end
    end
    return list[ugcTry.idx], #list
end
function activeUGCQuest()
    if not UGCEvents then return nil end
    for _, ev in pairs(UGCEvents) do
        local button = MainUI:FindFirstChild(ev.uiName)
        local ok, visible = pcall(function() return button and button.Visible end)
        if ok and visible then
            local gui = PG:FindFirstChild(ev.uiName)
            if gui and gui:FindFirstChild("Frame") then return ev, gui end
            return nil
        end
    end
    return nil
end
ugcLastRequest = 0
function ugcRequestData(gap)
    if tick() - ugcLastRequest < gap then return false end
    local folder = Events:FindFirstChild("NewUGCEvents")
    local reqData = folder and folder:FindFirstChild("RequestEventData")
    local ev = activeUGCQuest()
    if not (reqData and UGCEvents and ev) then return false end
    for key, e in pairs(UGCEvents) do
        if e == ev then
            ugcLastRequest = tick()
            pcall(function() reqData:FireServer(key) end)
            return true
        end
    end
    return false
end
function parseDuration(text)
    local total, found = 0, false
    for n, unit in tostring(text):gmatch("(%d+)%s*([hmsHMS])") do
        found = true
        unit = unit:lower()
        total = total + tonumber(n) * (unit == "h" and 3600 or unit == "m" and 60 or 1)
    end
    return found and total or nil
end
function parseProgress(qt, text)
    text = tostring(text or "")
    local a, b = text:match("(%d+%.?%d*)%s*/%s*(%d+)")
    if a then return tonumber(a) >= tonumber(b), tonumber(a), tonumber(b) end
    local left, right = text:match("^(.-)%s*/%s*(.-)$")
    local cur, need = parseDuration(left), parseDuration(right)
    if cur and need then return cur >= need, cur, need end
    local low = text:lower()
    if low:find("complete", 1, true) or low:find("done", 1, true) or text:find("✓", 1, true) then
        return true, qt.required, qt.required
    end
    local h, m, sec = text:match("^(%d+):(%d+):(%d+)$")
    if h then
        local tot = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
        return tot >= qt.required, tot, qt.required
    end
    local mm, ss = text:match("^(%d+):(%d+)$")
    if mm then
        local tot = tonumber(mm) * 60 + tonumber(ss)
        return tot >= qt.required, tot, qt.required
    end
    local n = tonumber((text:gsub("[^%d%.]", "")))
    if n then return n >= qt.required, n, qt.required end
    return false, 0, qt.required
end
function readUGCProgress(ev, gui)
    local list = {}
    local metrics = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Metrics")
    for i, qt in ipairs(ev.tasks) do
        local nameLbl = metrics and metrics:FindFirstChild(i .. "Name")
        local valueLbl = metrics and metrics:FindFirstChild(i .. "Value")
        local value = valueLbl and valueLbl.Text or "?"
        local done = parseProgress(qt, value)
        list[i] = {
            name = nameLbl and nameLbl.Text ~= "" and nameLbl.Text or qt.displayName,
            value = value,
            done = done
        }
    end
    return list
end
function ugcInfoText()
    ugcRequestData(3)
    local ev, gui = activeUGCQuest()
    if not ev then return "No active UGC quest.\nStatus: " .. (_G.AutoUGCQuest and ugcStatus or "Off") end
    local progress = readUGCProgress(ev, gui)
    local lines = { "Quest: " .. (ev.uiName:gsub("(%l)(%u)", "%1 %2")) }
    for i, qt in ipairs(ev.tasks) do
        local p = progress[i]
        local how
        if BossKeywords[qt.metric] or qt.metric == "nextBoss" then
            local boss, count = nil, 1
            if qt.metric == "nextBoss" then
                local list = findBossesByLabel(p.name)
                boss, count = list[1], #list
            else
                boss = findQuestBoss(qt.metric)
            end
            how = boss and ("Boss: " .. islandName(boss.sn) .. " (Stage " .. boss.sn .. ", " .. (DIFF[boss.mn] or ("Mode " .. boss.mn)) .. ")" .. (count > 1 and (" +" .. (count - 1) .. " same name") or ""))
                or (qt.metric == "nextBoss" and "Boss: name not shown yet" or "Boss: not found")
        elseif qt.metric == "hatchLegendaryPets" then
            how = "Hatch eggs (cheapest egg)"
        elseif qt.metric == "playtime" then
            how = "Stay in game"
        else
            how = qt.metric
        end
        lines[#lines + 1] = ("%d) %s\n   %s | %s | %s"):format(i, p.name, how, p.value, p.done and "DONE" or "TODO")
    end
    lines[#lines + 1] = "Status: " .. (_G.AutoUGCQuest and ugcStatus or "Off")
    return table.concat(lines, "\n")
end
function ugcStopHelpers()
    bossOverride = nil
    if ugcOwned.boss then _G.AutoFarmBoss = false ugcOwned.boss = false end
    if ugcOwned.hatch then _G.AutoHatchIsland = false ugcOwned.hatch = false hatchCheap = false end
end
function ugcUseBoss(target)
    if ugcOwned.hatch then _G.AutoHatchIsland = false ugcOwned.hatch = false hatchCheap = false end
    bossOverride = { sn = target.sn, mn = target.mn }
    if not _G.AutoFarmBoss then _G.AutoFarmBoss = true ugcOwned.boss = true startBossFarm() end
end
function ugcUseAnyBoss()
    if ugcOwned.hatch then _G.AutoHatchIsland = false ugcOwned.hatch = false hatchCheap = false end
    bossOverride = nil
    if not _G.AutoFarmBoss then _G.AutoFarmBoss = true ugcOwned.boss = true startBossFarm() end
end
function ugcUseHatch()
    bossOverride = nil
    if ugcOwned.boss then _G.AutoFarmBoss = false ugcOwned.boss = false end
    if not _G.AutoHatchIsland then _G.AutoHatchIsland = true ugcOwned.hatch = true hatchCheap = true startHatchIsland() end
end
function startUGCQuest()
    if not ugcWatching then
        ugcWatching = true
        task.spawn(function()
            local prev = fightVisible()
            while _G.AutoUGCQuest and isRunning() do
                local now = fightVisible()
                if prev and not now then ugcFights = ugcFights + 1 ugcFightEnd = tick() end
                prev = now
                task.wait(0.2)
            end
            ugcWatching = false
        end)
    end
    task.spawn(function()
        while _G.AutoUGCQuest and isRunning() do
            pcall(function()
                local ev, gui = activeUGCQuest()
                if not ev then ugcStatus = "No active UGC quest" ugcStopHelpers() return end
                if ugcRequestData(1.5) then task.wait(0.4) end
                local progress = readUGCProgress(ev, gui)
                local pendingAny, acted = false, false
                for i, qt in ipairs(ev.tasks) do
                    if not progress[i].done then
                        pendingAny = true
                        if BossKeywords[qt.metric] or qt.metric == "nextBoss" then
                            local boss = qt.metric == "nextBoss" and pickNextBoss(progress[i].name, progress[i].value) or findQuestBoss(qt.metric)
                            if not boss and qt.metric == "nextBoss" then
                                ugcUseAnyBoss()
                                ugcStatus = "Next Boss: farming strongest boss"
                                acted = true
                            elseif not boss then
                                ugcStatus = "Boss not found: " .. progress[i].name
                            elseif not isUnlocked(boss.sn) then
                                ugcStatus = "Locked island: " .. islandName(boss.sn)
                            else
                                local need = req("Stage" .. boss.sn, tostring(boss.mn))
                                if need and need > damage() then
                                    ugcStatus = "Need more damage: " .. progress[i].name
                                else
                                    ugcUseBoss(boss)
                                    ugcStatus = "Fighting: " .. progress[i].name
                                    acted = true
                                end
                            end
                            if acted then break end
                        elseif qt.metric == "hatchLegendaryPets" then
                            ugcUseHatch()
                            ugcStatus = "Hatching: " .. progress[i].value
                            acted = true
                            break
                        end
                    end
                end
                if not acted then
                    ugcStopHelpers()
                    if not pendingAny then ugcStatus = "All tasks completed"
                    elseif ugcStatus == "Idle" or ugcStatus:find("^Fighting") or ugcStatus:find("^Hatching") then
                        ugcStatus = "Waiting (playtime)"
                    end
                end
            end)
            task.wait(2)
        end
        ugcStopHelpers()
    end)
end
function startClaimUGCItem()
    task.spawn(function()
        local ugcEvents = Events:FindFirstChild("NewUGCEvents")
        while _G.AutoClaimUGCItem and isRunning() do
            pcall(function()
                if ugcEvents and UGCEvents then
                    local reqData = ugcEvents:FindFirstChild("RequestEventData")
                    local claimBtn = ugcEvents:FindFirstChild("ClickedEventClaimButton")
                    for k in pairs(UGCEvents) do
                        if reqData then reqData:FireServer(k) end
                        task.wait(0.05)
                        if claimBtn then claimBtn:FireServer(k) end
                    end
                end
            end)
            task.wait(3)
        end
    end)
end
end
do
DG = { Center = nil, Target = nil, Farming = false, Radius = 1200, RoomRadius = 150 }
DG_BACKUP = {
    ["1"] = {{name = "Noob", hp = "100"}, {name = "Buff Guy", hp = "1K"}, {name = "Armoured Noob", hp = "10K"}, {name = "Buff Noob", hp = "50K"}},
    ["2"] = {{name = "Cowboy", hp = "62.5K"}, {name = "Mr Cowboy", hp = "312K"}, {name = "Evil Cowboy", hp = "1.56M"}, {name = "Cowboy Noob", hp = "4.37M"}},
    ["3"] = {{name = "Cave Dweller", hp = "6.2M"}, {name = "Miner", hp = "31M"}, {name = "Demolitionist", hp = "155M"}, {name = "TNT Guy", hp = "434M"}},
    ["4"] = {{name = "Squid Noob", hp = "750M"}, {name = "Fisherman", hp = "3.75B"}, {name = "CEO", hp = "18.7B"}, {name = "Shark Boss", hp = "52.5B"}},
    ["5"] = {{name = "Bunny Noob", hp = "120B"}, {name = "Candy Robber", hp = "600B"}, {name = "Candy Thief", hp = "3T"}, {name = "Bunny Boss", hp = "8.4T"}},
    ["6"] = {{name = "Ice Skeleton", hp = "25T"}, {name = "Penguin", hp = "125T"}, {name = "Yeti", hp = "625T"}, {name = "Boss Yeti", hp = "1.75Qa"}},
    ["7"] = {{name = "Goblin", hp = "1.3Qa"}, {name = "Orc", hp = "6.5Qa"}, {name = "Orc King", hp = "26Qa"}, {name = "Toy Boss", hp = "65Qa"}},
    ["8"] = {{name = "Farmer", hp = "44Qa"}, {name = "Villager", hp = "220Qa"}, {name = "Merchant", hp = "880Qa"}, {name = "Wanderer", hp = "1.76Qi"}},
    ["9"] = {{name = "Basic Ninja", hp = "1.2Qi"}, {name = "White Ninja", hp = "6Qi"}, {name = "Dark Ninja", hp = "18Qi"}, {name = "Yellow Hair Ninja", hp = "36Qi"}},
    ["10"] = {{name = "Astronaut Noob", hp = "31Qi"}, {name = "Alien", hp = "155Qi"}, {name = "Alien Spaceman", hp = "465Qi"}, {name = "Golden Astronaut BOSS", hp = "930Qi"}},
    ["11"] = {{name = "Basic Wizard", hp = "810Qi"}, {name = "Mushroom Wizard", hp = "4.05Sx"}, {name = "Forest Wizard", hp = "12.1Sx"}, {name = "Wizard BOSS", hp = "21.8Sx"}},
    ["12"] = {{name = "Angel Noob", hp = "21Sx"}, {name = "Respected Angel", hp = "104Sx"}, {name = "Angel Commander", hp = "314Sx"}, {name = "Angel Leader", hp = "566Sx"}},
    ["13"] = {{name = "Underworld Noob", hp = "550Sx"}, {name = "Underworld Emperor", hp = "2.2Sp"}, {name = "Demon", hp = "8.25Sp"}, {name = "Lucifer", hp = "14.8Sp"}},
    ["14"] = {{name = "Scientist", hp = "14Sp"}, {name = "Research Scientist", hp = "56Sp"}, {name = "Crazy Scientist", hp = "210Sp"}, {name = "Mutant Scientist", hp = "378Sp"}},
    ["15"] = {{name = "Trainee Pirate", hp = "360Sp"}, {name = "Old Pirate", hp = "1.44Oc"}, {name = "Pirate Captain", hp = "5.4Oc"}, {name = "Pirate King", hp = "9.72Oc"}},
    ["16"] = {{name = "Explorer", hp = "8.9Oc"}, {name = "Giraffe Person", hp = "35.6Oc"}, {name = "Poacher", hp = "133Oc"}, {name = "Elephant Man", hp = "240Oc"}},
    ["17"] = {{name = "Peasant", hp = "220Oc"}, {name = "Warrior", hp = "880Oc"}, {name = "Gladiator", hp = "3.3No"}, {name = "Roman Emperor", hp = "5.94No"}},
    ["18"] = {{name = "Snowman", hp = "5.6No"}, {name = "Winter Fighter", hp = "22.4No"}, {name = "Winter Warrior", hp = "84No"}, {name = "Ice Queen", hp = "151No"}},
    ["19"] = {{name = "Friendly Robot", hp = "140No"}, {name = "Robot", hp = "560No"}, {name = "Cyborg", hp = "2.1Dc"}, {name = "Evil Cyborg", hp = "3.78Dc"}},
    ["20"] = {{name = "Lava Apprentice", hp = "3.3Dc"}, {name = "Magma Monster", hp = "13.2Dc"}, {name = "Lava Summoner", hp = "49.5Dc"}, {name = "Lava Warrior", hp = "89.1Dc"}},
    ["21"] = {{name = "Trainer Fairy", hp = "80Dc"}, {name = "Flower Fairy", hp = "320Dc"}, {name = "Fairy Queen", hp = "1.2Ud"}, {name = "Evil Fairy", hp = "2.16Ud"}},
    ["22"] = {{name = "Zombie", hp = "1.9Ud"}, {name = "Mummy", hp = "7.6Ud"}, {name = "Witch", hp = "28.5Ud"}, {name = "Vampire King", hp = "51.3Ud"}},
    ["23"] = {{name = "Cleopatra", hp = "46Ud"}, {name = "Egyptian", hp = "184Ud"}, {name = "Cobra", hp = "690Ud"}, {name = "Egyptian Cat", hp = "1.24Dd"}},
    ["24"] = {{name = "Mechanical Man", hp = "1.1Dd"}, {name = "Master Mechanic", hp = "4.4Dd"}, {name = "Cogs Worker", hp = "16.5Dd"}, {name = "Mechanical Man", hp = "29.7Dd"}},
    ["25"] = {{name = "Nebula Boy", hp = "27Dd"}, {name = "Nebula Warrior", hp = "108Dd"}, {name = "Nebula", hp = "405Dd"}, {name = "Nebula Butterfly", hp = "729Dd"}},
    ["26"] = {{name = "Boy", hp = "640Dd"}, {name = "Eagle", hp = "2.56Td"}, {name = "Dragon", hp = "9.6Td"}, {name = "Cloud Man", hp = "17.2Td"}},
    ["27"] = {{name = "Cookie Warrior", hp = "15Td"}, {name = "Donut Defender", hp = "60Td"}, {name = "Cookie Chief", hp = "225Td"}, {name = "Gingerbread Man", hp = "405Td"}},
}
task.spawn(ensureDungeonBackup)
do
    local module = Modules:FindFirstChild("DungeonData")
    local ok, data = pcall(function() return module and require(module) end)
    DG.Data = ok and data or nil
end
DG.SetTarget = Events:WaitForChild("SetTarget")
DG.Punch = Events:WaitForChild("PunchEvent")
DG.Highest, DG.NextWave, DG.Complete, DG.OpenedAt, DG.LastUpdate = nil, nil, false, nil, 0
DG.Remote = Events:FindFirstChild("DungeonEvent") or Events:WaitForChild("DungeonEvent", 5)
if DG.Remote then
    DG.Remote.OnClientEvent:Connect(function(kind, value)
        if kind == "StartGUIUpdate" and type(value) == "number" then
            DG.NextWave = value
            DG.Highest = value - 1
            DG.Complete = DG.Data ~= nil and DG.Data[value] == nil
            DG.LastUpdate = tick()
        elseif kind == "SetMaxWave" and type(value) == "number" then
            DG.Highest = value
        elseif kind == "Open" then
            DG.OpenedAt = tick()
        end
    end)
end
function DG.requestInfo()
    if DG.Remote then pcall(function() DG.Remote:FireServer("StartGUIUpdate") end) end
end
function DG.inDungeon()
    local main = PG:FindFirstChild("DungeonMain")
    return main ~= nil and main.Enabled == true
end
function DG.statusText()
    local lines = {}
    if DG.inDungeon() then
        local f = PG.DungeonMain:FindFirstChild("Frame")
        local timer = f and f:FindFirstChild("TimeBanner") and f.TimeBanner:FindFirstChild("Time")
        lines[1] = "State: In dungeon"
        lines[2] = ("Wave: %s | Enemies left: %s"):format(tostring(DG.wave(f) or "?"), tostring(DG.left(f) or "?"))
        if timer and timer.Text ~= "" then lines[#lines + 1] = "Time: " .. timer.Text end
    else
        lines[1] = "State: Not in dungeon"
        if tick() - DG.LastUpdate > 20 then
            DG.LastUpdate = tick()
            DG.requestInfo()
        end
    end
    lines[#lines + 1] = "Highest wave: " .. (DG.Highest ~= nil and tostring(DG.Highest) or "?")
    if DG.Complete then lines[#lines + 1] = "All waves cleared" end
    if DG.OpenedAt then
        lines[#lines + 1] = ("Last open notice: %ds ago"):format(math.floor(tick() - DG.OpenedAt))
    end
    return table.concat(lines, "\n")
end
function DG.setStartUI(open)
    local gui = PG:FindFirstChild("DungeonStartUI")
    if not gui then
        UI:Notify({ Title = "Dungeon", Content = "Dungeon Start UI not found", Duration = 3, Type = "Error" })
        return
    end
    local frame = gui:FindFirstChild("Frame")
    local okG, g = pcall(function() return getrenv()._G end)
    g = okG and type(g) == "table" and g or _G
    local done = false
    if frame and type(g.openUI) == "function" and type(g.closeUI) == "function" then
        done = pcall(function()
            if open and not gui.Enabled then
                g.openUI(gui, frame)
            elseif not open and gui.Enabled then
                g.closeUI(gui, frame)
            end
        end)
    end
    if not done then gui.Enabled = open end
    if open then
        if type(g.dungeonOpen) == "function" then task.spawn(pcall, g.dungeonOpen) else DG.requestInfo() end
    end
end
function dungeonStatusText() return DG.statusText() end
function setDungeonStartUI(open) DG.setStartUI(open) end
function DG.hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
function DG.frame()
    local main = PG:FindFirstChild("DungeonMain")
    return (main and main.Enabled) and main:FindFirstChild("Frame") or nil
end
function DG.left(f)
    local n = f and f:FindFirstChild("NumberLeft")
    local l = n and n:FindFirstChild("Left")
    return l and tonumber(l.Text:match("%d+"))
end
function DG.wave(f)
    local w = f and f:FindFirstChild("Wave")
    local wn = w and w:FindFirstChild("WaveNumber")
    return wn and tonumber(wn.Text:match("%d+"))
end
function DG.mobName(w)
    local data = DG.Data and w and DG.Data[w]
    local npc = data and data.NPCNames and data.NPCNames[1]
    return npc and npc.NPCName
end
function DG.float(on)
    local hrp = DG.hrp()
    if not hrp then return end
    local f = hrp:FindFirstChild("DungeonFloat")
    if on and not f then
        f = Instance.new("BodyVelocity")
        f.Name = "DungeonFloat"
        f.Velocity = Vector3.zero
        f.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        f.Parent = hrp
    elseif not on and f then
        f:Destroy()
    end
end
function DG.updateCenter(f)
    if not f then
        DG.Center = nil
        return
    end
    local hrp = DG.hrp()
    if not hrp then return end
    if not DG.Center or (hrp.Position - DG.Center).Magnitude > DG.Radius + 25 then
        DG.Center = hrp.Position
    end
end
function DG.inRoom(m)
    local root = m and m.Parent and m:FindFirstChild("HumanoidRootPart")
    return root ~= nil and DG.Center ~= nil and (root.Position - DG.Center).Magnitude <= DG.Radius + 25
end
function DG.mobs(mobName)
    local named, any = {}, {}
    local folder = Breakable:FindFirstChild("Dungeon")
    if not folder or not DG.Center then return named end
    local canOwn = typeof(isnetworkowner) == "function"
    local ownedNamed, ownedAny = {}, {}
    for _, v in ipairs(folder:GetChildren()) do
        local root = v:IsA("Model") and v:FindFirstChild("HumanoidRootPart")
        local hum = root and v:FindFirstChildOfClass("Humanoid")
        local hpGui = root and root:FindFirstChild("EnemyHealthGUI")
        local hpText = hpGui and hpGui:FindFirstChild("HealthText1")
        local alive
        if hpText then
            alive = hpText.Text ~= "" and not hpText.Text:match("^0%f[%D]")
        else
            alive = not hum or hum.Health > 0
        end
        local dist = root and (root.Position - DG.Center).Magnitude
        if root and alive and dist <= DG.Radius then
            local mine = false
            if canOwn then
                local ok, r = pcall(isnetworkowner, root)
                mine = ok and r == true
            end
            if mine or dist <= DG.RoomRadius then
                local isNamed = mobName ~= nil and v.Name == mobName
                any[#any + 1] = v
                if isNamed then named[#named + 1] = v end
                if mine then
                    ownedAny[#ownedAny + 1] = v
                    if isNamed then ownedNamed[#ownedNamed + 1] = v end
                end
            end
        end
    end
    if mobName then
        if #ownedNamed > 0 then return ownedNamed end
        return named
    end
    if #ownedAny > 0 then return ownedAny end
    return any
end
function DG.closest(list)
    local hrp = DG.hrp()
    if not hrp then return end
    local best, bestDist = nil, math.huge
    for _, v in ipairs(list) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local d = root and (root.Position - hrp.Position).Magnitude
        if d and d < bestDist then best, bestDist = v, d end
    end
    return best
end
function DG.floorY(pos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { Breakable:FindFirstChild("Dungeon") }
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character then ignore[#ignore + 1] = pl.Character end
    end
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -600, 0), params)
    return hit and hit.Position.Y
end
function DG.rootHeight(m, r)
    local hum = m:FindFirstChildOfClass("Humanoid")
    return (hum and hum.HipHeight or 2) + r.Size.Y / 2
end
DG.noCollide = setmetatable({}, { __mode = "k" })
DG.lastPull = setmetatable({}, { __mode = "k" })
DG.LeashFlat = 8
DG.LeashY = 6
DG.PullCooldown = 0.6
function DG.pull(list, base, skip)
    local floor = DG.floorY(base)
    if not floor then return end
    local now = tick()
    local n = 0
    for _, m in ipairs(list) do
        local r = m ~= skip and m.Parent and m:FindFirstChild("HumanoidRootPart")
        if r then
            n = n + 1
            if n > 14 then break end
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                pcall(function()
                    if hum.PlatformStand then hum.PlatformStand = false end
                    if hum.Sit then hum.Sit = false end
                    local st = hum:GetState()
                    if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.FallingDown
                        or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.PlatformStanding then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end)
            end
            local gx = (n % 3 - 1) * 2
            local gz = (math.floor(n / 3) % 3 - 1) * 2
            local slot = Vector3.new(base.X + gx, floor + DG.rootHeight(m, r), base.Z + gz)
            local off = r.Position - slot
            local far = Vector3.new(off.X, 0, off.Z).Magnitude > DG.LeashFlat or math.abs(off.Y) > DG.LeashY
            if far and now - (DG.lastPull[m] or 0) >= DG.PullCooldown then
                DG.lastPull[m] = now
                r.CFrame = CFrame.new(slot) * r.CFrame.Rotation
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
            end
            if not DG.noCollide[m] then
                DG.noCollide[m] = true
                for _, part in ipairs(m:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end
end
function claimDungeonReward()
    local gui = PG:FindFirstChild("DungeonFinishUI")
    local frame = gui and gui:FindFirstChild("Frame")
    local btn = frame and frame:FindFirstChild("ClaimButton")
    if not (gui and gui.Enabled and btn and btn.Visible) then return false end
    if typeof(firesignal) == "function" then
        pcall(firesignal, btn.MouseButton1Click)
        pcall(firesignal, btn.Activated)
    end
    return true
end
function startDungeonClaim()
    if DG.Claiming then return end
    DG.Claiming = true
    task.spawn(function()
        while _G.AutoDungeon and isRunning() do
            pcall(claimDungeonReward)
            task.wait(1)
        end
        DG.Claiming = false
    end)
end
function startDungeon()
    if DG.Farming then return end
    startDungeonClaim()
    DG.Farming = true
    local STUCK_TIME, SKIP_TIME = 3, 15
    local skipUntil = {}
    local watch = nil
    local function hpTextOf(m)
        local root = m and m:FindFirstChild("HumanoidRootPart")
        local gui = root and root:FindFirstChild("EnemyHealthGUI")
        return gui and gui:FindFirstChild("HealthText1")
    end
    DG.FarmThread = task.spawn(function()
        while _G.AutoDungeon and isRunning() do
            pcall(function()
                local bp = workspace:FindFirstChild("BreakableParts")
                local folder = bp and bp:FindFirstChild("Dungeon")
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not folder or not hrp then return end
                if watch then
                    local alive = watch.mob.Parent == folder
                    local hpNow = watch.hpText and watch.hpText.Text or nil
                    if not alive then
                        watch = nil
                    elseif hpNow ~= watch.lastHp then
                        watch.lastHp, watch.since = hpNow, tick()
                    elseif tick() - watch.since >= STUCK_TIME then
                        skipUntil[watch.mob] = tick() + SKIP_TIME
                        watch = nil
                    end
                end
                local best, bestDist = nil, math.huge
                for _, m in ipairs(folder:GetChildren()) do
                    local root = m:IsA("Model") and m:FindFirstChild("HumanoidRootPart")
                    if root and (not skipUntil[m] or tick() >= skipUntil[m]) then
                        local d = (root.Position - hrp.Position).Magnitude
                        if d < bestDist then best, bestDist = m, d end
                    end
                end
                if not best then return end
                if not watch or watch.mob ~= best then
                    local ht = hpTextOf(best)
                    watch = { mob = best, hpText = ht, lastHp = ht and ht.Text, since = tick() }
                end
                local root = best:FindFirstChild("HumanoidRootPart")
                DG.SetTarget:FireServer(best)
                char:PivotTo(root.CFrame + Vector3.new(0, 12.4, 0))
                DG.Punch:FireServer(best)
            end)
            task.wait()
        end
        DG.Target = nil
        DG.Farming = false
    end)
end
function startJoin()
    task.spawn(function()
        while _G.JoinDungeon and isRunning() do
            if DG.Remote and not DG.inDungeon() then
                DG.NextWave = nil
                DG.requestInfo()
                local t0 = tick()
                while DG.NextWave == nil and tick() - t0 < 2 do task.wait(0.1) end
                if DG.Complete then
                    task.wait(10)
                else
                    pcall(function() DG.Remote:FireServer("StartDungeon") end)
                    local t1 = tick()
                    while _G.JoinDungeon and isRunning() and not DG.inDungeon() and tick() - t1 < 10 do
                        task.wait(0.3)
                    end
                end
            end
            task.wait(3)
        end
    end)
end
function startInviteAllDungeon()
    task.spawn(function()
        local rem = Events:FindFirstChild("PartyEvent")
        while _G.AutoInviteAllDungeon and isRunning() do
            local main = PG:FindFirstChild("DungeonMain")
            if rem and (not main or not main.Enabled) then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP then
                        pcall(function() rem:FireServer("PartyInvite", p) end)
                        task.wait(0.1)
                    end
                end
            end
            task.wait(3)
        end
    end)
end
end
do
function startTask()
    local lastTask
    task.spawn(function()
        while _G.AutoClaimTask and isRunning() do
            local ok, id, _, prog, max = pcall(function() return QuestEvent:InvokeServer("Info") end)
            if ok and id and type(prog) == "number" and type(max) == "number" then
                if prog >= max and lastTask ~= id then
                    pcall(function() QuestEvent:InvokeServer("Claim") end)
                    lastTask = id
                elseif prog < max then
                    lastTask = nil
                end
            end
            task.wait(1)
        end
    end)
end
function claimDaily()
    pcall(function() ClaimDailyRemote:FireServer() end)
end
UpdateDailyRemote.OnClientEvent:Connect(function()
    if _G.AutoClaimDaily then task.wait(0.75) claimDaily() end
end)
function startDaily()
    task.spawn(function()
        while _G.AutoClaimDaily and isRunning() do
            claimDaily()
            task.wait(3)
        end
    end)
end
GiftRunning = false
GiftLastBlind = 0
function claimGifts()
    local remote = Events:FindFirstChild("PlaytimeRewardUpdateEvent")
    if not remote then return end
    local gui = PG:FindFirstChild("PlaytimeRewards")
    local outer = gui and gui:FindFirstChild("Frame")
    local frame = outer and outer:FindFirstChild("Frame")
    if frame then
        for i = 1, 12 do
            local gift = frame:FindFirstChild("Gift" .. i)
            local timer = gift and gift:FindFirstChild("Timer")
            if timer and timer.Text == "Claim!" then
                pcall(function() remote:FireServer(i) end)
                task.wait(0.1)
            end
        end
    elseif tick() - GiftLastBlind >= 10 then
        GiftLastBlind = tick()
        for i = 1, 12 do
            if not _G.AutoClaimGift then break end
            pcall(function() remote:FireServer(i) end)
            task.wait(0.1)
        end
    end
end
function startGift()
    if GiftRunning then return end
    GiftRunning = true
    task.spawn(function()
        while _G.AutoClaimGift and isRunning() do
            pcall(claimGifts)
            task.wait(1)
        end
        GiftRunning = false
    end)
end
SeasonPassRemote, SeasonPassData, SeasonPassLoading = nil, nil, false
function loadSeasonPass()
    if SeasonPassRemote or SeasonPassLoading then return end
    SeasonPassLoading = true
    task.spawn(function()
        local ok, remote = pcall(function()
            local loader = RS:WaitForChild("ModuleLoader", 10)
            if not loader then return nil end
            return require(loader)("RemoteHandler").GetRemoteEvent("UpdateSeasonPass")
        end)
        if ok and remote then
            remote.OnClientEvent:Connect(function(data) SeasonPassData = data end)
            SeasonPassRemote = remote
        end
        SeasonPassLoading = false
    end)
end
loadSeasonPass()
function claimSeasonPass()
    local remote = SeasonPassRemote
    local data = SeasonPassData
    if not (remote and data and data.Tier and data.Claimed and data.ClaimedPremium) then return end
    for tier = 1, data.Tier do
        if not _G.AutoClaimSeasonPass then return end
        local key = tostring(tier)
        if not data.Claimed[key] then
            pcall(function() remote:FireServer(tier, false) end)
            task.wait(0.75)
        end
        if data.Premium and not data.ClaimedPremium[key] then
            pcall(function() remote:FireServer(tier, true) end)
            task.wait(0.75)
        end
    end
end
function startSeasonPass()
    loadSeasonPass()
    task.spawn(function()
        while _G.AutoClaimSeasonPass and isRunning() do
            claimSeasonPass()
            task.wait(3)
        end
    end)
end
function spinCount()
    local ok, text = pcall(function() return MainUI.SpinWheel.SpinNumber.Text end)
    return (ok and type(text) == "string") and (tonumber(text:match("%d+")) or 0) or 0
end
function startSpin()
    task.spawn(function()
        while _G.AutoSpin and isRunning() do
            local remote = Events:FindFirstChild("SpinWheelEvent")
            if remote and spinCount() >= 1 then
                pcall(function() remote:FireServer("Spin") end)
                task.wait(0.75)
                pcall(function() remote:FireServer("SpinComplete") end)
            else
                task.wait(1)
            end
        end
    end)
end
function PowerCoreMake(remoteName, moduleName)
    local pc = { data = nil, cache = nil, bought = 0, spent = 0, last = "-", lastProbe = 0 }
    function pc.getData()
        if pc.data then return pc.data end
        local ok, data = pcall(function() return require(Modules:WaitForChild(moduleName, 5)) end)
        if ok and type(data) == "table" then pc.data = data end
        return pc.data
    end
    function pc.fmt(n)
        local str, k = tostring(math.floor(n)), nil
        repeat str, k = str:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
        return str
    end
    function pc.levels()
        local rem = Events:FindFirstChild(remoteName)
        if not rem then return nil end
        local ok, lv, step = pcall(function() return rem:InvokeServer("GetLevels") end)
        if ok and type(lv) == "number" and type(step) == "number" then return lv, step end
        return nil
    end
    function pc.state(force)
        local c = pc.cache
        if not force and c and tick() - c.t < 3 then return c.lv, c.step end
        local lv, step = pc.levels()
        pc.cache = lv and { lv = lv, step = step, t = tick() } or nil
        return lv, step
    end
    function pc.nextStep(lv, step)
        local data = pc.getData()
        if not data then return nil end
        if lv < 1 then return 1, 1 end
        if not data[lv] then return nil end
        if step < #data[lv] then return lv, step + 1 end
        if data[lv + 1] then return lv + 1, 1 end
        return nil
    end
    function pc.remaining(lv, step)
        local data = pc.getData()
        local total, steps = 0, 0
        local l, st = pc.nextStep(lv, step)
        while l do
            total = total + data[l][st].Cost
            steps = steps + 1
            l, st = pc.nextStep(l, st)
        end
        return total, steps
    end
    function pc.boosts(lv, step)
        local data = pc.getData()
        local cur = data and data[lv] and data[lv][step]
        if not cur then return "-" end
        local parts = {}
        if cur.Damage then parts[#parts + 1] = "Damage +" .. cur.Damage .. "%" end
        if lv >= 2 and cur.Coins then parts[#parts + 1] = "Wins +" .. cur.Coins .. "%" end
        if lv >= 3 and cur.Gems then parts[#parts + 1] = "Gems +" .. cur.Gems .. "%" end
        if lv >= 4 and cur.PetLuck then parts[#parts + 1] = "Pet Luck +" .. cur.PetLuck .. "%" end
        return #parts > 0 and table.concat(parts, " | ") or "-"
    end
    function pc.status()
        local data = pc.getData()
        local lv, step = pc.state(false)
        if not data or not lv then return "Power Core: unavailable" end
        local lines = {}
        local stepMax = data[lv] and #data[lv] or 8
        lines[#lines + 1] = ("Level %d/%d | Step %d/%d"):format(lv, #data, step, stepMax)
        local nl, ns = pc.nextStep(lv, step)
        if nl then
            local cost = data[nl][ns].Cost
            local have = gems()
            local total, n = pc.remaining(lv, step)
            lines[#lines + 1] = ("Next: %s Gems (Lv %d - %d/%d) | Have: %s"):format(
                pc.fmt(cost), nl, ns, #data[nl], have and pc.fmt(have) or "?")
            lines[#lines + 1] = ("To MAX: %s Gems (%d steps)"):format(pc.fmt(total), n)
        else
            lines[#lines + 1] = "MAX LEVEL"
        end
        lines[#lines + 1] = "Boosts: " .. pc.boosts(lv, step)
        lines[#lines + 1] = ("Bought: %d (-%s) | %s"):format(pc.bought, pc.fmt(pc.spent), pc.last)
        return table.concat(lines, "\n")
    end
    function pc.start(flag)
        task.spawn(function()
            local rem = Events:FindFirstChild(remoteName) or Events:WaitForChild(remoteName, 5)
            while _G[flag] and isRunning() do
                local delay = 1
                if rem and pc.getData() then
                    local lv, step = pc.state(true)
                    if not lv then
                        pc.last = "Cannot read level"
                        delay = 2
                    else
                        local nl, ns = pc.nextStep(lv, step)
                        if not nl then
                            pc.last = "MAX - nothing to buy"
                            delay = 10
                        else
                            local cost = pc.data[nl][ns].Cost
                            local have = gems()
                            local enough = not have or have >= cost
                            if enough or tick() - pc.lastProbe >= 10 then
                                if not enough then pc.lastProbe = tick() end
                                local ok, res = pcall(function() return rem:InvokeServer("PurchaseNext") end)
                                if ok and res then
                                    pc.bought = pc.bought + 1
                                    pc.spent = pc.spent + cost
                                    pc.last = ("Bought Lv %d step %d"):format(nl, ns)
                                    pc.cache = nil
                                    delay = 0.3
                                else
                                    pc.last = enough and "Purchase failed" or ("Need %s more"):format(pc.fmt(cost - have))
                                    delay = 2
                                end
                            else
                                pc.last = ("Need %s more"):format(pc.fmt(cost - have))
                                delay = 2
                            end
                        end
                    end
                end
                task.wait(delay)
            end
        end)
    end
    return pc
end
PCore = PowerCoreMake("PowerCore", "PowercoreData")
PCoreV2 = PowerCoreMake("PowerCoreV2", "PowercoreV2Data")
function startPowerCore() PCore.start("AutoPowerCore") end
function startPowerCoreV2() PCoreV2.start("AutoPowerCoreV2") end
WWOrder = { "Small", "Medium", "Mega" }
WWTiers = { Small = { Cost = 50 }, Medium = { Cost = 200 }, Mega = { Cost = 1000 } }
WWState = { tier = "Mega", thrown = 0, msg = "Idle", boosts = nil, expiry = nil }
WWNames = { Coins = "Wins", Damage = "Damage", Gems = "Gems", PetLuck = "Pet Luck" }
pcall(function()
    local data = require(Modules:WaitForChild("WishingWell", 5))
    for name, info in pairs(data) do
        WWTiers[name] = WWTiers[name] or {}
        WWTiers[name].Cost = info.Cost or WWTiers[name].Cost
    end
end)
task.spawn(function()
    local rem = Events:FindFirstChild("WishingWell") or Events:WaitForChild("WishingWell", 5)
    if not rem then return end
    rem.OnClientEvent:Connect(function(boosts, expiry)
        if type(boosts) == "table" and type(expiry) == "number" then
            WWState.boosts, WWState.expiry = boosts, expiry
            WWState.msg = "Got a boost!"
        end
    end)
end)
function fmtDur(sec)
    sec = math.max(0, math.floor(sec))
    local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
    if h > 0 then return ("%dh %02dm %02ds"):format(h, m, s) end
    return ("%dm %02ds"):format(m, s)
end
function wwActive()
    if not RobuxShop then return nil end
    local ok, list = pcall(function() return (RobuxShop:InvokeServer("Boosts")) end)
    if not ok or type(list) ~= "table" then return nil end
    local now, out = os.time(), {}
    for _, b in pairs(list) do
        if type(b) == "table" and b.WishingWell and b.ActivationTime and b.Duration then
            local left = b.ActivationTime + b.Duration - now
            if left > 0 then out[#out + 1] = { type = b.Type, left = left } end
        end
    end
    return out
end
function wwStatus()
    local active = wwActive()
    local lines = {}
    if active == nil then
        lines[#lines + 1] = "Boost: unavailable"
    elseif #active == 0 then
        lines[#lines + 1] = "Boost: none (feed gems for a surprise)"
    else
        local left = 0
        for _, b in ipairs(active) do left = math.max(left, b.left) end
        lines[#lines + 1] = "Boost: ACTIVE - " .. fmtDur(left) .. " left"
        local rolled = WWState.boosts and WWState.expiry and WWState.expiry > os.time()
        local parts = {}
        for _, b in ipairs(active) do
            local label = WWNames[b.type] or tostring(b.type)
            local pct = rolled and WWState.boosts[b.type]
            parts[#parts + 1] = pct and ("+%s%% %s"):format(tostring(pct), label) or label
        end
        lines[#lines + 1] = "Effects: " .. table.concat(parts, " | ")
    end
    local tier = WWTiers[WWState.tier]
    local cost = tier and tier.Cost
    local have = gems()
    lines[#lines + 1] = ("Tier: %s (%s gems) | Have: %s"):format(
        WWState.tier, cost and PCore.fmt(cost) or "?", have and PCore.fmt(have) or "?")
    lines[#lines + 1] = ("Thrown: %d | %s"):format(WWState.thrown, WWState.msg)
    return table.concat(lines, "\n")
end
function startWishingWell()
    task.spawn(function()
        local rem = Events:FindFirstChild("WishingWell") or Events:WaitForChild("WishingWell", 5)
        while _G.AutoWishingWell and isRunning() do
            local delay = 3
            local active = rem and wwActive()
            if not rem then
                WWState.msg = "WishingWell remote not found"
                delay = 5
            elseif active == nil then
                WWState.msg = "Cannot read boosts"
            elseif #active > 0 then
                WWState.msg = "Waiting for boost to expire"
                delay = 5
            else
                local cost = WWTiers[WWState.tier] and WWTiers[WWState.tier].Cost
                local have = gems()
                if cost and have and have < cost then
                    WWState.msg = ("Need %s more gems"):format(PCore.fmt(cost - have))
                    delay = 5
                else
                    pcall(function() rem:FireServer(WWState.tier) end)
                    WWState.thrown = WWState.thrown + 1
                    WWState.msg = "Threw " .. WWState.tier
                    delay = 6
                end
            end
            task.wait(delay)
        end
    end)
end
HackState = { price = nil, started = 0, msg = "Idle" }
HackNames = { Gems = "Gems", Coins = "Wins", Damage = "Damage", PetLuck = "Pet Luck" }
function hackInfo()
    local rem = Events:FindFirstChild("HackEvent")
    if not rem then return nil end
    local ok, info = pcall(function() return rem:InvokeServer("Info") end)
    if not ok then return nil end
    return type(info) == "table" and info or false
end
function hackPrice()
    if HackState.price then return HackState.price end
    local rem = Events:FindFirstChild("HackEvent")
    if not rem then return nil end
    local ok, price = pcall(function() return rem:InvokeServer("Price") end)
    if ok and type(price) == "number" then HackState.price = price end
    return HackState.price
end
function hackLeft(info)
    return info.Duration - (os.time() - info.ActivationTime)
end
function hackLabel(info)
    local pct = math.round((info.Multiplier - 1) * 100)
    return ("+%d%% %s"):format(pct, HackNames[info.Type] or tostring(info.Type))
end
function hackBegin()
    local rem = Events:FindFirstChild("HackEvent")
    if not rem then HackState.msg = "HackEvent not found"; return nil end
    local ok, res = pcall(function() return rem:InvokeServer("Begin") end)
    if ok and type(res) == "table" then
        HackState.started = HackState.started + 1
        HackState.msg = "Started " .. hackLabel(res)
        return res
    end
    HackState.msg = "Hack failed (not enough gems?)"
    return nil
end
function hackStatus()
    local info = hackInfo()
    local price = hackPrice()
    local have = gems()
    local lines = {}
    if info == nil then
        lines[#lines + 1] = "Hack: unavailable"
    elseif info then
        lines[#lines + 1] = ("Hack: ACTIVE - %s | %s left"):format(hackLabel(info), fmtDur(hackLeft(info)))
    else
        lines[#lines + 1] = "Hack: none"
    end
    lines[#lines + 1] = ("Price: %s gems | Have: %s"):format(
        price and PCore.fmt(price) or "?", have and PCore.fmt(have) or "?")
    lines[#lines + 1] = ("Started: %d | %s"):format(HackState.started, HackState.msg)
    return table.concat(lines, "\n")
end
function startHackStation()
    task.spawn(function()
        while _G.AutoHackStation and isRunning() do
            local delay = 3
            local info = hackInfo()
            if info == nil then
                HackState.msg = "Cannot read hack info"
                delay = 5
            elseif info then
                HackState.msg = "Waiting for boost to expire"
                delay = math.clamp(hackLeft(info) + 1, 1, 5)
            else
                local price, have = hackPrice(), gems()
                if price and have and have < price then
                    HackState.msg = ("Need %s more gems"):format(PCore.fmt(price - have))
                    delay = 5
                else
                    hackBegin()
                    delay = 4
                end
            end
            task.wait(delay)
        end
    end)
end
JesterCards = {
    { name = "FIGHTER",   pro = "+15% Damage",    con = "-5% Gems" },
    { name = "LUCKY",     pro = "+20% Pet Luck",  con = "-10% Gems" },
    { name = "WARRIOR",   pro = "+10% Damage",    con = "-20% Pet Luck" },
    { name = "PET LOVER", pro = "+1 Pet Equip",   con = "-10% Damage" },
    { name = "HOARDER",   pro = "+15% Gems",      con = "-20% Pet Luck" },
    { name = "SOLDIER",   pro = "+10% Damage",    con = "-1 Pet Equip" },
    { name = "TANK",      pro = "+200% Health",   con = "-10% Damage" },
    { name = "CRAFTER",   pro = "+10% Materials", con = "-10% Gems" },
    { name = "JEWELER",   pro = "+33% Gems",      con = "-33% Materials" },
    { name = "WELDER",    pro = "+10% Materials", con = "-10% Damage" },
}
JesterSel = {}
JesterState = { toggled = 0, bought = 0, msg = "Idle", fail = {}, buyTry = {} }
function jesterRead()
    local ui = PG:FindFirstChild("JesterUi")
    local main = ui and ui:FindFirstChild("Frame")
    local frame = main and main:FindFirstChild("cardframe")
    if not frame then return nil end
    local cards, unlocked = {}, 0
    for i = 1, #JesterCards do
        local f = frame:FindFirstChild(tostring(i))
        local locked = f and f:FindFirstChild("Locked")
        if locked then
            local btn = f:FindFirstChild("On/OffButton")
            local on = btn and btn:FindFirstChild("On")
            local isUnlocked = not locked.Visible
            cards[i] = { unlocked = isUnlocked, enabled = (isUnlocked and on ~= nil and on.Text == "On") }
            if isUnlocked then unlocked = unlocked + 1 end
        end
    end
    return cards, unlocked
end
function jesterPrice(unlocked)
    return 2 ^ unlocked * 100
end
function jesterStatus()
    local cards, unlocked = jesterRead()
    if not cards then return "Jester UI not found" end
    local lines = {}
    local have = gems()
    local total = #JesterCards
    if unlocked < total then
        lines[#lines + 1] = ("Unlocked: %d/%d | Next: %s gems | Have: %s"):format(
            unlocked, total, PCore.fmt(jesterPrice(unlocked)), have and PCore.fmt(have) or "?")
    else
        lines[#lines + 1] = ("Unlocked: %d/%d (all)"):format(unlocked, total)
    end
    local onLines, offNames, lockedIds = {}, {}, {}
    for i, info in ipairs(JesterCards) do
        local c = cards[i]
        if c then
            if not c.unlocked then
                lockedIds[#lockedIds + 1] = tostring(i)
            elseif c.enabled then
                onLines[#onLines + 1] = ("ON  %d %s: %s | %s"):format(i, info.name, info.pro, info.con)
            else
                offNames[#offNames + 1] = ("%d %s"):format(i, info.name)
            end
        end
    end
    if #onLines == 0 then lines[#lines + 1] = "ON: none" end
    for _, l in ipairs(onLines) do lines[#lines + 1] = l end
    if #offNames > 0 then lines[#lines + 1] = "Off: " .. table.concat(offNames, ", ") end
    if #lockedIds > 0 then lines[#lines + 1] = "Locked: " .. table.concat(lockedIds, ", ") end
    lines[#lines + 1] = ("Toggled: %d | Bought: %d | %s"):format(JesterState.toggled, JesterState.bought, JesterState.msg)
    return table.concat(lines, "\n")
end
function startJester()
    task.spawn(function()
        while _G.AutoJester and isRunning() do
            local rem = Events:FindFirstChild("ToggleJesterCard")
            local cards = jesterRead()
            if next(JesterSel) == nil then
                JesterState.msg = "Select cards first"
            elseif not cards then
                JesterState.msg = "Jester UI not found"
            elseif not rem then
                JesterState.msg = "ToggleJesterCard not found"
            else
                JesterState.msg = "Cards in sync"
                for i = 1, #JesterCards do
                    if not _G.AutoJester then break end
                    local c = cards[i]
                    if c and c.unlocked and c.enabled ~= (JesterSel[i] == true) then
                        local f = JesterState.fail[i] or { n = 0, t = 0 }
                        if f.n >= 3 and tick() - f.t > 30 then f.n = 0 end
                        if f.n < 3 then
                            f.n = f.n + 1
                            f.t = tick()
                            JesterState.fail[i] = f
                            pcall(function() rem:FireServer(i) end)
                            JesterState.toggled = JesterState.toggled + 1
                            JesterState.msg = ("Toggled card %d %s"):format(i, JesterCards[i].name)
                            task.wait(0.7)
                        else
                            JesterState.msg = ("Card %d not changing (server rejected?)"):format(i)
                        end
                    elseif c then
                        JesterState.fail[i] = nil
                    end
                end
            end
            task.wait(2)
        end
    end)
end
function startJesterUnlock()
    task.spawn(function()
        while _G.AutoJesterUnlock and isRunning() do
            local delay = 3
            local rem = Events:FindFirstChild("BuyJesterCard")
            local cards, unlocked = jesterRead()
            if next(JesterSel) == nil then
                JesterState.msg = "Select cards first"
            elseif not cards then
                JesterState.msg = "Jester UI not found"
            elseif not rem then
                JesterState.msg = "BuyJesterCard not found"
            else
                local target
                for i = 1, #JesterCards do
                    if JesterSel[i] and cards[i] and not cards[i].unlocked then
                        target = i
                        break
                    end
                end
                if not target then
                    JesterState.msg = "All selected cards unlocked"
                    delay = 5
                else
                    local price, have = jesterPrice(unlocked), gems()
                    local tries = JesterState.buyTry[target] or 0
                    if have and have < price then
                        JesterState.msg = ("Need %s more gems for card %d"):format(PCore.fmt(price - have), target)
                        delay = 5
                    elseif tries >= 3 then
                        JesterState.buyTry[target] = 0
                        JesterState.msg = ("Card %d not unlocking - retry later"):format(target)
                        delay = 15
                    else
                        JesterState.buyTry[target] = tries + 1
                        pcall(function() rem:FireServer(target) end)
                        JesterState.bought = JesterState.bought + 1
                        JesterState.msg = ("Bought card %d %s"):format(target, JesterCards[target].name)
                        delay = 2
                    end
                end
            end
            task.wait(delay)
        end
    end)
end
function claimChestsOnce(shouldRun, includePrompts)
    shouldRun = shouldRun or function() return true end
    local rem = Events:FindFirstChild("ChestEvent")
    local vipRem = Events:FindFirstChild("ClaimVIPChest")
    if rem then
        for chestId = 1, math.max(27, #IslandList) do
            if not shouldRun() then return end
            pcall(function() rem:FireServer(chestId) end)
            task.wait(0.1)
        end
    end
    if vipRem then
        pcall(function() vipRem:FireServer() end)
    end
    if includePrompts then
        return claimHiddenChests()
    end
end
function startClaimChests()
    task.spawn(function()
        while _G.AutoClaimChests and isRunning() do
            claimChestsOnce(function() return _G.AutoClaimChests and isRunning() end, true)
            task.wait(10)
        end
    end)
end
function redeemAllCodes()
    local codeRem = Events:FindFirstChild("CodeEvent")
    local codeMod = Modules:FindFirstChild("CodeData")
    if not codeRem then
        UI:Notify({ Title = "Codes", Content = "CodeEvent Remote not found!", Duration = 3 })
        return
    end
    local codes = {}
    pcall(function()
        if codeMod then
            for k in pairs(require(codeMod)) do
                table.insert(codes, tostring(k))
            end
        end
    end)
    if #codes == 0 then
        codes = {"10KLIKES", "SUMMER", "50KLIKES", "WELCOME", "SPOOKY", "4KLIKES", "UPD13", "100LIKES", "6KLIKES", "1KLIKES", "150K"}
    end
    task.spawn(function()
        local count = 0
        for _, c in ipairs(codes) do
            pcall(function() codeRem:InvokeServer(c) end)
            count = count + 1
            task.wait(0.2)
        end
        UI:Notify({ Title = "Codes", Content = "Redeemed " .. count .. " codes!", Duration = 3, Type = "Success" })
    end)
end
PerkUI = { sel = { "Slot 1", "None", "None" }, labelToKey = {}, dropdowns = {}, sig = "", info = {}, tried = {} }
do
    local ev = Events:FindFirstChild("GetPerkInfo")
    if ev and ev:IsA("RemoteEvent") then
        ev.OnClientEvent:Connect(function(data)
            if type(data) ~= "table" then return end
            for k, v in pairs(data) do
                local tier = tonumber(k)
                if tier and type(v) == "table" then
                    PerkUI.info[tier] = { unlocked = v.tierUnlocked ~= false, selected = v.selected }
                end
            end
        end)
    end
end
function PerkUI.gui()
    return game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("PerksShop")
end
function PerkUI.tiers()
    local list, frame = {}, nil
    pcall(function() frame = PerkUI.gui().Frame.ScrollingFrame.Frame end)
    if frame then
        for _, c in ipairs(frame:GetChildren()) do
            local n = tonumber(c.Name)
            if c:IsA("Frame") and n then list[#list + 1] = n end
        end
    end
    if #list == 0 then for i = 1, 7 do list[i] = i end end
    table.sort(list)
    return list, frame
end
function PerkUI.state(tier, frame)
    local info = PerkUI.info[tier]
    if info then return info.unlocked, info.selected end
    local tf = frame and frame:FindFirstChild(tostring(tier))
    if not tf then return nil, nil end
    local lk = tf:FindFirstChild("Locked")
    if lk and lk.Visible then return false, nil end
    local first = tf:FindFirstChild("1")
    local cb = first and first:FindFirstChild("ChooseButton")
    local selected
    if cb and not cb.Visible then
        for n = 1, 3 do
            local o = tf:FindFirstChild(tostring(n))
            local ol = o and o:FindFirstChild("Locked")
            if ol and not ol.Visible then selected = n end
        end
    end
    return true, selected
end
function PerkUI.effect(tier, n, frame)
    local tf = frame and frame:FindFirstChild(tostring(tier))
    local opt = tf and tf:FindFirstChild(tostring(n))
    if not opt then return nil end
    local cb = opt:FindFirstChild("ChooseButton")
    local lk = opt:FindFirstChild("Locked")
    for _, d in ipairs(opt:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text:find("%+")
            and not (cb and d:IsDescendantOf(cb)) and not (lk and d:IsDescendantOf(lk)) then
            local t = d.Text:gsub("<[^>]+>", ""):gsub("%s+", " ")
            return t
        end
    end
    return nil
end
function PerkUI.optionText(tier, n, frame, full)
    local eff = PerkUI.effect(tier, n, frame)
    if eff then return eff end
    local tf = frame and frame:FindFirstChild(tostring(tier))
    local opt = tf and tf:FindFirstChild(tostring(n))
    if not opt then return "?" end
    local parts = {}
    for _, d in ipairs(opt:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= "" then
            local skip = false
            for _, name in ipairs({ "Locked", "ChooseButton" }) do
                local ex = opt:FindFirstChild(name)
                if ex and d:IsDescendantOf(ex) then skip = true break end
            end
            if not skip then
                local t = d.Text:gsub("<[^>]+>", ""):gsub("%s+", " ")
                if t ~= "" and t ~= " " then parts[#parts + 1] = t end
            end
        end
    end
    local text = table.concat(parts, " - ")
    if not full and #text > 60 then text = text:sub(1, 57) .. "..." end
    return text ~= "" and text or "?"
end
function PerkUI.norm(text)
    local t = tostring(text):lower()
    t = t:gsub("%f[%w]x%s*%d[%d%.,]*", " ")
    t = t:gsub("[%d%.,%+%%%-%(%)%[%]:]", " ")
    t = t:gsub("%s+", " ")
    return (t:gsub("^%s+", ""):gsub("%s+$", ""))
end
function PerkUI.catalog()
    local tiers, frame = PerkUI.tiers()
    local byKey, order, slots = {}, {}, {}
    for _, tier in ipairs(tiers) do
        slots[tier] = {}
        for n = 1, 3 do
            local key = PerkUI.norm(PerkUI.optionText(tier, n, frame, true))
            if key ~= "" and key ~= "?" then
                slots[tier][n] = key
                if not byKey[key] then
                    byKey[key] = key:sub(1, 1):upper() .. key:sub(2, 40)
                    order[#order + 1] = key
                end
            end
        end
    end
    return byKey, order, slots
end
PerkUI.tierChoice = {}
PerkUI.tierDropdowns = {}
PerkUI.shortLines = {}
function PerkUI.ensureTierDropdowns()
    local tiers = PerkUI.tiers()
    for _, tier in ipairs(tiers) do
        if not PerkUI.tierDropdowns[tier] then
            PerkUI.tierChoice[tier] = PerkUI.tierChoice[tier] or "Auto"
            PerkUI.tierDropdowns[tier] = UpgradeTab:CreateDropdown({
                Title = ("Tier %d"):format(tier),
                Options = { "Auto", "Perk 1", "Perk 2", "Perk 3", "Skip" },
                Default = PerkUI.tierChoice[tier],
                Callback = function(value) PerkUI.tierChoice[tier] = tostring(value) end
            })
        end
    end
end
function PerkUI.pick(tier, slots)
    local c = PerkUI.tierChoice[tier]
    if c == "Skip" then return nil end
    local manual = c and tonumber(tostring(c):match("^Perk (%d)$"))
    if manual then return manual end
    for i = 1, 3 do
        local s = tostring(PerkUI.sel[i])
        local slotN = s:match("^Slot (%d)$")
        if slotN then return tonumber(slotN) end
        local key = PerkUI.labelToKey[s]
        if key and slots[tier] then
            for n = 1, 3 do
                if slots[tier][n] == key then return n end
            end
        end
    end
    return nil
end
function PerkUI.refreshOptions()
    local byKey, order = PerkUI.catalog()
    local names, map = {}, {}
    for _, key in ipairs(order) do
        local label = byKey[key]
        if not map[label] then
            names[#names + 1] = label
            map[label] = key
        end
    end
    local sig = table.concat(names, "|")
    if sig == PerkUI.sig then return end
    PerkUI.sig = sig
    PerkUI.labelToKey = map
    for i = 1, 3 do
        local dd = PerkUI.dropdowns[i]
        if dd then
            local opts = {}
            if i > 1 then opts[#opts + 1] = "None" end
            for _, l in ipairs(names) do opts[#opts + 1] = l end
            for n = 1, 3 do opts[#opts + 1] = "Slot " .. n end
            local keep = PerkUI.sel[i]
            local found = false
            for _, o in ipairs(opts) do if o == keep then found = true break end end
            if not found then keep = (i == 1) and "Slot 1" or "None" end
            dd:SetOptions(opts, false)
            PerkUI.sel[i] = keep
            dd:Set(keep, true)
        end
    end
end
function PerkUI.status()
    local tiers, frame = PerkUI.tiers()
    local _, _, slots = PerkUI.catalog()
    local lines = {}
    for _, tier in ipairs(tiers) do
        local unlocked, selected = PerkUI.state(tier, frame)
        local line
        if unlocked == nil then
            line = ("Tier %d: ?"):format(tier)
        elseif unlocked and selected then
            line = ("Tier %d: Perk %d - %s"):format(tier, selected, PerkUI.optionText(tier, selected, frame))
        else
            local n = PerkUI.pick(tier, slots)
            local plan = n and ("Perk %d - %s"):format(n, PerkUI.optionText(tier, n, frame)) or "no match"
            line = ("Tier %d: %s -> %s"):format(tier, unlocked and "Not chosen" or "Locked", plan)
        end
        lines[#lines + 1] = line
        local short
        if unlocked == nil then short = ("Tier %d"):format(tier)
        elseif unlocked and selected then short = ("Tier %d [Done] P%d %s"):format(tier, selected, PerkUI.optionText(tier, selected, frame))
        else
            local n = PerkUI.pick(tier, slots)
            short = ("Tier %d [%s] %s"):format(tier, unlocked and "Open" or "Locked",
                n and ("-> P%d %s"):format(n, PerkUI.optionText(tier, n, frame)) or "-> no match")
        end
        PerkUI.shortLines[tier] = short
    end
    return table.concat(lines, "\n")
end
function PerkUI.updateTitles()
    for tier, dd in pairs(PerkUI.tierDropdowns) do
        local t = PerkUI.shortLines[tier]
        if t then dd:SetTitle(t) end
    end
end
function startPerks()
    task.spawn(function()
        local rem = Events:FindFirstChild("BuyPerkTier")
        local sRem = Events:FindFirstChild("BuySummerPerkTier")
        while _G.AutoBuyPerks and isRunning() do
            if rem then
                local tiers, frame = PerkUI.tiers()
                for _, tier in ipairs(tiers) do
                    local unlocked = PerkUI.state(tier, frame)
                    if unlocked == false then
                        pcall(function() rem:FireServer(tier) end)
                        break
                    end
                end
            end
            if sRem then
                for tier = 1, 7 do
                    if not _G.AutoBuyPerks then break end
                    pcall(function() sRem:FireServer(tier) end)
                    task.wait(0.2)
                end
            end
            task.wait(2)
        end
    end)
end
function PerkUI.startChoose()
    task.spawn(function()
        local rem = Events:FindFirstChild("ClickedPerk")
        while _G.AutoChoosePerk and isRunning() do
            if rem then
                local tiers, frame = PerkUI.tiers()
                local _, _, slots = PerkUI.catalog()
                for _, tier in ipairs(tiers) do
                    if not _G.AutoChoosePerk then break end
                    local unlocked, selected = PerkUI.state(tier, frame)
                    if unlocked and selected == nil and tick() - (PerkUI.tried[tier] or 0) > 5 then
                        local n = PerkUI.pick(tier, slots)
                        if n then
                            PerkUI.tried[tier] = tick()
                            pcall(function() rem:FireServer(tier, n) end)
                            task.wait(0.3)
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end
function startMilestones()
    task.spawn(function()
        while _G.AutoClaimMilestones and isRunning() do
            pcall(function()
                local pg = LP:FindFirstChild("PlayerGui")
                local ui = pg and pg:FindFirstChild("Milestones")
                local frame = ui and ui:FindFirstChild("Frame")
                local sf = frame and (frame:FindFirstChild("ScrollingFrame") or frame:FindFirstChild("Scroll"))
                if sf then
                    for _, child in ipairs(sf:GetChildren()) do
                        local btn = child:FindFirstChild("Claimbutton") or child:FindFirstChild("ClaimButton")
                        if btn and btn.Visible and typeof(firesignal) == "function" then
                            pcall(firesignal, btn.MouseButton1Click)
                            task.wait(0.1)
                        end
                    end
                end
            end)
            task.wait(5)
        end
    end)
end
AbbrevSuffix = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td" }
function abbrevNum(n)
    if type(n) ~= "number" then return "?" end
    if n < 1000 then return tostring(math.floor(n)) end
    local i = 0
    while n >= 1000 and i < #AbbrevSuffix do
        n = n / 1000
        i = i + 1
    end
    return ("%.2f%s"):format(n, AbbrevSuffix[i])
end
MinerState = { claims = 0, coins = 0, gems = 0, delay = 2, msg = "Idle" }
function minerInfo()
    local rem = Events:FindFirstChild("MinerCurrency")
    if not rem then return nil end
    local ok, coins, gemsAmt, cph, gph, cap = pcall(function() return rem:InvokeServer("Info") end)
    if not ok or type(coins) ~= "number" then return nil end
    return coins, gemsAmt, cph, gph, cap
end
function minerPart()
    local hex = workspace:FindFirstChild("TouchHexagons")
    local miner = hex and hex:FindFirstChild("MinerHexagon")
    local ui = miner and miner:FindFirstChild("MinerUI")
    return ui and ui:FindFirstChild("HitboxPart")
end
function minerClaim()
    local rem = Events:FindFirstChild("MinerCurrency")
    if not rem then MinerState.msg = "MinerCurrency not found"; return false end
    local part = minerPart()
    if not part then MinerState.msg = "Miner hitbox not loaded (go near the Miner)"; return false end
    local coins, gemsAmt = minerInfo()
    local ok, res = pcall(function() return rem:InvokeServer("Claim", part) end)
    if ok and res then
        MinerState.claims = MinerState.claims + 1
        MinerState.coins = MinerState.coins + (coins or 0)
        MinerState.gems = MinerState.gems + (gemsAmt or 0)
        MinerState.msg = ("Claimed %s Wins, %s Gems"):format(abbrevNum(coins or 0), abbrevNum(gemsAmt or 0))
        return true
    end
    MinerState.msg = "Claim failed"
    return false
end
function minerStatus()
    local coins, gemsAmt, cph, gph, cap = minerInfo()
    local lines = {}
    if not coins then
        lines[#lines + 1] = "Miner: unavailable"
    else
        lines[#lines + 1] = ("Stored: %s Wins | %s Gems"):format(abbrevNum(coins), abbrevNum(gemsAmt or 0))
        lines[#lines + 1] = ("Rate: %s Wins/h | %s Gems/h"):format(abbrevNum(cph or 0), abbrevNum(gph or 0))
        if cap and cap > 0 then
            if coins >= cap then
                lines[#lines + 1] = ("Wins cap: %s (FULL - claim now)"):format(abbrevNum(cap))
            else
                local full = ""
                if cph and cph > 0 then
                    full = " - full in " .. fmtDur((cap - coins) / (cph / 3600))
                end
                lines[#lines + 1] = ("Wins cap: %s (%.1f%% full%s)"):format(abbrevNum(cap), coins / cap * 100, full)
            end
        end
    end
    lines[#lines + 1] = ("Claimed: %dx (+%s Wins, +%s Gems) | %s"):format(
        MinerState.claims, abbrevNum(MinerState.coins), abbrevNum(MinerState.gems), MinerState.msg)
    return table.concat(lines, "\n")
end
function startMiner()
    task.spawn(function()
        while _G.AutoMiner and isRunning() do
            pcall(minerClaim)
            task.wait(MinerState.delay)
        end
    end)
end
BoostNames = { "Coins", "Damage", "PetLuck" }
pcall(function()
    local data = require(Modules:WaitForChild("BundleData", 5))
    local list = {}
    for name in pairs(data.Boosts) do list[#list + 1] = name end
    if #list > 0 then table.sort(list) BoostNames = list end
end)
selectedBoosts = {}
lastBoostLabels = ""
function readBoosts()
    local ok, activeList, ownedList = pcall(function() return RobuxShop:InvokeServer("Boosts") end)
    if not ok or type(activeList) ~= "table" or type(ownedList) ~= "table" then return nil end
    local active, qty = {}, {}
    for _, b in pairs(activeList) do
        if b.ActivationTime + b.Duration > os.time() and not (b.WishingWell or b.Hack) then active[b.Type] = true end
    end
    for _, b in pairs(ownedList) do qty[b.Type] = (qty[b.Type] or 0) + b.Quantity end
    return active, qty
end
function refreshBoostDropdown(qty)
    local labels, chosen = {}, {}
    for _, name in ipairs(BoostNames) do
        local label = name .. " (" .. tostring(qty[name] or 0) .. ")"
        labels[#labels + 1] = label
        if selectedBoosts[name] then chosen[#chosen + 1] = label end
    end
    local key = table.concat(labels, "|")
    if key == lastBoostLabels then return end
    lastBoostLabels = key
    BoostDropdown:SetOptions(labels, false)
    BoostDropdown:Set(chosen, true)
end
function startUseBoost()
    task.spawn(function()
        while _G.AutoUseBoost and isRunning() do
            local active, qty = readBoosts()
            if active then
                refreshBoostDropdown(qty)
                for name in pairs(selectedBoosts) do
                    if not _G.AutoUseBoost then break end
                    if (qty[name] or 0) > 0 and not active[name] then
                        pcall(function() RobuxShop:InvokeServer("UseBoost", name) end)
                        task.wait(0.5)
                    end
                end
            end
            task.wait(3)
        end
    end)
end
EquipShop = {}
pcall(function()
    EquipShop.data = require(Modules:WaitForChild("EquipmentData", 5))
end)
function EquipShop.remote()
    return Events:FindFirstChild("EquipmentStoreEvent")
end
function EquipShop.info()
    local remote = EquipShop.remote()
    if not remote then return nil end
    local ok, info = pcall(function() return remote:InvokeServer("Info") end)
    if ok and type(info) == "table" then return info end
    return nil
end
function EquipShop.displayName(item)
    local d = EquipShop.data and EquipShop.data[item.Name]
    return (d and d.displayName) or tostring(item.Name)
end
function EquipShop.gameG()
    local ok, g = pcall(function() return getrenv()._G end)
    if ok and type(g) == "table" then return g end
    return _G
end
function EquipShop.refreshGameUI()
    local f = EquipShop.gameG().updateEquipmentGui
    if type(f) == "function" then pcall(f) end
end
function EquipShop.statusText()
    local info = EquipShop.info()
    if not info then return "Status unavailable" end
    local have = gems()
    local okText, gemText = pcall(function() return Top.Gems.TextLabel.Text end)
    local lines = { "Gems: " .. (okText and tostring(gemText) or "?") }
    for slot = 1, 3 do
        local item = info[slot]
        if item then
            local stock, price = item.Stock or 0, item.Price or 0
            local state
            if stock <= 0 then
                state = "Sold out"
            elseif have and have < price then
                state = "Not enough Gems"
            else
                state = "Can buy"
            end
            lines[#lines + 1] = ("[%d] %s (%s) | Stock: %s | %s Gems | %s"):format(
                slot, EquipShop.displayName(item), tostring(item.Rarity), tostring(stock), tostring(price), state)
        end
    end
    return table.concat(lines, "\n")
end
function EquipShop.setUI(open)
    local pg = LP:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild("EquipmentShop")
    if not gui then
        UI:Notify({ Title = "Equipment Shop", Content = "Equipment Shop UI not found", Duration = 3, Type = "Error" })
        return
    end
    local frame = gui:FindFirstChild("Frame")
    local g = EquipShop.gameG()
    local done = false
    if frame and type(g.openUI) == "function" and type(g.closeUI) == "function" then
        done = pcall(function()
            if open and not gui.Enabled then
                g.openUI(gui, frame)
            elseif not open and gui.Enabled then
                g.closeUI(gui, frame)
            end
        end)
    end
    if not done then gui.Enabled = open end
    if open then task.spawn(EquipShop.refreshGameUI) end
end
function startBuyEquipment()
    task.spawn(function()
        while _G.AutoBuyEquipment and isRunning() do
            local remote = EquipShop.remote()
            local info = remote and EquipShop.info()
            local bought = false
            if info then
                for slot = 1, 3 do
                    if not (_G.AutoBuyEquipment and isRunning()) then break end
                    local item = info[slot]
                    if item and (item.Stock or 0) > 0 then
                        local have = gems()
                        if not have or have >= (item.Price or 0) then
                            local ok, res = pcall(function() return remote:InvokeServer("Purchase", slot) end)
                            if ok and res then
                                bought = true
                                UI:Notify({ Title = "Equipment Shop", Content = ("Bought %s (%s)"):format(EquipShop.displayName(item), tostring(item.Rarity)), Duration = 2, Type = "Success" })
                            end
                            task.wait(0.5)
                        end
                    end
                end
            end
            if bought then EquipShop.refreshGameUI() end
            task.wait(2)
        end
    end)
end
GemStoreData = {}
pcall(function()
    GemStoreData = require(Modules:WaitForChild("GemStoreData", 5))
end)
GemStoreNames = {}
for name in pairs(GemStoreData) do GemStoreNames[#GemStoreNames + 1] = name end
table.sort(GemStoreNames)
if #GemStoreNames == 0 then
    GemStoreNames = { "CoinBoost", "CoinCollectionRange", "EggLuck", "GemBoost", "ScrewCopperBoltBoost", "TankSpeed" }
end
selectedGemUpgrades = {}
for _, name in ipairs(GemStoreNames) do selectedGemUpgrades[name] = true end
gemDelay = 2
gemReserve = 0
gemNotify = true
function buyGemPass(auto)
    local remote = Events:FindFirstChild("GemStoreEvent") or Events:WaitForChild("GemStoreEvent", 5)
    if not remote then return 0 end
    local ok, info = pcall(function() return remote:InvokeServer("Info") end)
    if not ok or type(info) ~= "table" then return 0 end
    local have = gems()
    local count = 0
    for _, name in ipairs(GemStoreNames) do
        if auto and not _G.AutoBuyGemShop then break end
        local tiers = GemStoreData[name]
        local level = info[name]
        local nextTier = tiers and type(level) == "number" and tiers[level + 1]
        if selectedGemUpgrades[name] and nextTier and (not have or have - gemReserve >= nextTier.Gems) then
            local bought = pcall(function() remote:InvokeServer("Purchase", name) end)
            if bought then
                count = count + 1
                if have then have = have - nextTier.Gems end
                if gemNotify then
                    local label = name:gsub("(%l)(%u)", "%1 %2")
                    UI:Notify({ Title = "Gem Shop", Content = ("%s -> Lv %d (-%d Gems)"):format(label, level + 1, nextTier.Gems), Duration = 2, Type = "Success" })
                end
            end
            task.wait(0.3)
        end
    end
    if count > 0 and type(_G.UpdateGemStoreUI) == "function" then
        pcall(_G.UpdateGemStoreUI)
    end
    return count
end
function startBuyGemShop()
    task.spawn(function()
        while _G.AutoBuyGemShop and isRunning() do
            pcall(buyGemPass, true)
            task.wait(gemDelay)
        end
    end)
end
end
task.spawn(function()
    task.wait(1)
    while isRunning() do
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if loopWalkspeed and hum.WalkSpeed ~= customWalkspeed then hum.WalkSpeed = customWalkspeed end
            if loopJumppower and hum.JumpPower ~= customJumppower then hum.JumpPower = customJumppower end
        end
        task.wait(0.2)
    end
end)
pcall(function()
    UIS.JumpRequest:Connect(function()
        if infJump and LP.Character then
            local hum = LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
end)
RunService.Stepped:Connect(function()
    if noclip and LP.Character then
        for _, part in ipairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end
end)
do
function destroyNotification(v)
    if v:IsA("TextLabel") or v:IsA("ImageLabel") then v:Destroy() end
end
function destroyCentreMessage()
    local g = PG:FindFirstChild("CentreMessage")
    if g and g:IsA("ScreenGui") then pcall(function() g:Destroy() end) end
end
function forceOnScreenTextOff()
    local gui = PG:FindFirstChild("OnScreenTextUI")
    if not gui then return end
    local function clearLabels(root)
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") then pcall(function() d:Destroy() end) end
        end
    end
    gui.Enabled = false
    clearLabels(gui)
    if OnScreenTextConn then OnScreenTextConn:Disconnect() end
    if OnScreenTextLabelConn then OnScreenTextLabelConn:Disconnect() end
    OnScreenTextConn = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if _G.DestroyNotification and gui.Enabled then
            gui.Enabled = false
        end
    end)
    OnScreenTextLabelConn = gui.DescendantAdded:Connect(function(d)
        if _G.DestroyNotification and d:IsA("TextLabel") then
            task.defer(function()
                if d.Parent then pcall(function() d:Destroy() end) end
            end)
        end
    end)
end
function startNotification()
    destroyCentreMessage()
    forceOnScreenTextOff()
    if CentreAddedConn then CentreAddedConn:Disconnect() end
    CentreAddedConn = PG.ChildAdded:Connect(function(c)
        if c.Name == "CentreMessage" and c:IsA("ScreenGui") then
            task.defer(function() if _G.DestroyNotification then pcall(function() c:Destroy() end) end end)
        end
    end)
    local CG = PG:WaitForChild("CoinGem")
    for _, v in ipairs(CG:GetDescendants()) do destroyNotification(v) end
    if NotifyConnection then NotifyConnection:Disconnect() end
    NotifyConnection = CG.DescendantAdded:Connect(function(v)
        if _G.DestroyNotification then
            task.defer(function()
                if _G.DestroyNotification and v.Parent then destroyNotification(v) end
            end)
        end
    end)
end
function stopNotification()
    if NotifyConnection then NotifyConnection:Disconnect() NotifyConnection = nil end
    if OnScreenTextConn then OnScreenTextConn:Disconnect() OnScreenTextConn = nil end
    if OnScreenTextLabelConn then OnScreenTextLabelConn:Disconnect() OnScreenTextLabelConn = nil end
    if CentreAddedConn then CentreAddedConn:Disconnect() CentreAddedConn = nil end
end
function startNoPunchAnim()
    if PunchConnection then return end
    _G.punchAnimation = function() end
    PunchConnection = RunService.RenderStepped:Connect(function()
        if not _G.AttackNoAnimation or (Window and Window:IsDestroyed()) then return end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            local anim = track.Animation
            local id = anim and anim.AnimationId:match("%d+")
            if PunchAnimations[id] then track:Stop(0) end
        end
    end)
end
function stopNoPunchAnim()
    if PunchConnection then PunchConnection:Disconnect() PunchConnection = nil end
    _G.punchAnimation = OriginalPunch
end
FPSOrig = setmetatable({}, { __mode = "k" })
FPSEnv = nil
FPSConns = {}
FPSRunId = 0
FPSRestoring = false
function fpsApply(inst)
    if FPSOrig[inst] then return end
    if inst:IsA("Terrain") then
        return
    elseif inst:IsA("BasePart") then
        FPSOrig[inst] = { Material = inst.Material, Reflectance = inst.Reflectance, CastShadow = inst.CastShadow }
        inst.Material = Enum.Material.SmoothPlastic
        inst.Reflectance = 0
        inst.CastShadow = false
    elseif inst:IsA("Decal") then
        FPSOrig[inst] = { Transparency = inst.Transparency }
        inst.Transparency = 1
    elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
        or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("PostEffect") then
        FPSOrig[inst] = { Enabled = inst.Enabled }
        inst.Enabled = false
    elseif inst:IsA("Atmosphere") then
        FPSOrig[inst] = { Density = inst.Density, Haze = inst.Haze }
        inst.Density = 0
        inst.Haze = 0
    end
end
function fpsSweep(root, runId)
    local list = root:GetDescendants()
    for i, inst in ipairs(list) do
        if runId ~= FPSRunId then return end
        pcall(fpsApply, inst)
        if i % 300 == 0 then task.wait() end
    end
end
function stopFPSBoost()
    FPSRunId = FPSRunId + 1
    for _, c in ipairs(FPSConns) do c:Disconnect() end
    FPSConns = {}
    local snapshot = {}
    for inst, props in pairs(FPSOrig) do snapshot[#snapshot + 1] = { inst, props } end
    FPSOrig = setmetatable({}, { __mode = "k" })
    local env = FPSEnv
    FPSEnv = nil
    FPSRestoring = true
    task.spawn(function()
        for i, item in ipairs(snapshot) do
            local inst, props = item[1], item[2]
            if inst.Parent then
                pcall(function()
                    for k, v in pairs(props) do inst[k] = v end
                end)
            end
            if i % 300 == 0 then task.wait() end
        end
        if env then
            pcall(function()
                for k, v in pairs(env.lighting) do Lighting[k] = v end
            end)
            local t = workspace.Terrain
            for k, v in pairs(env.terrain) do
                if k == "Decoration" then
                    if typeof(sethiddenproperty) == "function" then pcall(sethiddenproperty, t, k, v) end
                else
                    pcall(function() t[k] = v end)
                end
            end
            if env.quality then
                pcall(function() settings().Rendering.QualityLevel = env.quality end)
            end
        end
        FPSRestoring = false
    end)
end
function startFPSBoost()
    FPSRunId = FPSRunId + 1
    local runId = FPSRunId
    task.spawn(function()
        while FPSRestoring do task.wait() end
        if runId ~= FPSRunId then return end
        if not FPSEnv then
            FPSEnv = { lighting = {}, terrain = {} }
            local t = workspace.Terrain
            pcall(function()
                FPSEnv.lighting.GlobalShadows = Lighting.GlobalShadows
                FPSEnv.lighting.FogEnd = Lighting.FogEnd
            end)
            pcall(function()
                FPSEnv.terrain.WaterWaveSize = t.WaterWaveSize
                FPSEnv.terrain.WaterWaveSpeed = t.WaterWaveSpeed
                FPSEnv.terrain.WaterReflectance = t.WaterReflectance
            end)
            if typeof(gethiddenproperty) == "function" then
                pcall(function() FPSEnv.terrain.Decoration = gethiddenproperty(t, "Decoration") end)
            end
            pcall(function() FPSEnv.quality = settings().Rendering.QualityLevel end)
        end
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1e9
        end)
        pcall(function()
            local t = workspace.Terrain
            t.WaterWaveSize = 0
            t.WaterWaveSpeed = 0
            t.WaterReflectance = 0
            if typeof(sethiddenproperty) == "function" then pcall(sethiddenproperty, t, "Decoration", false) end
        end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        local function onAdded(inst)
            task.defer(function()
                if runId == FPSRunId and inst.Parent then pcall(fpsApply, inst) end
            end)
        end
        FPSConns[#FPSConns + 1] = workspace.DescendantAdded:Connect(onAdded)
        FPSConns[#FPSConns + 1] = Lighting.DescendantAdded:Connect(onAdded)
        fpsSweep(Lighting, runId)
        fpsSweep(workspace, runId)
        while runId == FPSRunId do
            if not isRunning() then
                _G.FPSBoost = false
                stopFPSBoost()
                break
            end
            task.wait(1)
        end
    end)
end
function startFPSBoostPlus()
    task.spawn(function()
        local Lighting = game:GetService("Lighting")
        local t = workspace.Terrain
        for _, path in ipairs({
            function() return Lighting.DepthOfField end,
            function() return Lighting.ColorCorrection end,
            function() return Lighting.Blur end,
            function() return Lighting.Sky end,
            function() return Lighting.Atmosphere end,
            function() return workspace.Camera.arrowBeam end,
        }) do
            pcall(function()
                local obj = path()
                if obj then obj:Destroy() end
            end)
        end
        pcall(function()
            t.WaterWaveSize = 0
            t.WaterWaveSpeed = 0
            t.WaterReflectance = 0
            t.WaterTransparency = 0
        end)
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9000000000
            Lighting.Brightness = 0
        end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        local EFFECTS = {"BlurEffect", "SunRaysEffect", "ColorCorrectionEffect", "BloomEffect", "DepthOfFieldEffect"}
        local function simplify(d)
            if not _G.FPSBoostPlus then return end
            pcall(function()
                if d:IsA("BasePart") then
                    d.Material = Enum.Material.Plastic
                    d.Reflectance = 0
                    if d:IsA("MeshPart") then
                        d.TextureID = "rbxassetid://10385902758728956"
                    end
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = 1
                elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
                    if not (d.Parent and d.Parent.Name == "RelicFire") then
                        d.Lifetime = NumberRange.new(0)
                    end
                elseif d:IsA("Explosion") then
                    d.BlastPressure = 1
                    d.BlastRadius = 1
                elseif d:IsA("Fire") or d:IsA("SpotLight") or d:IsA("Smoke") or d:IsA("Sparkles") then
                    d.Enabled = false
                end
            end)
        end
        for _, d in ipairs(game:GetDescendants()) do simplify(d) end
        for _, e in ipairs(Lighting:GetChildren()) do
            for _, name in ipairs(EFFECTS) do
                if e:IsA(name) then pcall(function() e.Enabled = false end) end
            end
        end
        local map = workspace:WaitForChild("Map", 3)
        if map then
            for _, d in ipairs(map:GetDescendants()) do
                if d:IsA("BasePart") then
                    pcall(function() d.Material = Enum.Material.SmoothPlastic end)
                elseif d:IsA("Texture") and not d:GetAttribute("Offset") then
                    pcall(function() d:Destroy() end)
                end
            end
        end
        local unloaded = game:GetService("ReplicatedStorage"):WaitForChild("Unloaded", 3)
        if unloaded then
            for _, d in ipairs(unloaded:GetDescendants()) do
                if d:IsA("BasePart") then
                    pcall(function() d.Material = Enum.Material.SmoothPlastic end)
                elseif d:IsA("Texture") and not d:GetAttribute("Offset") then
                    pcall(function() d:Destroy() end)
                end
            end
        end
        local conn = workspace.DescendantAdded:Connect(simplify)
        local conn2 = Lighting.DescendantAdded:Connect(simplify)
        while _G.FPSBoostPlus and isRunning() do task.wait(1) end
        conn:Disconnect()
        conn2:Disconnect()
    end)
end
function startAntiAFK()
    if not _G.AntiAFKConnected then
        _G.AntiAFKConnected = true
        pcall(function()
            if typeof(getconnections) == "function" then
                for _, v in pairs(getconnections(LP.Idled)) do v:Disable() end
            end
        end)
        local vu = game:GetService("VirtualUser")
        LP.Idled:Connect(function()
            if _G.AntiAFK then
                pcall(function()
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.zero)
                end)
            end
        end)
    end
end
end
IslandList = {}
if type(TeleportData) == "table" then
    for _, info in ipairs(TeleportData) do
        if type(info) == "table" and tonumber(info.stageUnlockRequired) and type(info.name) == "string" then
            IslandList[#IslandList + 1] = { stage = tonumber(info.stageUnlockRequired), name = info.name }
        end
    end
    table.sort(IslandList, function(a, b) return a.stage < b.stage end)
end
if #IslandList > 0 then
    writeJsonFile(ISLAND_BACKUP_FILE, IslandList)
end
if #IslandList == 0 then
    IslandList = IslandFallback
end
function teleportToStage(sn, name)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local cf = islandCFrame(sn)
    if hrp and cf then
        hrp.CFrame = cf
        UI:Notify({ Title = "Teleport", Content = "Teleported to " .. (name or ("Stage " .. sn)), Duration = 2, Type = "Info" })
    else
        pcall(function()
            local ev = Events:FindFirstChild("TeleportEvent")
            if ev then ev:InvokeServer("Teleport", sn) end
        end)
    end
end
do
WINDOW_TITLE = "Punch Simulator"
Window = UI:CreateWindow({
    Title = WINDOW_TITLE,
    Subtitle = "by pnka",
    Size = UDim2.fromOffset(656, 300)
})
if UI.SetNotiName then UI.SetNotiName(WINDOW_TITLE, "") end
ShopTab = Window:CreateTab("Tab Shop")
RewardsTab = ShopTab
PlayerTab = Window:CreateTab("Tab Player")
FarmTab = Window:CreateTab("Tab Main")
EggTab = Window:CreateTab("Tab Pet")
UpgradeTab = Window:CreateTab("Tab Upgrade")
DungeonTab = Window:CreateTab("Tab Dungeon")
TeleportTab = Window:CreateTab("Tab Teleport")
HalloweenTab = Window:CreateTab("Tab Halloween")
UGCTab = Window:CreateTab("Tab UGC")
SettingTab = Window:CreateTab("Tab Setting")
AccountPara = FarmTab:CreateStatus("Account Status")
task.spawn(function()
    local ACCOUNT_LABELS = {
        {"Coins", "lucide-coins", function() return MainUI.Top.Coins.TextLabel end},
        {"Damage", "lucide-swords", function() return MainUI.Top.Damage.TextLabel end},
        {"Gems", "lucide-gem", function() return MainUI.Top.Gems.TextLabel end},
        {"Bolts", "lucide-cog", function() return MainUI.Right.Bolts.TextLabel end},
        {"Copper", "lucide-package", function() return MainUI.Right.Copper.TextLabel end},
        {"Screws", "lucide-wrench", function() return MainUI.Right.Screws.TextLabel end},
    }
    local function readLabel(getter)
        local ok, lbl = pcall(getter)
        if ok and lbl then return tostring(lbl.Text) end
        return "?"
    end
    local pending = false
    local function refresh()
        if pending then return end
        pending = true
        task.defer(function()
            pending = false
            local rows = {}
            for _, item in ipairs(ACCOUNT_LABELS) do
                rows[#rows + 1] = { icon = item[2], text = item[1] .. ": " .. readLabel(item[3]) }
            end
            pcall(function() AccountPara:Set(nil, rows) end)
        end)
    end
    refresh()
    for _, item in ipairs(ACCOUNT_LABELS) do
        local ok, lbl = pcall(item[3])
        if ok and lbl then
            lbl:GetPropertyChangedSignal("Text"):Connect(refresh)
        end
    end
end)
function addToggle(tab, title, flag, onStart, onStop)
    local obj = tab:CreateToggle({
        Title = title,
        Default = false,
        Callback = function(value)
            _G[flag] = value
            if value then
                if onStart then onStart() end
            elseif onStop then
                onStop()
            end
        end
    })
    toggleObjs[flag] = { obj = obj, onStart = onStart, onStop = onStop }
    return obj
end
EquipAuto = {
    rarityRank = { Common = 1, Rare = 2, Mythic = 3, Legendary = 4, Secret = 5, Demonic = 6 },
    statPriority = {
        "damage", "petEquip", "petLuck", "eggOpen", "criticalChance", "fireSpeed",
        "coinDrops", "gemDropChance", "coinMagnet", "moveSpeed", "health"
    },
    getInventory = nil
}
function EquipAuto.slotCount()
    local pg = LP:FindFirstChild("PlayerGui")
    local eq = pg and pg:FindFirstChild("Equipment")
    local frame = eq and eq:FindFirstChild("Frame")
    local extra = frame and frame:FindFirstChild("ExtraSlots")
    if extra and extra.Visible == false then
        return 11
    end
    return 6
end
function EquipAuto.plan(inv, data)
    local statOrder = {}
    for i, st in ipairs(EquipAuto.statPriority) do
        statOrder[st] = i
    end
    local items = {}
    for id, item in pairs(inv) do
        if type(item) == "table" and type(item.name) == "string" then
            local info = data and data[item.name]
            local rank = EquipAuto.rarityRank[item.rarity] or 0
            local inc = 0
            if info and type(info.statIncrease) == "table" then
                inc = tonumber(info.statIncrease[rank]) or 0
            end
            items[#items + 1] = {
                id = id,
                equipped = item.equipped == true,
                rank = rank,
                stat = info and statOrder[info.statType] or 99,
                inc = inc
            }
        end
    end
    table.sort(items, function(a, b)
        if a.rank ~= b.rank then
            return a.rank > b.rank
        end
        if a.stat ~= b.stat then
            return a.stat < b.stat
        end
        if a.inc ~= b.inc then
            return a.inc > b.inc
        end
        if a.equipped ~= b.equipped then
            return a.equipped
        end
        return tostring(a.id) < tostring(b.id)
    end)
    local keep, unequip, equip = {}, {}, {}
    for i = 1, math.min(EquipAuto.slotCount(), #items) do
        keep[items[i].id] = true
    end
    for _, it in ipairs(items) do
        if it.equipped and not keep[it.id] then
            unequip[#unequip + 1] = it.id
        elseif keep[it.id] and not it.equipped then
            equip[#equip + 1] = it.id
        end
    end
    return unequip, equip
end
function startEquipBest()
    task.spawn(function()
        local EquipRemote = Events:FindFirstChild("EquipEquipment") or Events:WaitForChild("EquipEquipment", 5)
        local UnequipRemote = Events:FindFirstChild("UnequipEquipment") or Events:WaitForChild("UnequipEquipment", 5)
        local data
        pcall(function()
            data = require(Modules:WaitForChild("EquipmentData", 5))
        end)
        if not (EquipRemote and UnequipRemote) then
            UI:Notify({ Title = "Equipment", Content = "Equip remotes not found", Duration = 4, Type = "Error" })
            return
        end
        local lastSig, tries, warned = "", 0, false
        while _G.AutoEquipBestEquipment and isRunning() do
            local inv = EquipAuto.getInventory and EquipAuto.getInventory()
            if not inv then
                if not warned then
                    warned = true
                    UI:Notify({
                        Title = "Equipment",
                        Content = "Equipment inventory not found yet (open the Equipment menu once).",
                        Duration = 5,
                        Type = "Info"
                    })
                end
                task.wait(3)
            else
                local unequip, equip = EquipAuto.plan(inv, data)
                if #unequip == 0 and #equip == 0 then
                    lastSig, tries = "", 0
                    task.wait(3)
                else
                    local sig = table.concat(unequip, ",") .. "|" .. table.concat(equip, ",")
                    if sig == lastSig then
                        tries = tries + 1
                    else
                        lastSig, tries = sig, 1
                    end
                    if tries > 3 then
                        tries = 0
                        task.wait(20)
                    else
                        for _, id in ipairs(unequip) do
                            if not _G.AutoEquipBestEquipment then
                                break
                            end
                            UnequipRemote:FireServer(id)
                            task.wait(0.4)
                        end
                        for _, id in ipairs(equip) do
                            if not _G.AutoEquipBestEquipment then
                                break
                            end
                            EquipRemote:FireServer(id)
                            task.wait(0.4)
                        end
                        if tries == 1 then
                            UI:Notify({
                                Title = "Equipment",
                                Content = ("Equipped %d best item(s), swapped out %d"):format(#equip, #unequip),
                                Duration = 3,
                                Type = "Success"
                            })
                        end
                        task.wait(2)
                    end
                end
            end
        end
    end)
end
do
FarmTab:CreateSection("Auto Farming")
addToggle(FarmTab, "Farm Punch", "FarmPunch", startPunch)
startDataSync()
addToggle(FarmTab, "Auto Farm Boss", "AutoFarmBoss", startBossFarm)
addToggle(FarmTab, "Auto Equip Best Glove", "AutoEquipBestGlove", startGlove)
addToggle(FarmTab, "Auto Equip Best Equipment", "AutoEquipBestEquipment", startEquipBest)
addToggle(FarmTab, "Auto Open Door", "AutoOpenDoor", startDoors)
addToggle(FarmTab, "Magnet (Get Drops)", "AutoMagnet", startMagnet)
addToggle(FarmTab, "Auto Ascend", "AutoAscend", startAscend)
end
do
EggTab:CreateSection("Auto Hatching")
EggTab:CreateDropdown({
    Title = "Choose Egg",
    Options = #EggNames > 0 and EggNames or {"(no eggs found)"},
    Default = EggNames[1],
    Callback = function(value) selectedEgg = EggNameToKey[value] end
})
regCtrl("selectedEgg", function() return selectedEgg end,
    function(v) if type(v) == "string" then selectedEgg = v end end)
EggTab:CreateSlider({
    Title = "Hatch Speed (seconds)",
    Min = 0.05,
    Max = 30,
    Increment = 0.05,
    Default = 0.1,
    Callback = function(value) hatchSpeed = value end
})
addToggle(EggTab, "Auto Hatch Selected Egg", "AutoHatchEgg", startHatch)
addToggle(EggTab, "Auto Hatch By Island", "AutoHatchIsland", startHatchIsland)
EggTab:CreateSection("Pet Management")
addToggle(EggTab, "Auto Equip Best Pet", "AutoEquipBestPet", startPet)
DeleteRarityDropdown = EggTab:CreateMultiDropdown({
    Title = "Delete Pet Rarity",
    Options = RARITIES,
    Callback = function(list)
        deleteRarities = {}
        for _, rarity in ipairs(list) do
            deleteRarities[rarity] = true
        end
    end
})
DeleteRarityDropdown:Set({ "Common", "Uncommon" }, true)
addToggle(EggTab, "Auto Delete Pets", "AutoDeleteWeak", startDeleteWeak)
EggTab:CreateSection("Pet Evolution & Merging")
MergePetDropdown, MergeTypeDropdown = nil, nil
mergeRows, mergeKey = {}, ""
function refreshMergePets()
    mergeRows = mergePetRows()
    local labels = {}
    for _, row in ipairs(mergeRows) do
        labels[#labels + 1] = row.label
    end
    if #labels == 0 then
        labels = { "(no pets)" }
    end
    local key = table.concat(labels, "\n")
    if key == mergeKey then
        return
    end
    mergeKey = key
    MergePetDropdown:SetOptions(labels, false)
    local row
    for _, r in ipairs(mergeRows) do
        if r.name == mergeSel.name and r.level == mergeSel.level then
            row = r
            break
        end
    end
    if not row and mergeSel.name then
        for _, r in ipairs(mergeRows) do
            if r.name == mergeSel.name then
                row = r
                break
            end
        end
    end
    if row then
        mergeSel.name = row.name
        mergeSel.level = row.level
        MergePetDropdown:Set(row.label, true)
    else
        mergeSel.level = nil
    end
end
MergePetDropdown = EggTab:CreateDropdown({
    Title = "Select Pet  (name | type | level)",
    Options = { "(loading...)" },
    Callback = function(value)
        local name, level = mergePetName(value)
        if name then
            mergeSel.name, mergeSel.level = name, level
        end
    end
})
mergeTypeLabels = {}
for i, t in ipairs(MergeTypes) do
    mergeTypeLabels[i] = mergeTypeLabel(t)
end
MergeTypeDropdown = EggTab:CreateDropdown({
    Title = "Merge Type  (gems per 6 pets)",
    Options = mergeTypeLabels,
    Callback = function(value)
        for i, label in ipairs(mergeTypeLabels) do
            if label == value then
                mergeSel.type = MergeTypes[i]
                break
            end
        end
        mergeSel.name = nil
        mergeSel.level = nil
        mergeKey = ""
        task.spawn(refreshMergePets)
    end
})
MergeTypeDropdown:Set(mergeTypeLabels[1], true)
EggTab:CreateButton({
    Title = "Refresh Pet List",
    Callback = function()
        mergeKey = ""
        task.spawn(refreshMergePets)
    end
})
mergeHook = refreshMergePets
task.spawn(function()
    while isRunning() do
        pcall(refreshMergePets)
        task.wait(1.5)
    end
end)
addToggle(EggTab, "Auto Merge Pet", "AutoMerge", startAutoMerge)
EggTab:CreateSection("Pet Levels")
PetLevelDropdown = nil
petLevelKey = ""
function refreshPetLevels()
    local rows = petLevelRows()
    local labels = {}
    for _, row in ipairs(rows) do
        labels[#labels + 1] = row.label
    end
    if #labels == 0 then
        labels = { "(no pets)" }
    end
    local key = table.concat(labels, "\n")
    if key == petLevelKey then
        return
    end
    petLevelKey = key
    PetLevelDropdown:SetOptions(labels, false)
    local row
    for _, r in ipairs(rows) do
        if r.name == petLevelSel.name and r.petType == petLevelSel.petType then
            row = r
            break
        end
    end
    if row then
        PetLevelDropdown:Set(row.label, true)
    else
        petLevelSel.name, petLevelSel.petType = nil, nil
    end
end
PetLevelParagraph = EggTab:CreateParagraph({ Title = "Pet Level Status", Content = "Loading..." })
PetLevelDropdown = EggTab:CreateDropdown({
    Title = "Select Pet  (name | type | count)",
    Options = { "(loading...)" },
    Callback = function(value)
        local name, petType = petLevelParse(value)
        if name then
            petLevelSel.name = name
            for _, r in ipairs(petLevelRows()) do
                if r.name == name and tostring(r.petType) == petType then
                    petLevelSel.petType = r.petType
                    break
                end
            end
        end
    end
})
EggTab:CreateButton({
    Title = "Refresh Pet Level List",
    Callback = function()
        petLevelKey = ""
        task.spawn(refreshPetLevels)
    end
})
task.spawn(function()
    while isRunning() do
        pcall(refreshPetLevels)
        local ok, text = pcall(petLevelStatus)
        pcall(PetLevelParagraph.Set, PetLevelParagraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
addToggle(EggTab, "Auto Level Pet (merge same pets for XP)", "AutoPetLevel", startPetLevel)
end
do
UGCTab:CreateSection("UGC Quest Tracker")
UGCParagraph = UGCTab:CreateParagraph({ Title = "UGC Quest", Content = "Loading..." })
addToggle(UGCTab, "Auto Complete UGC Quest", "AutoUGCQuest", startUGCQuest, function()
    ugcStatus = "Idle"
    ugcStopHelpers()
end)
addToggle(UGCTab, "Auto Claim UGC Items", "AutoClaimUGCItem", startClaimUGCItem)
UGCTab:CreateButton({
    Title = "Copy Discord Server",
    Callback = function()
        local link = "https://discord.gg/habitgames"
        if typeof(setclipboard) == "function" then
            setclipboard(link)
            pcall(function()
                UI:Notify({Title = "Discord", Content = "Discord link copied", Duration = 3})
            end)
        else
            pcall(function()
                UI:Notify({Title = "Discord", Content = link, Duration = 5})
            end)
        end
    end
})
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(ugcInfoText)
        pcall(UGCParagraph.Set, UGCParagraph, ok and text or "Quest info unavailable")
        task.wait(1.5)
    end
end)
end
do
MD_mainName = nil
MD_helpers = {}
MD_invited = {}
MD_partyData = nil
function MD_containsName(t, name, depth)
    if type(t) ~= "table" or depth <= 0 then return false end
    for _, v in pairs(t) do
        if v == name then return true end
        if typeof(v) == "Instance" and v:IsA("Player") and v.Name == name then return true end
        if type(v) == "table" and MD_containsName(v, name, depth - 1) then return true end
    end
    return false
end
function MD_isJoined(name)
    return MD_containsName(MD_partyData, name, 3)
end
function MD_inviteState(name)
    local ok, txt = pcall(function()
        return PG:FindFirstChild("DungeonStartUI").Frame.Friends.ScrollingFrame[name].HasJoined.Text
    end)
    if ok then return txt end
    return nil
end
function MD_normalize(v)
    local out = {}
    if type(v) == "string" then
        out[v] = true
    elseif type(v) == "table" then
        for k, val in pairs(v) do
            if type(val) == "string" then out[val] = true
            elseif val == true and type(k) == "string" then out[k] = true end
        end
    end
    return out
end
function MD_playerNames()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(t, p.Name)
    end
    table.sort(t)
    return t
end
function MD_statusText()
    if not MD_mainName or MD_mainName == "" then
        return "No main account selected"
    end
    if LP.Name == MD_mainName then
        local names = {}
        for name in pairs(MD_helpers) do
            if name ~= LP.Name then table.insert(names, name) end
        end
        table.sort(names)
        if #names == 0 then return "No help account selected" end
        local lines = { "Main: " .. LP.Name .. " (leader)" }
        local joined = 0
        local inServer = 0
        for _, name in ipairs(names) do
            local st = MD_inviteState(name)
            local state
            if not Players:FindFirstChild(name) then
                state = "Offline"
            elseif st == "In Party" then
                inServer = inServer + 1
                state = "Joined"
                joined = joined + 1
            elseif st == "Invited" then
                inServer = inServer + 1
                state = "Invited, waiting to accept"
            elseif st == "Tap to invite" then
                inServer = inServer + 1
                state = "Not invited"
            else
                inServer = inServer + 1
                state = "Unknown, open the Dungeon panel to refresh"
            end
            table.insert(lines, name .. ": " .. state)
        end
        table.insert(lines, 1, (joined + 1) .. "/" .. (inServer + 1))
        return table.concat(lines, "\n")
    end
    return "Main: " .. MD_mainName .. "\n" .. LP.Name .. ": " .. (MD_isJoined(LP.Name) and "Joined" or "Not joined")
end
function startMultiDungeonLoop()
    task.spawn(function()
        while _G.AutoJoinDungeon and isRunning() do
            if MD_mainName and LP.Name == MD_mainName then
                local rem = Events:FindFirstChild("PartyEvent")
                if rem then
                    for name in pairs(MD_helpers) do
                        local p = name ~= LP.Name and Players:FindFirstChild(name)
                        local recent = MD_invited[name] and os.clock() - MD_invited[name] < 15
                        if p and not recent and MD_inviteState(name) == "Tap to invite" then
                            pcall(function() rem:FireServer("PartyInvite", p) end)
                            MD_invited[name] = os.clock()
                            task.wait(0.2)
                        end
                    end
                end
            end
            task.wait(5)
        end
    end)
end
do
    local rem = Events:FindFirstChild("PartyEvent") or Events:WaitForChild("PartyEvent", 5)
    if rem then
        rem.OnClientEvent:Connect(function(action, a, b)
            if action == "Update" then
                MD_partyData = a
            elseif action == "PartyDestroyed" then
                MD_partyData = nil
            elseif action == "SendInvite" then
                if _G.AutoJoinDungeon and MD_mainName and LP.Name ~= MD_mainName
                    and typeof(a) == "Instance" and a.Name == MD_mainName and type(b) == "table" then
                    pcall(function() rem:FireServer("AcceptInvite", b.ID) end)
                end
            end
        end)
    end
end
DungeonTab:CreateSection("Multi Dungeon")
MD_mainDrop = DungeonTab:CreateDropdown({
    Title = "Main Account Dungeon",
    Options = MD_playerNames(),
    Callback = function(value)
        MD_mainName = value
        MD_invited = {}
    end
})
regCtrl("mdMain", function() return MD_mainName end,
    function(v) if type(v) == "string" then MD_mainName = v; pcall(function() MD_mainDrop:Set(v) end) end end)
MD_helperDrop = DungeonTab:CreateMultiDropdown({
    Title = "Help Account Dungeon",
    Options = MD_playerNames(),
    Callback = function(value)
        MD_helpers = MD_normalize(value)
        MD_invited = {}
    end
})
regCtrl("mdHelpers", function()
        local t = {}
        for k in pairs(MD_helpers) do table.insert(t, k) end
        return t
    end,
    function(v) if type(v) == "table" then MD_helpers = MD_normalize(v) end end)
MD_statusPara = DungeonTab:CreateParagraph({
    Title = "Party Status",
    Content = "No data yet"
})
DungeonTab:CreateButton({
    Title = "Check Status",
    Callback = function()
        MD_statusPara:Set(MD_statusText())
    end
})
addToggle(DungeonTab, "Auto Join", "AutoJoinDungeon", startMultiDungeonLoop)
task.spawn(function()
    while isRunning() do
        pcall(function() MD_statusPara:Set(MD_statusText()) end)
        task.wait(2)
    end
end)
Players.PlayerAdded:Connect(function()
    local names = MD_playerNames()
    pcall(function() MD_mainDrop:SetOptions(names) end)
    pcall(function() MD_helperDrop:SetOptions(names) end)
end)
Players.PlayerRemoving:Connect(function()
    task.wait()
    local names = MD_playerNames()
    pcall(function() MD_mainDrop:SetOptions(names) end)
    pcall(function() MD_helperDrop:SetOptions(names) end)
end)
DungeonTab:CreateSection("Dungeon Status")
DungeonParagraph = DungeonTab:CreateParagraph({
    Title = "Dungeon Status",
    Content = "Loading..."
})
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(dungeonStatusText)
        pcall(DungeonParagraph.Set, DungeonParagraph, ok and text or "Status unavailable")
        task.wait(1)
    end
end)
DungeonStartUIToggle = DungeonTab:CreateToggle({
    Title = "Show Dungeon Start UI",
    Default = false,
    Callback = function(value)
        _G.DungeonStartUIOn = value
        setDungeonStartUI(value)
    end
})
regCtrl("dungeonStartUI", function() return _G.DungeonStartUIOn == true end,
    function(v) if type(v) == "boolean" then _G.DungeonStartUIOn = v; setDungeonStartUI(v) end end, DungeonStartUIToggle)
DungeonTab:CreateSection("Dungeon Farming")
addToggle(DungeonTab, "Auto Join Dungeon", "JoinDungeon", startJoin)
addToggle(DungeonTab, "Auto Clear Dungeon", "AutoDungeon", startDungeon)
addToggle(DungeonTab, "Auto Invite All Players", "AutoInviteAllDungeon", startInviteAllDungeon)
DungeonTab:CreateButton({
    Title = "Quit Dungeon",
    Callback = function()
        pcall(function() Events:WaitForChild("DungeonEvent", 5):FireServer("Exit") end)
    end
})
end
do
RewardsTab:CreateSection("Auto Claim Rewards")
addToggle(RewardsTab, "Auto Claim Task", "AutoClaimTask", startTask)
addToggle(RewardsTab, "Auto Claim Daily", "AutoClaimDaily", startDaily)
addToggle(RewardsTab, "Auto Claim Gifts", "AutoClaimGift", startGift)
addToggle(RewardsTab, "Auto Claim Season Pass", "AutoClaimSeasonPass", startSeasonPass)
addToggle(RewardsTab, "Auto Claim Milestones / Achievements", "AutoClaimMilestones", startMilestones)
addToggle(RewardsTab, "Auto Spin Wheel", "AutoSpin", startSpin)
UpgradeTab:CreateSection("Power Core (Ocean)")
PCore.paragraph = UpgradeTab:CreateParagraph({ Title = "Power Core V1", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(PCore.status)
        pcall(PCore.paragraph.Set, PCore.paragraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
addToggle(UpgradeTab, "Auto Buy Power Core V1", "AutoPowerCore", startPowerCore)
PCoreV2.paragraph = UpgradeTab:CreateParagraph({ Title = "Power Core V2", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(PCoreV2.status)
        pcall(PCoreV2.paragraph.Set, PCoreV2.paragraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
addToggle(UpgradeTab, "Auto Buy Power Core V2", "AutoPowerCoreV2", startPowerCoreV2)
ShopTab:CreateSection("Chests & Codes")
addToggle(ShopTab, "Auto Claim All Hidden Chests & VIP", "AutoClaimChests", startClaimChests)
ShopTab:CreateButton({
    Title = "Redeem All Active Codes",
    Callback = redeemAllCodes
})
UpgradeTab:CreateSection("Wishing Well (Candy Zone)")
WWParagraph = UpgradeTab:CreateParagraph({ Title = "Wishing Well Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(wwStatus)
        pcall(WWParagraph.Set, WWParagraph, ok and text or "Status unavailable")
        task.wait(3)
    end
end)
wwLabels = {}
for i, name in ipairs(WWOrder) do
    wwLabels[i] = ("%s (%s gems)"):format(name, WWTiers[name] and PCore.fmt(WWTiers[name].Cost) or "?")
end
UpgradeTab:CreateDropdown({
    Title = "Wishing Well Tier",
    Options = wwLabels,
    Default = wwLabels[#wwLabels],
    Callback = function(value)
        local name = tostring(value):match("^(%S+)")
        if name and WWTiers[name] then WWState.tier = name end
    end
})
regCtrl("wishingWellTier", function() return WWState.tier end,
    function(v) if type(v) == "string" and WWTiers[v] then WWState.tier = v end end)
UpgradeTab:CreateButton({
    Title = "Throw Gems Now",
    Callback = function()
        local rem = Events:FindFirstChild("WishingWell")
        if rem then
            pcall(function() rem:FireServer(WWState.tier) end)
            WWState.thrown = WWState.thrown + 1
            WWState.msg = "Threw " .. WWState.tier
        end
    end
})
addToggle(UpgradeTab, "Auto Wishing Well (only when no boost active)", "AutoWishingWell", startWishingWell)
UpgradeTab:CreateSection("Hacker Station (Toy Zone)")
HackParagraph = UpgradeTab:CreateParagraph({ Title = "Hacker Station Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(hackStatus)
        pcall(HackParagraph.Set, HackParagraph, ok and text or "Status unavailable")
        task.wait(3)
    end
end)
UpgradeTab:CreateButton({
    Title = "Hack Now",
    Callback = function()
        task.spawn(function()
            if hackInfo() then
                HackState.msg = "A hack boost is already active"
            else
                hackBegin()
            end
        end)
    end
})
addToggle(UpgradeTab, "Auto Hacker Station (only when no boost active)", "AutoHackStation", startHackStation)
UpgradeTab:CreateSection("Jester Cards (Farm)")
JesterParagraph = UpgradeTab:CreateParagraph({ Title = "Jester Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(jesterStatus)
        pcall(JesterParagraph.Set, JesterParagraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
jesterLabels = {}
for i, info in ipairs(JesterCards) do
    jesterLabels[i] = ("%d %s (%s | %s)"):format(i, info.name, info.pro, info.con)
end
UpgradeTab:CreateMultiDropdown({
    Title = "Select Jester Cards",
    Options = jesterLabels,
    Callback = function(list)
        JesterSel = {}
        for _, label in ipairs(list) do
            local n = tonumber(tostring(label):match("^(%d+)"))
            if n then JesterSel[n] = true end
        end
    end
})
addToggle(UpgradeTab, "Auto Jester Cards (keep only selected ON)", "AutoJester", startJester)
addToggle(UpgradeTab, "Auto Unlock Selected Jester Cards (costs gems)", "AutoJesterUnlock", startJesterUnlock)
ShopTab:CreateSection("Miner")
MinerParagraph = ShopTab:CreateParagraph({ Title = "Miner Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(minerStatus)
        pcall(MinerParagraph.Set, MinerParagraph, ok and text or "Status unavailable")
        task.wait(3)
    end
end)
ShopTab:CreateButton({
    Title = "Claim Miner Now",
    Callback = function() task.spawn(minerClaim) end
})
ShopTab:CreateSlider({
    Title = "Miner Claim Delay (seconds)",
    Min = 1,
    Max = 60,
    Increment = 1,
    Default = 2,
    Callback = function(value) MinerState.delay = value end
})
regCtrl("minerDelay", function() return MinerState.delay end,
    function(v) if type(v) == "number" then MinerState.delay = v end end)
addToggle(ShopTab, "Auto Claim Miner", "AutoMiner", startMiner)
end
do
UpgradeTab:CreateSection("Auto Use Boosts")
BoostDropdown = UpgradeTab:CreateMultiDropdown({
    Title = "Select Boosts",
    Options = (function()
        local labels = {}
        for _, name in ipairs(BoostNames) do labels[#labels + 1] = name .. " (0)" end
        return labels
    end)(),
    Callback = function(list)
        selectedBoosts = {}
        for _, label in ipairs(list) do
            local name = label:match("^(%S+)")
            if name then selectedBoosts[name] = true end
        end
    end
})
task.spawn(function()
    while isRunning() do
        local _, qty = readBoosts()
        if qty then pcall(refreshBoostDropdown, qty) end
        task.wait(1.5)
    end
end)
addToggle(UpgradeTab, "Auto Use Selected Boosts", "AutoUseBoost", startUseBoost)
ShopPanel = {}
function ShopPanel.gameG()
    local ok, g = pcall(function() return getrenv()._G end)
    if ok and type(g) == "table" then
        return g
    end
    return _G
end
ShopPanel.beforeOpen = {
    RobloxShop = function(g)
        if type(g.RobloxShopOpened) == "function" then
            pcall(g.RobloxShopOpened)
        end
    end
}
ShopPanel.afterOpen = {
    EquipmentShop = function()
        task.spawn(EquipShop.refreshGameUI)
    end
}
function ShopPanel.toggle(name, title)
    local pg = LP:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild(name)
    if not gui then
        UI:Notify({ Title = "Shop", Content = (title or name) .. " UI not found", Duration = 3, Type = "Error" })
        return false
    end
    local frame = gui:FindFirstChild("Frame")
    local g = ShopPanel.gameG()
    local opening = not gui.Enabled
    local done = false
    if frame and type(g.openUI) == "function" and type(g.closeUI) == "function" then
        if opening and ShopPanel.beforeOpen[name] then
            pcall(ShopPanel.beforeOpen[name], g)
        end
        done = pcall(function()
            if opening then
                g.openUI(gui, frame)
            else
                g.closeUI(gui, frame)
            end
        end)
    end
    if not done then
        gui.Enabled = opening
    end
    if opening and ShopPanel.afterOpen[name] then
        pcall(ShopPanel.afterOpen[name])
    end
    return true
end
function ShopPanel.addButton(tab, title, guiName)
    tab:CreateButton({
        Title = title,
        Callback = function()
            ShopPanel.toggle(guiName, title)
        end
    })
end
function claimTrophyShopFree()
    local rem = Events:FindFirstChild("FreeRobloxShop")
    if rem then pcall(function() rem:FireServer() end) end
end
function startClaimTrophyShop()
    task.spawn(function()
        while _G.AutoClaimTrophyShop and isRunning() do
            claimTrophyShopFree()
            task.wait(1)
        end
    end)
end
ShopTab:CreateSection("Open Panels")
ShopPanel.addButton(ShopTab, "Open Gem Shop (Forest)", "GemShop")
ShopPanel.addButton(ShopTab, "Open Glove Shop (Forest)", "GloveShop")
ShopPanel.addButton(ShopTab, "Open Equipment Shop (Snow)", "EquipmentShop")
ShopPanel.addButton(ShopTab, "Open Forge / Merge (Cave)", "MergeEquipment")
ShopPanel.addButton(ShopTab, "Open Crafting Station (Desert)", "EquipmentCraft")
ShopPanel.addButton(ShopTab, "Open Perks Shop (Ocean)", "PerksShop")
ShopPanel.addButton(ShopTab, "Open Melter (Samurai)", "EquipmentMelter")
ShopPanel.addButton(ShopTab, "Open Temple (Samurai)", "TempleUI")
ShopPanel.addButton(ShopTab, "Open Altar (Space)", "AltarUI")
ShopPanel.addButton(ShopTab, "Open Christmas Gem Shop (Event)", "ChristmasGemShop")
ShopPanel.addButton(ShopTab, "Open Trophy Shop", "RobloxShop")
ShopTab:CreateButton({
    Title = "Unlock Trophy Shop Access",
    Callback = function()
        pcall(function()
            LP:SetAttribute("CanClaimRobloxShop", 69)
            UI:Notify({ Title = "Shop", Content = "Trophy Shop unlocked!", Duration = 3 })
        end)
    end
})
addToggle(ShopTab, "Auto Claim Trophy Shop", "AutoClaimTrophyShop", startClaimTrophyShop)
ShopTab:CreateSection("Equipment Shop (Snow)")
EquipParagraph = ShopTab:CreateParagraph({
    Title = "Equipment Shop Status",
    Content = "Loading..."
})
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(EquipShop.statusText)
        pcall(EquipParagraph.Set, EquipParagraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
addToggle(ShopTab, "Auto Buy Equipment Shop (1-3)", "AutoBuyEquipment", startBuyEquipment)
ShopTab:CreateSection("Gem Shop (Forest)")
GemLabelToKey, GemLabels = {}, {}
for _, name in ipairs(GemStoreNames) do
    local label = name:gsub("(%l)(%u)", "%1 %2")
    GemLabelToKey[label] = name
    GemLabels[#GemLabels + 1] = label
end
function gemShopInfoText()
    local remote = Events:FindFirstChild("GemStoreEvent")
    local ok, info = pcall(function() return remote and remote:InvokeServer("Info") end)
    if not ok or type(info) ~= "table" then return "Status unavailable" end
    local okGems, gemText = pcall(function() return Top.Gems.TextLabel.Text end)
    local lines = { "Gems: " .. (okGems and tostring(gemText) or "?") }
    local totalToMax = 0
    for _, name in ipairs(GemStoreNames) do
        local tiers = GemStoreData[name]
        local level = info[name]
        local label = name:gsub("(%l)(%u)", "%1 %2")
        if tiers and type(level) == "number" then
            for i = level + 1, #tiers do totalToMax = totalToMax + tiers[i].Gems end
            local nextTier = tiers[level + 1]
            lines[#lines + 1] = nextTier
                and ("%s: %d/%d | Next: %d Gems"):format(label, level, #tiers, nextTier.Gems)
                or ("%s: MAX"):format(label)
        end
    end
    lines[#lines + 1] = "Total to MAX all: " .. totalToMax .. " Gems"
    return table.concat(lines, "\n")
end
GemParagraph = ShopTab:CreateParagraph({
    Title = "Gem Shop Status",
    Content = "Loading..."
})
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(gemShopInfoText)
        pcall(GemParagraph.Set, GemParagraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
GemDropdown = ShopTab:CreateMultiDropdown({
    Title = "Select Gem Upgrades",
    Options = GemLabels,
    Callback = function(list)
        selectedGemUpgrades = {}
        for _, label in ipairs(list) do
            local key = GemLabelToKey[label]
            if key then selectedGemUpgrades[key] = true end
        end
    end
})
GemDropdown:Set(GemLabels, true)
addToggle(ShopTab, "Auto Buy Gem Shop", "AutoBuyGemShop", startBuyGemShop)
ShopTab:CreateSlider({
    Title = "Gem Shop Delay (seconds)",
    Min = 0.5,
    Max = 10,
    Increment = 0.5,
    Default = 2,
    Callback = function(value) gemDelay = value end
})
regCtrl("gemDelay", function() return gemDelay end,
    function(v) if type(v) == "number" then gemDelay = v end end)
ShopTab:CreateSlider({
    Title = "Keep Gems (reserve)",
    Min = 0,
    Max = 5000,
    Increment = 50,
    Default = 0,
    Callback = function(value) gemReserve = value end
})
regCtrl("gemReserve", function() return gemReserve end,
    function(v) if type(v) == "number" then gemReserve = v end end)
GemNotifyToggle = ShopTab:CreateToggle({
    Title = "Notify Gem Purchases",
    Default = true,
    Callback = function(value) gemNotify = value end
})
regCtrl("gemNotify", function() return gemNotify == true end,
    function(v) if type(v) == "boolean" then gemNotify = v end end, GemNotifyToggle)
ShopTab:CreateButton({
    Title = "Buy Selected Once",
    Callback = function()
        task.spawn(function()
            local n = buyGemPass(false)
            UI:Notify({ Title = "Gem Shop", Content = n > 0 and ("Bought " .. n .. " upgrades") or "Nothing to buy (max / not enough Gems)", Duration = 3, Type = n > 0 and "Success" or "Info" })
        end)
    end
})
ShopTab:CreateButton({
    Title = "Buy Max Selected",
    Callback = function()
        task.spawn(function()
            local total = 0
            for _ = 1, 60 do
                if not isRunning() then break end
                local n = buyGemPass(false)
                if n == 0 then break end
                total = total + n
            end
            UI:Notify({ Title = "Gem Shop", Content = "Bought " .. total .. " levels in total", Duration = 3, Type = total > 0 and "Success" or "Info" })
        end)
    end
})
CraftingData = nil
pcall(function()
    CraftingData = require(Modules:WaitForChild("CraftingData", 5))
end)
craftNames, craftLabels, craftByLabel = {}, {}, {}
function craftDisplayName(name)
    return (name:gsub("(%l)(%u)", "%1 %2"))
end
if CraftingData then
    for name in pairs(CraftingData) do
        craftNames[#craftNames + 1] = name
    end
    table.sort(craftNames, function(a, b)
        return CraftingData[a].Stage < CraftingData[b].Stage
    end)
    for _, name in ipairs(craftNames) do
        local d = CraftingData[name]
        local label = ("%s | Stage %d | %d Gems, %d Bolts, %d Copper, %d Screws"):format(
            craftDisplayName(name), d.Stage, d.Gems, d.Bolts, d.Copper, d.Screws
        )
        craftLabels[#craftLabels + 1] = label
        craftByLabel[label] = name
    end
end
craftSel = craftNames[1]
craftDelay = 0.5
CRAFT_KEYS = { "Gems", "Bolts", "Copper", "Screws" }
function readMaterials()
    local nums, texts = {}, {}
    local function read(key, getter)
        local ok, text = pcall(getter)
        if ok and text then
            texts[key] = tostring(text)
            nums[key] = num(text)
        end
    end
    read("Gems", function() return Top.Gems.TextLabel.Text end)
    read("Bolts", function() return MainUI.Right.Bolts.TextLabel.Text end)
    read("Copper", function() return MainUI.Right.Copper.TextLabel.Text end)
    read("Screws", function() return MainUI.Right.Screws.TextLabel.Text end)
    return nums, texts
end
function craftLockedStages()
    local locked = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild("EquipmentCraft")
    local list = gui and gui:FindFirstChild("Frame")
    list = list and list:FindFirstChild("EquipmentFrame")
    list = list and list:FindFirstChild("ScrollingFrame")
    if list then
        for _, item in ipairs(list:GetChildren()) do
            local lbl = item:FindFirstChild("Unlockedlevel")
            if lbl and item:IsA("GuiObject") and item.Visible then
                local n = tonumber(tostring(lbl.Text):match("STAGE%s+(%d+)"))
                if n then
                    locked[n] = true
                end
            end
        end
    end
    return locked
end
function craftCheck(data, nums)
    if craftLockedStages()[data.Stage] or not isUnlocked(data.Stage) then
        return false, "Locked: unlocked at Stage " .. data.Stage
    end
    for _, key in ipairs(CRAFT_KEYS) do
        local have = nums[key]
        if have and have < data[key] then
            return false, ("Missing %s (%s/%d)"):format(key, tostring(math.floor(have)), data[key])
        end
    end
    return true, "Ready to craft"
end
function craftInfoText()
    local nums, texts = readMaterials()
    local parts = {}
    for _, key in ipairs(CRAFT_KEYS) do
        parts[#parts + 1] = key .. ": " .. (texts[key] or "?")
    end
    local data = craftSel and CraftingData and CraftingData[craftSel]
    local lines = { "Account: " .. table.concat(parts, " | ") }
    if data then
        local _, status = craftCheck(data, nums)
        lines[#lines + 1] = ("Selected: %s (Stage %d)"):format(craftDisplayName(craftSel), data.Stage)
        lines[#lines + 1] = ("Need: %d Gems, %d Bolts, %d Copper, %d Screws"):format(data.Gems, data.Bolts, data.Copper, data.Screws)
        lines[#lines + 1] = "Status: " .. status
    end
    return table.concat(lines, "\n")
end
function startCraft()
    task.spawn(function()
        local remote = Events:FindFirstChild("CraftingEvent")
        while _G.AutoCraft and isRunning() do
            local data = craftSel and CraftingData and CraftingData[craftSel]
            local nums = readMaterials()
            if remote and data and craftCheck(data, nums) then
                pcall(function()
                    remote:FireServer(craftSel)
                end)
                task.wait(craftDelay)
            else
                task.wait(1)
            end
        end
    end)
end
UpgradeTab:CreateSection("Crafting (Desert)")
CraftParagraph = UpgradeTab:CreateParagraph({
    Title = "Crafting Status",
    Content = "Loading..."
})
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(craftInfoText)
        pcall(CraftParagraph.Set, CraftParagraph, ok and text or "Status unavailable")
        task.wait(1.5)
    end
end)
CraftDropdown = UpgradeTab:CreateDropdown({
    Title = "Choose Equipment  (cost per craft)",
    Options = #craftLabels > 0 and craftLabels or { "(no data)" },
    Callback = function(value)
        craftSel = craftByLabel[value] or craftSel
    end
})
if craftLabels[1] then
    CraftDropdown:Set(craftLabels[1], true)
end
UpgradeTab:CreateSlider({
    Title = "Crafting Speed (seconds)",
    Min = 0.05,
    Max = 30,
    Increment = 0.05,
    Default = craftDelay,
    Callback = function(value)
        craftDelay = value
    end
})
regCtrl("craftDelay", function() return craftDelay end,
    function(v) if type(v) == "number" then craftDelay = v end end)
addToggle(UpgradeTab, "Auto Craft Selected Equipment", "AutoCraft", startCraft)
do
    local EquipmentData
    pcall(function()
        EquipmentData = require(Modules:WaitForChild("EquipmentData", 5))
    end)
    local GenEquip = Events:FindFirstChild("GenerateEquipment")
    local MergeRemote = Events:FindFirstChild("PlayerMergeEquipment")
    local EQ_ALL = "(All mergeable)"
    local RARITY_ORDER = { Common = 1, Rare = 2, Mythic = 3, Legendary = 4, Secret = 5 }
    local function looksLikeInventory(t)
        if type(t) ~= "table" then return false end
        local n = 0
        for _, v in pairs(t) do
            if type(v) ~= "table" or type(v.name) ~= "string" or type(v.rarity) ~= "string" then
                return false
            end
            if EquipmentData and not EquipmentData[v.name] then
                return false
            end
            n = n + 1
        end
        return n > 0
    end
    local listenerInv
    if GenEquip then
        GenEquip.OnClientEvent:Connect(function(inv)
            if type(inv) == "table" then
                listenerInv = inv
            end
        end)
    end
    local function inventoryFromHandler()
        local getups = (debug and debug.getupvalues) or getupvalues
        if not (GenEquip and getconnections and getups) then
            return nil
        end
        local ok, conns = pcall(getconnections, GenEquip.OnClientEvent)
        if not ok or type(conns) ~= "table" then
            return nil
        end
        for _, c in ipairs(conns) do
            local fn = c.Function
            if fn then
                local okUp, ups = pcall(getups, fn)
                if okUp and type(ups) == "table" then
                    for _, up in pairs(ups) do
                        if looksLikeInventory(up) then
                            return up
                        end
                    end
                end
            end
        end
        return nil
    end
    local gcInv, gcLast = nil, 0
    local function inventoryFromGC()
        if gcInv or not getgc or tick() - gcLast < 15 then return gcInv end
        gcLast = tick()
        local best, bestN = nil, 0
        for _, t in ipairs(getgc(true)) do
            if looksLikeInventory(t) then
                local n = 0
                for _ in pairs(t) do n = n + 1 end
                if n > bestN then
                    best, bestN = t, n
                end
            end
        end
        gcInv = best
        return best
    end
    local function equipmentInventory()
        return inventoryFromHandler() or listenerInv or inventoryFromGC()
    end
    EquipAuto.getInventory = equipmentInventory
    local function equipGroups()
        local inv = equipmentInventory()
        if not inv then
            return nil
        end
        local byKey, groups = {}, {}
        for id, item in pairs(inv) do
            local info = EquipmentData and EquipmentData[item.name]
            if not item.equipped
                and RARITY_ORDER[item.rarity]
                and not (info and info.canBeMerged == false) then
                local key = item.name .. "|" .. item.rarity
                local g = byKey[key]
                if not g then
                    g = {
                        key = key,
                        rarity = item.rarity,
                        display = info and info.displayName or item.name,
                        ids = {}
                    }
                    byKey[key] = g
                    groups[#groups + 1] = g
                end
                g.ids[#g.ids + 1] = tostring(id)
            end
        end
        table.sort(groups, function(a, b)
            if a.rarity ~= b.rarity then
                return RARITY_ORDER[a.rarity] < RARITY_ORDER[b.rarity]
            end
            return a.display < b.display
        end)
        return groups
    end
    local eqSel = { all = false, key = nil }
    local eqLabelToKey, eqKey = {}, ""
    local EquipDropdown
    local function refreshEquipDropdown()
        local groups = equipGroups()
        local labels, map = { EQ_ALL }, {}
        for _, g in ipairs(groups or {}) do
            local label = ("%s | %s | x%d"):format(g.rarity, g.display, #g.ids)
            labels[#labels + 1] = label
            map[label] = g.key
        end
        local key = table.concat(labels, "\n")
        if key == eqKey then
            return
        end
        eqKey = key
        eqLabelToKey = map
        EquipDropdown:SetOptions(labels, false)
        if eqSel.all then
            EquipDropdown:Set(EQ_ALL, true)
        elseif eqSel.key then
            for label, k in pairs(map) do
                if k == eqSel.key then
                    EquipDropdown:Set(label, true)
                    break
                end
            end
        end
    end
    local function startEquipMerge()
        task.spawn(function()
            while _G.AutoMergeEquip and isRunning() do
                pcall(function()
                    local groups = MergeRemote and equipGroups()
                    for _, g in ipairs(groups or {}) do
                        if not _G.AutoMergeEquip then
                            break
                        end
                        if eqSel.all or (eqSel.key and eqSel.key == g.key) then
                            local i = 1
                            while i + 2 <= #g.ids and _G.AutoMergeEquip do
                                MergeRemote:FireServer({ g.ids[i], g.ids[i + 1], g.ids[i + 2] })
                                i = i + 3
                                task.wait(0.5)
                            end
                        end
                    end
                end)
                task.wait(3)
            end
        end)
    end
    UpgradeTab:CreateSection("Equipment Merge (Cave)")
    EquipDropdown = UpgradeTab:CreateDropdown({
        Title = "Select Equipment  (rarity | name | count)",
        Options = { EQ_ALL },
        Callback = function(value)
            if value == EQ_ALL then
                eqSel = { all = true, key = nil }
            else
                eqSel = { all = false, key = eqLabelToKey[value] }
            end
        end
    })
    addToggle(UpgradeTab, "Auto Merge Equipment (3 same -> 1 higher)", "AutoMergeEquip", startEquipMerge)
    task.spawn(function()
        local warned = false
        while isRunning() do
            pcall(refreshEquipDropdown)
            if not warned and not equipmentInventory() then
                warned = true
                UI:Notify({
                    Title = "Equipment Merge",
                    Content = "Equipment inventory not found yet (open the Equipment menu once).",
                    Duration = 5,
                    Type = "Info"
                })
            end
            task.wait(1.5)
        end
    end)
end
UpgradeTab:CreateSection("Perks (Ocean)")
PerkUI.paragraph = UpgradeTab:CreateParagraph({ Title = "Perk Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        pcall(PerkUI.ensureTierDropdowns)
        pcall(PerkUI.refreshOptions)
        local ok, text = pcall(PerkUI.status)
        pcall(PerkUI.paragraph.Set, PerkUI.paragraph, ok and text or "Status unavailable")
        pcall(PerkUI.updateTitles)
        task.wait(2)
    end
end)
pcall(PerkUI.ensureTierDropdowns)
addToggle(UpgradeTab, "Auto Unlock Perk Tiers (Main + Summer)", "AutoBuyPerks", startPerks)
addToggle(UpgradeTab, "Auto Choose Perk", "AutoChoosePerk", PerkUI.startChoose)
do
AltarPayRemote = Events:FindFirstChild("ClickedAltarPay") or Events:WaitForChild("ClickedAltarPay", 5)
function altarStatus()
    local pg = LP:FindFirstChild("PlayerGui")
    local a = pg and pg:FindFirstChild("AltarUI")
    if not a then return "Altar: UI not loaded (click Open Altar once)" end
    local ok, text = pcall(function()
        local top = a.Frame.top
        return "Altar: " .. top.SacrificeNumber.Text .. " | " .. top.DamageNumber.Text
    end)
    return ok and text or "Altar: Status unavailable"
end
function startAltarAutoPay(flag, key)
    task.spawn(function()
        while _G[flag] and isRunning() do
            pcall(function()
                if AltarPayRemote then AltarPayRemote:FireServer(key) end
            end)
            task.wait(2)
        end
    end)
end
UpgradeTab:CreateSection("Altar (Space)")
AltarParagraph = UpgradeTab:CreateParagraph({ Title = "Altar Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(altarStatus)
        pcall(AltarParagraph.Set, AltarParagraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
addToggle(UpgradeTab, "Auto Pay Altar - Gems", "AutoAltarGems", function() startAltarAutoPay("AutoAltarGems", "gems") end)
addToggle(UpgradeTab, "Auto Pay Altar - Materials", "AutoAltarMaterials", function() startAltarAutoPay("AutoAltarMaterials", "materials") end)
addToggle(UpgradeTab, "Auto Pay Altar - Wins", "AutoAltarWins", function() startAltarAutoPay("AutoAltarWins", "coins") end)
end
do
function templeStatus()
    local pg = LP:FindFirstChild("PlayerGui")
    local t = pg and pg:FindFirstChild("TempleUI")
    if not t then return "Temple: UI not loaded (click Open Temple once)" end
    local ok, text = pcall(function()
        local sel = "none selected"
        for _, v in ipairs(t.Frame.Options:GetChildren()) do
            if v:FindFirstChild("SelectButton") and v.SelectButton.Boosts.Text == "SELECTED" then
                sel = v.SMALL.Title.Text
            end
        end
        local boosts = ""
        for _, v in ipairs(t.Frame.Options:GetChildren()) do
            if v:FindFirstChild("SelectButton") and v.SelectButton.Boosts.Text == "SELECTED" then
                boosts = v.Frame.SMALL.Text:gsub("\n", ", ")
            end
        end
        return "Temple: " .. sel .. (boosts ~= "" and (" (" .. boosts .. ")") or "") .. " | " .. t.Frame.top.timer.Text
    end)
    return ok and text or "Temple: Status unavailable"
end
TempleRemote = Events:FindFirstChild("ClickedTemple") or Events:WaitForChild("ClickedTemple", 5)
TempleFates = {
    { label = "Way of the Warrior: +25% Damage, x2 Health", id = 1 },
    { label = "Way of the Lucky: +25% Pet Luck, +1 Pet Equip", id = 2 },
    { label = "Way of the Greedy: +10% Wins, +10% Materials, +10% Gems", id = 3 },
}
TempleFateLabels, TempleFateById = {}, {}
for _, f in ipairs(TempleFates) do
    TempleFateLabels[#TempleFateLabels + 1] = f.label
    TempleFateById[f.label] = f.id
end
selectedTempleFate = TempleFates[1].id
UpgradeTab:CreateSection("Temple (Samurai)")
TempleParagraph = UpgradeTab:CreateParagraph({ Title = "Temple Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(templeStatus)
        pcall(TempleParagraph.Set, TempleParagraph, ok and text or "Status unavailable")
        task.wait(2)
    end
end)
UpgradeTab:CreateDropdown({
    Title = "Choose Fate",
    Options = TempleFateLabels,
    Default = TempleFateLabels[1],
    Callback = function(value)
        selectedTempleFate = TempleFateById[value] or selectedTempleFate
    end
})
UpgradeTab:CreateButton({
    Title = "Select Fate",
    Callback = function()
        pcall(function()
            if TempleRemote then TempleRemote:FireServer(selectedTempleFate) end
        end)
        UI:Notify({ Title = "Temple", Content = "Fate selection sent (once per day)", Duration = 3, Type = "Info" })
    end
})
end
end
do
PlayerTab:CreateSection("Movement")
PlayerTab:CreateSlider({
    Title = "WalkSpeed",
    Min = 16,
    Max = 250,
    Increment = 1,
    Default = 16,
    Callback = function(value) customWalkspeed = value end
})
addToggle(PlayerTab, "Loop WalkSpeed", "LoopWalkspeed", function()
    loopWalkspeed = true
end, function()
    loopWalkspeed = false
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end
end)
PlayerTab:CreateSlider({
    Title = "JumpPower",
    Min = 50,
    Max = 350,
    Increment = 5,
    Default = 50,
    Callback = function(value) customJumppower = value end
})
addToggle(PlayerTab, "Loop JumpPower", "LoopJumppower", function()
    loopJumppower = true
end, function()
    loopJumppower = false
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = 50 end
end)
addToggle(PlayerTab, "Infinite Jump", "InfJump", function() infJump = true end, function() infJump = false end)
addToggle(PlayerTab, "Noclip (Walk Through Walls)", "Noclip", function() noclip = true end, function() noclip = false end)
end
do
TeleportTab:CreateSection("Select Island (All " .. #IslandList .. " Stages)")
islandOptions = {}
islandOptionToStage = {}
for _, isl in ipairs(IslandList) do
    local label = isl.stage .. ": " .. isl.name
    islandOptions[#islandOptions + 1] = label
    islandOptionToStage[label] = isl
end
selectedIslandStage = 1
selectedIslandName = "Forest"
TeleportTab:CreateDropdown({
    Title = "Choose Island",
    Options = islandOptions,
    Default = islandOptions[1],
    Callback = function(value)
        local data = islandOptionToStage[value]
        if data then
            selectedIslandStage = data.stage
            selectedIslandName = data.name
        end
    end
})
TeleportTab:CreateButton({
    Title = "Teleport to Selected Island",
    Callback = function() teleportToStage(selectedIslandStage, selectedIslandName) end
})
TeleportTab:CreateSection("Quick Teleport Buttons")
for _, isl in ipairs(IslandList) do
    TeleportTab:CreateButton({
        Title = isl.stage .. ". " .. isl.name,
        Callback = function() teleportToStage(isl.stage, isl.name) end
    })
end
TeleportTab:CreateSection("Upgrade Teleport")
function teleportToPos(pos, name)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        UI:Notify({ Title = "Teleport", Content = "Teleported to " .. name, Duration = 2, Type = "Info" })
    end
end
TeleportTab:CreateButton({
    Title = "TP Temple (Samurai)",
    Callback = function() teleportToPos(Vector3.new(-10636.25, 94.20, 2519.60), "Temple") end
})
TeleportTab:CreateButton({
    Title = "TP Altar (Space)",
    Callback = function() teleportToPos(Vector3.new(-12329.03, 94.20, 2522.48), "Altar") end
})
TeleportTab:CreateButton({
    Title = "TP Glove Shop (Forest)",
    Callback = function() teleportToPos(Vector3.new(-1317.22, 93.98, 2516.92), "Glove Shop") end
})
TeleportTab:CreateButton({
    Title = "TP Blacksmith (Crafting, Desert)",
    Callback = function() teleportToPos(Vector3.new(-2237.79, 92.58, 2655.76), "Blacksmith (Crafting)") end
})
TeleportTab:CreateButton({
    Title = "TP Power Core (Ocean)",
    Callback = function() teleportToPos(Vector3.new(-4142.55, 92.58, 2538.34), "Power Core") end
})
TeleportTab:CreateButton({
    Title = "TP Perks (Ocean)",
    Callback = function() teleportToPos(Vector3.new(-4029.41, 92.32, 2504.82), "Perks") end
})
TeleportTab:CreateButton({
    Title = "TP Wishing Well (Candy Zone)",
    Callback = function() teleportToPos(Vector3.new(-4894.55, 92.16, 2517.47), "Wishing Well") end
})
TeleportTab:CreateButton({
    Title = "TP Pet Levels (Candy Zone)",
    Callback = function() teleportToPos(Vector3.new(-4781.58, 92.58, 2510.11), "Pet Levels") end
})
TeleportTab:CreateButton({
    Title = "TP Hacker Station (Toy Zone)",
    Callback = function() teleportToPos(Vector3.new(-7548.11, 92.30, 2528.78), "Hacker Station") end
})
TeleportTab:CreateButton({
    Title = "TP Miner (Farm)",
    Callback = function() teleportToPos(Vector3.new(-9313.57, 92.67, 2515.14), "Miner") end
})
TeleportTab:CreateButton({
    Title = "TP Jester (Farm)",
    Callback = function() teleportToPos(Vector3.new(-9410.24, 92.58, 2519.60), "Jester") end
})
TeleportTab:CreateButton({
    Title = "TP Power Core V2 (Magical Forest)",
    Callback = function() teleportToPos(Vector3.new(-13784.40, 92.93, 2582.22), "Power Core V2") end
})
end
do
SettingTab:CreateSection("Boss Fight Method")
SettingTab:CreateDropdown({
    Title = "Method",
    Options = {"Instant", "Tap Click"},
    Default = "Instant",
    Callback = function(value)
        bossMethod = value
        if _G.AutoFarmBoss then startBossFarm() end
    end
})
SettingTab:CreateSection("Performance & Animation")
POPUP_CLOSE_NAMES = {"UpdateLog", "UpdateLogNew", "StageBundleOffer"}
function startSkipPopup()
    task.spawn(function()
        while _G.SkipPopup and isRunning() do
            if typeof(firesignal) == "function" then
                for _, name in ipairs(POPUP_CLOSE_NAMES) do
                    local gui = PG:FindFirstChild(name)
                    local frame = gui and gui:FindFirstChild("Frame")
                    local btn = frame and frame:FindFirstChild("CloseButton")
                    if gui and gui:IsA("ScreenGui") and gui.Enabled and frame and frame.Visible and btn and (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
                        pcall(firesignal, btn.MouseButton1Click)
                        pcall(firesignal, btn.Activated)
                        if gui:IsA("ScreenGui") then pcall(function() gui.Enabled = false end) end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end
function turnOffAllToggles()
    local count = 0
    for flag, info in pairs(toggleObjs) do
        if _G[flag] == true then
            _G[flag] = false
            count += 1
            if info.obj then pcall(function() info.obj:SetStage(false) end) end
            if info.onStop then pcall(info.onStop) end
        end
    end
    return count
end
function deleteConfigFile()
    if typeof(isfile) ~= "function" or typeof(delfile) ~= "function" then return nil end
    local ok, res = pcall(function()
        if not isfile(SETTINGS_FILE) then return false end
        delfile(SETTINGS_FILE)
        return true
    end)
    if not ok then return nil end
    return res
end
function claimHiddenChests()
    if typeof(fireproximityprompt) ~= "function" then return nil end
    local folder = workspace:FindFirstChild("HiddenChests")
    if not folder then return false end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local count = 0
    for _, model in ipairs(folder:GetChildren()) do
        local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            local part = prompt.Parent
            if part and not part:IsA("BasePart") then
                part = part:FindFirstAncestorWhichIsA("BasePart")
            end
            if part then
                hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.3)
                pcall(fireproximityprompt, prompt)
                count += 1
                task.wait(0.3)
            end
        end
    end
    return count
end
addToggle(SettingTab, "Destroy Notifications", "DestroyNotification", startNotification, stopNotification)
addToggle(SettingTab, "FPS Boost", "FPSBoost", startFPSBoost, stopFPSBoost)
addToggle(SettingTab, "FPS Boost+", "FPSBoostPlus", startFPSBoostPlus, function() end)
addToggle(SettingTab, "Skip Popup", "SkipPopup", startSkipPopup, function() end)
addToggle(SettingTab, "Attack No Animation", "AttackNoAnimation", startNoPunchAnim, stopNoPunchAnim)
addToggle(SettingTab, "Disable 3D", "SaveBattery3D", function()
    pcall(function() RunService:Set3dRenderingEnabled(false) end)
end, function()
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
end)
addToggle(SettingTab, "Disable Fog", "DisableFog", function()
    local R = game.Lighting
    R.FogEnd = 100000
    for _, m in pairs(R:GetDescendants()) do
        if m:IsA("Atmosphere") then
            m:Destroy()
        end
    end
end, function() end)
addToggle(SettingTab, "Disable Shadows", "DisableShadows", function(val)
    pcall(function() Lighting.GlobalShadows = not val end)
end)
addToggle(SettingTab, "Anti-AFK", "AntiAFK", startAntiAFK)
addToggle(SettingTab, "Notify Egg", "NotifyEgg", startNotifyEgg)
addToggle(SettingTab, "Destroy Egg V1", "AntiEggLag", startAntiEgg1)
addToggle(SettingTab, "Destroy Egg V2", "AntiEggLag2", startAntiEgg2)
addToggle(SettingTab, "Skip Egg Animation", "SkipEggAnim", startSkipAnim)
NotifyRarityDropdown = SettingTab:CreateMultiDropdown({
    Title = "Notify Rarity",
    Options = RARITIES,
    Callback = function(list)
        notifyRarities = {}
        for _, rarity in ipairs(list) do notifyRarities[rarity] = true end
    end
})
NotifyRarityDropdown:Set(RARITIES, true)
SettingTab:CreateButton({ Title = "Fix Character Move", Callback = fixCharacterMove })
SettingTab:CreateButton({
    Title = "Remove Hatching Animation",
    Callback = function()
        local map = RS:FindFirstChild("EggOpenMap")
        if map then map:Destroy() end
    end
})
SettingTab:CreateButton({
    Title = "Turn off all toggles",
    Callback = function()
        local n = turnOffAllToggles()
        pcall(function()
            UI:Notify({Title = "Toggles", Content = "Turned off " .. n .. " toggle(s)", Duration = 2})
        end)
    end
})
SettingTab:CreateButton({
    Title = "Delete config and rejoin",
    Callback = function()
        _G.PnkaStopSave = true
        deleteConfigFile()
        pcall(function()
            UI:Notify({Title = "Config", Content = "Config deleted, rejoining in 1 second", Duration = 2})
        end)
        task.delay(1, function()
            local TS = game:GetService("TeleportService")
            local ok = pcall(function()
                TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
            end)
            if not ok then
                pcall(function() TS:Teleport(game.PlaceId, LP) end)
            end
        end)
    end
})
end
do
HalloweenTab:CreateSection("Halloween Event")
HalloweenAccount = HalloweenTab:CreateStatus("Halloween Account")
task.spawn(function()
    local LABELS = {
        {"Spooky Damage", "lucide-skull", function() return Top:WaitForChild("SpookyDamage", 10).TextLabel end},
        {"Candy Corn", "lucide-ghost", function() return Top:WaitForChild("CandyCorn", 10).TextLabel end},
    }
    local function refresh()
        local rows = {}
        for _, item in ipairs(LABELS) do
            local ok, lbl = pcall(item[3])
            rows[#rows + 1] = { icon = item[2], text = item[1] .. ": " .. (ok and lbl and tostring(lbl.Text) or "?") }
        end
        pcall(function() HalloweenAccount:Set(nil, rows) end)
    end
    refresh()
    for _, item in ipairs(LABELS) do
        local ok, lbl = pcall(item[3])
        if ok and lbl then lbl:GetPropertyChangedSignal("Text"):Connect(refresh) end
    end
end)
HalloweenPara = HalloweenTab:CreateParagraph({ Title = "Halloween Status", Content = "Loading..." })
function hwRemote(kind, name)
    local ok, remote = pcall(function()
        local handler = require(RS:WaitForChild("ModuleLoader", 10))("RemoteHandler")
        if kind == "event" then return handler.GetRemoteEvent(name) end
        return handler.GetRemoteFunction(name)
    end)
    return ok and remote or nil
end
function hwData(name)
    local ok, mod = pcall(function()
        return require(Modules:WaitForChild("HalloweenEvent", 10):WaitForChild("Shared", 10):WaitForChild(name, 10))
    end)
    return ok and mod or nil
end
function hwCandyText()
    local ok, text = pcall(function() return Top:WaitForChild("CandyCorn", 10).TextLabel.Text end)
    return ok and text or "?"
end
hwLiveTexts = {}
function hwSetLive(para, text)
    hwLiveTexts[para] = text
    pcall(para.Set, para, text)
end
function hwRefreshCandy(text)
    local lbl = Top:FindFirstChild("CandyCorn")
    local v = lbl and lbl.TextLabel and lbl.TextLabel.Text or "?"
    text = text:gsub("^Candy Corn: [^\n]*", "Candy Corn: " .. v)
    text = text:gsub("\nCandy Corn: [^\n]*", "\nCandy Corn: " .. v)
    return text
end
task.spawn(function()
    while isRunning() do
        for para, text in pairs(hwLiveTexts) do
            pcall(para.Set, para, hwRefreshCandy(text))
        end
        task.wait(0.2)
    end
end)
function hwNum(n) return (tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) end
hwShopItems, hwShopLabels, hwShopLabelToKey, hwShopSelected = {}, {}, {}, {}
for _, it in ipairs((hwData("HalloweenRewardShopData") or { items = {} }).items) do
    if it.kind == "boost" then hwShopItems[#hwShopItems + 1] = it end
end
table.sort(hwShopItems, function(a, b) return a.price < b.price end)
for _, it in ipairs(hwShopItems) do
    hwShopLabelToKey[it.displayName] = it.key
    hwShopLabels[#hwShopLabels + 1] = it.displayName
    hwShopSelected[it.key] = true
end
hwBundleItems, hwBundleLabels, hwBundleLabelToKey, hwBundleSelected = {}, {}, {}, {}
for _, it in ipairs((hwData("HalloweenRewardShopData") or { items = {} }).items) do
    if it.category == "Bundles" then hwBundleItems[#hwBundleItems + 1] = it end
end
table.sort(hwBundleItems, function(a, b) return a.price < b.price end)
for _, it in ipairs(hwBundleItems) do
    hwBundleLabelToKey[it.displayName] = it.key
    hwBundleLabels[#hwBundleLabels + 1] = it.displayName
    hwBundleSelected[it.key] = true
end
function hwBundlePrice(state, it)
    if it.kind == "wins" then
        return (state.winsBundle and state.winsBundle.price) or it.price
    elseif it.kind == "gems" then
        local shopData = hwData("HalloweenRewardShopData")
        local ok, price = pcall(function() return shopData.getGemPrice(state.bought, it) end)
        return ok and price or it.price
    end
    return it.price
end
hwPetItems, hwPetLabels, hwPetLabelToKey, hwPetSelected = {}, {}, {}, {}
do
    local okPS, PS = pcall(function() return require(Modules:WaitForChild("PetStats", 10)) end)
    if okPS and type(PS) == "table" then
        for key, st in pairs(PS) do
            if type(st) == "table" and st.homePetKey then
                hwPetItems[#hwPetItems + 1] = { key = key, name = st.name or key }
            end
        end
    end
    table.sort(hwPetItems, function(a, b) return a.key < b.key end)
    for _, it in ipairs(hwPetItems) do
        hwPetLabelToKey[it.name] = it.key
        hwPetLabels[#hwPetLabels + 1] = it.name
        hwPetSelected[it.key] = true
    end
end
function hwPetInfo(state, key)
    local shop = hwData("HalloweenRewardShopData")
    local ok, info = pcall(function()
        return {
            price = shop.getHomePetPrice(key, state.bought),
            required = shop.getHomePetsRequired(key),
            have = (state.spookyPets or {})[key] or 0,
            bought = shop.homePetsBought(state.bought, key),
            limit = shop.HOME_PET_LIMIT,
        }
    end)
    return ok and info or nil
end
hwUpData = hwData("HalloweenUpgradeData") or {}
hwUpKeys, hwUpLabels, hwUpLabelToKey, hwUpSelected, hwUpLevels = {}, {}, {}, {}, {}
for key in pairs(hwUpData) do hwUpKeys[#hwUpKeys + 1] = key end
table.sort(hwUpKeys, function(a, b) return hwUpData[a].order < hwUpData[b].order end)
for _, key in ipairs(hwUpKeys) do
    local label = hwUpData[key].displayName
    hwUpLabelToKey[label] = key
    hwUpLabels[#hwUpLabels + 1] = label
    hwUpSelected[key] = true
end
task.spawn(function()
    hwUpEv = hwRemote("event", "HalloweenUpgradeEvent")
    if hwUpEv then hwUpEv.OnClientEvent:Connect(function(l) hwUpLevels = l or {} end) end
end)
function hwOpenPanel(name, title)
    local pg = LP:FindFirstChild("PlayerGui")
    local gui = pg and pg:FindFirstChild(name)
    if not gui then
        UI:Notify({ Title = "Shop", Content = title .. " UI not found", Duration = 3, Type = "Error" })
        return
    end
    if gui.Enabled then
        ShopPanel.toggle(name, title)
        return
    end
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local hexes = workspace:FindFirstChild("Halloween") and workspace.Halloween:FindFirstChild("TouchHexagons")
    local hex = hexes and hexes:FindFirstChild(name)
    local hit = hex and (hex:FindFirstChild("HitboxPart") or hex)
    local fired = false
    if hit and root and typeof(getconnections) == "function" then
        for _, c in ipairs(getconnections(hit.Touched)) do
            if pcall(function() c:Fire(root) end) then fired = true end
        end
    end
    if not fired then
        UI:Notify({ Title = "Shop", Content = "Go to the Halloween world first (TP Halloween World)", Duration = 3, Type = "Error" })
    end
end
function startHalloweenQuest()
    task.spawn(function()
        local fn = hwRemote("function", "HalloweenDailyQuestsUIEvent")
        while fn and _G.AutoHalloweenQuest and isRunning() do
            local ok, state = pcall(function() return fn:InvokeServer("Info") end)
            if ok and type(state) == "table" then
                for setKey, set in pairs(state) do
                    for i, q in ipairs(type(set) == "table" and set.quests or {}) do
                        if q.claimable == true then
                            pcall(function() fn:InvokeServer("Claim", setKey, i) end)
                            task.wait(0.5)
                        end
                    end
                end
            end
            task.wait(5)
        end
    end)
end
function startHalloweenQuestClaim()
    task.spawn(function()
        local fn = hwRemote("function", "HalloweenQuestEvent")
        while fn and _G.AutoHalloweenQuestClaim and isRunning() do
            local ok, idx, progress, goal = pcall(function() return fn:InvokeServer("Info") end)
            if ok and idx ~= nil and type(progress) == "number" and type(goal) == "number" and progress >= goal then
                pcall(function() fn:InvokeServer("Claim") end)
                task.wait(2)
            else
                task.wait(3)
            end
        end
    end)
end
function startHalloweenShop()
    task.spawn(function()
        local fn = hwRemote("function", "HalloweenRewardShopUIEvent")
        if not fn then return end
        while _G.AutoHalloweenShop and isRunning() do
            local ok, state = pcall(function() return fn:InvokeServer("Opened") end)
            if ok and type(state) == "table" then
                for _, it in ipairs(hwShopItems) do
                    if not _G.AutoHalloweenShop then break end
                    if hwShopSelected[it.key] and not (state.bought or {})[it.key] and it.price <= (state.candyCorn or 0) then
                        local ok2, new = pcall(function() return fn:InvokeServer("Buy", it.key) end)
                        if ok2 and type(new) == "table" then state = new end
                        task.wait(0.5)
                    end
                end
            end
            task.wait(5)
        end
    end)
end
hwBossRun = 0
function hwSpookyDamage()
    local g = getrenv()._G
    return (g.TotalCurrency and g.TotalCurrency.SpookyDamage) or 0
end
function hwPickBoss()
    local stage = Breakable:FindFirstChild("Stage100")
    if not stage then return nil end
    local spooky, best = hwSpookyDamage(), nil
    for _, mode in ipairs(stage:GetChildren()) do
        local root = mode:FindFirstChild("HumanoidRootPart")
        local prompt = root and root:FindFirstChildOfClass("ProximityPrompt")
        local mn = tonumber(mode.Name)
        local r = prompt and mn and req("Stage100", mode.Name)
        if r and r <= spooky and (not best or r > best.req) then
            local enemy = EnemyData[100] and EnemyData[100][mn]
            best = { mn = mn, req = r, part = root, name = (enemy and enemy.DisplayName) or ("Boss " .. mn) }
        end
    end
    return best
end
function hwEnsureWorld(alive)
    local stateFn = hwRemote("function", "HalloweenWorldState")
    local tpFn = hwRemote("function", "HalloweenTeleport")
    local function inWorld()
        if not stateFn then return false end
        local ok, r = pcall(function() return stateFn:InvokeServer() end)
        return ok and r == true
    end
    if inWorld() then return true end
    if not tpFn then return false end
    UI:Notify({ Title = "Halloween Boss", Content = "Teleporting to Halloween World...", Duration = 2, Type = "Info" })
    local ok, res = pcall(function() return tpFn:InvokeServer() end)
    if not ok or not res then return false end
    for _ = 1, 20 do
        if not alive() then return false end
        task.wait(0.5)
        if inWorld() then break end
    end
    task.wait(2)
    return alive() and inWorld()
end
function startHalloweenBoss()
    hwBossRun = hwBossRun + 1
    local id = hwBossRun
    local function alive() return _G.AutoFarmBossHalloween and hwBossRun == id end
    if bossMethod == "Instant" then
        task.spawn(function()
            while alive() do pcall(fixCharacterMove) task.wait(0.5) end
        end)
    end
    task.spawn(function()
        local lastTarget, pushed, lastWorldCheck = nil, false, 0
        while alive() do
            if not fightVisible() and tick() - lastWorldCheck > 5 then
                lastWorldCheck = tick()
                if not hwEnsureWorld(alive) then
                    lastWorldCheck = 0
                    task.wait(3)
                    continue
                end
            end
            if fightVisible() then
                if bossMethod == "Instant" then
                    if not pushed then
                        pushed = true
                        pcall(function() PushEvent:FireServer(true) end)
                    end
                    task.wait(0.2)
                else
                    if Countdown.Text == "Tap!" then tap() else selectButton(false) end
                    task.wait()
                end
            elseif dataBusy then
                pushed = false
                selectButton(false)
                task.wait(0.3)
            else
                pushed = false
                selectButton(false)
                local boss = hwPickBoss()
                if boss then
                    if lastTarget ~= boss.mn then
                        lastTarget = boss.mn
                        UI:Notify({
                            Title = "Halloween Boss",
                            Content = "Targeting: " .. boss.name .. " (" .. hwNum(boss.req) .. " Spooky Damage)",
                            Duration = 3,
                            Type = "Info"
                        })
                    end
                    local char = LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and boss.part.Parent and alive() then
                        root.CFrame = boss.part.CFrame * CFrame.new(0, 0, 4)
                        task.wait(0.3)
                        if alive() then
                            FightEvent:FireServer("Fight", 100, boss.mn)
                            task.wait(1.5)
                        end
                    else
                        task.wait(1)
                    end
                else
                    lastTarget = nil
                    task.wait(1)
                end
            end
        end
        selectButton(false)
        if not _G.AutoFarmBossHalloween and fightVisible() then stopFight() end
    end)
end
function hwSpookyRanking(inv)
    local spooky = {}
    for id, pet in pairs(inv) do
        local st = type(pet) == "table" and PetStatsData and PetStatsData[pet.name]
        if st and st.spookyPet then spooky[id] = pet end
    end
    local list = {}
    for id, pet in pairs(inv) do
        if type(pet) == "table" and pet.canEquip ~= false then
            local ok, dmg = pcall(PetCalc.CalculateDamage, pet.name, pet.level or 1, pet.petType, 1, spooky)
            list[#list + 1] = { id = id, pet = pet, dmg = (ok and type(dmg) == "number") and dmg or 0 }
        end
    end
    table.sort(list, function(a, b) return a.dmg > b.dmg end)
    return list
end
function startHalloweenPet()
    task.spawn(function()
        local equipRemote = Events:WaitForChild("EquipPet", 5)
        local unequipRemote = Events:WaitForChild("UnequipPet", 5)
        if not (equipRemote and unequipRemote and PetStatsData and PetCalc) then return end
        local cap, capReset = nil, tick()
        while _G.AutoEquipBestHalloweenPet and isRunning() do
            pcall(function()
                local inv = mergeInventory()
                if not inv then return end
                if tick() - capReset > 60 then cap, capReset = nil, tick() end
                local ranking = hwSpookyRanking(inv)
                local equippedCount, nonSpooky, spookyEquipped = 0, {}, {}
                for id, pet in pairs(inv) do
                    if type(pet) == "table" and pet.equipped == true then
                        equippedCount += 1
                        if pet.canEquip ~= false then
                            spookyEquipped[#spookyEquipped + 1] = id
                        else
                            nonSpooky[#nonSpooky + 1] = id
                        end
                    end
                end
                local dmgById = {}
                for _, r in ipairs(ranking) do dmgById[r.id] = r.dmg end
                table.sort(spookyEquipped, function(a, b) return (dmgById[a] or 0) < (dmgById[b] or 0) end)
                local changed = 0
                for _, r in ipairs(ranking) do
                    if not _G.AutoEquipBestHalloweenPet then break end
                    if r.pet.equipped ~= true then
                        local full = cap and equippedCount >= cap
                        if not full then
                            pcall(function() equipRemote:InvokeServer(r.id, true, true) end)
                            task.wait(0.3)
                            local after = mergeInventory()
                            local nowEquipped = after and after[r.id] and after[r.id].equipped == true
                            if nowEquipped then
                                equippedCount += 1
                                changed += 1
                            else
                                cap = equippedCount
                                full = true
                            end
                        end
                        if full then
                            local victim = table.remove(nonSpooky, 1)
                            if not victim then
                                local weakest = spookyEquipped[1]
                                if weakest and (dmgById[weakest] or 0) < r.dmg then
                                    victim = table.remove(spookyEquipped, 1)
                                end
                            end
                            if not victim then break end
                            pcall(function() unequipRemote:InvokeServer(victim, true, true) end)
                            task.wait(0.3)
                            pcall(function() equipRemote:InvokeServer(r.id, true, true) end)
                            task.wait(0.3)
                            changed += 1
                        end
                    end
                end
                if changed > 0 then
                    UI:Notify({
                        Title = "Halloween Pet",
                        Content = "Updated " .. changed .. " spooky pet(s)",
                        Duration = 3,
                        Type = "Success"
                    })
                end
            end)
            task.wait(3)
        end
    end)
end
function startHalloweenEgg()
    task.spawn(function()
        local eggKey = "HalloweenEgg"
        local data = EggVendorData[eggKey]
        local cost = data and data.otherCurrencyCostData and data.otherCurrencyCostData.amount or 50
        while _G.AutoOpenHalloweenEgg and isRunning() do
            local g = getrenv()._G
            local candy = (g.TotalCurrency and g.TotalCurrency.CandyCorn) or 0
            if HatchEvent and candy >= cost then
                pcall(function() HatchEvent:FireServer(eggKey) end)
                task.wait(hatchSpeed)
            else
                task.wait(1)
            end
        end
    end)
end
function startHalloweenGlove()
    task.spawn(function()
        local stats = require(Modules:WaitForChild("GloveStats"))
        while _G.AutoEquipBestHalloweenGlove and isRunning() do
            local g = getrenv()._G
            local spooky = (g.TotalCurrency and g.TotalCurrency.SpookyDamage) or 0
            local best, multiplier
            for name, data in pairs(stats) do
                if type(data) == "table"
                    and data.stage == 100
                    and type(data.requirement) == "number"
                    and type(data.damageMultiplier) == "number"
                    and not data.robuxPrice
                    and spooky >= data.requirement
                    and (not multiplier or data.damageMultiplier > multiplier) then
                    best = name
                    multiplier = data.damageMultiplier
                end
            end
            if best and g.equippedGloves ~= best then
                GloveRemote:FireServer(best)
                UI:Notify({
                    Title = "Halloween Glove",
                    Content = "Equipping: " .. tostring(stats[best].name or best),
                    Duration = 3,
                    Type = "Success"
                })
            end
            task.wait(2)
        end
    end)
end
function startHalloweenBundle()
    task.spawn(function()
        local fn = hwRemote("function", "HalloweenRewardShopUIEvent")
        if not fn then return end
        while _G.AutoHalloweenBundle and isRunning() do
            local ok, state = pcall(function() return fn:InvokeServer("Opened") end)
            if ok and type(state) == "table" then
                for _, it in ipairs(hwBundleItems) do
                    if not _G.AutoHalloweenBundle then break end
                    if hwBundleSelected[it.key] and hwBundlePrice(state, it) <= (state.candyCorn or 0) then
                        local ok2, new = pcall(function() return fn:InvokeServer("Buy", it.key) end)
                        if ok2 and type(new) == "table" then state = new end
                        task.wait(0.5)
                    end
                end
            end
            task.wait(2)
        end
    end)
end
function startHalloweenPetHome()
    task.spawn(function()
        local fn = hwRemote("function", "HalloweenRewardShopUIEvent")
        if not fn then return end
        while _G.AutoHalloweenPetHome and isRunning() do
            local ok, state = pcall(function() return fn:InvokeServer("Opened") end)
            if ok and type(state) == "table" then
                for _, it in ipairs(hwPetItems) do
                    if not _G.AutoHalloweenPetHome then break end
                    local info = hwPetSelected[it.key] and hwPetInfo(state, it.key)
                    if info and info.bought < info.limit and info.have >= info.required and info.price <= (state.candyCorn or 0) then
                        local ok2, new = pcall(function() return fn:InvokeServer("Buy", "HomePet", it.key) end)
                        if ok2 and type(new) == "table" then state = new end
                        task.wait(0.5)
                    end
                end
            end
            task.wait(3)
        end
    end)
end
function startHalloweenUpgrade()
    task.spawn(function()
        while _G.AutoHalloweenUpgrade and isRunning() do
            if hwUpEv then
                pcall(function() hwUpEv:FireServer("update") end)
                task.wait(1)
                local candy = getrenv()._G.TotalCurrency and getrenv()._G.TotalCurrency.CandyCorn or 0
                local bestKey, bestCost
                for _, key in ipairs(hwUpKeys) do
                    local nxt = hwUpSelected[key] and hwUpData[key].levels[(hwUpLevels[key] or 0) + 1]
                    if nxt and nxt.cost <= candy and (not bestCost or nxt.cost < bestCost) then
                        bestKey, bestCost = key, nxt.cost
                    end
                end
                if bestKey then pcall(function() hwUpEv:FireServer("doUpgrade", bestKey) end) end
            end
            task.wait(1)
        end
    end)
end
HalloweenQuestPara = HalloweenTab:CreateParagraph({ Title = "Daily Quest Status", Content = "Loading..." })
task.spawn(function()
    local fn = hwRemote("function", "HalloweenDailyQuestsUIEvent")
    local questData = hwData("HalloweenDailyQuestData")
    local state, lastFetch = nil, 0
    local function fmtTime(sec)
        sec = math.max(0, math.floor(sec))
        local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
        if h > 0 then return ("%dh %dm %ds"):format(h, m, s) end
        return ("%dm %ds"):format(m, s)
    end
    local function questTitle(q)
        local def = questData and questData.quests and (questData.quests[q.key] or nil)
        if not def and questData and questData.quests then
            for _, d in pairs(questData.quests) do
                if type(d) == "table" and d.key == q.key then def = d break end
            end
        end
        local title = def and def.displayTitle or tostring(q.key)
        return (title:gsub("@", tostring(q.target)))
    end
    while isRunning() do
        local ok, text = pcall(function()
            if not fn then return "Status unavailable" end
            if not state or tick() - lastFetch >= 5 then
                local ok2, res = pcall(function() return fn:InvokeServer("Info") end)
                if ok2 and type(res) == "table" then state, lastFetch = res, tick() end
            end
            if type(state) ~= "table" then return "Status unavailable" end
            local lines = {}
            for _, name in ipairs({ "Hourly", "Daily" }) do
                local set = state[name]
                if type(set) == "table" then
                    local left = (set.endTime or 0) - workspace:GetServerTimeNow()
                    lines[#lines + 1] = name .. " (resets in " .. fmtTime(left) .. ")"
                    for _, q in ipairs(set.quests or {}) do
                        local status
                        if q.rewarded then
                            status = "Claimed"
                        elseif q.claimable then
                            status = "Ready to claim"
                        else
                            status = hwNum(math.min(q.progress or 0, q.target or 0)) .. "/" .. hwNum(q.target or 0)
                        end
                        lines[#lines + 1] = "- " .. questTitle(q) .. ": " .. status
                    end
                end
            end
            return table.concat(lines, "\n")
        end)
        pcall(HalloweenQuestPara.Set, HalloweenQuestPara, ok and text or "Status unavailable")
        task.wait(1)
    end
end)
function onHalloweenIsland()
    local char = game.Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hw = workspace:FindFirstChild("Halloween")
    local tp = hw and hw:FindFirstChild("TeleportLocations") and hw.TeleportLocations:FindFirstChild("Halloween")
    if not hrp or not tp then return false end
    local pos = tp:IsA("BasePart") and tp.Position or tp:GetPivot().Position
    return (hrp.Position - pos).Magnitude < 150
end
function ensureHalloweenWorld()
    if onHalloweenIsland() then return end
    pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("HalloweenTeleport"):InvokeServer()
    end)
    for _ = 1, 20 do
        if onHalloweenIsland() then break end
        task.wait(0.5)
    end
end
function addHwToggle(title, flag, fn, stop)
    return addToggle(HalloweenTab, title, flag, function()
        task.spawn(function()
            ensureHalloweenWorld()
            fn()
        end)
    end, stop)
end
addHwToggle("Auto Daily Quest", "AutoHalloweenQuest", startHalloweenQuest)
addHwToggle("Auto Claim Halloween Quest", "AutoHalloweenQuestClaim", startHalloweenQuestClaim)
addHwToggle("Auto Equip Best Halloween Glove", "AutoEquipBestHalloweenGlove", startHalloweenGlove)
addHwToggle("Auto Equip Best Halloween Pet", "AutoEquipBestHalloweenPet", startHalloweenPet)
addHwToggle("Auto Open Halloween Egg", "AutoOpenHalloweenEgg", startHalloweenEgg)
addHwToggle("Auto Farm Boss Halloween", "AutoFarmBossHalloween", startHalloweenBoss)
addHwToggle("Auto Farm Punch Halloween", "AutoFarmPunchHalloween", function()
    if not _G.FarmPunch then toggleObjs.FarmPunch.obj:Set(true) end
end, function()
    if _G.FarmPunch then toggleObjs.FarmPunch.obj:Set(false) end
end)
HalloweenTab:CreateSection("Halloween Reward Shop")
HalloweenTab:CreateButton({
    Title = "Open Halloween Reward Shop",
    Callback = function()
        pcall(hwOpenPanel, "HalloweenRewardShopUI", "Halloween Reward Shop")
    end
})
HalloweenShopPara = HalloweenTab:CreateParagraph({ Title = "Reward Shop Status", Content = "Loading..." })
task.spawn(function()
    local fn = hwRemote("function", "HalloweenRewardShopUIEvent")
    while isRunning() do
        local ok, text = pcall(function()
            local state = fn and fn:InvokeServer("Opened")
            if type(state) ~= "table" then return "Status unavailable" end
            local lines, left = {}, 0
            for _, it in ipairs(hwShopItems) do
                if (state.bought or {})[it.key] then
                    lines[#lines + 1] = it.displayName .. ": Bought"
                else
                    left += it.price
                    lines[#lines + 1] = it.displayName .. ": " .. hwNum(it.price) .. " Candy Corn"
                end
            end
            lines[#lines + 1] = "Total left: " .. hwNum(left) .. " Candy Corn"
            return table.concat(lines, "\n")
        end)
        hwSetLive(HalloweenShopPara, ok and text or "Status unavailable")
        task.wait(10)
    end
end)
HalloweenShopDropdown = HalloweenTab:CreateMultiDropdown({
    Title = "Select Reward Shop Items",
    Options = hwShopLabels,
    Callback = function(list)
        hwShopSelected = {}
        for _, label in ipairs(list) do
            local key = hwShopLabelToKey[label]
            if key then hwShopSelected[key] = true end
        end
    end
})
HalloweenShopDropdown:Set(hwShopLabels, true)
addHwToggle("Auto Buy Reward Shop", "AutoHalloweenShop", startHalloweenShop)
HalloweenTab:CreateSection("Wins, Gems & Potions")
HalloweenBundlePara = HalloweenTab:CreateParagraph({ Title = "Wins, Gems & Potions Status", Content = "Loading..." })
task.spawn(function()
    local fn = hwRemote("function", "HalloweenRewardShopUIEvent")
    while isRunning() do
        local ok, text = pcall(function()
            local state = fn and fn:InvokeServer("Opened")
            if type(state) ~= "table" then return "Status unavailable" end
            local lines = {}
            for _, it in ipairs(hwBundleItems) do
                local label = it.displayName
                if it.kind == "wins" and state.winsBundle then
                    label = label .. " (" .. hwNum(state.winsBundle.amount or 0) .. " Wins)"
                end
                lines[#lines + 1] = label .. ": " .. hwNum(hwBundlePrice(state, it)) .. " Candy Corn"
            end
            lines[#lines + 1] = "Candy Corn: " .. hwCandyText()
            return table.concat(lines, "\n")
        end)
        hwSetLive(HalloweenBundlePara, ok and text or "Status unavailable")
        task.wait(10)
    end
end)
HalloweenBundleDropdown = HalloweenTab:CreateMultiDropdown({
    Title = "Select Wins, Gems & Potions",
    Options = hwBundleLabels,
    Callback = function(list)
        hwBundleSelected = {}
        for _, label in ipairs(list) do
            local key = hwBundleLabelToKey[label]
            if key then hwBundleSelected[key] = true end
        end
    end
})
HalloweenBundleDropdown:Set(hwBundleLabels, true)
addHwToggle("Auto Buy Wins, Gems & Potions", "AutoHalloweenBundle", startHalloweenBundle)
HalloweenTab:CreateSection("Take a Pet Home")
HalloweenPetPara = HalloweenTab:CreateParagraph({ Title = "Take a Pet Home Status", Content = "Loading..." })
task.spawn(function()
    local fn = hwRemote("function", "HalloweenRewardShopUIEvent")
    while isRunning() do
        local ok, text = pcall(function()
            local state = fn and fn:InvokeServer("Opened")
            if type(state) ~= "table" then return "Status unavailable" end
            local lines = {}
            for _, it in ipairs(hwPetItems) do
                local info = hwPetInfo(state, it.key)
                if info then
                    local tail = info.bought >= info.limit and "LIMIT REACHED"
                        or (hwNum(info.price) .. " Candy Corn")
                    lines[#lines + 1] = ("%s: Taken %d/%d | Pets %d/%d | %s"):format(
                        it.name, info.bought, info.limit, info.have, info.required, tail)
                end
            end
            lines[#lines + 1] = "Candy Corn: " .. hwCandyText()
            return table.concat(lines, "\n")
        end)
        hwSetLive(HalloweenPetPara, ok and text or "Status unavailable")
        task.wait(10)
    end
end)
HalloweenPetDropdown = HalloweenTab:CreateMultiDropdown({
    Title = "Select Pets to Take Home",
    Options = hwPetLabels,
    Callback = function(list)
        hwPetSelected = {}
        for _, label in ipairs(list) do
            local key = hwPetLabelToKey[label]
            if key then hwPetSelected[key] = true end
        end
    end
})
HalloweenPetDropdown:Set(hwPetLabels, true)
addHwToggle("Auto Take Pet Home", "AutoHalloweenPetHome", startHalloweenPetHome)
HalloweenTab:CreateSection("Halloween Upgrades")
HalloweenUpPara = HalloweenTab:CreateParagraph({ Title = "Halloween Upgrade Status", Content = "Loading..." })
task.spawn(function()
    while isRunning() do
        local ok, text = pcall(function()
            if not hwUpEv then return "Status unavailable" end
            pcall(function() hwUpEv:FireServer("update") end)
            task.wait(1)
            local lines = { "Candy Corn: " .. hwCandyText() }
            local totalToMax = 0
            for _, key in ipairs(hwUpKeys) do
                local up = hwUpData[key]
                local level = hwUpLevels[key] or 0
                for i = level + 1, #up.levels do totalToMax += up.levels[i].cost end
                local nxt = up.levels[level + 1]
                lines[#lines + 1] = nxt
                    and ("%s: %d/%d | Next: %d Candy Corn"):format(up.displayName, level, #up.levels, nxt.cost)
                    or ("%s: MAX"):format(up.displayName)
            end
            lines[#lines + 1] = "Total to MAX all: " .. totalToMax .. " Candy Corn"
            return table.concat(lines, "\n")
        end)
        hwSetLive(HalloweenUpPara, ok and text or "Status unavailable")
        task.wait(4)
    end
end)
HalloweenUpDropdown = HalloweenTab:CreateMultiDropdown({
    Title = "Select Halloween Upgrades",
    Options = hwUpLabels,
    Callback = function(list)
        hwUpSelected = {}
        for _, label in ipairs(list) do
            local key = hwUpLabelToKey[label]
            if key then hwUpSelected[key] = true end
        end
    end
})
HalloweenUpDropdown:Set(hwUpLabels, true)
addHwToggle("Auto Upgrade", "AutoHalloweenUpgrade", startHalloweenUpgrade)
HalloweenTab:CreateSection("Teleport")
task.spawn(function()
    local quest = hwRemote("function", "HalloweenDailyQuestsUIEvent")
    while isRunning() do
        pcall(function()
            local lines = { "Candy Corn: " .. hwCandyText() }
            local claimable = "?"
            if quest then
                local ok, state = pcall(function() return quest:InvokeServer("Info") end)
                if ok and type(state) == "table" then
                    claimable = 0
                    for _, set in pairs(state) do
                        for _, q in ipairs(type(set) == "table" and set.quests or {}) do
                            if q.claimable == true then claimable += 1 end
                        end
                    end
                end
            end
            lines[#lines + 1] = "Quests claimable: " .. claimable
            hwSetLive(HalloweenPara, table.concat(lines, "\n"))
        end)
        task.wait(1)
    end
end)
HalloweenTab:CreateButton({
    Title = "TP Halloween World",
    Callback = function()
        task.spawn(function()
            local fn = hwRemote("function", "HalloweenTeleport")
            local ok, res = pcall(function() return fn and fn:InvokeServer() end)
            UI:Notify({ Title = "Teleport", Content = (ok and res) and "Teleported to Halloween" or "Server refused teleport", Duration = 2, Type = "Info" })
        end)
    end
})
HalloweenTab:CreateSection("Open Panels")
HalloweenTab:CreateButton({
    Title = "Open Halloween Glove Shop",
    Callback = function()
        pcall(hwOpenPanel, "HalloweenGloveShop", "Halloween Glove Shop")
    end
})
HalloweenTab:CreateButton({
    Title = "Open Halloween Upgrades",
    Callback = function()
        pcall(hwOpenPanel, "HalloweenUpgradesUI", "Halloween Upgrades")
    end
})
HalloweenTab:CreateButton({
    Title = "Open Halloween Quests (Hourly/Daily)",
    Callback = function()
        pcall(hwOpenPanel, "HalloweenDailyQuestsUI", "Halloween Quests")
    end
})
end
end
task.spawn(function()
    pcall(loadSettingsFile)
    local lastSaved = nil
    while isRunning() do
        local ok, json = pcall(function() return HttpService:JSONEncode(collectSettings()) end)
        if ok and json and json ~= lastSaved and not _G.PnkaStopSave then
            pcall(writefile, SETTINGS_FILE, json)
            lastSaved = json
        end
        task.wait(1.75)
    end
end)
