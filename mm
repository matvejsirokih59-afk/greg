--[[ Auto Steal an Egg | Наш скрипт ]]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local RANGE, SPEED, WAIT_T, TIMEOUT = 8, 16, 0.4, 8
local Rarities = {Divine=true,Eternal=true,Secret=true,Cosmic=true,Mythic=true,Legendary=true,Epic=false,Rare=false,Uncommon=false,Common=false}
local Priority = {Divine=10,Eternal=9,Secret=8,Cosmic=7,Mythic=6,Legendary=5,Epic=4,Rare=3,Uncommon=2,Common=1}

local Steal = nil
for _, v in ipairs(RS:GetDescendants()) do
    if v:IsA("RemoteEvent") then
        local n = v.Name:lower()
        if n:find("steal") or n:find("takeegg") or n:find("eggsteal") then Steal = v break end
    end
end
if not Steal then warn("[AutoSteal] RemoteEvent не найден!") return end
print("[AutoSteal] RemoteEvent: " .. Steal:GetFullName())

local gui = Instance.new("ScreenGui")
gui.Name = "AutoStealGui" gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,200,0,400) frame.Position = UDim2.new(0,20,0,60)
frame.BackgroundColor3 = Color3.fromRGB(25,25,30) frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,28) title.BackgroundColor3 = Color3.fromRGB(45,45,55)
title.TextColor3 = Color3.fromRGB(255,255,255) title.Text = "Auto Steal an Egg"
title.Font = Enum.Font.GothamBold title.TextSize = 13 title.Parent = frame

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0,160,0,32) toggle.Position = UDim2.new(0,20,0,38)
toggle.BackgroundColor3 = Color3.fromRGB(50,150,50) toggle.TextColor3 = Color3.fromRGB(255,255,255)
toggle.Text = "ВКЛЮЧИТЬ" toggle.Font = Enum.Font.GothamBold toggle.TextSize = 13
toggle.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,0,0,18) status.Position = UDim2.new(0,0,0,76)
status.BackgroundTransparency = 1 status.TextColor3 = Color3.fromRGB(200,200,200)
status.Text = "Статус: выключено" status.Font = Enum.Font.Gotham
status.TextSize = 11 status.Parent = frame

local y = 100
for name, enabled in pairs(Rarities) do
    local check = Instance.new("TextButton")
    check.Size = UDim2.new(0,160,0,24) check.Position = UDim2.new(0,20,0,y)
    check.BackgroundColor3 = enabled and Color3.fromRGB(40,100,40) or Color3.fromRGB(45,45,45)
    check.TextColor3 = Color3.fromRGB(255,255,255)
    check.Text = name .. ": " .. (enabled and "ON" or "OFF")
    check.Font = Enum.Font.Gotham check.TextSize = 11 check.Parent = frame
    check.MouseButton1Click:Connect(function()
        Rarities[name] = not Rarities[name]
        check.Text = name .. ": " .. (Rarities[name] and "ON" or "OFF")
        check.BackgroundColor3 = Rarities[name] and Color3.fromRGB(40,100,40) or Color3.fromRGB(45,45,45)
    end)
    y = y + 26
end

local running, origSpeed = false, nil

local function getRarity(egg)
    for rName in pairs(Rarities) do
        if egg.Name:lower():find(rName:lower()) then return rName end
    end
    local a = egg:GetAttribute("Rarity") or egg:GetAttribute("rarity") or egg:GetAttribute("EggRarity")
    if a then return tostring(a) end
    for _, c in ipairs(egg:GetChildren()) do
        if c:IsA("StringValue") and c.Name:lower():find("rarity") then return c.Value end
    end
    return "Common"
end

local function findAllEggs()
    local list = {}
    for _, o in ipairs(workspace:GetDescendants()) do
        if (o:IsA("Model") or o:IsA("Part")) and o.Name:lower():find("egg") then
            if not (o:GetAttribute("Claimed") or o:GetAttribute("IsClaimed") or o:GetAttribute("Taken")) then
                table.insert(list, o)
            end
        end
    end
    return list
end

local function selectBest()
    local best, score = nil, -1
    for _, e in ipairs(findAllEggs()) do
        local r = getRarity(e)
        if Rarities[r] and (Priority[r] or 0) > score then
            score = Priority[r] best = e
        end
    end
    return best
end

local function moveTo(pos)
    local ch = LP.Character
    local h = ch and ch:FindFirstChildOfClass("Humanoid")
    local rt = ch and ch:FindFirstChild("HumanoidRootPart")
    if not (h and rt) then return false end
    h:MoveTo(pos)
    local t = tick()
    while running and tick() - t < TIMEOUT do
        if not rt.Parent then return false end
        if (rt.Position - pos).Magnitude < RANGE then h:MoveTo(rt.Position) return true end
        h:MoveTo(pos) task.wait(0.1)
    end
    return false
end

task.spawn(function()
    while task.wait(WAIT_T) do
        if not running then continue end
        local ch = LP.Character
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = SPEED else continue end
        local t = selectBest()
        if t then
            status.Text = "Цель: " .. t.Name .. " (" .. getRarity(t) .. ")"
            if moveTo(t.Position) and running then
                pcall(function() Steal:FireServer(t) end)
                task.wait(0.3)
            end
        else status.Text = "Подходящих яиц нет" end
    end
end)

toggle.MouseButton1Click:Connect(function()
    running = not running
    toggle.Text = running and "ВЫКЛЮЧИТЬ" or "ВКЛЮЧИТЬ"
    toggle.BackgroundColor3 = running and Color3.fromRGB(150,50,50) or Color3.fromRGB(50,150,50)
    status.Text = running and "Статус: включено" or "Статус: выключено"
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then
        if running then origSpeed = h.WalkSpeed h.WalkSpeed = SPEED
        else h.WalkSpeed = origSpeed or 16 end
    end
end)
print("[AutoSteal] Загружено!")
