--[[ Steal an Egg | Ultimate v9 | правильные RF + кнопка ]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local S = {
    Auto = false, ReturnHome = false,
    FlySpeed = 300, StopDist = 15, Range = 10,
    Delay = 0.05, HomePos = nil,
    Rarities = {Common=true,Uncommon=true,Rare=true,Epic=true,Legendary=true,Mythic=true,Cosmic=true,Secret=true,Eternal=true,Divine=true},
}
local prio = {Divine=10,Eternal=9,Secret=8,Cosmic=7,Mythic=6,Legendary=5,Epic=4,Rare=3,Uncommon=2,Common=1}

-- ===== ПРАВИЛЬНЫЕ REMOTE FUNCTION =====
local NetRoot = RS:FindFirstChild("Packages")
NetRoot = NetRoot and NetRoot:FindFirstChild("Networking")
local EggsFolder = NetRoot and NetRoot:FindFirstChild("RF")

local function findRF(path)
    local cur = EggsFolder
    for _, part in ipairs(path:split("/")) do
        if not cur then return nil end
        cur = cur:FindFirstChild(part)
    end
    return cur
end

local CarryRF = findRF("EggWorld/AskFieldEggCarry")
local DropRF  = findRF("EggWorld/AskFieldEggDrop")
local PlaceRF = findRF("EggWorld/AskPlaceEgg")
local HatchRF = findRF("EggWorld/AskHatch")

print("[v9] Carry:", CarryRF and CarryRF.Name or "нет")
print("[v9] Drop:", DropRF and DropRF.Name or "нет")

-- ===== КНОПКА ВЫБРОСА =====
local DropBtn = LP:WaitForChild("PlayerGui"):WaitForChild("DropHeldEgg", 5)
DropBtn = DropBtn and DropBtn:FindFirstChild("Button")

local function clickDropButton()
    if not DropBtn then
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            local f = pg:FindFirstChild("DropHeldEgg")
            if f then DropBtn = f:FindFirstChild("Button") end
        end
    end
    if not DropBtn then return false end
    pcall(function() DropBtn:Activate() end)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local p = DropBtn.AbsolutePosition + DropBtn.AbsoluteSize/2
        vim:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 1)
        task.wait(0.02)
        vim:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 1)
    end)
    return true
end

-- ===== ОПРЕДЕЛЕНИЕ РЕДКОСТИ =====
local function getRarity(o)
    for _, a in ipairs({"Rarity","rarity","EggRarity","Tier"}) do
        local v = o:GetAttribute(a)
        if v then return tostring(v) end
    end
    if o:GetAttribute("RareEgg") or o:GetAttribute("Highlight") then return "Rare" end
    for _, c in ipairs(o:GetChildren()) do
        if c:IsA("StringValue") and c.Name:lower():find("rarity") then return c.Value end
    end
    return "Common"
end

-- ===== ПОИСК ЯИЦ (правильные папки) =====
local function isEggObj(o)
    if not (o:IsA("Model") or o:IsA("Part") or o:IsA("MeshPart")) then return false end
    local n = o.Name:lower()
    if n:find("egg") then return true end
    if o:GetAttribute("Rarity") or o:GetAttribute("EggRarity") then return true end
    for _, c in ipairs(o:GetChildren()) do
        if c:IsA("StringValue") and c.Name:lower():find("rarity") then return true end
    end
    return false
end

local Cache, LastScan = {}, 0
local SCAN_INT = 1
local function scan()
    local now = tick()
    if now - LastScan < SCAN_INT then return Cache end
    LastScan = now
    local list = {}
    local folders = {
        workspace:FindFirstChild("PlacedEggRenders"),
        workspace:FindFirstChild("AreaEggSlotsClient"),
    }
    for _, f in ipairs(folders) do
        if f then
            for _, o in ipairs(f:GetChildren()) do
                -- сам объект и его дети
                if isEggObj(o) then
                    table.insert(list, {model=o, rarity=getRarity(o)})
                end
                for _, c in ipairs(o:GetChildren()) do
                    if isEggObj(c) then
                        table.insert(list, {model=c, rarity=getRarity(c)})
                    end
                end
            end
        end
    end
    Cache = list
    return list
end

local function nearestEgg()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local b, md = nil, math.huge
    for _, e in ipairs(scan()) do
        local d = (hrp.Position - e.model.Position).Magnitude
        if d < md then md = d b = e end
    end
    return b
end

