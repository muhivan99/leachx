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
        Providers = {
            { Name = "Linkvertise", Url = "https://link-target.net/3347586/dV15rXm8LmqJ" },
            { Name = "LootLabs",    Url = "https://loot-link.com/s?pePuaeDT" },
        },
    },
    [10769798178] = {
        Name = "Make Rug",
        Url  = "https://raw.githubusercontent.com/joustingmatch/Ouroboros/main/loader.lua",
        Providers = {
            { Name = "Linkvertise", Url = "https://link-center.net/3347586/ROh9vMondKOG" },
            { Name = "LootLabs",    Url = "https://lootdest.org/s?45EIIOA5" },
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
    Bg      = Color3.fromRGB(11, 12, 24),
    Bg2     = Color3.fromRGB(26, 16, 52),
    Panel   = Color3.fromRGB(21, 23, 42),
    Field   = Color3.fromRGB(30, 33, 58),
    FieldHi = Color3.fromRGB(38, 42, 72),
    Text    = Color3.fromRGB(238, 241, 255),
    Muted   = Color3.fromRGB(132, 138, 176),
    AccentA = Color3.fromRGB(0, 235, 190),
    AccentB = Color3.fromRGB(122, 92, 255),
    AccentC = Color3.fromRGB(255, 94, 196),
    Good    = Color3.fromRGB(90, 235, 165),
    Bad     = Color3.fromRGB(255, 96, 118),
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
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, THEME.AccentA),
            ColorSequenceKeypoint.new(0.5, THEME.AccentB),
            ColorSequenceKeypoint.new(1, THEME.AccentC),
        }),
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
}, { corner(16) })

-- Latar bergradasi (lapisan terpisah supaya garis tepi tidak ikut berubah warna)
new("Frame", {
    Name = "Bg",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ZIndex = 1,
    Parent = main,
}, {
    corner(16),
    new("UIGradient", {
        Rotation = 125,
        Color = ColorSequence.new(THEME.Bg2, THEME.Bg),
    }),
})

-- Garis tepi bergradasi yang berputar dan berdenyut
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

-- Partikel yang melayang pelan di latar
local fx = new("Frame", {
    Name = "FX",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 2,
    Parent = main,
})
local particleColors = { THEME.AccentA, THEME.AccentB, THEME.AccentC }
local particles = {}
for i = 1, 16 do
    local size = math.random(2, 4)
    local f = new("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundColor3 = particleColors[(i % #particleColors) + 1],
        BackgroundTransparency = 0.55 + math.random() * 0.3,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = fx,
    }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    particles[i] = {
        f = f,
        x = math.random(14, math.floor(W) - 14),
        y = math.random(14, H - 14),
        speed = 8 + math.random() * 14,
        phase = math.random() * 6.28,
    }
end

-- Bagian-bagian panel yang masuk satu per satu saat dibuka
local function group()
    return new("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 16),
        ZIndex = 3,
        Parent = main,
    })
end

local gHeader, gKey, gVerify, gProv = group(), group(), group(), group()

local function reveal(g, delay)
    task.delay(delay, function()
        if g.Parent then
            tween(g, 0.5, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
        end
    end)
end

reveal(gHeader, 0.18)
reveal(gKey, 0.28)
reveal(gVerify, 0.38)
reveal(gProv, 0.48)

-- Header: lencana, judul, status game
local badge = new("Frame", {
    Position = UDim2.fromOffset(20, 14),
    Size = UDim2.fromOffset(40, 40),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    Parent = gHeader,
}, { corner(12) })
local badgeGrad = gradient(45)
badgeGrad.Parent = badge

new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Font = Enum.Font.GothamBlack,
    Text = "L",
    TextSize = 22,
    TextColor3 = THEME.Bg,
    Parent = badge,
})

local title = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(70, 11),
    Size = UDim2.new(1, -120, 0, 28),
    Font = Enum.Font.GothamBlack,
    Text = CONFIG.Name,
    TextSize = 26,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = gHeader,
})
local titleGrad = gradient(0)
titleGrad.Parent = title

local dot = new("Frame", {
    Position = UDim2.fromOffset(71, 46),
    Size = UDim2.fromOffset(8, 8),
    BackgroundColor3 = target and THEME.Good or THEME.Bad,
    BorderSizePixel = 0,
    Parent = gHeader,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(86, 40),
    Size = UDim2.new(1, -130, 0, 20),
    Font = Enum.Font.GothamMedium,
    Text = (target and target.Name or "Game belum didukung") .. "  •  v" .. CONFIG.Version,
    TextSize = 12,
    TextColor3 = THEME.Muted,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = gHeader,
})

