local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- CLEANUP OLD VERSIONS
--------------------------------------------------

for version = 10, 16 do
    local cleanup = _G["MM2V" .. version .. "Cleanup"]

    if type(cleanup) == "function" then
        pcall(cleanup)
    end

    local oldGui = playerGui:FindFirstChild(
        "MM2_V" .. version
    )

    if oldGui then
        oldGui:Destroy()
    end
end

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local CONFIG = {
    Speed = 10,
    MaxSpeed = 25,

    MinFlySpeed = 3,
    MaxFlySpeed = 38,

    SearchInterval = 0.35,
    CoinPause = 0.45,
    CoinRetryDelay = 8,

    MaxCoinDistance = 500,
    ArrivalDistance = 5,

    RespawnDelay = 1.5,
    Theme = "Purple"
}

--------------------------------------------------
-- THEMES
--------------------------------------------------

local THEMES = {
    Purple = {
        Background = Color3.fromRGB(15, 12, 27),
        Panel = Color3.fromRGB(32, 25, 51),
        Accent = Color3.fromRGB(174, 104, 255),
        AccentDark = Color3.fromRGB(100, 55, 165),
        Text = Color3.fromRGB(248, 244, 255),
        Muted = Color3.fromRGB(169, 157, 191)
    },

    Blue = {
        Background = Color3.fromRGB(10, 18, 33),
        Panel = Color3.fromRGB(22, 37, 59),
        Accent = Color3.fromRGB(72, 169, 255),
        AccentDark = Color3.fromRGB(35, 95, 175),
        Text = Color3.fromRGB(240, 249, 255),
        Muted = Color3.fromRGB(151, 180, 205)
    },

    Red = {
        Background = Color3.fromRGB(29, 12, 20),
        Panel = Color3.fromRGB(54, 25, 36),
        Accent = Color3.fromRGB(255, 92, 122),
        AccentDark = Color3.fromRGB(160, 45, 75),
        Text = Color3.fromRGB(255, 241, 245),
        Muted = Color3.fromRGB(201, 155, 169)
    }
}

local themeNames = {"Purple", "Blue", "Red"}
local themeIndex = 1

--------------------------------------------------
-- STATE
--------------------------------------------------

local running = false
local destroyed = false
local minimized = false
local afkEnabled = false

local runId = 0
local activeTween = nil

local totalCoins = 0
local sessionCoins = 0

local elapsedBefore = 0
local startedAt = nil

local visited = {}
local failedCoins = {}

local connections = {}
local afkConnection = nil
local themedObjects = {}

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function make(className, props, parent)
    local obj = Instance.new(className)

    for key, value in pairs(props) do
        obj[key] = value
    end

    obj.Parent = parent
    return obj
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function corner(obj, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius)
    }, obj)
end

local function registerTheme(obj, property, key)
    table.insert(themedObjects, {
        Object = obj,
        Property = property,
        Key = key
    })
end

local function applyTheme(animated)
    local theme = THEMES[CONFIG.Theme]

    for _, item in ipairs(themedObjects) do
        local obj = item.Object

        if obj and obj.Parent then
            local color = theme[item.Key]

            if animated then
                TweenService:Create(
                    obj,
                    TweenInfo.new(0.25),
                    {[item.Property] = color}
                ):Play()
            else
                obj[item.Property] = color
            end
        end
    end
end

--------------------------------------------------
-- GUI
--------------------------------------------------

local theme = THEMES[CONFIG.Theme]

local gui = make("ScreenGui", {
    Name = "MM2_V16",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 100
}, playerGui)

local main = make("Frame", {
    Size = UDim2.fromOffset(430, 480),
    Position = UDim2.new(0.5, -215, 0.5, -240),
    BackgroundColor3 = theme.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true
}, gui)

corner(main, 17)
registerTheme(main, "BackgroundColor3", "Background")

local outline = make("UIStroke", {
    Color = theme.Accent,
    Thickness = 1.5
}, main)

registerTheme(outline, "Color", "Accent")

local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 67),
    BackgroundTransparency = 1
}, main)

