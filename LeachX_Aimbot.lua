--[[
    LeachX | Universal Hub
    Aimbot, Triggerbot, ESP, Movement, Misc
    UI custom (gaya sama dengan gate LeachX), tanpa library luar.
    Tampil/sembunyi: RightShift atau tombol "L" di kiri layar.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

------------------------------------------------------------------
-- Pengaturan
------------------------------------------------------------------
local S = {
    -- Aimbot
    Aim = false, HoldToAim = true, AimKey = "Right Mouse", AimPart = "Head",
    Smooth = 25, Prediction = 0, FOV = 150, ShowFOV = true,
    TeamCheck = true, WallCheck = false, AliveCheck = true, MaxDist = 1000,
    -- Triggerbot
    Trigger = false, TriggerDelay = 60,
    -- ESP
    ESP = false, ESPBox = true, ESPInfo = true, ESPTeam = false,
    -- Movement
    SpeedOn = false, Speed = 40, JumpOn = false, Jump = 80,
    InfJump = false, Noclip = false, Fly = false, FlySpeed = 60,
    -- Misc
    Fullbright = false,
}

local AimKeys = {
    ["Right Mouse"] = Enum.UserInputType.MouseButton2,
    ["Left Mouse"]  = Enum.UserInputType.MouseButton1,
    ["E"] = Enum.KeyCode.E, ["Q"] = Enum.KeyCode.Q, ["Left Shift"] = Enum.KeyCode.LeftShift,
}

------------------------------------------------------------------
-- Util UI
------------------------------------------------------------------
local T = {
    Bg = Color3.fromRGB(11, 12, 24), Bg2 = Color3.fromRGB(26, 16, 52),
    Panel = Color3.fromRGB(21, 23, 42), Field = Color3.fromRGB(30, 33, 58),
    FieldHi = Color3.fromRGB(38, 42, 72), Text = Color3.fromRGB(238, 241, 255),
    Muted = Color3.fromRGB(132, 138, 176),
    A = Color3.fromRGB(0, 235, 190), B = Color3.fromRGB(122, 92, 255), C = Color3.fromRGB(255, 94, 196),
    Good = Color3.fromRGB(90, 235, 165), Bad = Color3.fromRGB(255, 96, 118),
}

local function new(class, props, children)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = i end
    return i
end
local function tween(i, t, p, style, dir)
    local tw = TweenService:Create(i, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), p)
    tw:Play() return tw
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function gradient(rot)
    return new("UIGradient", { Rotation = rot or 0, Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, T.A), ColorSequenceKeypoint.new(0.5, T.B), ColorSequenceKeypoint.new(1, T.C),
    }) })
end

local conns = {}
local function connect(sig, fn) local c = sig:Connect(fn) table.insert(conns, c) return c end

-- Hapus instance lama bila script dijalankan dua kali
for _, p in ipairs({ CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui") }) do
    pcall(function() local o = p:FindFirstChild("LeachXHub") if o then o:Destroy() end end)
end
pcall(function() if gethui then local o = gethui():FindFirstChild("LeachXHub") if o then o:Destroy() end end end)

local gui = new("ScreenGui", {
    Name = "LeachXHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
})
do
    local cands = {}
    pcall(function() if gethui then table.insert(cands, gethui()) end end)
    table.insert(cands, CoreGui)
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(cands, pg) end
    for _, p in ipairs(cands) do
        local ok = pcall(function() gui.Parent = p end)
        if ok and gui.Parent == p then break end
    end
end

------------------------------------------------------------------
-- Jendela utama
------------------------------------------------------------------
local W = math.min(430, Camera.ViewportSize.X - 32)
local H = math.min(420, Camera.ViewportSize.Y - 40)

local main = new("Frame", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(0, 0), BackgroundColor3 = T.Bg, BorderSizePixel = 0,
    ClipsDescendants = true, Parent = gui,
}, { corner(16) })
tween(main, 0.55, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Back)

new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1, Parent = main },
    { corner(16), new("UIGradient", { Rotation = 125, Color = ColorSequence.new(T.Bg2, T.Bg) }) })

local stroke = new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = main })
local strokeGrad = gradient(0) strokeGrad.Parent = stroke

