--[[
    LeachX Key Gateway
    Key system untuk executor (Delta, Potassium, dll) dengan banyak game.
    Key dibuat dan dikelola sendiri lewat file JSON (lihat KeysUrl di bawah).
    Pengambilan key lewat Linkvertise atau LootLabs.

    Pemakaian di executor:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/muhivan99/leachx/refs/heads/main/LeachX.lua?t=" .. os.time()))()
]]

------------------------------------------------------------------
-- CONFIG (ubah bagian ini saja)
------------------------------------------------------------------
local CONFIG = {
    Name            = "LeachX",
    Version         = "1.0.0",

    -- Daftar key (file JSON milikmu, misalnya di GitHub raw). Format:
    --   { "keys": {
    --       "LEACHX-ABCD-1234": { "expires": 1795000000 },
    --       "LEACHX-WXYZ-9876": { "expires": 1795000000, "games": [1111111111] },
    --       "LEACHX-FOREVER-01": {}
    --   } }
    -- expires = waktu kedaluwarsa (unix detik, opsional)
    -- games   = batasi key ke GameId/PlaceId tertentu (opsional)
    KeysUrl = "https://raw.githubusercontent.com/muhivan99/leachx/refs/heads/main/keys.json",

    -- Cadangan tanpa file JSON (tidak disarankan, key terbaca di dalam script)
    StaticKeys = {},

    -- Daftar game. Kunci = GameId (universe) atau PlaceId, Url = link script
    -- mentah (raw) untuk game tersebut.
    -- GameId lebih disarankan karena berlaku untuk semua place di dalam game itu.
    -- Cara cari ID: jalankan  print(game.GameId, game.PlaceId)  di game tujuan.
    Games = {
        [10768941204] = {
            Name = "Steal A DNA",
            Url  = "https://raw.githubusercontent.com/joustingmatch/Ouroboros/main/loader.lua",
            -- Link pengambilan key khusus game ini
            Providers = {
                { Name = "Linkvertise", Url = "https://link-target.net/3347586/dV15rXm8LmqJ" },
                { Name = "LootLabs",    Url = "https://loot-link.com/s?pePuaeDT" },
            },
        },
    },

    -- Dipakai jika game tidak ada di daftar di atas. Isi nil agar game lain
    -- ditolak dengan pesan "belum didukung".
    Universal = nil,
    -- Universal = { Name = "Universal", Url = "https://raw.githubusercontent.com/USERNAME/REPO/main/universal.lua" },

    -- Link pengambilan key bawaan. Dipakai oleh game yang tidak punya
    -- Providers sendiri di daftar Games di atas.
    Providers = {
        { Name = "Linkvertise", Url = "https://link-target.net/3347586/dV15rXm8LmqJ" },
        { Name = "LootLabs",    Url = "https://loot-link.com/s?pePuaeDT" },
    },

    -- File sisa dari versi lama yang menyimpan key. Dihapus otomatis agar
    -- key tidak muncul lagi di kolom input.
    OldSaveFile   = "LeachX_key.txt",
}

------------------------------------------------------------------
-- Services & util
------------------------------------------------------------------
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")

local THEME = {
    Bg      = Color3.fromRGB(14, 14, 20),
    Panel   = Color3.fromRGB(24, 24, 34),
    Field   = Color3.fromRGB(32, 32, 46),
    Text    = Color3.fromRGB(235, 235, 245),
    Muted   = Color3.fromRGB(140, 140, 165),
    AccentA = Color3.fromRGB(0, 224, 176),
    AccentB = Color3.fromRGB(122, 90, 255),
    Good    = Color3.fromRGB(80, 220, 140),
    Bad     = Color3.fromRGB(255, 90, 100),
}

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end

