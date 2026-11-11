if game.PlaceId ~= 76869349597254 then return nil end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local remote = ReplicatedStorage:WaitForChild("PianoGameEvent")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("PianoGui")
local area = gui:WaitForChild("GameArea")
local mainMenu = gui:WaitForChild("MainMenu")
local playButton = mainMenu:WaitForChild("PlayButton")
local openButton = gui:WaitForChild("OpenMenuButton")
local countdown = gui:WaitForChild("CountdownLabel")
local gameOver = gui:WaitForChild("GameOverPanel")
local backButton = gameOver:WaitForChild("BackButton")

local StarterGui = game:GetService("StarterGui")
local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "by pnka",
            Text = tostring(text),
            Duration = 3
        })
    end)
end

_G.ENABLED = false
_G.AUTO_PLAY = false
_G.DEBUG = false
_G.TRIGGER_Y = 100
_G.DEFAULT_MAX_Y = 272
_G.MAX_Y = _G.DEFAULT_MAX_Y
_G.FAKE_HEIGHT = 0
_G.START_COOLDOWN = 1
_G.RESTART_DELAY = 1.5

local scoreLabel = area:WaitForChild("ScoreLabel")

local playing = false
local roundId = 0
local currentSpeed = 200
local lastPress = 0
local lastOver = 0
local clicked = {}

local function pressButton(btn)
    if firesignal and pcall(firesignal, btn.MouseButton1Click) then return end
    if getconnections then
        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
            pcall(function() c:Fire() end)
        end
    end
end

local function updateMaxY()
    if _G.FAKE_HEIGHT and _G.FAKE_HEIGHT > 0 then
        _G.MAX_Y = _G.FAKE_HEIGHT
    else
        local h = math.floor(area.AbsoluteSize.Y)
        _G.MAX_Y = h > 0 and h or _G.DEFAULT_MAX_Y
    end
end

local function spoofHeight()
    if _G.FAKE_HEIGHT and _G.FAKE_HEIGHT > 0 then
        remote:FireServer("ReportGameAreaHeight", { height = _G.FAKE_HEIGHT })
        if _G.DEBUG then notify("sent ReportGameAreaHeight = " .. _G.FAKE_HEIGHT) end
    end
end

countdown:GetPropertyChangedSignal("Visible"):Connect(function()
    if countdown.Visible and _G.ENABLED then
        updateMaxY()
        task.delay(0.5, spoofHeight)
        task.delay(3, spoofHeight)
    end
end)

local function scheduleClick(tileId, speed)
    if tileId == nil then return end
    local trigger = math.min(_G.TRIGGER_Y, _G.MAX_Y - 40)
    local delay = math.max(0, (trigger + 80) / speed)
    local myRound = roundId
    task.delay(delay, function()
        if myRound ~= roundId or not playing or not _G.ENABLED or clicked[tileId] then return end
        clicked[tileId] = true
        remote:FireServer("TileClicked", { tileId = tileId })
        if _G.DEBUG then notify("clicked tile " .. tostring(tileId)) end
    end)
end

remote.OnClientEvent:Connect(function(action, data)
    if type(data) ~= "table" then data = {} end
    if action == "SpawnTile" then
        if _G.ENABLED and playing then
            scheduleClick(data.tileId, tonumber(data.speed) or currentSpeed)
        end
    elseif action == "ScoreUpdate" then
        if type(data.speed) == "number" then currentSpeed = data.speed end
    elseif action == "GameOverSecure" then
        playing = false
        roundId += 1
        lastOver = os.clock()
        if _G.DEBUG then notify("game over, score: " .. tostring(data.finalScore)) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        local inGame = area.Visible or countdown.Visible
        if inGame then
            if not playing then
                playing = true
                roundId += 1
                clicked = {}
            end
        elseif _G.AUTO_PLAY and os.clock() - lastPress >= _G.START_COOLDOWN
            and os.clock() - lastOver >= _G.RESTART_DELAY then
            lastPress = os.clock()
            if gameOver.Visible then
                pressButton(backButton)
                if _G.DEBUG then notify("pressed Back") end
            elseif mainMenu.Visible then
                pressButton(playButton)
                if _G.DEBUG then notify("pressed Play") end
            else
                pressButton(openButton)
                if _G.DEBUG then notify("pressed Open") end
            end
        end
    end
end)