-- Partikel
local fx = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = main })
local pcols = { T.A, T.B, T.C }
local particles = {}
for i = 1, 14 do
    local s = math.random(2, 4)
    particles[i] = {
        f = new("Frame", { Size = UDim2.fromOffset(s, s), BackgroundColor3 = pcols[(i % 3) + 1],
            BackgroundTransparency = 0.55 + math.random() * 0.3, BorderSizePixel = 0, ZIndex = 2, Parent = fx },
            { new("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
        x = math.random(14, math.floor(W) - 14), y = math.random(14, H - 14),
        sp = 8 + math.random() * 14, ph = math.random() * 6.28,
    }
end

-- Header
local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), ZIndex = 5, Parent = main })
local badge = new("Frame", { Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(38, 38),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5, Parent = header }, { corner(12) })
local badgeGrad = gradient(45) badgeGrad.Parent = badge
new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack,
    Text = "L", TextSize = 21, TextColor3 = T.Bg, ZIndex = 6, Parent = badge })

local title = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -130, 0, 26),
    Font = Enum.Font.GothamBlack, Text = "LeachX", TextSize = 24, TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = header })
local titleGrad = gradient(0) titleGrad.Parent = title
new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(65, 33), Size = UDim2.new(1, -130, 0, 16),
    Font = Enum.Font.GothamMedium, Text = "Universal Hub  •  v1.0", TextSize = 12, TextColor3 = T.Muted,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = header })

local function headerBtn(txt, xOff)
    local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xOff, 0, 14), Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = T.Panel, Text = txt, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = T.Muted,
        AutoButtonColor = false, ZIndex = 6, Parent = header }, { corner(9) })
    b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundColor3 = T.FieldHi, TextColor3 = T.Text }) end)
    b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundColor3 = T.Panel, TextColor3 = T.Muted }) end)
    return b
end
local btnMin = headerBtn("–", -52)
local btnClose = headerBtn("×", -14)

-- Seret jendela lewat header
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

------------------------------------------------------------------
-- Tab & halaman
------------------------------------------------------------------
local tabNames = { "Aimbot", "Visuals", "Move", "Misc" }
local tabBar = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 32), ZIndex = 5, Parent = main })
local tabW = (W - 32 - (#tabNames - 1) * 6) / #tabNames
local pages, tabBtns = {}, {}

local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 102), Size = UDim2.new(1, -32, 1, -114),
    ClipsDescendants = true, ZIndex = 5, Parent = main })

local function selectTab(name)
    for n, pg in pairs(pages) do
        local on = n == name
        pg.Visible = on
        if on then pg.Position = UDim2.fromOffset(0, 10) tween(pg, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back) end
        tween(tabBtns[n].b, 0.2, { BackgroundColor3 = on and T.Field or T.Panel, TextColor3 = on and T.Text or T.Muted })
        tween(tabBtns[n].bar, 0.25, { Size = UDim2.new(on and 0.6 or 0, 0, 0, 3) })
    end
end

for idx, name in ipairs(tabNames) do
    local b = new("TextButton", { Position = UDim2.fromOffset((idx - 1) * (tabW + 6), 0), Size = UDim2.fromOffset(tabW, 32),
        BackgroundColor3 = T.Panel, Text = name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Muted,
        AutoButtonColor = false, ZIndex = 6, Parent = tabBar }, { corner(9) })
    local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(0, 0, 0, 3),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7, Parent = b }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    gradient(0).Parent = bar
    tabBtns[name] = { b = b, bar = bar }
    b.MouseButton1Click:Connect(function() selectTab(name) end)

    local pg = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.B, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 5, Parent = content })
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pg })
    new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = pg })
    pages[name] = pg
end

------------------------------------------------------------------
-- Komponen
------------------------------------------------------------------
local function rowFrame(page, h)
    return new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = T.Panel, BorderSizePixel = 0, ZIndex = 6, Parent = page }, { corner(10) })
end
local function rowLabel(r, txt)
    return new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 0, 38),
        Font = Enum.Font.GothamMedium, Text = txt, TextSize = 13, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = r })
end

local function section(page, txt)
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        Text = string.upper(txt), TextSize = 11, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = page },
        { new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 6) }) })
end