local close = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = THEME.Panel,
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextColor3 = THEME.Muted,
    AutoButtonColor = false,
    Parent = gHeader,
}, { corner(9) })

-- Label bagian
local function sectionLabel(text, y, parent)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, y),
        Size = UDim2.new(1, -40, 0, 14),
        Font = Enum.Font.GothamBold,
        Text = string.upper(text),
        TextSize = 11,
        TextColor3 = THEME.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    })
end

-- Input key
sectionLabel("Masukkan key", 82, gKey)

-- Cincin cahaya yang menyala saat kolom key dipilih
local fieldGlow = new("Frame", {
    Position = UDim2.fromOffset(17, 99),
    Size = UDim2.new(1, -34, 0, 50),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 1,
    Parent = gKey,
}, { corner(13) })
local glowGrad = gradient(0)
glowGrad.Parent = fieldGlow

local keyField = new("Frame", {
    Position = UDim2.fromOffset(20, 102),
    Size = UDim2.new(1, -40, 0, 44),
    BackgroundColor3 = THEME.Field,
    BorderSizePixel = 0,
    ZIndex = 2,
    Parent = gKey,
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

keyBox.Focused:Connect(function()
    tween(fieldStroke, 0.2, { Color = THEME.AccentA })
    tween(fieldGlow, 0.25, { BackgroundTransparency = 0.55 })
    tween(keyField, 0.2, { BackgroundColor3 = THEME.FieldHi })
end)
keyBox.FocusLost:Connect(function()
    tween(fieldStroke, 0.2, { Color = THEME.Field })
    tween(fieldGlow, 0.25, { BackgroundTransparency = 1 })
    tween(keyField, 0.2, { BackgroundColor3 = THEME.Field })
end)

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
    Parent = gKey,
})

local function setStatus(text, color)
    status.Text = text
    -- pesan baru muncul sedikit dari bawah sambil memudar masuk
    status.TextTransparency = 0.7
    status.Position = UDim2.fromOffset(20, 157)
    tween(status, 0.25, {
        TextColor3 = color or THEME.Muted,
        TextTransparency = 0,
        Position = UDim2.fromOffset(20, 152),
    })
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
    Parent = gVerify,
})

local verifyGrad = gradient(0)
local verifyBg = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = verify,
}, { corner(12), verifyGrad })

-- Kilau cahaya yang melintas di atas tombol
local shine = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(-0.2, 0, 0.5, 0),
    Size = UDim2.new(0, 36, 1.8, 0),
    Rotation = 20,
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.78,
    BorderSizePixel = 0,
    Visible = false,
    Parent = verifyBg,
})

local verifyLabel = new("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 2,
    Text = "Verifikasi Key",
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextColor3 = THEME.Bg, -- gelap agar terbaca di atas warna toska, ungu, maupun merah muda
    Parent = verify,
})

-- Lingkaran berputar saat key sedang diperiksa
local spinner = new("Frame", {
    Position = UDim2.new(0, 16, 0.5, -9),
    Size = UDim2.fromOffset(18, 18),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 3,
    Parent = verify,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local spinStroke = new("UIStroke", {
    Thickness = 2.5,
    Color = THEME.Bg,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Parent = spinner,
})
local spinGrad = new("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.55, 1),
        NumberSequenceKeypoint.new(1, 1),
    }),
    Parent = spinStroke,
})

verify.MouseEnter:Connect(function()
    tween(verifyBg, 0.15, { Size = UDim2.new(1, 6, 1, 3) })
end)
verify.MouseLeave:Connect(function()
    tween(verifyBg, 0.15, { Size = UDim2.fromScale(1, 1) })
end)
verify.MouseButton1Down:Connect(function()
    tween(verifyBg, 0.08, { Size = UDim2.new(1, -6, 1, -4) })
end)
verify.MouseButton1Up:Connect(function()
    tween(verifyBg, 0.12, { Size = UDim2.fromScale(1, 1) })
end)

-- Pilihan provider
sectionLabel("Ambil key lewat", 238, gProv)

local providerRow = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 258),
    Size = UDim2.new(1, -40, 0, 44),
    Parent = gProv,
}, {
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }),
})

