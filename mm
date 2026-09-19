--[[ Steal an Egg | Ultimate v6 | SPEED 300 + мгновенный ТП ]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local S = {
    Auto = false, ReturnHome = false,
    FlySpeed = 300,        -- снижено до 300
    Range = 6, Delay = 0.05,
    HomePos = nil,
    Rarities = {Common=true,Uncommon=true,Rare=true,Epic=true,Legendary=true,Mythic=true,Cosmic=true,Secret=true,Eternal=true,Divine=true},
}
local prio = {Divine=10,Eternal=9,Secret=8,Cosmic=7,Mythic=6,Legendary=5,Epic=4,Rare=3,Uncommon=2,Common=1}

local StealRemote, DropRemote
for _, o in ipairs(RS:GetDescendants()) do
    if o:IsA("RemoteEvent") then
        local n = o.Name:lower()
        if not StealRemote and (n:find("steal") or n:find("takeegg") or n:find("eggsteal")) then StealRemote = o end
        if not DropRemote and (n:find("drop") or n:find("removeegg") or n:find("clear") or n:find("discard")) then DropRemote = o end
    end
end

local function getRarity(o)
    for _, a in ipairs({"Rarity","rarity","EggRarity","Tier"}) do
        local v = o:GetAttribute(a)
        if v then return tostring(v) end
    end
    if o:GetAttribute("RareEgg") or o:GetAttribute("Highlight") then return "Rare" end
    local n = o.Name:lower()
    for r in pairs(prio) do if n:find(r:lower()) then return r end end
    return "Common"
end

local function isEgg(o)
    if not (o:IsA("Model") or o:IsA("Part") or o:IsA("MeshPart")) then return false end
    local n = o.Name:lower()
    if n:find("placed") and n:find("egg") then return true end
    if n:find("placeegg") or n:find("rareegg") or n:find("stealable") then return true end
    for _, a in ipairs({"IsEgg","IsPlaced","PlacedEgg","RareEgg","Stealable","Owner"}) do
        if o:GetAttribute(a) ~= nil then return true end
    end
    local p = o:FindFirstChildWhichIsA("ProximityPrompt", true)
    if p then
        local t = (p.ActionText.." "..p.ObjectText):lower()
        if t:find("steal") or t:find("take") or t:find("grab") then return true end
    end
    return false
end

local Cache, LastScan = {}, 0
local SCAN_INT = 0.8
local function scan()
    local now = tick()
    if now - LastScan < SCAN_INT then return Cache end
    LastScan = now
    local list = {}
    local function tryAdd(o)
        if isEgg(o) then
            table.insert(list, {
                model=o,
                prompt=o:FindFirstChildWhichIsA("ProximityPrompt", true),
                click=o:FindFirstChildWhichIsA("ClickDetector", true),
                rarity=getRarity(o),
                owner=tostring(o:GetAttribute("Owner") or o:GetAttribute("UserId") or "")
            })
        end
    end
    for _, o in ipairs(workspace:GetChildren()) do tryAdd(o) end
    for _, fn in ipairs({"Eggs","SpawnedEggs","ActiveEggs","EggFolder","PlacedEggs","Bases","Plots"}) do
        local f = workspace:FindFirstChild(fn)
        if f then for _, o in ipairs(f:GetChildren()) do
            tryAdd(o)
            for _, c in ipairs(o:GetChildren()) do tryAdd(c) end
        end end
    end
    Cache = list
    return list
end

local function nearestEgg()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local b, md = nil, math.huge
    local myId = tostring(LP.UserId)
    for _, e in ipairs(scan()) do
        if e.owner ~= myId then
            local d = (hrp.Position - e.model.Position).Magnitude
            if d < md then md = d b = e end
        end
    end
    return b
end

local function bestEgg()
    local b, sc = nil, -1
    local myId = tostring(LP.UserId)
    for _, e in ipairs(scan()) do
        if e.owner ~= myId and S.Rarities[e.rarity] and (prio[e.rarity] or 0) > sc then
            sc = prio[e.rarity] b = e
        end
    end
    return b
end

-- Полёт со скоростью 300
local function flyTo(pos, stopDist)
    stopDist = stopDist or 4
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end
    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity", hrp)
    bv.MaxForce = Vector3.new(1e6,1e6,1e6)
    local t = tick()
    local ok = false
    while S.Auto and tick() - t < 6 do
        if not hrp.Parent then break end
        local diff = pos - hrp.Position
        if diff.Magnitude < stopDist then ok = true break end
        bv.Velocity = diff.Unit * S.FlySpeed
        task.wait()
    end
    bv:Destroy()
    if hum then hum.PlatformStand = false end
    return ok
end

-- Мгновенный ТП
local function tpTo(pos)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0)) end
end

local function flyHome()
    if S.HomePos then
        tpTo(S.HomePos)
    end
end

local function doSteal(e)
    if e.prompt and fireproximityprompt then pcall(fireproximityprompt, e.prompt) return end
    if e.click and fireclickdetector then pcall(fireclickdetector, e.click) return end
    if StealRemote then pcall(function() StealRemote:FireServer(e.model) end) end
end

local function doDrop()
    if DropRemote then pcall(function() DropRemote:FireServer() end) end
end

