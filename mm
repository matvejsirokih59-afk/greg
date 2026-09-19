--[[ Steal an Egg | v10 | без кика ]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local S = {
    Auto=false, ReturnHome=false,
    FlySpeed=200,     -- медленнее, но безопаснее
    StopDist=15, Range=12, Delay=0.15,
    HomePos=nil,
    Rarities={Common=true,Uncommon=true,Rare=true,Epic=true,Legendary=true,Mythic=true,Cosmic=true,Secret=true,Eternal=true,Divine=true},
}
local prio={Divine=10,Eternal=9,Secret=8,Cosmic=7,Mythic=6,Legendary=5,Epic=4,Rare=3,Uncommon=2,Common=1}

-- RF
local Net = RS:FindFirstChild("Packages")
Net = Net and Net:FindFirstChild("Networking")
local RF = Net and Net:FindFirstChild("RF")
local function findRF(path)
    local cur = RF
    for _, p in ipairs(path:split("/")) do
        if not cur then return nil end
        cur = cur:FindFirstChild(p)
    end
    return cur
end
local CarryRF = findRF("EggWorld/AskFieldEggCarry")
local DropRF  = findRF("EggWorld/AskFieldEggDrop")

-- Кнопка выброса
local DropBtn = LP:WaitForChild("PlayerGui"):WaitForChild("DropHeldEgg", 5)
DropBtn = DropBtn and DropBtn:FindFirstChild("Button")

local function clickDrop()
    if not DropBtn then return end
    pcall(function() DropBtn:Activate() end)
end

-- ===== FIX: getPos для Model и BasePart =====
local function getPos(o)
    if not o then return nil end
    if o:IsA("Model") then
        local ok, piv = pcall(function() return o:GetPivot().Position end)
        if ok and piv then return piv end
        local prim = o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")
        if prim then return prim.Position end
        return nil
    elseif o:IsA("BasePart") then
        return o.Position
    end
    return nil
end

local function getRarity(o)
    for _, a in ipairs({"Rarity","rarity","EggRarity","Tier"}) do
        local v = o:GetAttribute(a)
        if v then return tostring(v) end
    end
    return "Common"
end

local function isEgg(o)
    if not (o:IsA("Model") or o:IsA("Part") or o:IsA("MeshPart")) then return false end
    if o:GetAttribute("Rarity") or o:GetAttribute("EggRarity") then return true end
    return o.Name:lower():find("egg") ~= nil
end

-- Скан
local Cache, Last = {}, 0
local function scan()
    if tick()-Last < 1 then return Cache end
    Last = tick()
    local list = {}
    for _, fn in ipairs({"PlacedEggRenders","AreaEggSlotsClient"}) do
        local f = workspace:FindFirstChild(fn)
        if f then
            for _, o in ipairs(f:GetChildren()) do
                if isEgg(o) then
                    local p = getPos(o)
                    if p then table.insert(list, {model=o, pos=p, rarity=getRarity(o)}) end
                end
                for _, c in ipairs(o:GetChildren()) do
                    if isEgg(c) then
                        local p = getPos(c)
                        if p then table.insert(list, {model=c, pos=p, rarity=getRarity(c)}) end
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
        local d = (hrp.Position - e.pos).Magnitude
        if d < md then md=d b=e end
    end
    return b
end

local function bestEgg()
    local b, sc = nil, -1
    for _, e in ipairs(scan()) do
        if S.Rarities[e.rarity] and (prio[e.rarity] or 0) > sc then
            sc=prio[e.rarity] b=e
        end
    end
    return b
end

-- Быстрый полёт БЕЗ CFrame-тп
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
    while S.Auto and tick()-t < 8 do
        if not hrp.Parent then break end
        local diff = pos - hrp.Position
        local d = diff.Magnitude
        if d < stopDist then ok=true break end
        local sp = S.FlySpeed
        if d < stopDist*3 then sp = math.max(60, S.FlySpeed*(d/(stopDist*3))) end
        bv.Velocity = diff.Unit * sp
        task.wait()
    end
    bv:Destroy()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    if hum then hum.PlatformStand = false end
    return ok
end

-- Кража (через RF, но с паузой)
local function doCarry(egg)
    if CarryRF then
        pcall(function() CarryRF:InvokeServer(egg.model) end)
    end
end

local function doDrop()
    pcall(function() if DropRF then DropRF:InvokeServer() end end)
    task.wait(0.1)
    clickDrop()
end

-- Цикл
task.spawn(function()
    while task.wait(0.15) do
        if not S.Auto then continue end

        local n = nearestEgg()
        if n then
            Status.Text = "1/3 → ближайшее"
            flyTo(n.pos, S.StopDist)
            doCarry(n)
            task.wait(0.25)
            doDrop()
            task.wait(0.2)
        end

        local t = bestEgg()
        if t then
            Status.Text = "2/3 → цель ("..t.rarity..")"
            flyTo(t.pos, S.StopDist)
            doCarry(t)
            task.wait(S.Delay)

            if S.ReturnHome and S.HomePos then
                Status.Text = "3/3 → база"
                flyTo(S.HomePos, 5)
                task.wait(0.2)
            end
        else
            Status.Text = "Яиц нет"
        end
    end
end)

-- GUI
local g = Instance.new("ScreenGui")
g.Name="UltimateV10" g.ResetOnSpawn=false
g.Parent = LP:WaitForChild("PlayerGui")

local F = Instance.new("Frame", g)
F.Size=UDim2.new(0,320,0,270) F.Position=UDim2.new(0.5,-160,0.5,-135)
F.BackgroundColor3=Color3.fromRGB(18,18,24) F.BorderSizePixel=0
F.Active=true F.Draggable=true
Instance.new("UICorner", F).CornerRadius=UDim.new(0,10)

local T = Instance.new("TextLabel", F)
T.Size=UDim2.new(1,0,0,32) T.BackgroundColor3=Color3.fromRGB(34,34,46)
T.TextColor3=Color3.fromRGB(255,255,255) T.Text="⚡ v10 | Без кика"
T.Font=Enum.Font.GothamBold T.TextSize=13
Instance.new("UICorner", T).CornerRadius=UDim.new(0,10)

local X = Instance.new("TextButton", T)
X.Size=UDim2.new(0,26,0,26) X.Position=UDim2.new(1,-30,0,3)
X.BackgroundColor3=Color3.fromRGB(200,50,50) X.TextColor3=Color3.fromRGB(255,255,255)
X.Text="X" X.Font=Enum.Font.GothamBold X.TextSize=12
Instance.new("UICorner", X).CornerRadius=UDim.new(0,6)
X.MouseButton1Click:Connect(function() g:Destroy() end)

local body = Instance.new("Frame", F)
body.Size=UDim2.new(1,-20,1,-46) body.Position=UDim2.new(0,10,0,40)
body.BackgroundTransparency=1
Instance.new("UIListLayout", body).Padding=UDim.new(0,5)

local function mkBtn(txt, col, cb)
    local b=Instance.new("TextButton", body)
    b.Size=UDim2.new(1,0,0,28) b.BackgroundColor3=col or Color3.fromRGB(50,50,75)
    b.TextColor3=Color3.fromRGB(255,255,255) b.Text=txt
    b.Font=Enum.Font.GothamBold b.TextSize=12
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
    return b
end

local toggle = mkBtn("▶ ВКЛЮЧИТЬ", Color3.fromRGB(50,160,50), function()
    S.Auto = not S.Auto
    toggle.Text = S.Auto and "⏹ ВЫКЛЮЧИТЬ" or "▶ ВКЛЮЧИТЬ"
    toggle.BackgroundColor3 = S.Auto and Color3.fromRGB(160,50,50) or Color3.fromRGB(50,160,50)
end)

Status = Instance.new("TextLabel", body)
Status.Size=UDim2.new(1,0,0,22) Status.BackgroundTransparency=1
Status.TextColor3=Color3.fromRGB(150,220,150) Status.Text="Статус: ожидание"
Status.Font=Enum.Font.Gotham Status.TextSize=12

mkBtn("🏠 Сохранить базу", Color3.fromRGB(60,60,140), function()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if r then S.HomePos = r.Position Status.Text="База сохранена" end
end)

local retBtn = mkBtn("🔄 Возврат: ВЫКЛ", Color3.fromRGB(45,45,65), function()
    S.ReturnHome = not S.ReturnHome
    retBtn.Text = "🔄 Возврат: "..(S.ReturnHome and "ВКЛ" or "ВЫКЛ")
    retBtn.BackgroundColor3 = S.ReturnHome and Color3.fromRGB(40,110,40) or Color3.fromRGB(45,45,65)
end)

mkBtn("🗑 Выбросить яйцо сейчас", Color3.fromRGB(150,60,60), doDrop)