local function toggle(page, txt, default, cb)
    local r = rowFrame(page, 38) rowLabel(r, txt)
    local sw = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = T.Field, Text = "", AutoButtonColor = false, ZIndex = 7, Parent = r }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local g = gradient(0) g.Enabled = false g.Parent = sw
    local knob = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = T.Muted,
        BorderSizePixel = 0, ZIndex = 8, Parent = sw }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local state = default
    local function render(anim)
        g.Enabled = state
        local p = { Position = UDim2.fromOffset(state and 23 or 3, 3), BackgroundColor3 = state and Color3.new(1, 1, 1) or T.Muted }
        if anim then tween(knob, 0.2, p, Enum.EasingStyle.Back) else for k, v in pairs(p) do knob[k] = v end end
        sw.BackgroundColor3 = state and Color3.new(1, 1, 1) or T.Field
    end
    render(false)
    sw.MouseButton1Click:Connect(function() state = not state render(true) cb(state) end)
end

local function slider(page, txt, min, max, default, suffix, cb)
    local r = rowFrame(page, 52) rowLabel(r, txt).Size = UDim2.new(1, -90, 0, 30)
    local val = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0),
        Size = UDim2.fromOffset(80, 30), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.A,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7, Parent = r })
    local track = new("Frame", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = T.Field,
        BorderSizePixel = 0, ZIndex = 7, Parent = r }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 8, Parent = track },
        { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    gradient(0).Parent = fill
    local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 9, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local hit = new("TextButton", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "", ZIndex = 10, Parent = r })

    local function set(v, fire)
        v = math.clamp(v, min, max)
        local a = (v - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1) knob.Position = UDim2.fromScale(a, 0.5)
        val.Text = tostring(v) .. (suffix or "")
        if fire then cb(v) end
    end
    set(default, false)
    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        set(math.floor(min + (max - min) * a + 0.5), true)
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true fromX(i.Position.X) end
    end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
    end)
    connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function cycle(page, txt, options, default, cb)
    local r = rowFrame(page, 38) rowLabel(r, txt)
    local idx = table.find(options, default) or 1
    local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(112, 26),
        BackgroundColor3 = T.Field, Text = options[idx], Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.A,
        AutoButtonColor = false, ZIndex = 7, Parent = r }, { corner(8) })
    b.MouseButton1Click:Connect(function()
        idx = idx % #options + 1 b.Text = options[idx] cb(options[idx])
        tween(b, 0.1, { BackgroundColor3 = T.FieldHi }) task.delay(0.12, function() tween(b, 0.2, { BackgroundColor3 = T.Field }) end)
    end)
end

local function button(page, txt, color, cb)
    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Panel, Text = txt, Font = Enum.Font.GothamBold,
        TextSize = 13, TextColor3 = color or T.Text, AutoButtonColor = false, ZIndex = 6, Parent = page }, { corner(10) })
    local s = new("UIStroke", { Thickness = 1.5, Color = T.Field, Parent = b })
    b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundColor3 = T.Field }) tween(s, 0.15, { Color = T.B }) end)
    b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundColor3 = T.Panel }) tween(s, 0.15, { Color = T.Field }) end)
    b.MouseButton1Click:Connect(cb)
end

------------------------------------------------------------------
-- Isi tab
------------------------------------------------------------------
local P = pages
-- Aimbot
section(P.Aimbot, "Aimbot")
toggle(P.Aimbot, "Enable Aimbot", false, function(v) S.Aim = v end)
toggle(P.Aimbot, "Hold to Aim", true, function(v) S.HoldToAim = v end)
cycle(P.Aimbot, "Aim Key", { "Right Mouse", "Left Mouse", "E", "Q", "Left Shift" }, "Right Mouse", function(v) S.AimKey = v end)
cycle(P.Aimbot, "Aim Part", { "Head", "HumanoidRootPart", "UpperTorso" }, "Head", function(v) S.AimPart = v end)
slider(P.Aimbot, "Smoothness", 5, 100, 25, "%", function(v) S.Smooth = v end)
slider(P.Aimbot, "Prediction", 0, 30, 0, "", function(v) S.Prediction = v end)
section(P.Aimbot, "FOV & Filter")
toggle(P.Aimbot, "Show FOV Circle", true, function(v) S.ShowFOV = v end)
slider(P.Aimbot, "FOV Radius", 30, 500, 150, " px", function(v) S.FOV = v end)
slider(P.Aimbot, "Max Distance", 100, 3000, 1000, "", function(v) S.MaxDist = v end)
toggle(P.Aimbot, "Team Check", true, function(v) S.TeamCheck = v end)
toggle(P.Aimbot, "Wall Check", false, function(v) S.WallCheck = v end)
toggle(P.Aimbot, "Alive Check", true, function(v) S.AliveCheck = v end)
section(P.Aimbot, "Triggerbot")
toggle(P.Aimbot, "Triggerbot", false, function(v) S.Trigger = v end)
slider(P.Aimbot, "Trigger Delay", 0, 300, 60, " ms", function(v) S.TriggerDelay = v end)

