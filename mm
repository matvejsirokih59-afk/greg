--[[
    Steal an Egg | Auto Steal + GUI
    - Авто-кража через ProximityPrompt
    - Плавное движение (WalkSpeed = 16 по умолчанию)
    - Фильтр редкости (галочки)
    - Возврат на базу
    - Телепорты к яйцам
    - Красивое тёмное GUI
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ========== НАСТРОЙКИ ==========
local Settings = {
    AutoSteal = false,
    ReturnToBase = true,
    WalkSpeed = 16,
    StealRange = 8,
    Delay = 0.3,
    Rarities = {
        Common = true, Uncommon = true, Rare = true, Epic = true,
        Legendary = true, Mythic = true, Cosmic = true,
        Secret = true, Eternal = true, Divine = true,
    },
    BasePosition = nil,
}

-- ========== ФУНКЦИИ ==========
local function getRarity(egg)
    local attr = egg:GetAttribute("Rarity") or egg:GetAttribute("rarity") or egg:GetAttribute("EggRarity")
    if attr then return tostring(attr) end
    local name = egg.Name:lower()
    local rarities = {"divine","eternal","secret","cosmic","mythic","legendary","epic","rare","uncommon","common"}
    for _, r in ipairs(rarities) do
        if name:find(r) then return r:sub(1,1):upper()..r:sub(2) end
    end
    return "Common"
end

local function findEggs()
    local eggs = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Part") then
            if obj.Name:lower():find("egg") then
                local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    table.insert(eggs, {model = obj, prompt = prompt, rarity = getRarity(obj)})
                end
            end
        end
    end
    return eggs
end

local function selectBestEgg()
    local eggs = findEggs()
    local best, bestScore = nil, -1
    local priority = {Divine=10,Eternal=9,Secret=8,Cosmic=7,Mythic=6,Legendary=5,Epic=4,Rare=3,Uncommon=2,Common=1}
    for _, egg in ipairs(eggs) do
        if Settings.Rarities[egg.rarity] then
            local score = priority[egg.rarity] or 0
            if score > bestScore then
                bestScore = score
                best = egg
            end
        end
    end
    return best
end

local function moveTo(pos)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return false end
    hum:MoveTo(pos)
    local t = tick()
    while Settings.AutoSteal and tick() - t < 8 do
        if not root.Parent then return false end
        if (root.Position - pos).Magnitude < Settings.StealRange then
            hum:MoveTo(root.Position)
            return true
        end
        hum:MoveTo(pos)
        task.wait(0.1)
    end
    return false
end

local function stealEgg(prompt)
    if fireproximityprompt then
        fireproximityprompt(prompt)
    else
        prompt:InputHoldBegin()
        task.wait(0.1)
        prompt:InputHoldEnd()
    end
end

local function returnToBase()
    if Settings.BasePosition then
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(Settings.BasePosition + Vector3.new(0, 5, 0))
        end
    end
end

-- ========== ОСНОВНОЙ ЦИКЛ ==========
task.spawn(function()
    while task.wait(0.1) do
        if not Settings.AutoSteal then continue end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Settings.WalkSpeed end

        local target = selectBestEgg()
        if target then
            if StatusLabel then
                StatusLabel.Text = "Цель: " .. target.model.Name .. " (" .. target.rarity .. ")"
            end
            if moveTo(target.model.Position) then
                stealEgg(target.prompt)
                task.wait(Settings.Delay)
                if Settings.ReturnToBase then
                    returnToBase()
                    task.wait(0.5)
                end
            end
        else
            if StatusLabel then StatusLabel.Text = "Подходящих яиц нет" end
        end
        task.wait(Settings.Delay)
    end
end)

-- ========== GUI ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StealEggGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 320)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(60, 60, 70)
UIStroke.Thickness = 1
UIStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "Steal an Egg | Auto Steal"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Title
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 35)
TabBar.Position = UDim2.new(0, 10, 0, 45)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 5)
TabLayout.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -90)
Content.Position = UDim2.new(0, 10, 0, 85)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local tabs = {}
local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = TabBar
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = Content
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = frame
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.Parent = frame
    table.insert(tabs, {btn = btn, frame = frame})
    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(tabs) do
            t.frame.Visible = false
            t.btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
            t.btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        frame.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    return frame
end

local function createSlider(parent, text, min, max, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 50)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = text .. ": " .. default
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -10, 0, 6)
    sliderBg.Position = UDim2.new(0, 5, 0, 30)
    sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = container
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = sliderBg

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Text = ""
    knob.Parent = sliderBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local value = default
    local function update(v)
        value = math.clamp(v, min, max)
        local alpha = (value - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -7, 0.5, -7)
        label.Text = text .. ": " .. math.floor(value * 100) / 100
        callback(value)
    end
    update(default)

    local dragging = false
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mouseX = input.Position.X
            local sliderX = sliderBg.AbsolutePosition.X
            local sliderW = sliderBg.AbsoluteSize.X
            local alpha = math.clamp((mouseX - sliderX) / sliderW, 0, 1)
            update(min + alpha * (max - min))
        end
    end)
    return container
end

-- Вкладка "Главная"
local mainTab = createTab("Главная")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -10, 0, 35)
toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Text = "ВКЛЮЧИТЬ АВТО-КРАЖУ"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.Parent = mainTab
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = toggleBtn

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -10, 0, 20)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.Text = "Статус: выключено"
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 13
StatusLabel.Parent = mainTab

local returnCheck = Instance.new("TextButton")
returnCheck.Size = UDim2.new(1, -10, 0, 25)
returnCheck.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
returnCheck.TextColor3 = Color3.fromRGB(220, 220, 220)
returnCheck.Text = "Возврат на базу: ВКЛ"
returnCheck.Font = Enum.Font.Gotham
returnCheck.TextSize = 13
returnCheck.Parent = mainTab
local returnCorner = Instance.new("UICorner")
returnCorner.CornerRadius = UDim.new(0, 6)
returnCorner.Parent = returnCheck