local function bestEgg()
    local b, sc = nil, -1
    for _, e in ipairs(scan()) do
        if S.Rarities[e.rarity] and (prio[e.rarity] or 0) > sc then
            sc = prio[e.rarity] b = e
        end
    end
    return b
end

-- ===== ТП без смерти =====
local function zeroVel()
    local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if h then
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
    end
end

local function tpTo(pos)
    local ch = LP.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end
    hum.PlatformStand = true
    zeroVel()
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 8, 0))
    task.wait(0.05)
    zeroVel()
    hum.PlatformStand = false
end

-- ===== ПОЛЁТ =====
local function flyTo(pos, stopDist)
    stopDist = stopDist or S.StopDist
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
        local d = diff.Magnitude
        if d < stopDist then ok = true break end
        local sp = S.FlySpeed
        if d < stopDist * 3 then sp = math.max(80, S.FlySpeed * (d / (stopDist*3))) end
        bv.Velocity = diff.Unit * sp
        task.wait()
    end
    bv:Destroy()
    zeroVel()
    if hum then hum.PlatformStand = false end
    return ok
end

-- ===== КРАЖА / СБРОС =====
local function doCarry(egg)
    if CarryRF then
        local ok1 = pcall(function() CarryRF:InvokeServer(egg.model) end)
        local ok2 = pcall(function() CarryRF:InvokeServer() end)
        if ok1 or ok2 then return true end
    end
    -- fallback: ProximityPrompt / ClickDetector
    local p = egg.model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if p and fireproximityprompt then pcall(fireproximityprompt, p) return true end
    local c = egg.model:FindFirstChildWhichIsA("ClickDetector", true)
    if c and fireclickdetector then pcall(fireclickdetector, c) return true end
    return false
end

local function doDrop()
    -- сначала через RF
    if DropRF then
        pcall(function() DropRF:InvokeServer() end)
    end
    -- потом через кнопку (надёжнее)
    task.wait(0.05)
    clickDropButton()
end

-- ===== ЦИКЛ =====
task.spawn(function()
    while task.wait(0.1) do
        if not S.Auto then continue end

        -- 1) Ближайшее → взял → сбросил
        local n = nearestEgg()
        if n then
            Status.Text = "1/3 → ближайшее: "..n.model.Name
            flyTo(n.model.Position, S.StopDist)
            doCarry(n)
            task.wait(0.15)
            doDrop()
            task.wait(0.1)
        end

        -- 2) ТП к целевому
        local t = bestEgg()
        if t then
            Status.Text = "2/3 ТП → "..t.model.Name.." ("..t.rarity..")"
            tpTo(t.model.Position)
            task.wait(0.1)
            doCarry(t)
            task.wait(S.Delay)

            -- 3) ТП на базу
            if S.ReturnHome and S.HomePos then
                Status.Text = "3/3 ТП → база"
                tpTo(S.HomePos)
                task.wait(0.05)
            end
        else
            Status.Text = "Яиц нет"
        end
    end
end)

-- ===== GUI =====
local g = Instance.new("ScreenGui")
g.Name = "UltimateV9" g.ResetOnSpawn = false
g.Parent = LP:WaitForChild("PlayerGui")

local F = Instance.new("Frame", g)
F.Size = UDim2.new(0,340,0,300) F.Position = UDim2.new(0.5,-170,0.5,-150)
F.BackgroundColor3 = Color3.fromRGB(18,18,24) F.BorderSizePixel = 0
F.Active = true F.Draggable = true
Instance.new("UICorner", F).CornerRadius = UDim.new(0,10)

local T = Instance.new("TextLabel", F)
T.Size = UDim2.new(1,0,0,34) T.BackgroundColor3 = Color3.fromRGB(34,34,46)
T.TextColor3 = Color3.fromRGB(255,255,255) T.Text = "⚡ Steal an Egg v9 | RF + Кнопка"
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

mkBtn("🗑 Тест: выбросить яйцо", Color3.fromRGB(150,60,60), function()
    doDrop()
    Status.Text = "Кнопка выброса нажата"
end)

mkBtn("🔍 Показать яйца (F9)", Color3.fromRGB(120,80,30), function()
    print("=== ЯЙЦА ===")
    local list = scan()
    print("Найдено:", #list)
    for i, e in ipairs(list) do
        print(i..") "..e.model:GetFullName().." | "..e.rarity)
    end
    print("CarryRF:", CarryRF and "OK" or "нет")
    print("DropRF:", DropRF and "OK" or "нет")
    print("DropBtn:", DropBtn and DropBtn:GetFullName() or "нет")
    Status.Text = "Яиц: "..#list.." — смотри F9"
end)