local title = make("TextLabel", {
    Position = UDim2.fromOffset(19, 10),
    Size = UDim2.fromOffset(330, 28),
    BackgroundTransparency = 1,
    Text = "✦  MM2 AUTO FARM",
    Font = Enum.Font.GothamBold,
    TextSize = 21,
    TextColor3 = theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)

registerTheme(title, "TextColor3", "Text")

local subtitle = make("TextLabel", {
    Position = UDim2.fromOffset(22, 39),
    Size = UDim2.fromOffset(310, 16),
    BackgroundTransparency = 1,
    Text = "V16  •  AUTO START FIX",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = theme.Muted,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)

registerTheme(subtitle, "TextColor3", "Muted")

local minimizeButton = make("TextButton", {
    Position = UDim2.new(1, -49, 0, 15),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = theme.Panel,
    TextColor3 = theme.Text,
    Text = "−",
    Font = Enum.Font.GothamBold,
    TextSize = 22
}, header)

corner(minimizeButton, 9)
registerTheme(minimizeButton, "BackgroundColor3", "Panel")
registerTheme(minimizeButton, "TextColor3", "Text")

local separator = make("Frame", {
    Position = UDim2.fromOffset(17, 66),
    Size = UDim2.new(1, -34, 0, 1),
    BackgroundColor3 = theme.Accent,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0
}, main)

registerTheme(separator, "BackgroundColor3", "Accent")

local body = make("Frame", {
    Position = UDim2.fromOffset(0, 70),
    Size = UDim2.new(1, 0, 1, -70),
    BackgroundTransparency = 1
}, main)

local function panel(x, y, w, h)
    local obj = make("Frame", {
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = theme.Panel,
        BorderSizePixel = 0
    }, body)

    corner(obj, 12)
    registerTheme(obj, "BackgroundColor3", "Panel")

    return obj
end

local function label(text, x, y, w, h, size, key)
    key = key or "Text"

    local obj = make("TextLabel", {
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = size,
        TextColor3 = theme[key],
        TextXAlignment = Enum.TextXAlignment.Left
    }, body)

    registerTheme(obj, "TextColor3", key)

    return obj
end

local function button(text, x, y, w, h, key)
    key = key or "Panel"

    local obj = make("TextButton", {
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = theme[key],
        TextColor3 = theme.Text,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = true
    }, body)

    corner(obj, 10)

    registerTheme(obj, "BackgroundColor3", key)
    registerTheme(obj, "TextColor3", "Text")

    return obj
end

--------------------------------------------------
-- STATS
--------------------------------------------------

panel(18, 10, 394, 92)

local totalLabel = label(
    "0", 32, 17, 220, 45,
    34, "Accent"
)

label(
    "TOTAL COINS", 33, 67,
    190, 20, 11, "Muted"
)

local statusDot = make("Frame", {
    Position = UDim2.fromOffset(369, 29),
    Size = UDim2.fromOffset(12, 12),
    BackgroundColor3 = Color3.fromRGB(240, 90, 120)
}, body)

corner(statusDot, 6)

local statusLabel = label(
    "READY", 246, 51, 150, 24,
    11, "Muted"
)

statusLabel.TextXAlignment =
    Enum.TextXAlignment.Center

panel(18, 112, 125, 70)
panel(152, 112, 125, 70)
panel(286, 112, 126, 70)

label("FARM TIME", 29, 119, 112, 18, 10, "Muted")
label("COINS/MIN", 163, 119, 112, 18, 10, "Muted")
label("COINS/HOUR", 297, 119, 112, 18, 10, "Muted")

local timeLabel = label(
    "00:00", 29, 144, 112, 29, 17
)

local minuteLabel = label(
    "0.0", 163, 144, 112, 29, 17
)

local hourLabel = label(
    "0", 297, 144, 112, 29, 17, "Accent"
)

--------------------------------------------------
-- SPEED
--------------------------------------------------

label(
    "FLIGHT SPEED", 21, 198,
    180, 23, 12, "Muted"
)

local speedLabel = label(
    "10 / 25", 303, 198,
    104, 23, 14, "Accent"
)

speedLabel.TextXAlignment =
    Enum.TextXAlignment.Right

local minusButton = button(
    "−", 19, 228, 58, 40
)

local plusButton = button(
    "+", 353, 228, 58, 40
)

local speedTrack = make("Frame", {
    Position = UDim2.fromOffset(90, 244),
    Size = UDim2.fromOffset(250, 9),
    BackgroundColor3 = theme.Panel,
    BorderSizePixel = 0
}, body)

corner(speedTrack, 5)
registerTheme(speedTrack, "BackgroundColor3", "Panel")

local speedFill = make("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = theme.Accent,
    BorderSizePixel = 0
}, speedTrack)

corner(speedFill, 5)
registerTheme(speedFill, "BackgroundColor3", "Accent")

--------------------------------------------------
-- BUTTONS
--------------------------------------------------

local startButton = button(
    "▶ START FARM",
    19, 287, 191, 44, "AccentDark"
)

local stopButton = button(
    "■ STOP FARM",
    220, 287, 191, 44
)

local afkButton = button(
    "AFK MODE • OFF",
    19, 346, 191, 44
)

local themeButton = button(
    "THEME: PURPLE",
    220, 346, 191, 44
)

--------------------------------------------------
-- STATUS
--------------------------------------------------

local function setStatus(message, active)
    if destroyed then return end

    statusLabel.Text = message

    statusDot.BackgroundColor3 = active
        and Color3.fromRGB(75, 225, 155)
        or Color3.fromRGB(240, 90, 120)
end

local function updateSpeed()
    speedLabel.Text =
        CONFIG.Speed .. " / 25"

    TweenService:Create(
        speedFill,
        TweenInfo.new(0.15),
        {
            Size = UDim2.fromScale(
                CONFIG.Speed / CONFIG.MaxSpeed,
                1
            )
        }
    ):Play()
end

local function getElapsed()
    return elapsedBefore
        + (
            startedAt
            and (os.clock() - startedAt)
            or 0
        )
end

--------------------------------------------------
-- BUTTON EVENTS
--------------------------------------------------

connect(minusButton.MouseButton1Click, function()
    CONFIG.Speed = math.max(
        1, CONFIG.Speed - 1
    )

    updateSpeed()
end)

connect(plusButton.MouseButton1Click, function()
    CONFIG.Speed = math.min(
        25, CONFIG.Speed + 1
    )

    updateSpeed()
end)

connect(themeButton.MouseButton1Click, function()
    themeIndex = themeIndex + 1

    if themeIndex > #themeNames then
        themeIndex = 1
    end

    CONFIG.Theme = themeNames[themeIndex]

    themeButton.Text =
        "THEME: " .. CONFIG.Theme:upper()

    applyTheme(true)
end)

--------------------------------------------------
-- MINIMIZE
--------------------------------------------------

connect(minimizeButton.MouseButton1Click, function()
    minimized = not minimized

    body.Visible = not minimized
    separator.Visible = not minimized

    TweenService:Create(
        main,
        TweenInfo.new(0.22),
        {
            Size = minimized
                and UDim2.fromOffset(430, 67)
                or UDim2.fromOffset(430, 480)
        }
    ):Play()

    minimizeButton.Text =
        minimized and "+" or "−"
end)

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

local dragging = false
local dragStart
local dragPosition
local dragInput

connect(header.InputBegan, function(input)
    if input.UserInputType
        == Enum.UserInputType.MouseButton1
        or input.UserInputType
        == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        dragPosition = main.Position
        dragInput = input
    end
end)

connect(UIS.InputChanged, function(input)
    if not dragging then return end

    if input.UserInputType
        == Enum.UserInputType.MouseMovement
        or input == dragInput then

        local delta =
            input.Position - dragStart

        main.Position = UDim2.new(
            dragPosition.X.Scale,
            dragPosition.X.Offset + delta.X,
            dragPosition.Y.Scale,
            dragPosition.Y.Offset + delta.Y
        )
    end
end)

connect(UIS.InputEnded, function(input)
    if input.UserInputType
        == Enum.UserInputType.MouseButton1
        or input == dragInput then

        dragging = false
    end
end)

--------------------------------------------------
-- AFK
--------------------------------------------------

connect(afkButton.MouseButton1Click, function()
    afkEnabled = not afkEnabled

    afkButton.Text = afkEnabled
        and "AFK MODE • ON"
        or "AFK MODE • OFF"

    if afkConnection then
        afkConnection:Disconnect()
        afkConnection = nil
    end

    if afkEnabled then
        afkConnection = player.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end)
        end)
    end