-- Visuals
section(P.Visuals, "ESP")
toggle(P.Visuals, "Enable ESP", false, function(v) S.ESP = v end)
toggle(P.Visuals, "Highlight Box", true, function(v) S.ESPBox = v end)
toggle(P.Visuals, "Name / Distance / HP", true, function(v) S.ESPInfo = v end)
toggle(P.Visuals, "Show Teammates", false, function(v) S.ESPTeam = v end)
section(P.Visuals, "World")
toggle(P.Visuals, "Fullbright", false, function(v) S.Fullbright = v end)

-- Move
section(P.Move, "Speed & Jump")
toggle(P.Move, "WalkSpeed", false, function(v) S.SpeedOn = v end)
slider(P.Move, "Speed Value", 16, 200, 40, "", function(v) S.Speed = v end)
toggle(P.Move, "JumpPower", false, function(v) S.JumpOn = v end)
slider(P.Move, "Jump Value", 50, 300, 80, "", function(v) S.Jump = v end)
toggle(P.Move, "Infinite Jump", false, function(v) S.InfJump = v end)
section(P.Move, "Fly & Noclip")
toggle(P.Move, "Fly (Space / Ctrl)", false, function(v) S.Fly = v end)
slider(P.Move, "Fly Speed", 20, 250, 60, "", function(v) S.FlySpeed = v end)
toggle(P.Move, "Noclip", false, function(v) S.Noclip = v end)

------------------------------------------------------------------
-- Logika: Aimbot & Triggerbot
------------------------------------------------------------------
local fovCircle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 300),
    Visible = false, ZIndex = 1, Parent = gui }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local fovStroke = new("UIStroke", { Thickness = 1.5, Color = Color3.new(1, 1, 1), Parent = fovCircle })
local fovGrad = gradient(0) fovGrad.Parent = fovStroke

local function alive(char)
    local h = char and char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function sameTeam(plr)
    return S.TeamCheck and plr.Team ~= nil and plr.Team == LocalPlayer.Team
end
local function visible(part, char)
    if not S.WallCheck then return true end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LocalPlayer.Character, char }
    local o = Camera.CFrame.Position
    return Workspace:Raycast(o, part.Position - o, rp) == nil
end
local function aimPos(part)
    local pos = part.Position
    if S.Prediction > 0 then pos = pos + part.AssemblyLinearVelocity * (S.Prediction / 100) end
    return pos
end
local function getTarget()
    local best, bd = nil, S.FOV
    local m = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not sameTeam(plr) then
            local char = plr.Character
            local part = char and char:FindFirstChild(S.AimPart)
            if part and (not S.AliveCheck or alive(char)) then
                local p, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(p.X, p.Y) - m).Magnitude
                    local d3 = (part.Position - Camera.CFrame.Position).Magnitude
                    if d < bd and d3 <= S.MaxDist and visible(part, char) then best, bd = part, d end
                end
            end
        end
    end
    return best
end
local function aiming()
    if not S.Aim then return false end
    if not S.HoldToAim then return true end
    local k = AimKeys[S.AimKey]
    if k.EnumType == Enum.UserInputType then return UserInputService:IsMouseButtonPressed(k) end
    return UserInputService:IsKeyDown(k)
end