-- Pakai link khusus game jika ada, jika tidak pakai link bawaan
local providers = (target and target.Providers) or CONFIG.Providers
local dotColors = { THEME.AccentA, THEME.AccentC, THEME.AccentB }

for i, p in ipairs(providers) do
    local count = #providers
    local holder = new("Frame", {
        LayoutOrder = i,
        Size = UDim2.new(1 / count, -(10 * (count - 1)) / count, 1, 0),
        BackgroundTransparency = 1,
        Parent = providerRow,
    })
    local btn = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = THEME.Panel,
        Text = p.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = THEME.Text,
        AutoButtonColor = false,
        ClipsDescendants = true,
        Parent = holder,
    }, { corner(12) })
    local s = new("UIStroke", { Thickness = 1.5, Color = THEME.Field, Parent = btn })

    -- titik warna kecil sebagai penanda tiap pilihan
    new("Frame", {
        Position = UDim2.new(0, 14, 0.5, -3),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = dotColors[((i - 1) % #dotColors) + 1],
        BorderSizePixel = 0,
        Parent = btn,
    }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    btn.MouseEnter:Connect(function()
        tween(btn, 0.18, { BackgroundColor3 = THEME.Field, Position = UDim2.fromOffset(0, -2) })
        tween(s, 0.18, { Color = THEME.AccentB })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.18, { BackgroundColor3 = THEME.Panel, Position = UDim2.fromOffset(0, 0) })
        tween(s, 0.18, { Color = THEME.Field })
    end)
    btn.MouseButton1Click:Connect(function()
        -- efek riak dari tengah tombol
        local ripple = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(0, 0),
            BackgroundColor3 = THEME.AccentA,
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0,
            Parent = btn,
        }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
        tween(ripple, 0.5, { Size = UDim2.fromOffset(260, 260), BackgroundTransparency = 1 })
        task.delay(0.55, function() ripple:Destroy() end)

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

close.MouseEnter:Connect(function()
    tween(close, 0.2, { TextColor3 = THEME.Bad, Rotation = 90 })
end)
close.MouseLeave:Connect(function()
    tween(close, 0.2, { TextColor3 = THEME.Muted, Rotation = 0 })
end)
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

-- Animasi (garis tepi, judul, tombol, kilau, putaran, partikel)
local startT = tick()
local conn
conn = RunService.RenderStepped:Connect(function(dt)
    if not gui.Parent then conn:Disconnect() return end
    local t = tick() - startT

    strokeGrad.Rotation = (strokeGrad.Rotation + dt * 90) % 360
    stroke.Transparency = 0.08 + 0.12 * (0.5 + 0.5 * math.sin(t * 2))

    badgeGrad.Rotation = (badgeGrad.Rotation + dt * 60) % 360
    glowGrad.Rotation = (glowGrad.Rotation + dt * 120) % 360

    titleGrad.Offset = Vector2.new((0.5 + 0.5 * math.sin(t * 0.9)) * 0.5 - 0.25, 0)

    local shift = (t * 0.4) % 2
    local off = shift < 1 and shift or 2 - shift
    verifyGrad.Offset = Vector2.new(off * 0.4 - 0.2, 0)

    -- kilau melintas, lalu jeda sebentar
    local phase = (t % 3.6) / 2.2
    if phase <= 1 then
        shine.Visible = true
        shine.Position = UDim2.new(-0.15 + phase * 1.3, 0, 0.5, 0)
    else
        shine.Visible = false
    end

    -- lingkaran berputar hanya saat memeriksa key
    local loading = verifyLabel.Text:sub(1, 9) == "Memeriksa"
    spinner.Visible = loading
    if loading then spinGrad.Rotation = (spinGrad.Rotation + dt * 360) % 360 end

    dot.BackgroundTransparency = 0.5 * (0.5 + 0.5 * math.sin(t * 3))

    for _, pt in ipairs(particles) do
        pt.y = pt.y - pt.speed * dt
        if pt.y < 12 then
            pt.y = H - 12
            pt.x = math.random(14, math.floor(W) - 14)
        end
        pt.f.Position = UDim2.fromOffset(pt.x + math.sin(t * 0.8 + pt.phase) * 8, pt.y)
    end
end)

print("[LeachX] siap. GameId=" .. tostring(game.GameId) .. " PlaceId=" .. tostring(game.PlaceId)
    .. " game=" .. (target and target.Name or "tidak dikenal"))