end)

--------------------------------------------------
-- CHARACTER
--------------------------------------------------

local function getCharacter()
    local character = player.Character

    if not character then
        return nil, nil
    end

    return character:FindFirstChildOfClass("Humanoid"),
        character:FindFirstChild("HumanoidRootPart")
end

local function isActive(id)
    return running
        and not destroyed
        and id == runId
end

local function stopFlight()
    if activeTween then
        local tween = activeTween
        activeTween = nil
        tween:Cancel()
    end

    local _, root = getCharacter()

    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

--------------------------------------------------
-- COIN SEARCH
--------------------------------------------------

local function isCoin(obj)
    return obj
        and obj:IsA("BasePart")
        and obj:IsDescendantOf(workspace)
        and obj.Transparency < 1
        and obj.Name:lower():find(
            "coin", 1, true
        ) ~= nil
end

local function validCoin(coin, root)
    if not isCoin(coin) or not root then
        return false
    end

    local path = coin:GetFullName():lower()

    for _, excluded in ipairs({
        "lobby",
        "waiting",
        "spawnroom",
        "spectator"
    }) do
        if path:find(excluded, 1, true) then
            return false
        end
    end

    local distance =
        (coin.Position - root.Position).Magnitude

    return distance <= CONFIG.MaxCoinDistance
