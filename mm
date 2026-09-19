--[[
    Steal An Egg | ULTIMATE HUB
    Объединяет лучшие функции из caomod2077, Dodoyung24, Project-Madara,
    bobloscript и UB Hub.
    Автор сборки: ты + я
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

-- ========== НАСТРОЙКИ ==========
local S = {
    AutoSteal = false, AutoPlace = false, AutoHatch = false,
    AutoSell = false, AutoFuse = false, AutoTreadmill = false,
    ReturnToBase = false, AutoServerHop = false, AntiAFK = true,
    Speed = 16, JumpPower = 50, StealRange = 10, StealDelay = 0.4,
    MinIncome = 0, BigEggWeight = 0,
    TargetPriority = "Rarest", -- Rarest / Nearest / MostMutated / Heaviest
    HomePos = nil,
    Rarities = {
        Common=true, Uncommon=true, Rare=true, Epic=true,
        Legendary=true, Mythic=true, Cosmic=true,
        Secret=true, Eternal=true, Divine=true
    },
    Zones = {
        Forest=true, Lake=true, Desert=true, Jungle=true,
        Snow=true, Volcano=true, ["Abyss Ocean"]=true,
        Prehistoric=true, Cosmic=true, Sakura=true, ["Titan Temple"]=true
    },
    Mutations = { Normal=true, Gold=true, Diamond=true, Rainbow=true, Crystal=true },
}

local priority = {Divine=10,Eternal=9,Secret=8,Cosmic=7,Mythic=6,Legendary=5,Epic=4,Rare=3,Uncommon=2,Common=1}
local zoneSpeed = {Forest=16, Lake=20, Desert=25, Jungle=30, Snow=35, Volcano=40, ["Abyss Ocean"]=50, Prehistoric=60, Cosmic=70, Sakura=80, ["Titan Temple"]=100}

-- ========== АВТО-ПОИСК REMOTE EVENT ==========
local StealRemote, PlaceRemote, HatchRemote, SellRemote, FuseRemote
for _, o in ipairs(RS:GetDescendants()) do
    if o:IsA("RemoteEvent") then
        local n = o.Name:lower()
        if n:find("steal") or n:find("takeegg") or n:find("eggsteal") then StealRemote = o end
        if n:find("place") or n:find("putegg") then PlaceRemote = o end
        if n:find("hatch") or n:find("openegg") then HatchRemote = o end
        if n:find("sell") then SellRemote = o end
        if n:find("fuse") then FuseRemote = o end
    end
end
print("[Ultimate] Steal:", StealRemote and StealRemote.Name or "не найден")
print("[Ultimate] Place:", PlaceRemote and PlaceRemote.Name or "не найден")
print("[Ultimate] Hatch:", HatchRemote and HatchRemote.Name or "не найден")

-- ========== ФУНКЦИИ ==========
local function getRarity(o)
    local a = o:GetAttribute("Rarity") or o:GetAttribute("rarity") or o:GetAttribute("EggRarity")
    if a then return tostring(a) end
    local n = o.Name:lower()
    for r in pairs(priority) do if n:find(r:lower()) then return r end end
    return "Common"
end

local function getMutation(o)
    local m = o:GetAttribute("Mutation") or o:GetAttribute("mutation")
    return m and tostring(m) or "Normal"
end

local function getIncome(o)
    local inc = o:GetAttribute("Income") or o:GetAttribute("income") or o:GetAttribute("Value")
    return tonumber(inc) or 0
end

local function getWeight(o)
    local w = o:GetAttribute("Weight") or o:GetAttribute("weight")
    return tonumber(w) or 0
end

local EggCache, LastScan = {}, 0
local SCAN_INT = 1.5

local function scanEggs()
    local now = tick()
    if now - LastScan < SCAN_INT then return EggCache end
    LastScan = now
    local container = workspace
    for _, name in ipairs({"Eggs","SpawnedEggs","ActiveEggs","EggFolder","Map"}) do
        local f = workspace:FindFirstChild(name)
        if f then container = f break end
    end
    local new = {}
    for _, o in ipairs(container:GetDescendants()) do
        if (o:IsA("Model") or o:IsA("Part")) and o.Name:lower():find("egg") then
            local prompt = o:FindFirstChildWhichIsA("ProximityPrompt", true)
            local click = o:FindFirstChildWhichIsA("ClickDetector", true)
            if prompt or click or StealRemote then
                table.insert(new, {
                    model = o, prompt = prompt, click = click,
                    rarity = getRarity(o), mutation = getMutation(o),
                    income = getIncome(o), weight = getWeight(o)
                })
            end
        end
    end
    EggCache = new
    return new
end

local function selectBestEgg()
    local eggs = scanEggs()
    local best, bestScore = nil, -math.huge
    for _, e in ipairs(eggs) do
        if S.Rarities[e.rarity] and S.Mutations[e.mutation] and e.income >= S.MinIncome then
            if S.BigEggWeight > 0 and e.weight < S.BigEggWeight then continue end
            local score = priority[e.rarity] or 0
            if S.TargetPriority == "Rarest" then
                score = (priority[e.rarity] or 0) * 1000 + e.income
            elseif S.TargetPriority == "MostMutated" then
                score = (e.mutation ~= "Normal" and 1 or 0) * 1000 + (priority[e.rarity] or 0)
            elseif S.TargetPriority == "Heaviest" then
                score = e.weight
            else -- Nearest
                local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if r then score = -((r.Position - e.model.Position).Magnitude) end
            end
            if score > bestScore then bestScore = score best = e end
        end
    end
    return best
end

local function moveTo(pos)
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local rt = ch and ch:FindFirstChild("HumanoidRootPart")
    if not (hum and rt) then return false end
    hum.WalkSpeed = S.Speed
    hum:MoveTo(pos)
    local t = tick()
    while S.AutoSteal and tick() - t < 6 do
        if not rt.Parent then return false end
        if (rt.Position - pos).Magnitude < S.StealRange then
            hum:MoveTo(rt.Position) return true
        end
        hum:MoveTo(pos) task.wait(0.1)
    end
    return false
end

local function doSteal(egg)
    if egg.prompt and fireproximityprompt then pcall(fireproximityprompt, egg.prompt) return end
    if egg.click and fireclickdetector then pcall(fireclickdetector, egg.click) return end
    if StealRemote then pcall(function() StealRemote:FireServer(egg.model) end) end
end

local function goHome()
    if S.HomePos then
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if r then r.CFrame = CFrame.new(S.HomePos + Vector3.new(0,5,0)) end
    end
end

-- ========== ОСНОВНОЙ ЦИКЛ ==========
task.spawn(function()
    while task.wait(0.2) do
        if S.AutoSteal then
            local ch = LP.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = S.Speed end
            local t = selectBestEgg()
            if t then
                StatusLabel.Text = "Цель: "..t.model.Name.." ("..t.rarity.." / "..t.mutation.." / $"..t.income..")"
                if moveTo(t.model.Position) then
                    doSteal(t)
                    task.wait(S.StealDelay)
                    if S.ReturnToBase then goHome() task.wait(0.3) end
                end
            else
                StatusLabel.Text = "Подходящих яиц нет"
            end
        end
        if S.AutoPlace and PlaceRemote then
            pcall(function() PlaceRemote:FireServer() end)
            task.wait(0.5)
        end
        if S.AutoHatch and HatchRemote then
            pcall(function() HatchRemote:FireServer() end)
            task.wait(0.5)
        end
        if S.AutoSell and SellRemote then
            pcall(function() SellRemote:FireServer() end)
            task.wait(0.5)
        end
        if S.AutoFuse and FuseRemote then
            pcall(function() FuseRemote:FireServer() end)
            task.wait(0.5)
        end
        if S.AutoTreadmill then
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:MoveTo(LP.Character.HumanoidRootPart.Position + Vector3.new(1,0,0)) end
        end
    end
end)

-- Anti-AFK
if S.AntiAFK then
    LP.Idled:Connect(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end

-- Server Hop
local function serverHop()
    local http = game:GetService("HttpService")
    local servers = http:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
    for _, s in ipairs(servers.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id, LP)
            return
        end
    end
end

-- ========== GUI ==========
local g = Instance.new("ScreenGui")
g.Name = "UltimateHub" g.ResetOnSpawn = false
g.Parent = LP:WaitForChild("PlayerGui")

local F = Instance.new("Frame")
F.Size = UDim2.new(0,460,0,380) F.Position = UDim2.new(0.5,-230,0.5,-190)
F.BackgroundColor3 = Color3.fromRGB(18,18,24) F.BorderSizePixel = 0
F.Active = true F.Draggable = true F.Parent = g
Instance.new("UICorner", F).CornerRadius = UDim.new(0,12)
local stroke = Instance.new("UIStroke", F)
stroke.Color = Color3.fromRGB(80,80,120) stroke.Thickness = 1.5

local T = Instance.new("TextLabel", F)
T.Size = UDim2.new(1,0,0,40) T.BackgroundColor3 = Color3.fromRGB(28,28,38)
T.TextColor3 = Color3.fromRGB(255,255,255) T.Text = "⚡ STEAL AN EGG | ULTIMATE HUB ⚡"
T.Font = Enum.Font.GothamBold T.TextSize = 16
Instance.new("UICorner", T).CornerRadius = UDim.new(0,12)

local X = Instance.new("TextButton", T)
X.Size = UDim2.new(0,28,0,28) X.Position = UDim2.new(1,-34,0,6)
X.BackgroundColor3 = Color3.fromRGB(200,50,50) X.TextColor3 = Color3.fromRGB(255,255,255)
X.Text = "✕" X.Font = Enum.Font.GothamBold X.TextSize = 14
Instance.new("UICorner", X).CornerRadius = UDim.new(0,6)
X.MouseButton1Click:Connect(function() g:Destroy() end)

local tabBar = Instance.new("Frame", F)
tabBar.Size = UDim2.new(1,-20,0,34) tabBar.Position = UDim2.new(0,10,0,46)
tabBar.BackgroundTransparency = 1
Instance.new("UIListLayout", tabBar).FillDirection = Enum.FillDirection.Horizontal
Instance.new("UIListLayout", tabBar).Padding = UDim.new(0,4)

local content = Instance.new("Frame", F)
content.Size = UDim2.new(1,-20,1,-90) content.Position = UDim2.new(0,10,0,86)
content.BackgroundTransparency = 1

local tabs = {}
local function makeTab(name)
    local b = Instance.new("TextButton", tabBar)
    b.Size = UDim2.new(0,86,1,0) b.BackgroundColor3 = Color3.fromRGB(40,40,55)
    b.TextColor3 = Color3.fromRGB(180,180,200) b.Text = name
    b.Font = Enum.Font.GothamBold b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local f = Instance.new("ScrollingFrame", content)
    f.Size = UDim2.new(1,0,1,0) f.BackgroundTransparency = 1 f.Visible = false
    f.ScrollBarThickness = 4 f.CanvasSize = UDim2.new(0,0,0,0)
    local lay = Instance.new("UIListLayout", f)
    lay.Padding = UDim.new(0,5)
    table.insert(tabs, {btn=b, frame=f})
    b.MouseButton1Click:Connect(function()
        for _, t in ipairs(tabs) do
            t.frame.Visible = false
            t.btn.BackgroundColor3 = Color3.fromRGB(40,40,55)
            t.btn.TextColor3 = Color3.fromRGB(180,180,200)
        end
        f.Visible = true
        b.BackgroundColor3 = Color3.fromRGB(70,70,110)
        b.TextColor3 = Color3.fromRGB(255,255,255)
    end)
    return f
end

local function makeBtn(parent, text, color, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(1,0,0,30) b.BackgroundColor3 = color or Color3.fromRGB(55,55,85)
    b.TextColor3 = Color3.fromRGB(255,255,255) b.Text = text
    b.Font = Enum.Font.GothamBold b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
    return b
end

-- Главная
local main = makeTab("Главная")
local toggle = makeBtn(main, "▶ ВКЛЮЧИТЬ АВТО-КРАЖУ", Color3.fromRGB(50,160,50), function()
    S.AutoSteal = not S.AutoSteal
    toggle.Text = S.AutoSteal and "⏹ ВЫКЛЮЧИТЬ АВТО-КРАЖУ" or "▶ ВКЛЮЧИТЬ АВТО-КРАЖУ"
    toggle.BackgroundColor3 = S.AutoSteal and Color3.fromRGB(160,50,50) or Color3.fromRGB(50,160,50)
end)
StatusLabel = Instance.new("TextLabel", main)
StatusLabel.Size = UDim2.new(1,0,0,22) StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(150,220,150) StatusLabel.Text = "Статус: ожидание"
StatusLabel.Font = Enum.Font.Gotham StatusLabel.TextSize = 12

makeBtn(main, "🏠 Сохранить базу", Color3.fromRGB(60,60,140), function()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if r then S.HomePos = r.Position StatusLabel.Text = "База сохранена!" end
end)
local retBtn = makeBtn(main, "🔄 Возврат на базу: ВЫКЛ", Color3.fromRGB(45,45,65), function()
    S.ReturnToBase = not S.ReturnToBase
    retBtn.Text = "🔄 Возврат на базу: "..(S.ReturnToBase and "ВКЛ" or "ВЫКЛ")
    retBtn.BackgroundColor3 = S.ReturnToBase and Color3.fromRGB(40,100,40) or Color3.fromRGB(45,45,65)
end)
makeBtn(main, "🔍 Диагностика", Color3.fromRGB(120,80,30), function()
    local eggs = scanEggs()
    print("=== Диагностика ===")
    print("Яиц найдено:", #eggs)
    if #eggs > 0 then
        local e = eggs[1]
        print("Пример:", e.model.Name, "| Редкость:", e.rarity, "| Мутация:", e.mutation, "| Доход:", e.income)
    end
    print("StealRemote:", StealRemote and StealRemote:GetFullName() or "нет")
    print("PlaceRemote:", PlaceRemote and PlaceRemote:GetFullName() or "нет")
    print("HatchRemote:", HatchRemote and HatchRemote:GetFullName() or "нет")
    StatusLabel.Text = "Смотри консоль (F9)"
end)

-- Автоматизация
local auto = makeTab("Авто")
for _, key in ipairs({"AutoPlace","AutoHatch","AutoSell","AutoFuse","AutoTreadmill","AutoServerHop","AntiAFK"}) do
    local labels = {AutoPlace="Авто-установка яиц", AutoHatch="Авто-инкубация", AutoSell="Авто-продажа", AutoFuse="Авто-фьюз", AutoTreadmill="Авто-беговая дорожка", AutoServerHop="Авто-смена сервера", AntiAFK="Anti-AFK"}
    local b = makeBtn(auto, labels[key]..": "..(S[key] and "ВКЛ" or "ВЫКЛ"), S[key] and Color3.fromRGB(40,100,40) or Color3.fromRGB(45,45,65), function()
        S[key] = not S[key]
        b.Text = labels[key]..": "..(S[key] and "ВКЛ" or "ВЫКЛ")
        b.BackgroundColor3 = S[key] and Color3.fromRGB(40,100,40) or Color3.fromRGB(45,45,65)
        if key == "AutoServerHop" and S[key] then serverHop() end
    end)
end

-- Фильтры
local filt = makeTab("Фильтры")
makeBtn(filt, "🎯 Приоритет: "..S.TargetPriority, Color3.fromRGB(80,60,120), function()
    local modes = {"Rarest","Nearest","MostMutated","Heaviest"}
    local i = 1
    for idx, m in ipairs(modes) do if m == S.TargetPriority then i = idx break end end
    i = i % #modes + 1
    S.TargetPriority = modes[i]
    filt:FindFirstChildWhichIsA("TextButton").Text = "🎯 Приоритет: "..S.TargetPriority
end)

local rarityFrame = Instance.new("Frame", filt)
rarityFrame.Size = UDim2.new(1,0,0,180) rarityFrame.BackgroundTransparency = 1
rarityFrame.Parent = filt
Instance.new("UIListLayout", rarityFrame).Padding = UDim.new(0,3)
local rTitle = Instance.new("TextLabel", rarityFrame)
rTitle.Size = UDim2.new(1,0,0,20) rTitle.BackgroundTransparency = 1
rTitle.TextColor3 = Color3.fromRGB(200,200,220) rTitle.Text = "Редкости:"
rTitle.Font = Enum.Font.GothamBold rTitle.TextSize = 12 rTitle.TextXAlignment = Enum.TextXAlignment.Left
for r, _ in pairs(S.Rarities) do
    local b = Instance.new("TextButton", rarityFrame)
    b.Size = UDim2.new(0,100,0,24) b.BackgroundColor3 = S.Rarities[r] and Color3.fromRGB(40,100,40) or Color3.fromRGB(45,45,65)
    b.TextColor3 = Color3.fromRGB(220,220,220) b.Text = r
    b.Font = Enum.Font.Gotham b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    b.MouseButton1Click:Connect(function()
        S.Rarities[r] = not S.Rarities[r]
        b.BackgroundColor3 = S.Rarities[r] and Color3.fromRGB(40,100,40) or Color3.fromRGB(45,45,65)
    end)
end

-- Настройки
local set = makeTab("Настройки")
local function makeSlider(parent, text, min, max, val, cb)
    local c = Instance.new("Frame", parent)
    c.Size = UDim2.new(1,0,0,45) c.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,0,0,20) l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(200,200,220) l.Text = text..": "..val
    l.Font = Enum.Font.Gotham l.TextSize = 12 l.TextXAlignment = Enum.TextXAlignment.Left
    local bar = Instance.new("Frame", c)
    bar.Size = UDim2.new(1,-10,0,6) bar.Position = UDim2.new(0,5,0,28)
    bar.BackgroundColor3 = Color3.fromRGB(50,50,65) bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((val-min)/(max-min),0,1,0) fill.BackgroundColor3 = Color3.fromRGB(80,160,255)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("TextButton", bar)
    knob.Size = UDim2.new(0,14,0,14) knob.Position = UDim2.new((val-min)/(max-min),-7,0.5,-7)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255) knob.Text = ""
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local drag = false
    knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local a = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = min + a * (max - min)
            fill.Size = UDim2.new(a,0,1,0) knob.Position = UDim2.new(a,-7,0.5,-7)
            l.Text = text..": "..math.floor(v*100)/100
            cb(v)
        end
    end)
end

makeSlider(set, "Скорость ходьбы", 8, 100, S.Speed, function(v) S.Speed = v end)
makeSlider(set, "Дистанция кражи", 4, 20, S.StealRange, function(v) S.StealRange = v end)
makeSlider(set, "Задержка кражи (сек)", 0.1, 2, S.StealDelay, function(v) S.StealDelay = v end)
makeSlider(set, "Мин. доход ($)", 0, 1000000, S.MinIncome, function(v) S.MinIncome = v end)

print("[Ultimate Hub] Загружено успешно!")