local function tween(inst, t, props, style, dir)
    local tw = TweenService:Create(
        inst,
        TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end

local function gradient(rot)
    return new("UIGradient", {
        Rotation = rot or 0,
        Color = ColorSequence.new(THEME.AccentA, THEME.AccentB),
    })
end

local function getParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    local okCore = pcall(function() return CoreGui.Name end)
    if okCore then return CoreGui end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Coba beberapa tempat sampai ada yang berhasil (executor berbeda,
-- dukungan gethui/CoreGui berbeda).
local function attach(g)
    local candidates = {}
    pcall(function()
        if gethui then table.insert(candidates, gethui()) end
    end)
    table.insert(candidates, CoreGui)
    local lp = Players.LocalPlayer
    if lp then
        local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
        if pg then table.insert(candidates, pg) end
    end
    for _, p in ipairs(candidates) do
        local ok = pcall(function() g.Parent = p end)
        if ok and g.Parent == p then
            print("[LeachX] panel dipasang di: " .. p:GetFullName())
            return true
        end
    end
    return false
end

local function copy(text)
    local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if fn then
        local ok = pcall(fn, text)
        return ok
    end
    return false
end

-- Key tidak disimpan. Hapus file lama (jika ada) dari versi sebelumnya.
pcall(function()
    if isfile and delfile and isfile(CONFIG.OldSaveFile) then
        delfile(CONFIG.OldSaveFile)
    end
end)

------------------------------------------------------------------
-- Validasi key
------------------------------------------------------------------
local function cleanKey(key)
    return ((key or ""):gsub("%s+", ""))
end

local function listHas(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function checkKey(key)
    key = cleanKey(key):upper()
    if key == "" then return false, "Masukkan key terlebih dahulu" end

    local keys = {}
    for _, k in ipairs(CONFIG.StaticKeys) do keys[cleanKey(k):upper()] = {} end

    if CONFIG.KeysUrl ~= "" then
        -- Parameter t menghindari data lama dari cache
        local ok, res = pcall(function()
            return game:HttpGet(CONFIG.KeysUrl .. "?t=" .. tostring(os.time()))
        end)
        if not ok then return false, "Daftar key tidak bisa diambil" end

        -- Buang karakter tak terlihat di awal file (BOM) dan spasi di ujung
        res = tostring(res)
        res = (res:gsub("^\239\187\191", ""))
        res = (res:gsub("^%s+", ""))
        res = (res:gsub("%s+$", ""))

        local okJson, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not okJson or type(data) ~= "table" or type(data.keys) ~= "table" then
            warn("[LeachX] Isi daftar key tidak terbaca. Awal respons: " .. res:sub(1, 120))
            if not okJson then warn("[LeachX] Galat JSON: " .. tostring(data)) end
            return false, "Format daftar key salah"
        end
        for k, v in pairs(data.keys) do
            keys[cleanKey(k):upper()] = type(v) == "table" and v or {}
        end
    end

    local rec = keys[key]
    if not rec then return false, "Key tidak valid" end

    if type(rec.expires) == "number" and os.time() > rec.expires then
        return false, "Key sudah kedaluwarsa"
    end

    if type(rec.games) == "table"
        and not (listHas(rec.games, game.GameId) or listHas(rec.games, game.PlaceId)) then
        return false, "Key tidak berlaku untuk game ini"
    end

    return true
end

local function resolveTarget()
    return CONFIG.Games[game.GameId] or CONFIG.Games[game.PlaceId] or CONFIG.Universal
end

local target = resolveTarget()

local function launchMain()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(target.Url))()
    end)
    if not ok then warn("[" .. CONFIG.Name .. "] Gagal memuat script: " .. tostring(err)) end
    return ok, err
end

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
local old = getParent():FindFirstChild(CONFIG.Name .. "_Gate")
if old then old:Destroy() end

local gui = new("ScreenGui", {
    Name = CONFIG.Name .. "_Gate",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
})
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
if not attach(gui) then
    warn("[LeachX] Gagal memasang panel ke layar. Executor ini mungkin tidak didukung.")
end

-- Layar redup di belakang
local dim = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = gui,
})
tween(dim, 0.4, { BackgroundTransparency = 0.45 })

local main = new("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(0, 0),
    BackgroundColor3 = THEME.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = gui,
}, { corner(14) })