end

local function findBestCoin()
    local _, root = getCharacter()

    if not root then
        return nil
    end

    local bestCoin = nil
    local bestScore = math.huge
    local now = os.clock()

    for _, obj in ipairs(
        workspace:GetDescendants()
    ) do
        if validCoin(obj, root) then
            local retryAt = failedCoins[obj]
            local visitedAt = visited[obj]

            if retryAt and now < retryAt then
                continue
            end

            if visitedAt
            and now - visitedAt
                < CONFIG.CoinRetryDelay then
                continue
            end

            local distance =
                (obj.Position - root.Position).Magnitude

            if distance < bestScore then
                bestScore = distance
                bestCoin = obj
            end
        end
    end

    return bestCoin
end

--------------------------------------------------
-- SMOOTH FLIGHT
--------------------------------------------------

local function flyToCoin(coin, id)
    local humanoid, root = getCharacter()

    if not humanoid
    or humanoid.Health <= 0
    or not root
    or not validCoin(coin, root) then
        return false
    end

    local destination =
        coin.Position + Vector3.new(0, 2, 0)

    local distance =
        (destination - root.Position).Magnitude

    local flySpeed =
        CONFIG.MinFlySpeed
        + (
            (CONFIG.Speed - 1)
            / (CONFIG.MaxSpeed - 1)
        )
        * (
            CONFIG.MaxFlySpeed
            - CONFIG.MinFlySpeed
        )

    local duration = math.max(
        0.1,
        distance / flySpeed
    )

    local tween = TweenService:Create(
        root,
        TweenInfo.new(
            duration,
            Enum.EasingStyle.Linear
        ),
        {CFrame = CFrame.new(destination)}
    )

    activeTween = tween
    tween:Play()

    local state = tween.Completed:Wait()

    if activeTween == tween then
        activeTween = nil
    end

    if not isActive(id)
    or state ~= Enum.PlaybackState.Completed then
        return false
    end

    local _, newRoot = getCharacter()

    return newRoot ~= nil
        and (
            newRoot.Position - destination
        ).Magnitude <= CONFIG.ArrivalDistance
end

--------------------------------------------------
-- FARM LOOP
--------------------------------------------------