task.spawn(function()
    while task.wait(0.1) do
        if not S.Auto then continue end

        -- 1) Ближайшее яйцо — быстро долетел, взял, сбросил
        local near = nearestEgg()
        if near then
            Status.Text = "1/3 → ближайшее: "..near.model.Name
            flyTo(near.model.Position, S.Range)
            doSteal(near)
            -- без пауз — сразу сброс
            doDrop()
        end

        -- 2) МГНОВЕННЫЙ ТП к целевому яйцу
        local target = bestEgg()
        if target then
            Status.Text = "2/3 ТП → "..target.model.Name.." ("..target.rarity..")"
            tpTo(target.model.Position)
            -- сразу крадём (ТП на месте — prompt уже рядом)
            doSteal(target)
            task.wait(S.Delay)

            -- 3) МГНОВЕННЫЙ ТП на базу
            if S.ReturnHome and S.HomePos then
                Status.Text = "3/3 ТП → база"
                flyHome()
                task.wait(0.05)
            end
        else
            Status.Text = "Нет подходящих яиц"
        end
    end
end)

-- GUI
local g = Instance.new("ScreenGui")
g.Name = "UltimateV6" g.ResetOnSpawn = false
g.Parent = LP:WaitForChild("PlayerGui")

local F = Instance.new("Frame", g)
F.Size = UDim2.new(0,340,0,300) F.Position = UDim2.new(0.5,-170,0.5,-150)
F.BackgroundColor3 = Color3.fromRGB(18,18,24) F.BorderSizePixel = 0
F.Active = true F.Draggable = true
Instance.new("UICorner", F).CornerRadius = UDim.new(0,10)

local T = Instance.new("TextLabel", F)
T.Size = UDim2.new(1,0,0,34) T.BackgroundColor3 = Color3.fromRGB(34,34,46)
T.TextColor3 = Color3.fromRGB(255,255,255) T.Text = "⚡ Steal an Egg v6 | Speed 300"
T.Font = Enum.Font.GothamBold T.TextSize = 14
Instance.new("UICorner", T).CornerRadius = UDim.new(0,10)

local X = Instance.new("TextButton", T)
X.Size = UDim2.new(0,26,0,26) X.Position = UDim2.new(1,-30,0,4)
X.BackgroundColor3 = Color3.fromRGB(200,50,50) X.TextColor3 = Color3.fromRGB(255,255,255)
X.Text = "X" X.Font = Enum.Font.GothamBold X.TextSize = 12
Instance.new("UICorner", X).CornerRadius = UDim.new(0,6)
X.MouseButton1Click:Connect(function() g:Destroy() end)

local body = Instance.new("Frame", F)
body.Size = UDim2.new(1,-20,1,-48) body.Position = UDim2.new(0,10,0,42)
body.BackgroundTransparency = 1
Instance.new("UIListLayout", body).Padding = UDim.new(0,5)

local function mkBtn(txt, col, cb)
    local b = Instance.new("TextButton", body)
    b.Size = UDim2.new(1,0,0,28) b.BackgroundColor3 = col or Color3.fromRGB(50,50,75)
    b.TextColor3 = Color3.fromRGB(255,255,255) b.Text = txt
    b.Font = Enum.Font.GothamBold b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
    return b
end

local toggle = mkBtn("▶ ВКЛЮЧИТЬ АВТО-КРАЖУ", Color3.fromRGB(50,160,50), function()
    S.Auto = not S.Auto
    toggle.Text = S.Auto and "⏹ ВЫКЛЮЧИТЬ" or "▶ ВКЛЮЧИТЬ АВТО-КРАЖУ"
    toggle.BackgroundColor3 = S.Auto and Color3.fromRGB(160,50,50) or Color3.fromRGB(50,160,50)
end)

Status = Instance.new("TextLabel", body)
Status.Size = UDim2.new(1,0,0,22) Status.BackgroundTransparency = 1
Status.TextColor3 = Color3.fromRGB(150,220,150) Status.Text = "Статус: ожидание"
Status.Font = Enum.Font.Gotham Status.TextSize = 12

mkBtn("🏠 Сохранить базу", Color3.fromRGB(60,60,140), function()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if r then S.HomePos = r.Position Status.Text = "База сохранена" end
end)

local retBtn = mkBtn("🔄 Возврат: ВЫКЛ", Color3.fromRGB(45,45,65), function()
    S.ReturnHome = not S.ReturnHome
    retBtn.Text = "🔄 Возврат: "..(S.ReturnHome and "ВКЛ" or "ВЫКЛ")
    retBtn.BackgroundColor3 = S.ReturnHome and Color3.fromRGB(40,110,40) or Color3.fromRGB(45,45,65)
end)

mkBtn("🔍 Диагностика (F9)", Color3.fromRGB(120,80,30), function()
    print("=== ДИАГНОСТИКА v6 ===")
    print("Steal:", StealRemote and StealRemote:GetFullName() or "нет")
    print("Drop:", DropRemote and DropRemote:GetFullName() or "нет")
    local list = scan()
    print("Яиц найдено:", #list)
    for i, e in ipairs(list) do
        print(i..") "..e.model:GetFullName().." | "..e.rarity.." | owner="..e.owner)
    end
    print("=== КОНЕЦ ===")
    Status.Text = "Яиц: "..#list.." — смотри F9"
end)