_G.AUTO_GACHA = false
local rouletteEvents = nil

task.spawn(function()
    while true do
        task.wait(1)
        if _G.AUTO_GACHA then
            rouletteEvents = rouletteEvents or ReplicatedStorage:FindFirstChild("RouletteEvents")
            local getCooldown = rouletteEvents and rouletteEvents:FindFirstChild("GetCooldown")
            local spinRequest = rouletteEvents and rouletteEvents:FindFirstChild("SpinRequest")
            if getCooldown and spinRequest then
                local ok, cd = pcall(function() return getCooldown:InvokeServer() end)
                if ok and type(cd) == "number" then
                    if cd <= 0 then
                        spinRequest:FireServer()
                        if _G.DEBUG then notify("gacha spin") end
                        task.wait(5)
                    else
                        task.wait(math.clamp(cd, 1, 10))
                    end
                end
            end
        end
    end
end)

_G.AUTO_ORB = false
_G.ORB_DELAY = 0.5

task.spawn(function()
    while true do
        task.wait(_G.ORB_DELAY)
        if _G.AUTO_ORB and firetouchinterest then
            local char = Players.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, v in ipairs(workspace.Terrain:GetDescendants()) do
                    if v:IsA("Folder") and string.find(v.Name:lower(), "parkour") then
                        for _, d in ipairs(v:GetDescendants()) do
                            if d:IsA("BasePart") and string.find(d.Name:lower(), "orb") then
                                pcall(function()
                                    firetouchinterest(root, d, 0)
                                    firetouchinterest(root, d, 1)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

local tycoonNames = {
    "SpedRuner Tycoon",
    "Noob Tycoon",
    "Pro Tycoon",
    "Herobrine Tycoon"
}

local function getTycoonFolder()
    local f = workspace:FindFirstChild("Tycoon")
    return f and f:FindFirstChild("Tycoons")
end

local function getTycoon()
    local folder = getTycoonFolder()
    if not folder then return nil end
    local lp = Players.LocalPlayer
    for _, name in ipairs(tycoonNames) do
        local x = folder:FindFirstChild(name)
        if x then
            local info = x:FindFirstChild("TycoonInfo")
            local owner = info and info:FindFirstChild("Owner")
            if owner and (owner.Value == lp.Name or owner.Value == lp) then
                return x
            end
        end
    end
    return nil
end

local function getClaimHead(name)
    local folder = getTycoonFolder()
    local t = folder and folder:FindFirstChild(name)
    local entrance = t and t:FindFirstChild("Essentials") and t.Essentials:FindFirstChild("Entrance")
    local claim = entrance and entrance:FindFirstChild("Touch To Claim!")
    return claim and claim:FindFirstChild("Head")
end

local function inNoTycoonTeam()
    local team = Players.LocalPlayer.Team
    return team ~= nil and team.Name == "No Tycoon"
end

-- Auto claim: nếu team là No Tycoon, chạm lần lượt claim của 4 tycoon đến khi có team
_G.AUTO_CLAIM = false

task.spawn(function()
    while true do
        if _G.AUTO_CLAIM and inNoTycoonTeam() then
            local char = Players.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and firetouchinterest then
                for _, name in ipairs(tycoonNames) do
                    local head = getClaimHead(name)
                    if head then
                        firetouchinterest(root, head, 0)
                        task.wait(0.2)
                        firetouchinterest(root, head, 1)
                        task.wait(0.2)
                    end
                    if not inNoTycoonTeam() or not _G.AUTO_CLAIM then break end
                end
            end
            task.wait(0.5)
        else
            task.wait(1)
        end
    end
end)

-- Auto cash: chạm Giver của tycoon bạn sở hữu mỗi 5 giây
_G.AUTO_CASH = false

task.spawn(function()
    while true do
        if _G.AUTO_CASH and firetouchinterest then
            local lp = Players.LocalPlayer
            local char = lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local tycoon = getTycoon()
            if root and tycoon then
                local essentials = tycoon:FindFirstChild("Essentials")
                local giver = essentials and essentials:FindFirstChild("Giver")
                if giver then
                    pcall(function()
                        firetouchinterest(root, giver, 0)
                        task.wait(0.5)
                        firetouchinterest(root, giver, 1)
                    end)
                end
            end
        end
        task.wait(5)
    end
end)

-- Auto buy: chỉ mua nút đang hiện (Head.Transparency < 1), từ rẻ đến đắt
_G.AUTO_BUY = false
local buyRetryAt = {}

local function touchPart(part)
    local lp = Players.LocalPlayer
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and part and part:IsA("BasePart") and firetouchinterest then
        firetouchinterest(root, part, 0)
        firetouchinterest(root, part, 1)
    end
end

local function playerCash()
    local ls = Players.LocalPlayer:FindFirstChild("leaderstats")
    local c = ls and ls:FindFirstChild("Cash")
    return c and c.Value or 0
end

task.spawn(function()
    while true do
        if _G.AUTO_BUY then
            local tycoon = getTycoon()
            local buttons = tycoon and tycoon:FindFirstChild("Buttons")
            local list = {}
            if buttons then
                local money = playerCash()
                local now = os.clock()
                for _, b in ipairs(buttons:GetChildren()) do
                    local price = b:FindFirstChild("Price")
                    local head = b:FindFirstChild("Head")
                    if head and head.Transparency < 1 and price and price.Value > 0
                        and price.Value <= money and (buyRetryAt[b] or 0) <= now then
                        table.insert(list, {b = b, head = head, price = price.Value})
                    end
                end
            end
            table.sort(list, function(a, b) return a.price < b.price end)
            if list[1] then
                local item = list[1]
                touchPart(item.head)
                task.wait(0.6)
                if item.b.Parent then buyRetryAt[item.b] = os.clock() + 5 end
            else
                task.wait(1)
            end
        else
            task.wait(1)
        end
    end
end)

local ToggleMain

local function applyEnabled(on)
    _G.ENABLED = on
end

local function applyAutoPlay(on)
    _G.AUTO_PLAY = on
end

local function PianoPlay()
    applyEnabled(true)
    applyAutoPlay(true)
    if ToggleMain then pcall(function() ToggleMain:Set(true) end) end
    notify("PianoPlay: enabled")
end

local function PianoStop()
    applyEnabled(false)
    applyAutoPlay(false)
    if ToggleMain then pcall(function() ToggleMain:Set(false) end) end
    notify("PianoStop: disabled")
end

local env = (getgenv and getgenv()) or _G
env.PianoPlay = PianoPlay
env.PianoStop = PianoStop

local okUI, uiErr = pcall(function()
    local redzlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/emaandthw/my-Ui-Library/refs/heads/main/redzlib.lua"))()

    local Window = redzlib:MakeWindow({
        Title = "Craft cube Tycoon",
        SubTitle = "by pnka",
        SaveFolder = "Redz Config"
    })

    Window:AddMinimizeButton({
        Button = { Image = "rbxassetid://10734896206", BackgroundTransparency = 0 },
        Corner = { CornerRadius = UDim.new(0.5, 0) },
    })

    local TabMain = Window:MakeTab({ "Tab Main", "home" })
    local TabSetting = Window:MakeTab({ "Tab Setting", "settings" })

    local ScoreParagraph = TabMain:AddParagraph({ "Score", tostring(scoreLabel.Text) })
    scoreLabel:GetPropertyChangedSignal("Text"):Connect(function()
        pcall(function() ScoreParagraph:SetDesc(tostring(scoreLabel.Text)) end)
    end)

    ToggleMain = TabMain:AddToggle({
        Name = "Auto piano",
        Description = "Auto start rounds + auto click tiles + auto replay",
        Default = false,
        Callback = function(Value)
            applyEnabled(Value)
            applyAutoPlay(Value)
        end
    })

    TabMain:AddToggle({
        Name = "Auto Claim Tycoon",
        Description = "If team is No Tycoon, claim any of the 4 tycoons until you get a team",
        Default = false,
        Callback = function(Value)
            _G.AUTO_CLAIM = Value
        end
    })

    TabMain:AddToggle({
        Name = "Auto Gacha",
        Description = "Spin automatically whenever the cooldown is ready",
        Default = false,
        Callback = function(Value)
            _G.AUTO_GACHA = Value
        end
    })

    TabMain:AddToggle({
        Name = "Auto Collect Orb",
        Description = "Touch every orb in the parkour folders (delay is set in Tab Setting)",
        Default = false,
        Callback = function(Value)
            _G.AUTO_ORB = Value
        end
    })

    TabMain:AddToggle({
        Name = "Auto Collect Cash",
        Description = "Collect cash from your tycoon every 5s",
        Default = false,
        Callback = function(Value)
            _G.AUTO_CASH = Value
        end
    })

    TabMain:AddToggle({
        Name = "Auto Buy Visible",
        Description = "Buy the visible tycoon buttons, cheapest first",
        Default = false,
        Callback = function(Value)
            _G.AUTO_BUY = Value
        end
    })

    TabSetting:AddButton({
        Name = "TP Safe Zone",
        Description = "Teleport to (400, 2, 668)",
        Callback = function()
            local char = Players.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = CFrame.new(400, 2, 668)
            else
                notify("Character not found")
            end
        end
    })

    local OrbDelayBox = TabSetting:AddTextBox({
        Name = "Orb delay (s)",
        Description = "Seconds between orb collects (default 0.5, min 0.05)",
        PlaceholderText = tostring(_G.ORB_DELAY),
        ClearText = true,
        Callback = function(Text)
            local n = tonumber(Text)
            if n then
                _G.ORB_DELAY = math.max(0.05, n)
                if _G.DEBUG then notify("ORB_DELAY = " .. _G.ORB_DELAY) end
            end
        end
    })
    OrbDelayBox.OnChanging = function(Text)
        local t = Text:gsub("[^%d%.]", "")
        local first = t:find("%.")
        if first then
            t = t:sub(1, first) .. t:sub(first + 1):gsub("%.", "")
        end
        return t
    end

    TabSetting:AddToggle({
        Name = "Hide PianoGui",
        Description = "On: hide PianoGui (script keeps running). Off: show it again",
        Default = false,
        Callback = function(Value)
            gui.Enabled = not Value
        end
    })

    local TriggerBox = TabSetting:AddTextBox({
        Name = "Click point (Y)",
        Description = "Click when the tile reaches this Y (any number, max = height - 40)",
        PlaceholderText = tostring(_G.TRIGGER_Y),
        ClearText = true,
        Callback = function(Text)
            local n = tonumber(Text)
            if n then _G.TRIGGER_Y = n end
        end
    })
    TriggerBox.OnChanging = function(Text)
        return (Text:gsub("%D", ""))
    end

    local HeightBox = TabSetting:AddTextBox({
        Name = "Fake height",
        Description = "Height sent to server, also the tile Y limit (0 = send real height)",
        PlaceholderText = tostring(_G.FAKE_HEIGHT),
        ClearText = true,
        Callback = function(Text)
            local n = tonumber(Text)
            if n then
                _G.FAKE_HEIGHT = math.floor(n)
                _G.MAX_Y = _G.FAKE_HEIGHT > 0 and _G.FAKE_HEIGHT or _G.DEFAULT_MAX_Y
                if _G.DEBUG then notify("FAKE_HEIGHT = " .. _G.FAKE_HEIGHT) end
            end
        end
    })
    HeightBox.OnChanging = function(Text)
        return (Text:gsub("%D", ""))
    end

    TabSetting:AddSlider({
        Name = "UI size (%)",
        Description = "Drag down to shrink the UI",
        Min = 40,
        Max = 150,
        Increase = 5,
        Default = 100,
        Callback = function(Value)
            pcall(function()
                redzlib:SetScale(450 / (Value / 100))
            end)
        end
    })
end)

if not okUI then
    notify("Could not create UI: " .. tostring(uiErr) .. " - use PianoPlay() / PianoStop() instead")
end

notify("v12 ready. Run PianoPlay() to enable, PianoStop() to disable.")
return "craftcube script loaded"