local function farmLoop(id)
    while isActive(id) do
        local humanoid, root = getCharacter()

        if not humanoid
        or humanoid.Health <= 0
        or not root then

            setStatus("WAITING PLAYER", false)
            task.wait(0.35)
            continue
        end

        local target = findBestCoin()

        if not target then
            setStatus("SEARCHING", true)

            for coin in pairs(visited) do
                if not coin:IsDescendantOf(workspace) then
                    visited[coin] = nil
                end
            end

            task.wait(CONFIG.SearchInterval)
            continue
        end

        setStatus("FLYING", true)

        local arrived = flyToCoin(target, id)

        if not isActive(id) then
            return
        end

        if not arrived then
            failedCoins[target] = os.clock() + 3
            task.wait(0.15)
            continue
        end

        visited[target] = os.clock()

        stopFlight()
        setStatus("COLLECTING", true)

        task.wait(CONFIG.CoinPause)

        if not isActive(id) then
            return
        end

        totalCoins = totalCoins + 1
        sessionCoins = sessionCoins + 1

        totalLabel.Text = tostring(totalCoins)
    end
end

--------------------------------------------------
-- FARM CONTROL
--------------------------------------------------

local function stopFarm()
    running = false
    runId = runId + 1

    if startedAt then
        elapsedBefore = getElapsed()
        startedAt = nil
    end

    stopFlight()
    setStatus("STOPPED", false)
end

local function launchFarmLoop()
    runId = runId + 1
    local id = runId

    visited = {}
    failedCoins = {}

    task.spawn(function()
        while isActive(id) do
            local humanoid, root = getCharacter()

            if humanoid
            and humanoid.Health > 0
            and root then
                break
            end

            setStatus("WAITING PLAYER", false)
            task.wait(0.3)
        end

        if not isActive(id) then
            return
        end

        setStatus("FARMING", true)
        farmLoop(id)
    end)
end

local function startFarm()
    if destroyed or running then
        return
    end

    running = true
    startedAt = os.clock()

    setStatus("STARTING", true)
    launchFarmLoop()
end

connect(startButton.MouseButton1Click, startFarm)
connect(stopButton.MouseButton1Click, stopFarm)

--------------------------------------------------
-- AUTO RESTART AFTER RESPAWN
--------------------------------------------------

connect(player.CharacterAdded, function(character)
    if not running or destroyed then
        return
    end

    stopFlight()

    -- Cancel previous farming loop
    runId = runId + 1
    local restartId = runId

    setStatus("RESPAWNING", false)

    task.spawn(function()
        local humanoid = character:WaitForChild(
            "Humanoid", 10
        )

        local root = character:WaitForChild(
            "HumanoidRootPart", 10
        )

        if not humanoid or not root then
            return
        end

        task.wait(CONFIG.RespawnDelay)

        if not running
        or destroyed
        or runId ~= restartId
        or player.Character ~= character then
            return
        end

        launchFarmLoop()
    end)
end)

--------------------------------------------------
-- LIVE STATS
--------------------------------------------------

task.spawn(function()
    while not destroyed do
        task.wait(0.5)

        local elapsed = getElapsed()

        local minutes =
            math.floor(elapsed / 60)

        local seconds =
            math.floor(elapsed % 60)

        local hours =
            math.floor(minutes / 60)

        if hours > 0 then
            timeLabel.Text = string.format(
                "%02d:%02d:%02d",
                hours,
                minutes % 60,
                seconds
            )
        else
            timeLabel.Text = string.format(
                "%02d:%02d",
                minutes,
                seconds
            )
        end

        if elapsed > 0 then
            minuteLabel.Text = string.format(
                "%.1f",
                sessionCoins / elapsed * 60
            )

            hourLabel.Text = string.format(
                "%.0f",
                sessionCoins / elapsed * 3600
            )
        else
            minuteLabel.Text = "0.0"
            hourLabel.Text = "0"
        end
    end
end)

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

_G.MM2V16Cleanup = function()
    if destroyed then return end

    stopFarm()
    destroyed = true

    if afkConnection then
        afkConnection:Disconnect()
    end

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    gui:Destroy()
end

--------------------------------------------------
-- INITIALIZE
--------------------------------------------------

updateSpeed()
applyTheme(false)
setStatus("READY", false)

main.BackgroundTransparency = 1

TweenService:Create(
    main,
    TweenInfo.new(
        0.35,
        Enum.EasingStyle.Quad
    ),
    {BackgroundTransparency = 0}
):Play()