returnCheck.MouseButton1Click:Connect(function()
    Settings.ReturnToBase = not Settings.ReturnToBase
    returnCheck.Text = "Возврат на базу: " .. (Settings.ReturnToBase and "ВКЛ" or "ВЫКЛ")
    returnCheck.BackgroundColor3 = Settings.ReturnToBase and Color3.fromRGB(40, 100, 40) or Color3.fromRGB(45, 45, 55)
end)

local saveBaseBtn = Instance.new("TextButton")
saveBaseBtn.Size = UDim2.new(1, -10, 0, 30)
saveBaseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
saveBaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBaseBtn.Text = "Сохранить текущую позицию как базу"
saveBaseBtn.Font = Enum.Font.Gotham
saveBaseBtn.TextSize = 13
saveBaseBtn.Parent = mainTab
local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 6)
saveCorner.Parent = saveBaseBtn

saveBaseBtn.MouseButton1Click:Connect(function()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        Settings.BasePosition = root.Position
        StatusLabel.Text = "База сохранена!"
    end
end)

local tpBaseBtn = Instance.new("TextButton")
tpBaseBtn.Size = UDim2.new(1, -10, 0, 30)
tpBaseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
tpBaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpBaseBtn.Text = "Телепорт на базу"
tpBaseBtn.Font = Enum.Font.Gotham
tpBaseBtn.TextSize = 13
tpBaseBtn.Parent = mainTab
local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 6)
tpCorner.Parent = tpBaseBtn

tpBaseBtn.MouseButton1Click:Connect(returnToBase)

toggleBtn.MouseButton1Click:Connect(function()
    Settings.AutoSteal = not Settings.AutoSteal
    toggleBtn.Text = Settings.AutoSteal and "ВЫКЛЮЧИТЬ АВТО-КРАЖУ" or "ВКЛЮЧИТЬ АВТО-КРАЖУ"
    toggleBtn.BackgroundColor3 = Settings.AutoSteal and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(50, 150, 50)
    StatusLabel.Text = "Статус: " .. (Settings.AutoSteal and "включено" or "выключено")
end)

-- Вкладка "Редкости"
local rarityTab = createTab("Редкости")
for rarity, enabled in pairs(Settings.Rarities) do
    local check = Instance.new("TextButton")
    check.Size = UDim2.new(1, -10, 0, 25)
    check.BackgroundColor3 = enabled and Color3.fromRGB(40, 100, 40) or Color3.fromRGB(45, 45, 55)
    check.TextColor3 = Color3.fromRGB(220, 220, 220)
    check.Text = rarity .. ": " .. (enabled and "ВКЛ" or "ВЫКЛ")
    check.Font = Enum.Font.Gotham
    check.TextSize = 13
    check.Parent = rarityTab
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = check
    check.MouseButton1Click:Connect(function()
        Settings.Rarities[rarity] = not Settings.Rarities[rarity]
        check.Text = rarity .. ": " .. (Settings.Rarities[rarity] and "ВКЛ" or "ВЫКЛ")
        check.BackgroundColor3 = Settings.Rarities[rarity] and Color3.fromRGB(40, 100, 40) or Color3.fromRGB(45, 45, 55)
    end)
end

-- Вкладка "Телепорт"
local tpTab = createTab("Телепорт")

local function tpToNearestEgg()
    local eggs = findEggs()
    if #eggs == 0 then return end
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local nearest = eggs[1]
    local minDist = (root.Position - nearest.model.Position).Magnitude
    for _, egg in ipairs(eggs) do
        local d = (root.Position - egg.model.Position).Magnitude
        if d < minDist then
            minDist = d
            nearest = egg
        end
    end
    root.CFrame = CFrame.new(nearest.model.Position + Vector3.new(0, 5, 0))
end

local tpNearestBtn = Instance.new("TextButton")
tpNearestBtn.Size = UDim2.new(1, -10, 0, 30)
tpNearestBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
tpNearestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpNearestBtn.Text = "Тп к ближайшему яйцу"
tpNearestBtn.Font = Enum.Font.Gotham
tpNearestBtn.TextSize = 13
tpNearestBtn.Parent = tpTab
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = tpNearestBtn
tpNearestBtn.MouseButton1Click:Connect(tpToNearestEgg)

local function tpToRarity(rarity)
    local eggs = findEggs()
    for _, egg in ipairs(eggs) do
        if egg.rarity == rarity then
            local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = CFrame.new(egg.model.Position + Vector3.new(0, 5, 0))
            end
            return
        end
    end
end

for _, r in ipairs({"Legendary", "Mythic", "Cosmic", "Secret"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = "Тп к " .. r .. " яйцу"
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Parent = tpTab
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    btn.MouseButton1Click:Connect(function() tpToRarity(r) end)
end

-- Вкладка "Настройки"
local settingsTab = createTab("Настройки")

createSlider(settingsTab, "Скорость ходьбы", 8, 50, Settings.WalkSpeed, function(v)
    Settings.WalkSpeed = v
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and Settings.AutoSteal then hum.WalkSpeed = v end
end)

createSlider(settingsTab, "Дистанция кражи", 4, 20, Settings.StealRange, function(v)
    Settings.StealRange = v
end)

createSlider(settingsTab, "Задержка (сек)", 0.1, 2, Settings.Delay, function(v)
    Settings.Delay = v
end)

-- Перетаскивание окна
local dragging = false
local dragStart = nil
local startPos = nil
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

print("[AutoSteal] Скрипт загружен!")