local trigBusy = false
local function triggerCheck()
    if not S.Trigger or trigBusy then return end
    local t = Mouse.Target
    if not t then return end
    local model = t:FindFirstAncestorOfClass("Model")
    local plr = model and Players:GetPlayerFromCharacter(model)
    if plr and plr ~= LocalPlayer and not sameTeam(plr) and (not S.AliveCheck or alive(model)) then
        trigBusy = true
        task.spawn(function()
            task.wait(S.TriggerDelay / 1000)
            pcall(function()
                if mouse1click then mouse1click()
                elseif mouse1press and mouse1release then mouse1press() task.wait(0.03) mouse1release() end
            end)
            task.wait(0.05)
            trigBusy = false
        end)
    end
end

------------------------------------------------------------------
-- Logika: ESP
------------------------------------------------------------------
local espFolder = new("Folder", { Name = "ESP", Parent = gui })
local esp = {}
local function clearEsp(plr)
    local e = esp[plr]
    if e then pcall(function() e.hl:Destroy() e.bb:Destroy() end) esp[plr] = nil end
end
local function makeEsp(plr, char)
    local head = char:FindFirstChild("Head")
    if not head then return end
    local hl = new("Highlight", { Adornee = char, FillColor = T.B, FillTransparency = 0.65, OutlineColor = T.A,
        OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = espFolder })
    local bb = new("BillboardGui", { Adornee = head, Size = UDim2.fromOffset(180, 34), StudsOffset = Vector3.new(0, 2.4, 0),
        AlwaysOnTop = true, Parent = espFolder })
    local lbl = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Parent = bb })
    gradient(0).Parent = lbl
    esp[plr] = { hl = hl, bb = bb, lbl = lbl, char = char }
end
local function updateEsp()
    for plr in pairs(esp) do if not plr.Parent then clearEsp(plr) end end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local show = S.ESP and char and alive(char) and (S.ESPTeam or not (plr.Team ~= nil and plr.Team == LocalPlayer.Team))
            if show then
                if esp[plr] and esp[plr].char ~= char then clearEsp(plr) end
                if not esp[plr] then makeEsp(plr, char) end
                local e = esp[plr]
                if e then
                    e.hl.Enabled = S.ESPBox
                    e.bb.Enabled = S.ESPInfo
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum then
                        local d = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
                        e.lbl.Text = string.format("%s  [%dm]  %d HP", plr.DisplayName, d, math.floor(hum.Health))
                    end
                end
            else
                clearEsp(plr)
            end
        end
    end
end
connect(Players.PlayerRemoving, function(p) clearEsp(p) end)

------------------------------------------------------------------
-- Logika: Movement & Misc
------------------------------------------------------------------
local function getHum() local c = LocalPlayer.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP() local c = LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end

local origSpeed, origJump
local flyBV
local function stopFly()
    if flyBV then flyBV:Destroy() flyBV = nil end
    local h = getHum() if h then h.PlatformStand = false end
end

connect(UserInputService.JumpRequest, function()
    if S.InfJump then local h = getHum() if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

local lightOrig
local function setFullbright(on)
    if on then
        if not lightOrig then
            lightOrig = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient }
        end
        Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = 2, 14, 1e5
        Lighting.GlobalShadows, Lighting.Ambient = false, Color3.fromRGB(170, 170, 170)
    elseif lightOrig then
        for k, v in pairs(lightOrig) do Lighting[k] = v end
        lightOrig = nil
    end
end

connect(RunService.Stepped, function()
    if S.Noclip then
        local c = LocalPlayer.Character
        if c then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
    end
end)