-- Garis tepi bergradasi yang berputar
local stroke = new("UIStroke", {
    Thickness = 2,
    Color = Color3.new(1, 1, 1),
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Parent = main,
})
local strokeGrad = gradient(0)
strokeGrad.Parent = stroke

-- Ukuran menyesuaikan layar kecil (HP)
local cam = workspace.CurrentCamera
local W = math.min(400, (cam and cam.ViewportSize.X or 800) - 32)
local H = 330

tween(main, 0.55, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Back)

-- Header
local title = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 14),
    Size = UDim2.new(1, -60, 0, 34),
    Font = Enum.Font.GothamBlack,
    Text = CONFIG.Name,
    TextSize = 28,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = main,
})
gradient(0).Parent = title

new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(21, 46),
    Size = UDim2.new(1, -60, 0, 16),
    Font = Enum.Font.Gotham,
    Text = (target and target.Name or "Game belum didukung") .. "  •  v" .. CONFIG.Version,
    TextSize = 12,
    TextColor3 = THEME.Muted,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = main,
})

local close = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = THEME.Panel,
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextColor3 = THEME.Muted,
    AutoButtonColor = false,
    Parent = main,
}, { corner(8) })

-- Label bagian
local function sectionLabel(text, y)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, y),
        Size = UDim2.new(1, -40, 0, 14),
        Font = Enum.Font.GothamBold,
        Text = string.upper(text),
        TextSize = 11,
        TextColor3 = THEME.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = main,
    })
end

-- Input key
sectionLabel("Masukkan key", 82)

local keyField = new("Frame", {
    Position = UDim2.fromOffset(20, 102),
    Size = UDim2.new(1, -40, 0, 44),
    BackgroundColor3 = THEME.Field,
    BorderSizePixel = 0,
    Parent = main,
}, { corner(10) })

local fieldStroke = new("UIStroke", {
    Thickness = 1.5,
    Color = THEME.Field,
    Transparency = 0,
    Parent = keyField,
})

local keyBox = new("TextBox", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -28, 1, 0),
    Font = Enum.Font.GothamMedium,
    PlaceholderText = "Tempel key di sini",
    PlaceholderColor3 = THEME.Muted,
    Text = "",
    TextColor3 = THEME.Text,
    TextSize = 14,
    ClearTextOnFocus = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = keyField,
})

keyBox.Focused:Connect(function() tween(fieldStroke, 0.2, { Color = THEME.AccentA }) end)
keyBox.FocusLost:Connect(function() tween(fieldStroke, 0.2, { Color = THEME.Field }) end)

-- Status
local status = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 152),
    Size = UDim2.new(1, -40, 0, 16),
    Font = Enum.Font.Gotham,
    Text = "Belum punya key? Ambil lewat salah satu pilihan di bawah.",
    TextSize = 12,
    TextColor3 = THEME.Muted,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = main,
})

local function setStatus(text, color)
    status.Text = text
    tween(status, 0.2, { TextColor3 = color or THEME.Muted })
end

-- Tombol verifikasi
-- Gradasi dipasang di lapisan latar terpisah. Kalau dipasang di tombolnya,
-- gradasi ikut mewarnai teks dan tulisannya jadi tidak terlihat.
local verify = new("TextButton", {
    Position = UDim2.fromOffset(20, 178),
    Size = UDim2.new(1, -40, 0, 44),
    BackgroundTransparency = 1,
    Text = "",
    AutoButtonColor = false,
    Parent = main,
})

local verifyBg = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Parent = verify,
}, { corner(10), gradient(0) })

local verifyLabel = new("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "Verifikasi Key",
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = THEME.Bg, -- gelap agar terbaca di atas warna toska maupun ungu
    Parent = verify,
})

-- Pilihan provider
sectionLabel("Ambil key lewat", 238)