connect(RunService.Heartbeat, function()
    local h, hrp = getHum(), getHRP()
    if h then
        if S.SpeedOn then origSpeed = origSpeed or h.WalkSpeed h.WalkSpeed = S.Speed
        elseif origSpeed then h.WalkSpeed = origSpeed origSpeed = nil end
        if S.JumpOn then origJump = origJump or h.JumpPower h.UseJumpPower = true h.JumpPower = S.Jump
        elseif origJump then h.JumpPower = origJump origJump = nil end
    end
    if S.Fly and h and hrp then
        if not flyBV or flyBV.Parent ~= hrp then
            if flyBV then flyBV:Destroy() end
            flyBV = new("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero, Parent = hrp })
        end
        h.PlatformStand = true
        local md = h.MoveDirection
        local y = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then y = 1
        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then y = -1
        elseif md.Magnitude > 0 then
            local look = Camera.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0 and md:Dot(flat.Unit) > 0.3 then y = look.Y end
        end
        flyBV.Velocity = Vector3.new(md.X * S.FlySpeed, y * S.FlySpeed, md.Z * S.FlySpeed)
    elseif flyBV then
        stopFly()
    end
end)

task.spawn(function()
    local last = false
    while gui.Parent do
        updateEsp()
        if S.Fullbright ~= last then setFullbright(S.Fullbright) last = S.Fullbright end
        task.wait(0.15)
    end
end)

------------------------------------------------------------------
-- Loop animasi + aimbot
------------------------------------------------------------------
local t0 = os.clock()
connect(RunService.RenderStepped, function(dt)
    Camera = Workspace.CurrentCamera
    local t = os.clock() - t0

    strokeGrad.Rotation = (t * 60) % 360
    titleGrad.Offset = Vector2.new(math.sin(t * 1.2) * 0.3, 0)
    badgeGrad.Rotation = (t * 40) % 360
    stroke.Thickness = 2 + math.sin(t * 2) * 0.4
    for _, p in ipairs(particles) do
        p.y = p.y - p.sp * dt
        if p.y < -6 then p.y = H + 6 p.x = math.random(14, math.floor(W) - 14) end
        p.f.Position = UDim2.fromOffset(p.x + math.sin(t + p.ph) * 6, p.y)
    end

    fovCircle.Visible = S.Aim and S.ShowFOV
    if fovCircle.Visible then
        local m = UserInputService:GetMouseLocation()
        fovCircle.Position = UDim2.fromOffset(m.X, m.Y)
        fovCircle.Size = UDim2.fromOffset(S.FOV * 2, S.FOV * 2)
        fovGrad.Rotation = (t * 80) % 360
    end

    if aiming() then
        local target = getTarget()
        if target then
            local look = CFrame.new(Camera.CFrame.Position, aimPos(target))
            Camera.CFrame = Camera.CFrame:Lerp(look, S.Smooth / 100)
        end
    end
    triggerCheck()
end)

------------------------------------------------------------------
-- Tampil/sembunyi & unload
------------------------------------------------------------------
local shown = true
local function setShown(v)
    shown = v
    if v then
        main.Visible = true
        tween(main, 0.4, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Back)
    else
        tween(main, 0.25, { Size = UDim2.fromOffset(0, 0) }).Completed:Connect(function() if not shown then main.Visible = false end end)
    end
end

local fab = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(40, 40),
    BackgroundColor3 = Color3.new(1, 1, 1), Text = "L", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = T.Bg,
    AutoButtonColor = false, ZIndex = 20, Parent = gui }, { corner(12) })
local fabGrad = gradient(45) fabGrad.Parent = fab
fab.MouseButton1Click:Connect(function() setShown(not shown) end)
btnMin.MouseButton1Click:Connect(function() setShown(false) end)
connect(UserInputService.InputBegan, function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then setShown(not shown) end
end)

local function unload()
    for k in pairs(S) do if type(S[k]) == "boolean" then S[k] = false end end
    stopFly()
    local h = getHum()
    if h then
        if origSpeed then h.WalkSpeed = origSpeed end
        if origJump then h.JumpPower = origJump end
    end
    setFullbright(false)
    for p in pairs(esp) do clearEsp(p) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    gui:Destroy()
end
btnClose.MouseButton1Click:Connect(unload)

-- Tab Misc (butuh unload di atas)
section(P.Misc, "Info")
new("TextLabel", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = T.Panel, Font = Enum.Font.GothamMedium, TextSize = 12,
    Text = "LeachX Universal Hub\nRightShift atau tombol L untuk tampil/sembunyi.", TextColor3 = T.Muted,
    TextWrapped = true, ZIndex = 6, Parent = P.Misc }, { corner(10) })
section(P.Misc, "Kontrol")
button(P.Misc, "Sembunyikan Menu", T.Text, function() setShown(false) end)
button(P.Misc, "Unload LeachX", T.Bad, unload)

selectTab("Aimbot")