local providerRow = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 258),
    Size = UDim2.new(1, -40, 0, 44),
    Parent = main,
}, {
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

-- Pakai link khusus game jika ada, jika tidak pakai link bawaan
local providers = (target and target.Providers) or CONFIG.Providers

for i, p in ipairs(providers) do
    local count = #providers
    local btn = new("TextButton", {
        LayoutOrder = i,
        Size = UDim2.new(1 / count, -(10 * (count - 1)) / count, 1, 0),
        BackgroundColor3 = THEME.Panel,
        Text = p.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = THEME.Text,
        AutoButtonColor = false,
        Parent = providerRow,
    }, { corner(10) })
    local s = new("UIStroke", { Thickness = 1.5, Color = THEME.Field, Parent = btn })

    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = THEME.Field })
        tween(s, 0.15, { Color = THEME.AccentB })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, { BackgroundColor3 = THEME.Panel })
        tween(s, 0.15, { Color = THEME.Field })
    end)
    btn.MouseButton1Click:Connect(function()
        if copy(p.Url) then
            setStatus("Link " .. p.Name .. " disalin. Buka di browser untuk mengambil key.", THEME.Good)
        else
            setStatus("Executor tidak mendukung salin. Link: " .. p.Url, THEME.Bad)
        end
    end)
end

------------------------------------------------------------------
-- Interaksi
------------------------------------------------------------------
local busy = false

local function shake()
    local base = main.Position
    for _, dx in ipairs({ 10, -10, 6, -6, 0 }) do
        tween(main, 0.04, {
            Position = UDim2.new(base.X.Scale, base.X.Offset + dx, base.Y.Scale, base.Y.Offset),
        }, Enum.EasingStyle.Linear)
        task.wait(0.04)
    end
end

local function closeGate(callback)
    tween(dim, 0.3, { BackgroundTransparency = 1 })
    local tw = tween(main, 0.3, { Size = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    tw.Completed:Wait()
    gui:Destroy()
    if callback then callback() end
end

verify.MouseButton1Click:Connect(function()
    if busy then return end
    busy = true
    local key = cleanKey(keyBox.Text)

    if not target then
        verifyLabel.Text = "Verifikasi Key"
        setStatus("Game ini belum didukung LeachX.", THEME.Bad)
        shake()
        busy = false
        return
    end

    verifyLabel.Text = "Memeriksa..."
    setStatus("Memeriksa key...", THEME.Muted)

    local ok, msg = checkKey(key)

    if ok then
        verifyLabel.Text = "Berhasil"
        setStatus("Key valid. Memuat script...", THEME.Good)
        task.wait(0.6)
        closeGate(launchMain)
    else
        verifyLabel.Text = "Verifikasi Key"
        setStatus(msg or "Key tidak valid", THEME.Bad)
        tween(fieldStroke, 0.2, { Color = THEME.Bad })
        shake()
        task.wait(0.4)
        tween(fieldStroke, 0.3, { Color = THEME.Field })
        busy = false
    end
end)

close.MouseEnter:Connect(function() tween(close, 0.15, { TextColor3 = THEME.Bad }) end)
close.MouseLeave:Connect(function() tween(close, 0.15, { TextColor3 = THEME.Muted }) end)
close.MouseButton1Click:Connect(function() closeGate() end)

-- Drag
do
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            local rel = input.Position.Y - main.AbsolutePosition.Y
            if rel <= 70 then
                dragging, dragStart, startPos = true, input.Position, main.Position
            end
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Animasi gradasi (garis tepi + tombol)
local conn
conn = RunService.RenderStepped:Connect(function(dt)
    if not gui.Parent then conn:Disconnect() return end
    strokeGrad.Rotation = (strokeGrad.Rotation + dt * 90) % 360
    local shift = (tick() * 0.4) % 2
    local off = shift < 1 and shift or 2 - shift
    verifyBg:FindFirstChildOfClass("UIGradient").Offset = Vector2.new(off * 0.4 - 0.2, 0)
end)

print("[LeachX] siap. GameId=" .. tostring(game.GameId) .. " PlaceId=" .. tostring(game.PlaceId)
    .. " game=" .. (target and target.Name or "tidak dikenal"))
