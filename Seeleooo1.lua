--[[
    SeeLeooo
    UI: ProxyLib
    Tab: Fishing | Auto | Misc | Settings
    F1 = Freecam | F2 = Auto Fish | F3 = Rekam Macro | F4 = Putar Macro
    Z (tahan) = NoClip
]]

local SeeLeoooEnv = type(getgenv) == "function" and getgenv() or _G
local previousRuntime = SeeLeoooEnv.SeeLeoooRuntime
if type(previousRuntime)=="table" and type(previousRuntime.Unload)=="function" then
    local stopped,err=pcall(previousRuntime.Unload)
    if not stopped then warn("[SeeLeooo] Cleanup versi lama gagal: "..tostring(err)) return end
    local deadline=os.clock()+5
    while previousRuntime.Busy and previousRuntime.Busy() and os.clock()<deadline do task.wait(0.05) end
    if previousRuntime.Busy and previousRuntime.Busy() then
        warn("[SeeLeooo] Worker lama masih cleanup. Tunggu lalu jalankan lagi.") return
    end
end

local ProxyLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ProxyHubDev/ProxyLib/refs/heads/main/Documents/ProxyLibrary"
))()
local Lib = ProxyLib.new()

local Window = Lib:CreateWindow({
    Title = "SeeLeooo",
    Subtitle = "1 Untuk Semua",
    Size = Vector2.new(500, 400),
    MinSize = Vector2.new(420, 320),
    MaxSize = Vector2.new(900, 620),
    Theme = Color3.fromRGB(255, 255, 0),
    TypeUI = "Classic",
    Language = "English",
    Search = true,
    AutoSave = false,
    AutoLoad = false,
    DefaultFps = false,
    DefaultPing = false,
    DefaultProfile = true,
    BackgroundImage = { Id = "rbxassetid://18791260555", Active = true },
    TitleConfig = {
        Gradient = true,
        Colors = { Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 220, 50) },
        Words = {
            { Text = "SeeLeooo", Colors = { Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 255, 25) } },
        },
    },
    ConfigPanel = {
        Enabled = true, Acrylic = true, Theme = true, Fps = false,
        Ping = false, Profile = true, HideNotify = true, Language = true,
        BackgroundImage = true,
    },
    FloatButton = {
        Shape = "Circle",
        Color = "Translucent",
        Size = 50,
        Icon = "rbxassetid://129646465196832"
    },
    Acrylic = { Enabled = false, Opacity = 0 },
})

-- =========================================================
-- SERVICES
-- =========================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- =========================================================
-- STATE
-- =========================================================
local Running = true -- false saat Unload (semua loop berhenti)
local Automation


local espPlayerActive = false
local infiniteJumpActive = false
local noClipActive = false
local antiAfkActive = false
local FreezeCharacter = false
local walkSpeedVal = 16
local jumpPowerVal = 50
local cframeInput = ""

-- Freecam
local freecamActive = false
local freecamConn = nil
local freecamSpeed = 2
local freecamFastMult = 4
local freecamCF = nil
local freecamYaw = 0
local freecamPitch = 0
local freecamSavedCFrame = nil
local freecamKeys = {
    W = false, A = false, S = false, D = false,
    Q = false, E = false, LeftShift = false,
}

-- Auto Fish
local AF = {
    On = false,
    ReelOffset = 0.25, -- reel X detik setelah window gigit buka
    Retry = true,      -- klik reel ulang kalau window masih terbuka
    Between = 0.4,     -- jeda antar cast (detik)
    Turbo = false,     -- mode tercepat (offset 0.12s, jeda 0.2s)
    Pos = nil,         -- posisi klik di air (layar)
    Cur = nil,         -- sesi aktif {Id, Windows, Duration}
    Paused = false,    -- dijeda saat proses/jual ikan
    NeedProcess = false,
    Caught = 0, Missed = 0, Failed = 0, Reels = 0,
    LastFish = nil,
    CatchLog = {},     -- [idIkan] = {n, maxW}
    AutoEquip = false,
    EquipSlot = 1,
    Hotkey = true,     -- F2
    HudGui = nil,
}

-- Macro proses ikan: rekam station + 1 posisi GUI, lalu putar
local PR = {
    Busy = false,
    Recording = false,
    Steps = {},
    GuiClickPos = nil,
    Runs = 0,
    Auto = false,
    Stop = false,
    MoveWait = 0.05,
    StepWait = 0.03,
    GuiWait = 0.25,
    AfterClick = 0.12,
}

-- Waypoint
local WP = { List = {}, Idx = 0, NameInput = "" }

-- Opsi lain
local Opt = { AutoRejoin = false, Rejoining = false, LowGfx = false, GfxBackup = nil }

-- Auto Click UI
local AutoClickUI = false
local UIClickPositions = {}
local UIClickDelay = 0.4
local IsSettingUIClick = false

-- Auto Claim
local AutoClaimMeteor = false
local ClaimingMeteor = false
local ClaimedMeteors = {}

local AutoHarvest = false

-- Auto Press Key
local AutoPressKey = false
local PressKeyCode = Enum.KeyCode.E
local PressKeyName = "E"
local PressKeyDelay = 0.08
local IsSettingPressKey = false


local connections = {}
local playerESPFolder = Instance.new("Folder")
playerESPFolder.Name = "SeeLeooo_PlayerESP"
playerESPFolder.Parent = CoreGui


-- =========================================================
-- HELPERS UMUM
-- =========================================================
local trackCount=0
local function track(c)
    trackCount+=1
    if trackCount%64==0 then
        for i=#connections,1,-1 do if not connections[i].Connected then table.remove(connections,i) end end
    end
    connections[#connections + 1] = c
    return c
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end


local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local noClipParts = setmetatable({}, { __mode="k" })
local noClipCharacter, noClipHook
local function restoreNoClip()
    for part, original in pairs(noClipParts) do pcall(function() part.CanCollide=original end) end
    table.clear(noClipParts)
    if noClipHook then noClipHook:Disconnect() noClipHook=nil end
    noClipCharacter=nil
end
local function updateNoClip()
    local char=player.Character
    if not noClipActive or not char then return end
    if noClipCharacter~=char then
        restoreNoClip() noClipCharacter=char
        for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then noClipParts[part]=part.CanCollide end end
        noClipHook=char.DescendantAdded:Connect(function(part)
            if part:IsA("BasePart") then noClipParts[part]=part.CanCollide end
        end)
    end
    for part in pairs(noClipParts) do if part.Parent then part.CanCollide=false end end
end

local function ClickAt(x, y, force)
    if Automation and Automation.ScriptAt and Automation:ScriptAt(x, y) then
        Automation.Status = "Klik ditunda: geser UI script yang menutupi tombol game"
        return false
    end
    local ok = pcall(function()
        VirtualInputManager:SendMouseMoveEvent(x, y, game)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.03)
    end)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1) end)
    return ok
end

-- Koordinat GUI yang stabil di windowed + fullscreen
local function guiClickCoords(obj)
    local p, s = obj.AbsolutePosition, obj.AbsoluteSize
    local cx, cy = p.X + s.X / 2, p.Y + s.Y / 2
    local inset = GuiService:GetGuiInset()
    local sg = obj:FindFirstAncestorOfClass("ScreenGui")
    local coords = {
        { cx, cy },
        { cx, cy + inset.Y },
        { cx, cy - inset.Y },
    }
    if sg and not sg.IgnoreGuiInset then
        coords = {
            { cx, cy + inset.Y },
            { cx, cy },
            { cx, cy - inset.Y },
        }
    end
    return coords
end

local function guiCenter(obj, noInset)
    local p, s = obj.AbsolutePosition, obj.AbsoluteSize
    local x, y = p.X + s.X / 2, p.Y + s.Y / 2
    local sg = obj:FindFirstAncestorOfClass("ScreenGui")
    if not noInset and sg and not sg.IgnoreGuiInset then
        y += GuiService:GetGuiInset().Y
    end
    return x, y
end

-- Klik GUI sekuat mungkin
local function hardPressGui(obj)
    if not obj then return false end

    local btn = obj
    if not obj:IsA("GuiButton") then
        btn = obj:FindFirstChildWhichIsA("GuiButton", true)
            or obj:FindFirstAncestorWhichIsA("GuiButton")
            or obj
    end

    -- 1) getconnections (paling sering berhasil di executor)
    pcall(function()
        if getconnections then
            for _, sig in ipairs({
                btn.MouseButton1Click,
                btn.MouseButton1Down,
                btn.MouseButton1Up,
                btn.Activated,
            }) do
                for _, c in ipairs(getconnections(sig)) do
                    pcall(function()
                        if c.Function then c.Function() end
                        if c.Fire then c:Fire() end
                    end)
                end
            end
        end
    end)

    -- 2) firesignal
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Click)
            firesignal(btn.MouseButton1Up)
            firesignal(btn.Activated)
        end
    end)

    -- 3) Activate bawaan
    pcall(function()
        if btn:IsA("GuiButton") then btn:Activate() end
    end)

    -- 4) Klik virtual: 2 mode koordinat (dengan/ tanpa inset)
    for _, noInset in ipairs({ false, true }) do
        local x, y = guiCenter(btn, noInset)
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
            task.wait(0.03)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.06)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        task.wait(0.05)
    end

    return true
end

local function pressGui(obj, noInset)
    return hardPressGui(obj)
end

local function firePrompt(prompt)
    if not prompt then return end
    for _ = 1, 3 do
        pcall(function()
            if fireproximityprompt then fireproximityprompt(prompt) end
        end)
        pcall(function() prompt:InputHoldBegin() end)
        task.wait(0.05)
        pcall(function() prompt:InputHoldEnd() end)
        task.wait(0.03)
    end
end

local function safeCreateInput(tab, opts)
    local ok, res = pcall(function()
        if tab.CreateInput then return tab:CreateInput(opts)
        elseif tab.CreateTextBox then return tab:CreateTextBox(opts)
        elseif tab.CreateTextbox then return tab:CreateTextbox(opts)
        end
        return nil
    end)
    if ok and res then return res end
    tab:CreateButton({
        Title = opts.Title or opts.Name or "Input",
        Description = (opts.Placeholder or opts.PlaceholderText or "") .. " (no input API)",
        Callback = function()
            notify("Input", "Library tidak support text input field", 3)
        end,
    })
    return nil
end

-- Freeze Character (dipakai tab RAR & Misc)
local function setFreeze(v, silent)
    FreezeCharacter = v
    local hrp = getHRP()
    if hrp then
        hrp.Anchored = v
        if v then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
    if not silent then
        notify("Freeze", v and "Character dibekukan" or "Character dilepas", 2)
    end
end

-- =========================================================
-- HELPERS FISHING / GUI
-- =========================================================
local LogBuf = {}
local function plog(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    local line = "[SeeLeooo] " .. table.concat(parts, " ")
    print(line)
    LogBuf[#LogBuf + 1] = line
    if #LogBuf > 500 then table.remove(LogBuf, 1) end
end

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Catat ikan yang didapat
local function recordCatch(fish)
    local id = tostring(rawget(fish, "Id") or "?")
    local w = tonumber(rawget(fish, "W")) or 0
    local e = AF.CatchLog[id]
    if not e then
        e = { n = 0, maxW = 0 }
        AF.CatchLog[id] = e
    end
    e.n += 1
    if w > e.maxW then e.maxW = w end
    AF.LastFish = string.format("%s %.2fkg", id, w)
end

local SLOT_KEYS = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
    Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
    Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

local function pressSlotKey(n)
    local kc = SLOT_KEYS[n]
    if not kc then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, kc, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, kc, false, game)
    end)
end

-- Posisi tengah GuiObject dalam koordinat layar (untuk klik virtual)
-- noInset = true -> jangan tambah GuiInset (cadangan kalau offset layar beda)
local function guiCenter(obj, noInset)
    local p, s = obj.AbsolutePosition, obj.AbsoluteSize
    local x, y = p.X + s.X / 2, p.Y + s.Y / 2
    local sg = obj:FindFirstAncestorOfClass("ScreenGui")
    if not noInset and sg and not sg.IgnoreGuiInset then
        y += GuiService:GetGuiInset().Y
    end
    return x, y
end

local function pressGui(obj, noInset)
    if not obj then return false end

    -- cari GuiButton terdekat (bisa ImageButton / TextButton)
    local btn = obj
    if not obj:IsA("GuiButton") then
        btn = obj:FindFirstChildWhichIsA("GuiButton", true)
            or obj:FindFirstAncestorWhichIsA("GuiButton")
            or obj
    end

    -- Method 1: firesignal / Activate
    if btn:IsA("GuiButton") then
        pcall(function()
            if firesignal then
                firesignal(btn.MouseButton1Down)
                firesignal(btn.MouseButton1Click)
                firesignal(btn.MouseButton1Up)
                firesignal(btn.Activated)
            end
        end)
        pcall(function() btn:Activate() end)
    end

    -- Method 2: klik virtual di tengah tombol (2 mode inset)
    local function clickCenter(useNoInset)
        local x, y = guiCenter(btn, useNoInset)
        pcall(function() VirtualInputManager:SendMouseMoveEvent(x, y, game) end)
        task.wait(0.04)
        ClickAt(x, y)
    end

    clickCenter(noInset)
    task.wait(0.06)
    clickCenter(not noInset) -- coba mode inset kebalikan juga

    return true
end

local function isShown(obj)
    local o = obj
    while o and o ~= game do
        if o:IsA("GuiObject") and not o.Visible then return false end
        if o:IsA("ScreenGui") then return o.Enabled end
        o = o.Parent
    end
    return true
end

local function promptPos(pr)
    local par = pr.Parent
    if par then
        if par:IsA("BasePart") then return par.Position end
        if par:IsA("Attachment") then return par.WorldPosition end
        if par:IsA("Model") then return par:GetPivot().Position end
        local bp = par:FindFirstChildWhichIsA("BasePart", true)
        if bp then return bp.Position end
    end
    return nil
end

local function findNearestPrompt(pos, radius)
    local best, bd = nil, radius or 20
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local pp = promptPos(v)
            if pp then
                local d = (pp - pos).Magnitude
                if d < bd then best, bd = v, d end
            end
        end
    end
    return best
end

    -- Cari prompt dekat posisi rekaman (ringan, tidak scan seluruh map)
    local function findStationPrompt(pos, action)
        if not pos then return nil end
        local best, bestD = nil, 8
        local want = (action or ""):lower()

        -- hanya cek region kecil lewat overlap (lebih ringan)
        local parts = workspace:GetPartBoundsInRadius(pos, 8)
        local checked = {}
        for _, part in ipairs(parts) do
            local model = part:FindFirstAncestorOfClass("Model") or part
            if not checked[model] then
                checked[model] = true
                local pr = model:FindFirstChildWhichIsA("ProximityPrompt", true)
                if pr then
                    local pp = promptPos(pr)
                    if pp then
                        local d = (pp - pos).Magnitude
                        if d < bestD then
                            if want == "" or (pr.ActionText .. " " .. pr.ObjectText):lower():find(want, 1, true) then
                                best, bestD = pr, d
                            elseif not best then
                                best, bestD = pr, d
                            end
                        end
                    end
                end
            end
        end
        return best
    end

-- Tekan prompt "kuat": hold di-nol-kan sementara + jarak dilonggarkan
local function firePromptStrong(prompt)
    if not prompt then return end
    pcall(function()
        if fireproximityprompt then fireproximityprompt(prompt) end
    end)
    local oldHold, oldLos, oldDist
    pcall(function()
        oldHold, oldLos, oldDist = prompt.HoldDuration, prompt.RequiresLineOfSight, prompt.MaxActivationDistance
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = math.max(oldDist or 10, 20)
    end)
    for _ = 1, 2 do
        pcall(function() prompt:InputHoldBegin() end)
        task.wait(0.12)
        pcall(function() prompt:InputHoldEnd() end)
        task.wait(0.05)
    end
    pcall(function()
        if oldHold ~= nil then prompt.HoldDuration = oldHold end
        if oldLos ~= nil then prompt.RequiresLineOfSight = oldLos end
        if oldDist ~= nil then prompt.MaxActivationDistance = oldDist end
    end)
end

-- Tahan tombol keyboard prompt (seperti pemain asli) selama HoldDuration + sedikit
local function pressPromptKey(prompt)
    if not prompt then return end
    local kc = prompt.KeyboardKeyCode
    if not kc or kc == Enum.KeyCode.Unknown then kc = Enum.KeyCode.E end
    local hold = math.max(prompt.HoldDuration or 0, 0) + 0.3
    pcall(function() VirtualInputManager:SendKeyEvent(true, kc, false, game) end)
    task.wait(hold)
    pcall(function() VirtualInputManager:SendKeyEvent(false, kc, false, game) end)
end

local function autoFindPrompt(keywords, nearPos)
    local best, bd = nil, math.huge
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local s = (v:GetFullName() .. " " .. v.ActionText .. " " .. v.ObjectText):lower()
            for _, k in ipairs(keywords) do
                if s:find(k, 1, true) then
                    local pp = promptPos(v)
                    if pp then
                        local d = nearPos and (pp - nearPos).Magnitude or 0
                        if d < bd then best, bd = v, d end
                    end
                    break
                end
            end
        end
    end
    return best
end

-- Cari entri ikan di GUI proses (FishEntry, dari dump FishingTutorial)
local function findFishEntry()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d.Name == "FishEntry" and d:IsA("GuiObject") and d.AbsoluteSize.X > 0
            and isShown(d) and not d:FindFirstAncestor("FishBox") then
            return d
        end
    end
    return nil
end

local function countEntries()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return 0 end
    local n = 0
    for _, d in ipairs(pg:GetDescendants()) do
        if d.Name == "FishEntry" and d:IsA("GuiObject") and d.AbsoluteSize.X > 0
            and isShown(d) and not d:FindFirstAncestor("FishBox") then
            n += 1
        end
    end
    return n
end

local function waitEntry(t)
    local t0 = os.clock()
    local e = findFishEntry()
    while not e and os.clock() - t0 < t do
        task.wait(0.15)
        e = findFishEntry()
    end
    return e
end

-- Cetak GUI terkait (fish/cut/sell/...) ke console. Yang TERLIHAT dicetak lengkap,
-- yang tersembunyi cuma dihitung per induk (biar log nggak penuh)
local function dumpGui(tag)
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    plog("---- DUMP GUI (" .. tostring(tag) .. ") ----")
    local on = {}
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then on[#on + 1] = g.Name end
    end
    plog("ScreenGui aktif:", table.concat(on, ", "))

    local shown, hiddenBy = 0, {}
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiObject") then
            local nm = d.Name:lower()
            if nm:find("fish") or nm:find("fridge") or nm:find("cut") or nm:find("station")
                or nm:find("sell") or nm:find("market") or nm:find("shop") or nm:find("confirm")
                or nm:find("process") then
                if d.AbsoluteSize.X > 0 and isShown(d) then
                    shown += 1
                    if shown <= 40 then
                        local txt = (d:IsA("TextButton") or d:IsA("TextLabel")) and d.Text or ""
                        plog(string.format("TAMPIL: %s | %s | %dx%d | %s",
                            d:GetFullName(), d.ClassName, d.AbsoluteSize.X, d.AbsoluteSize.Y, txt))
                    end
                else
                    local root = d:FindFirstAncestorOfClass("ScreenGui")
                    local k = root and root.Name or "?"
                    hiddenBy[k] = (hiddenBy[k] or 0) + 1
                end
            end
        end
    end
    local hb = {}
    for k, v in pairs(hiddenBy) do hb[#hb + 1] = k .. "=" .. v end
    plog("Tersembunyi per GUI:", table.concat(hb, ", "))
    plog("---- END DUMP (" .. shown .. " tampil) ----")
end

-- Ulangi klik di dunia: kamera dikunci ke sudut rekaman, lalu klik di posisi layar rekaman
local function macroClick(camCF, screenPos)
    local cam = workspace.CurrentCamera
    local prev = cam.CameraType
    pcall(function()
        cam.CameraType = Enum.CameraType.Scriptable
        cam.CFrame = camCF
    end)
    task.wait(0.3)
    pcall(function() VirtualInputManager:SendMouseMoveEvent(screenPos.X, screenPos.Y, game) end)
    task.wait(0.06)
    ClickAt(screenPos.X, screenPos.Y)
    task.wait(0.2)
    pcall(function()
        cam.CameraType = (prev == Enum.CameraType.Scriptable) and Enum.CameraType.Custom or prev
    end)
end

-- Tutup GUI (ScreenGui bernama rootName) lewat tombol Close / X kalau ada
local function closeGuiByRoot(rootName)
    pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        local root = pg and pg:FindFirstChild(rootName)
        if not root then return end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("GuiButton") and d.AbsoluteSize.X > 0 and isShown(d) then
                local n = d.Name:lower()
                local t = d:IsA("TextButton") and d.Text:lower() or ""
                if n:find("close") or n == "x" or t == "x" then
                    pressGui(d)
                    return
                end
            end
        end
    end)
end

local function closeFishGui()
    closeGuiByRoot("FishBoxSelect")
end

-- Cari GuiObject yang TERLIHAT berdasarkan nama persis
local function findShownByName(name, rootName)
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local container = rootName and pg:FindFirstChild(rootName) or pg
    if not container then return nil end
    for _, d in ipairs(container:GetDescendants()) do
        if d.Name == name and d:IsA("GuiObject") and d.AbsoluteSize.X > 0 and isShown(d) then
            return d
        end
    end
    return nil
end

-- UI script tetap terlihat selama semua pekerjaan auto.
local function hideLibUi()
    return function() end
end

local function findButtonByText(keys)
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        local txt
        if d:IsA("TextButton") then
            txt = d.Text
        elseif d:IsA("TextLabel") and d:FindFirstAncestorWhichIsA("GuiButton") then
            txt = d.Text
        end
        if txt and d.AbsoluteSize.X > 0 and isShown(d) then
            local l = txt:lower()
            for _, k in ipairs(keys) do
                if l:find(k, 1, true) then
                    return d:IsA("GuiButton") and d or d:FindFirstAncestorWhichIsA("GuiButton")
                end
            end
        end
    end
    return nil
end

-- =========================================================
-- HELPERS: SIMPAN / MUAT SETELAN, MODE HEMAT
-- =========================================================
local SETTINGS_FILE = "SeeLeooo_settings.json"

-- v2.5: bindings store the runtime value and update ProxyLib through its documented Set API.
local SettingsUI = { Controls = {}, ByObject = {}, Syncing = false }
function SettingsUI:Wrap(tab, tabName)
    return setmetatable({}, {__index=function(_, method)
        local original=tab[method]
        if type(original)~="function" then return original end
        if method~="CreateToggle" and method~="CreateSlider" and method~="CreateTextBox" then
            return function(_, ...) return original(tab, ...) end
        end
        return function(_, opts)
            local config=table.clone(opts)
            local entry={key=tabName.."/"..opts.Title, title=opts.Title, kind=method,
                value=opts.Default, apply=opts.Callback, min=opts.Min, max=opts.Max}
            config.Callback=function(value)
                if self.Syncing then return end
                entry.value=value
                entry.shown=nil
                if entry.apply then entry.apply(value) end
            end
            local object=original(tab,config)
            entry.object=object
            self.Controls[#self.Controls+1]=entry
            self.ByObject[object]=entry
            return object
        end
    end})
end
function SettingsUI:Bind(object,get)
    local entry=self.ByObject[object]
    if entry then entry.get=get end
end
function SettingsUI:Value(entry)
    if entry.get then return entry.get() end
    return entry.value
end
function SettingsUI:Sync()
    self.Syncing=true
    local failures={}
    for _,entry in ipairs(self.Controls) do
        local value=self:Value(entry)
        if entry.get and value~=nil and value~=entry.shown then
            local ok,err=pcall(function()
                assert(type(entry.object.Set)=="function","ProxyLib Set tidak tersedia")
                entry.object:Set(value)
            end)
            if ok then entry.shown=value else failures[#failures+1]=entry.title..": "..tostring(err) end
        end
    end
    self.Syncing=false
    return failures
end
function SettingsUI:Export()
    local data={}
    for _,entry in ipairs(self.Controls) do
        -- Only controls bound to runtime state are persisted; text commands are excluded.
        if entry.get then data[entry.key]=self:Value(entry) end
    end
    return data
end
function SettingsUI:Apply(data)
    if type(data)~="table" then return end
    for _,entry in ipairs(self.Controls) do
        local value=data[entry.key]
        if entry.get and entry.apply and value~=nil and entry.title~="Auto Putar" then
            local valid=(entry.kind=="CreateToggle" and type(value)=="boolean")
                or (entry.kind=="CreateSlider" and type(value)=="number" and value==value and math.abs(value)<1e15)
                or (entry.kind=="CreateTextBox" and type(value)=="string")
            if valid then
                if entry.kind=="CreateSlider" then value=math.clamp(value,entry.min,entry.max) end
                entry.apply(value)
                entry.value=value
            end
        end
    end
end


local function cfToTable(cf) return { cf:GetComponents() } end
local function tableToCf(t)
    if type(t)=="table" and #t==12 then
        for _,v in ipairs(t) do if type(v)~="number" or v~=v or math.abs(v)>1e9 then return nil end end
        return CFrame.new(table.unpack(t))
    end
    return nil
end

-- Serialisasi langkah macro (CFrame/Vector3 -> tabel angka)
local function stepsToTable(steps)
    local out = {}
    for _, st in ipairs(steps) do
        out[#out + 1] = {
            t = st.t, dt = st.dt, action = st.action, idx = st.idx, path = st.path, key = st.key,
            cf = st.cf and cfToTable(st.cf) or nil,
            cam = st.cam and cfToTable(st.cam) or nil,
            pos = st.pos and { st.pos.X, st.pos.Y, st.pos.Z } or nil,
            sx = st.sx, sy = st.sy,
        }
    end
    return out
end

local function stepsFromTable(arr)
    local out = {}
    if type(arr) ~= "table" then return out end
    for _, d in ipairs(arr) do
        if type(d) == "table" and type(d.t) == "string" then
            out[#out + 1] = {
                t = d.t, dt = tonumber(d.dt) or 0, action = d.action, idx = d.idx,
                path = d.path, key = d.key,
                cf = tableToCf(d.cf), cam = tableToCf(d.cam),
                pos = (type(d.pos) == "table" and #d.pos == 3)
                    and Vector3.new(d.pos[1], d.pos[2], d.pos[3]) or nil,
                sx = d.sx, sy = d.sy,
            }
        end
    end
    return out
end


local Profiles={File="SeeLeooo_profiles.json",Selected="Default",Name="Default"}
function Profiles:Read()
    assert(type(readfile)=="function" and type(isfile)=="function","Executor perlu readfile/isfile")
    if isfile(self.File) then
        local data=HttpService:JSONDecode(readfile(self.File))
        assert(type(data)=="table" and data.Schema==3 and type(data.Profiles)=="table","File profil rusak / versi tidak dikenal; file tidak ditimpa")
        return data
    end
    local data={Schema=3,Profiles={}}
    if isfile(SETTINGS_FILE) then
        local legacy=HttpService:JSONDecode(readfile(SETTINGS_FILE))
        assert(type(legacy)=="table","Setelan lama tidak valid")
        data.Profiles.Default=legacy
    end
    return data
end
function Profiles:Names()
    local ok,data=pcall(function() return self:Read() end)
    local names={}
    if ok then for name in pairs(data.Profiles) do names[#names+1]=name end end
    table.sort(names)
    if #names==0 then names={"Default"} end
    return names
end
function Profiles:Choose(name)
    self.Selected=name self.Name=name
    if self.Input then self.Input:Set(name) end
end
function Profiles:Save(data)
    assert(type(writefile)=="function","Executor perlu writefile")
    local name=trim(self.Name)
    assert(#name>0 and #name<=64 and not name:find("[%c]"),"Nama profil harus 1-64 karakter tanpa karakter kontrol")
    local store=self:Read()
    store.Profiles[name]=data
    local encoded=HttpService:JSONEncode(store)
    if isfile(self.File) then writefile(self.File..".bak",readfile(self.File)) end
    writefile(self.File,encoded)
    assert(readfile(self.File)==encoded,"Verifikasi file profil gagal")
    self:Choose(name)
    if self.Dropdown then self.Dropdown:Reload(self:Names()) self.Dropdown:Set(name) end
    return name
end

local function saveSettings()
    if not writefile then
        notify("Setelan", "Executor tidak support writefile", 3)
        return
    end
    local wps = {}
    for _, w in ipairs(WP.List) do
        wps[#wps + 1] = { Name = w.Name, CF = cfToTable(w.CF) }
    end
    local data = {
        Schema = 3,
        Controls = SettingsUI:Export(),
        RunSelection = Automation:CaptureRunSelection(),
        ManualPause = Automation.ManualPause,
        ClickPositions = {},
        PressKey = PressKeyName,
        AF = {
            On = AF.On,
            ReelOffset = AF.ReelOffset, Retry = AF.Retry, Between = AF.Between, Turbo = AF.Turbo,
            Hotkey = AF.Hotkey, AutoEquip = AF.AutoEquip, EquipSlot = AF.EquipSlot,
            PosX = AF.Pos and AF.Pos.X or nil, PosY = AF.Pos and AF.Pos.Y or nil,
        },
        PR = { Every = PR.Every, Repeat = PR.Repeat, Speed = PR.Speed,
            MoveWait=PR.MoveWait,StepWait=PR.StepWait,GuiWait=PR.GuiWait,AfterClick=PR.AfterClick,
            Steps = stepsToTable(PR.Steps) },
        WP = wps,
        Automation = Automation and Automation:Export() or nil,
        MacroGui = PR.GuiClickPos and { PR.GuiClickPos.X, PR.GuiClickPos.Y } or nil,
    }
    for _,point in ipairs(UIClickPositions) do data.ClickPositions[#data.ClickPositions+1]={point.X,point.Y} end
    local ok, result = pcall(function() return Profiles:Save(data) end)
    notify("Profil", ok and ("Tersimpan: "..result) or ("Gagal: "..tostring(result)), 4)
end

local function loadSettings()
    if Automation.Busy or AF.Cur or PR.Recording then notify("Profil","Selesaikan aksi/fishing/rekaman sebelum memuat",4) return end
    local ok, data = pcall(function()
        local store=Profiles:Read()
        local value=store.Profiles[Profiles.Selected]
        assert(type(value)=="table","Profil belum disimpan: "..Profiles.Selected)
        return value
    end)
    if not ok then notify("Profil",tostring(data),4) return end
    -- Parse before applying anything; invalid sections cannot partially overwrite a running setup.
    for _,key in ipairs({"AF","PR","WP","Automation","Controls","RunSelection","ClickPositions"}) do
        if data[key]~=nil and type(data[key])~="table" then notify("Profil","Bagian "..key.." tidak valid",4) return end
    end

    local function num(v, d) return type(v) == "number" and v==v and math.abs(v)<1e15 and v or d end
    local function bool(v, d) if type(v) == "boolean" then return v end return d end

    if Automation.Busy then notify("Setelan", "Tunggu aksi auto selesai sebelum memuat", 3) return end
    local gui = data.MacroGui
    PR.GuiClickPos=nil
    if type(gui) == "table" and num(gui[1],nil) and num(gui[2],nil) then
        PR.GuiClickPos = Vector2.new(gui[1], gui[2])
    end
    local a = data.AF or {}
    AF.ReelOffset = num(a.ReelOffset, AF.ReelOffset)
    AF.Retry = bool(a.Retry, AF.Retry)
    AF.Between = num(a.Between, AF.Between)
    AF.Turbo = bool(a.Turbo, AF.Turbo)
    AF.Hotkey = bool(a.Hotkey, AF.Hotkey)
    AF.AutoEquip = bool(a.AutoEquip, AF.AutoEquip)
    AF.EquipSlot = num(a.EquipSlot, AF.EquipSlot)
    AF.Pos=nil
    if num(a.PosX,nil) and num(a.PosY,nil) then AF.Pos=Vector2.new(a.PosX,a.PosY) end

    local p = data.PR or {}
    PR.Every = num(p.Every, PR.Every)
    PR.Repeat = num(p.Repeat, PR.Repeat)
    PR.Speed = num(p.Speed, PR.Speed)
    for _,key in ipairs({"MoveWait","StepWait","GuiWait","AfterClick"}) do PR[key]=math.clamp(num(p[key],PR[key]),0,10) end
    local steps = stepsFromTable(p.Steps)
    PR.Steps = steps


    if type(data.WP) == "table" then
        WP.List = {}
        for _, w in ipairs(data.WP) do
            local cf = tableToCf(w.CF)
            if cf and type(w.Name) == "string" then
                WP.List[#WP.List + 1] = { Name = w.Name, CF = cf }
            end
        end
        WP.Idx = #WP.List > 0 and 1 or 0
    end

    UIClickPositions={}
    for _,point in ipairs(data.ClickPositions or {}) do
        if #UIClickPositions>=16 then break end
        if type(point)=="table" and num(point[1],nil) and num(point[2],nil) then
            UIClickPositions[#UIClickPositions+1]=Vector2.new(point[1],point[2])
        end
    end
    if type(data.PressKey)=="string" then
        pcall(function()
            local key=Enum.KeyCode[data.PressKey]
            if key and key~=Enum.KeyCode.Unknown then PressKeyCode=key PressKeyName=key.Name end
        end)
    end
    Automation.LoadingProfile=true
    local applied,err=pcall(function()
        SettingsUI:Apply(data.Controls)
        for _,key in ipairs({"MoveWait","StepWait","GuiWait","AfterClick"}) do
            PR[key]=math.clamp(num(p[key],PR[key]),0,10)
        end
        Automation:Import(data.Automation)
        local run=Automation:CleanRunSelection(data.RunSelection)
        if run then
            for key in pairs(Automation.Flags) do Automation.Flags[key]=run.Flags[key]==true end
            AutoHarvest=run.Harvest AutoClaimMeteor=run.Meteor
            AutoClickUI=run.Click and #UIClickPositions>0 AutoPressKey=run.Key
            AF.On=run.Fishing and AF.Pos~=nil antiAfkActive=run.AntiAfk
            PR.Auto=run.MacroAuto and #PR.Steps>0 and PR.GuiClickPos~=nil
            PR.Requested=run.Macro and #PR.Steps>0 and PR.GuiClickPos~=nil
            PR.Stop=not (PR.Auto or PR.Requested)
            PR.NextStep=math.clamp(run.MacroStep,1,math.max(1,#PR.Steps))
        elseif type(a.On)=="boolean" then AF.On=a.On and AF.Pos~=nil end
        Automation.ManualPause=data.ManualPause==true
        Automation.QuestRequested=false Automation.NextQuestOpen=0
        Automation.SellVisited={}
        for _,job in ipairs(Automation.Jobs) do job.nextAt=0 end
        Automation:SyncUI()
    end)
    Automation.LoadingProfile=false
    notify("Profil",applied and ("Dimuat: "..Profiles.Selected.." | toggle & nilai sudah disinkronkan")
        or ("Gagal menerapkan: "..tostring(err)),5)
end

local function setLowGfx(v)
    Opt.LowGfx = v
    if v then
        pcall(function() Opt.GfxBackup = settings().Rendering.QualityLevel end)
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function() RunService:Set3dRenderingEnabled(false) end)
        if setfpscap then pcall(setfpscap, 20) end
    else
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
        pcall(function()
            if Opt.GfxBackup then settings().Rendering.QualityLevel = Opt.GfxBackup end
        end)
        if setfpscap then pcall(setfpscap, 60) end
    end
end

-- =========================================================
-- FREECAM (character diam)
-- =========================================================
local function stopFreecam()
    if not freecamActive then return end
    freecamActive = false
    if freecamConn then
        freecamConn:Disconnect()
        freecamConn = nil
    end
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
    pcall(function()
        Camera.CameraType = Enum.CameraType.Custom
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hum then Camera.CameraSubject = hum end
            if hrp and not FreezeCharacter then
                hrp.Anchored = false
            end
        end
    end)
    freecamSavedCFrame = nil
    notify("Freecam", "STOPPED", 2)
end

local function startFreecam()
    if Automation and Automation.Busy then notify("Freecam", "Tunggu aksi auto selesai dulu", 3) return end
    if freecamActive then return end
    freecamActive = true

    local cam = workspace.CurrentCamera
    freecamCF = cam.CFrame
    local look = freecamCF.LookVector
    freecamYaw = math.atan2(-look.X, -look.Z)
    freecamPitch = math.asin(math.clamp(look.Y, -1, 1))

    local hrp = getHRP()
    if hrp then
        freecamSavedCFrame = hrp.CFrame
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    cam.CameraType = Enum.CameraType.Scriptable
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    freecamConn = RunService.RenderStepped:Connect(function(dt)
        if not freecamActive then return end

        local hrp = getHRP()
        if hrp then
            hrp.Anchored = true
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if freecamSavedCFrame then
                hrp.CFrame = freecamSavedCFrame
            end
        end

        local sens = 0.0035
        local delta = UserInputService:GetMouseDelta()
        freecamYaw = freecamYaw - delta.X * sens
        freecamPitch = math.clamp(freecamPitch - delta.Y * sens, -1.4, 1.4)

        local rot = CFrame.fromEulerAnglesYXZ(freecamPitch, freecamYaw, 0)
        local move = Vector3.zero
        if freecamKeys.W then move = move + rot.LookVector end
        if freecamKeys.S then move = move - rot.LookVector end
        if freecamKeys.A then move = move - rot.RightVector end
        if freecamKeys.D then move = move + rot.RightVector end
        if freecamKeys.E then move = move + Vector3.yAxis end
        if freecamKeys.Q then move = move - Vector3.yAxis end

        local speed = freecamSpeed * 60 * dt
        if freecamKeys.LeftShift then speed = speed * freecamFastMult end

        if move.Magnitude > 0 then
            freecamCF = CFrame.new(freecamCF.Position + move.Unit * speed) * rot
        else
            freecamCF = CFrame.new(freecamCF.Position) * rot
        end
        cam.CFrame = freecamCF
    end)

    notify("Freecam", "STARTED — character diam | F1 stop", 3)
end

local function toggleFreecam()
    if freecamActive then stopFreecam() else startFreecam() end
end

-- =========================================================
-- TABS
-- =========================================================
local FishingTab = Window:CreateTab({
    Title = "Fishing",
    Subtitle = "Auto Fishing & Proses Ikan",
    Icon = "rbxassetid://6031071053"
})

local AutoTab = Window:CreateTab({
    Title = "Auto",
    Subtitle = "Click, Claim, Harvest & Key",
    Icon = "rbxassetid://6031280882"
})

local MiscTab = Window:CreateTab({
    Title = "Misc",
    Subtitle = "Player & TP",
    Icon = "rbxassetid://6034287594"
})

local SettingsTab = Window:CreateTab({
    Title = "Settings",
    Subtitle = "Utility",
    Icon = "rbxassetid://6031280882"
})

-- =========================================================
-- SHARED AUTOMATION: satu worker, satu pemilik gerak/input.
-- Tidak memulai pekerjaan baru sampai pekerjaan lama selesai/cleanup.
-- =========================================================
FishingTab=SettingsUI:Wrap(FishingTab,"Fishing")
AutoTab=SettingsUI:Wrap(AutoTab,"Auto")
MiscTab=SettingsUI:Wrap(MiscTab,"Misc")
SettingsTab=SettingsUI:Wrap(SettingsTab,"Settings")

Automation = {
    Version = 2, Focused = true, Busy = false, Epoch = 0,
    Flags = { Seat = false, Order = false, Cook = false, Serve = false,
        Pickup = false, Wash = false, Soul = false, Quest = false },
    AllCrops = true, SelectedCrops = {}, CropNames = {}, CropLabels = {},
    QuestKinds = { Utama = true, Daily = true, Event = true },
    Jobs = {}, Cursor = 0, Cooldowns = {}, Modules = {}, ModuleRetry = {},
    Souls = {}, Status = "Siap", LastError = "", Counts = {},
    NextWorldAction = 0, UIIndex = 0, SoulPriorityUsed = false,
}
do
    local A = Automation

    function A:Eligible(key)
        return os.clock() >= (self.Cooldowns[key] or 0)
    end

    function A:Result(key, ok, message, label)
        self.Cooldowns[key] = os.clock() + (ok and 1.5 or 4)
        if ok then
            self.Counts[label] = (self.Counts[label] or 0) + 1
            self.Status = label .. ": berhasil"
        else
            self.Status = label .. ": " .. tostring(message or "belum bisa")
        end
        return ok
    end

    function A:Active(token)
        if not Running or self.Epoch ~= token then return false end
        if self.CurrentEnabled and not self.CurrentEnabled() then return false end
        return true
    end

    function A:MoveTo(cf, token)
        if not self:Active(token) then return false end
        local hrp = getHRP()
        local p = cf and cf.Position
        if not p or p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or p.Magnitude > 1e7 then return false end
        if not hrp or hrp ~= self.ActionRoot then return false end
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Sit = false end
        hrp.Anchored = false
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.18)
        return self:Active(token) and getHRP() == hrp
    end

    function A:HandsBusy()
        return player:GetAttribute("TargetStoveId") ~= nil
            or player:GetAttribute("TargetCustomerId") ~= nil
            or player:GetAttribute("HoldingDirtyDish") == true
    end

    function A:CaptureInput()
        return self:GameModalOpen() or PR.Recording or self.Selecting or self.CropGuiOpen or IsSettingUIClick or IsSettingPressKey
            or UserInputService:GetFocusedTextBox() ~= nil
    end

    function A:WithAction(job, payload)
        if self.Busy or not Running or not job.enabled() then return false end
        self.Busy = true
        self.CurrentEnabled = job.enabled
        local token = self.Epoch
        local previousPause = AF.Paused
        AF.Paused = true -- hentikan cast baru, reel sesi aktif tetap berjalan
        local started = os.clock()
        self.Status = "Menunggu sesi fishing selesai: " .. job.name
        while AF.Cur and self:Active(token) and os.clock() - started < 12 do task.wait(0.05) end
        if AF.Cur or not self:Active(token) then
            AF.Paused = previousPause
            self.CurrentEnabled = nil
            self.Busy = false
            return false
        end

        local hrp = getHRP()
        if not hrp then
            AF.Paused = previousPause
            self.CurrentEnabled = nil
            self.Busy = false
            return false
        end
        self.ActionRoot = hrp
        local home, anchored = hrp.CFrame, hrp.Anchored
        local cam = workspace.CurrentCamera
        local camCF, camType, camSubject = cam.CFrame, cam.CameraType, cam.CameraSubject
        local restoreUi = hideLibUi()
        self.Status = job.name
        self.StartedAt = os.clock()
        local ok, err = xpcall(function() job.run(payload, token) end, function(e) return tostring(e) end)

        -- Cleanup selalu dilakukan, termasuk error, stop, dan respawn.
        if getHRP() == hrp then
            pcall(function()
                hrp.CFrame = home
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.Anchored = Running and (FreezeCharacter or anchored) or false
            end)
        end
        pcall(function()
            if workspace.CurrentCamera == cam and (cam.CameraType==camType or job.id=="macro") then
                cam.CFrame = camCF
                cam.CameraType = camType
                cam.CameraSubject = camSubject
            end
        end)
        pcall(restoreUi)
        if job.id == "macro" then PR.Busy = false end
        self.ActionRoot = nil
        self.StartedAt = nil
        self.CurrentEnabled = nil
        self.Busy = false
        AF.Paused = previousPause
        -- Beri fishing kesempatan cast sebelum job berikutnya mengambil giliran.
        self.NextWorldAction = os.clock() + (AF.On and 0.9 or 0.12)
        if not ok then
            self.FailureSerial=(self.FailureSerial or 0)+1
            job.nextAt = os.clock() + 5
            self.LastError = job.name .. ": " .. err
            self.Status = self.LastError
            warn("[SeeLeooo Auto] " .. self.LastError)
        end
        return ok
    end

    function A:AddJob(id, name, enabled, probe, run, interval)
        self.Jobs[#self.Jobs + 1] = { id = id, name = name, enabled = enabled,
            probe = probe, run = run, interval = interval or 0.3, nextAt = 0 }
    end

    function A:Probe(job)
        if os.clock() < job.nextAt or not job.enabled() then return nil end
        job.nextAt = os.clock() + job.interval
        local ok, payload = pcall(job.probe)
        if not ok then
            self.LastError = job.name .. ": " .. tostring(payload)
            job.nextAt = os.clock() + 5
            return nil
        end
        return payload
    end

    function A:PickJob()
        -- Satu prioritas Soul di antara giliran normal; tidak menghabiskan antrean.
        if not self.SoulPriorityUsed then
            for _, job in ipairs(self.Jobs) do
                if job.id == "soul" then
                    local payload = self:Probe(job)
                    if payload then self.SoulPriorityUsed = true return job, payload end
                end
            end
        end
        for _ = 1, #self.Jobs do
            self.Cursor = self.Cursor % #self.Jobs + 1
            local job = self.Jobs[self.Cursor]
            local payload = self:Probe(job)
            if payload then
                self.SoulPriorityUsed = job.id == "soul"
                return job, payload
            end
        end
        return nil
    end

    function A:Export()
        local selected = {}
        for id, value in pairs(self.SelectedCrops) do if value then selected[#selected + 1] = id end end
        table.sort(selected)
        return { AllCrops = self.AllCrops, SelectedCrops = selected,
            Flags = table.clone(self.Flags), QuestKinds = table.clone(self.QuestKinds),
            Harvest = AutoHarvest, Meteor = AutoClaimMeteor,
            ClickUI = AutoClickUI, PressKey = AutoPressKey }
    end

    function A:Import(data)
        if type(data) ~= "table" then return end
        if type(data.AllCrops) == "boolean" then self.AllCrops = data.AllCrops end
        if type(data.SelectedCrops) == "table" then
            self.SelectedCrops = {}
            for _, id in ipairs(data.SelectedCrops) do
                if type(id) == "string" then self.SelectedCrops[id] = true end
            end
        end
        for _, key in ipairs({ "Flags", "QuestKinds" }) do
            if type(data[key]) == "table" then
                for flag in pairs(self[key]) do
                    if type(data[key][flag]) == "boolean" then self[key][flag] = data[key][flag] end
                end
            end
        end
        if type(data.Harvest) == "boolean" then AutoHarvest = data.Harvest end
        if type(data.Meteor) == "boolean" then AutoClaimMeteor = data.Meteor end
        if type(data.ClickUI) == "boolean" then AutoClickUI = data.ClickUI end
        if type(data.PressKey) == "boolean" then AutoPressKey = data.PressKey end
        self:SyncUI()
    end

    function A:StopAll()
        self.Epoch += 1 -- batalkan tahap berikutnya, cleanup tetap memegang lock
        for k in pairs(self.Flags) do self.Flags[k] = false end
        AutoHarvest, AutoClaimMeteor, AutoClickUI, AutoPressKey = false, false, false, false
        antiAfkActive = false
        AF.On, AF.Cur, PR.Auto, PR.Requested, PR.Stop = false, nil, false, false, true
        if AF.MacroStop then pcall(AF.MacroStop) end
        self.Selecting = false
        self.CropGuiOpen = false
        if self.CropGui then self.CropGui.Enabled = false end
        self.Status = self.Busy and "Menghentikan aksi; menunggu cleanup" or "Semua auto OFF"
        self:SyncUI()
    end

    function A:Snapshot()
        local enabled = {}
        for id, v in pairs(self.Flags) do if v then enabled[#enabled + 1] = id end end
        if AutoHarvest then enabled[#enabled + 1] = "Harvest" end
        if AutoClaimMeteor then enabled[#enabled + 1] = "Meteor" end
        if AutoClickUI then enabled[#enabled + 1] = "Click UI" end
        if AutoPressKey then enabled[#enabled + 1] = "Press Key" end
        if AF.On then enabled[#enabled + 1] = "Fishing" end
        if PR.Auto or PR.Requested then enabled[#enabled + 1] = "Macro" end
        table.sort(enabled)
        local seconds=0
        for _,job in ipairs(self.Jobs) do if job.id=="quest" then seconds=math.max(0,math.ceil(job.nextAt-os.clock())) end end
        return self.Status .. "\nAktif: " .. (#enabled > 0 and table.concat(enabled, ", ") or "-")
            .. "\nQuest: setiap "..self.QuestInterval.." dtk | cek berikutnya "..seconds.." dtk"
    end

    function A:SyncUI()
        self.SyncingUI = true
        for _, control in ipairs(self.Controls or {}) do
            SettingsUI:Bind(control.object,control.get)
        end
        SettingsUI:Sync()
        self.SyncingUI = false
        if self.CropGuiOpen then self:RenderCropList() end
    end

    function A:Toggle(title, description, get, set)
        local object = AutoTab:CreateToggle({ Title = title, Description = description,
            Default = get(), Callback = function(v) if not self.SyncingUI then set(v) end end })
        self.Controls = self.Controls or {}
        self.Controls[#self.Controls + 1] = { object = object, get = get }
        SettingsUI:Bind(object,get)
    end

    -- Pemilih native: daftar bisa berubah tanpa bergantung API refresh ProxyLib.
    function A:RenderCropList()
        if not self.CropList then return end
        for _, child in ipairs(self.CropList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local query = (self.CropSearch.Text or ""):lower()
        local row = 0
        for _, label in ipairs(self.CropNames) do
            if query == "" or label:lower():find(query, 1, true) then
                local id = self.CropLabels[label]
                local button = Instance.new("TextButton")
                button.Size = UDim2.new(1, -12, 0, 32)
                button.Position = UDim2.fromOffset(4, row * 36)
                button.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
                button.TextColor3 = Color3.fromRGB(255, 240, 100)
                button.TextXAlignment = Enum.TextXAlignment.Left
                button.Font = Enum.Font.Gotham
                button.TextSize = 13
                button.Text = (self.SelectedCrops[id] and "  [x] " or "  [ ] ") .. label
                button.Parent = self.CropList
                button.Activated:Connect(function()
                    self.SelectedCrops[id] = not self.SelectedCrops[id] or nil
                    self.AllCrops = false
                    self:SyncUI()
                end)
                row += 1
            end
        end
        self.CropList.CanvasSize = UDim2.fromOffset(0, row * 36)
        self.CropCaption.Text = self.AllCrops and "Mode: Semua (termasuk jenis baru)" or "Mode: Pilihan manual"
    end

    function A:OpenCropPicker()
        if self.Busy or PR.Recording then notify("Tanaman", "Tunggu aksi/rekaman selesai dulu", 3) return end
        if not self.CropGui then
            local gui = Instance.new("ScreenGui")
            gui.Name = "SeeLeooo_CropPicker"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 200
            gui.Parent = CoreGui
            self.CropGui = gui
            local panel = Instance.new("Frame")
            panel.Size = UDim2.new(0.9, 0, 0.8, 0)
            panel.AnchorPoint = Vector2.new(0.5, 0.5)
            panel.Position = UDim2.fromScale(0.5, 0.5)
            panel.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
            panel.Parent = gui
            local limit = Instance.new("UISizeConstraint", panel)
            limit.MaxSize = Vector2.new(380, 450)
            local function button(title, x, width, callback)
                local b = Instance.new("TextButton")
                b.Position = UDim2.new(x, 8, 0, 76)
                b.Size = UDim2.new(width, -12, 0, 28)
                b.BackgroundColor3 = Color3.fromRGB(55, 55, 35)
                b.TextColor3 = Color3.fromRGB(255, 240, 100)
                b.Text, b.TextSize = title, 13
                b.Parent = panel
                b.Activated:Connect(callback)
            end
            local title = Instance.new("TextLabel")
            title.Position = UDim2.fromOffset(8, 4)
            title.Size = UDim2.new(1, -16, 0, 30)
            title.BackgroundTransparency = 1
            title.Text = "SeeLeooo | Pilih Tanaman"
            title.TextColor3 = Color3.fromRGB(255, 240, 100)
            title.Font, title.TextSize = Enum.Font.GothamBold, 16
            title.Parent = panel
            local search = Instance.new("TextBox")
            search.Position = UDim2.fromOffset(8, 38)
            search.Size = UDim2.new(1, -16, 0, 30)
            search.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
            search.TextColor3 = Color3.new(1, 1, 1)
            search.PlaceholderText, search.Text = "Cari tanaman...", ""
            search.TextSize = 14
            search.ClearTextOnFocus = false
            search.Parent = panel
            self.CropSearch = search
            track(search:GetPropertyChangedSignal("Text"):Connect(function() self:RenderCropList() end))
            button("Semua", 0, 0.33, function() self.AllCrops = true self:SyncUI() end)
            button("Kosongkan", 0.33, 0.34, function()
                self.AllCrops = false self.SelectedCrops = {} self:SyncUI()
            end)
            button("Selesai", 0.67, 0.33, function() self.CropGuiOpen = false gui.Enabled = false end)
            local caption = Instance.new("TextLabel")
            caption.Position = UDim2.fromOffset(8, 108)
            caption.Size = UDim2.new(1, -16, 0, 22)
            caption.BackgroundTransparency = 1
            caption.TextColor3 = Color3.new(1, 1, 1)
            caption.TextSize = 12
            caption.Parent = panel
            self.CropCaption = caption
            local list = Instance.new("ScrollingFrame")
            list.Position = UDim2.fromOffset(8, 134)
            list.Size = UDim2.new(1, -16, 1, -142)
            list.BackgroundTransparency = 1
            list.ScrollBarThickness = 5
            list.Parent = panel
            self.CropList = list
        end
        self.CropGuiOpen = true
        self.CropGui.Enabled = true
        self.RefreshRequested = true
        self:RenderCropList()
    end

    function A:BuildUI()
        AutoTab:CreateSection({ Text = "Kontrol Auto" })
        AutoTab:CreateButton({ Title = "Diagnosa Auto (Salin Log)",
            Description = "Jumlah prompt aktif, status worker, dan error terakhir",
            Callback = function() self:Diagnostics() end })
        AutoTab:CreateButton({ Title = "Lihat Status Auto",
            Description = "Antrean aksi, fitur aktif, dan hasil terakhir",
            Callback = function() notify("Auto Status", self:Snapshot(), 8) end })
        AutoTab:CreateButton({Title="PLAY Auto Pilihan Terakhir",
            Description="Lanjutkan auto yang aktif sebelum Stop; tidak menyalakan semuanya",
            Callback=function() self:PlaySelected() end})
        AutoTab:CreateButton({ Title = "STOP Semua Auto",
            Description = "Hentikan semua; pilihan disimpan untuk tombol PLAY",
            Callback = function() self:StopAll() notify("Auto", self.Status, 4) end })

        AutoTab:CreateSection({ Text = "Restoran" })
        for _, entry in ipairs({
            { "Seat", "Auto Assign Seat", "Gunakan prompt Assign Seat yang tersedia" },
            { "Order", "Auto Take Order", "Ambil pesanan pelanggan yang siap" },
            { "Cook", "Auto Cook", "Ambil tiket, lalu masak di kompor target" },
            { "Serve", "Auto Serve", "Ambil makanan siap, lalu antar ke pelanggan target" },
            { "Pickup", "Auto Pickup Dirty Plates", "Ambil piring kotor dari kursi" },
            { "Wash", "Auto Wash", "Masukkan piring ke dishwasher target" },
        }) do
            local key = entry[1]
            self:Toggle(entry[2], entry[3], function() return self.Flags[key] end,
                function(v) self.Flags[key] = v end)
        end

        AutoTab:CreateSection({ Text = "Harvest" })
        self:Toggle("Auto Harvest", "Panen tanaman matang sesuai pilihan; restoran sendiri",
            function() return AutoHarvest end, function(v) AutoHarvest = v end)
        self:Toggle("Semua Tanaman", "Termasuk jenis baru yang terdeteksi setelah update game",
            function() return self.AllCrops end, function(v) self.AllCrops = v end)
        self:RefreshCrops()
        AutoTab:CreateButton({ Title = "Pilih Tanaman (Multi)",
            Description = "Cari, centang beberapa, atau pilih Semua; daftar otomatis diperbarui",
            Callback = function() self:OpenCropPicker() end })
        AutoTab:CreateButton({ Title = "Refresh Daftar Tanaman",
            Callback = function() self.RefreshRequested = true end })
        -- Cadangan jika versi ProxyLib tidak punya API refresh dropdown.
        -- Nama tetap ditemukan otomatis oleh game, tidak dibatasi daftar statis.
        safeCreateInput(AutoTab, { Title = "Pilih Tanaman via Nama (Cadangan)",
            Placeholder = "Tomato, Wheat, Candy Corn (pisahkan koma)", Default = "",
            Callback = function(value)
                local selected, unknown = {}, {}
                for query in tostring(value):gmatch("[^,]+") do
                    query = trim(query):lower():gsub(" crop$", "")
                    local matched = false
                    for label, id in pairs(self.CropLabels) do
                        if label:lower():gsub(" crop$", "") == query or id:lower():gsub(" crop$", "") == query then
                            selected[id] = true matched = true
                        end
                    end
                    if not matched then unknown[#unknown + 1] = query end
                end
                if #unknown > 0 then notify("Tanaman", "Tidak ditemukan: " .. table.concat(unknown, ", "), 5) return end
                self.SelectedCrops = selected
                notify("Tanaman", "Pilihan disimpan. Matikan Semua Tanaman untuk memakai filter.", 4)
            end })
        AutoTab:CreateButton({ Title = "Lihat Pilihan Tanaman",
            Callback = function()
                local names = {}
                for id in pairs(self.SelectedCrops) do names[#names + 1] = id end
                table.sort(names)
                notify("Tanaman", self.AllCrops and "Mode: Semua Tanaman" or
                    (#names > 0 and table.concat(names, ", ") or "Belum memilih tanaman"), 8)
            end })

        AutoTab:CreateSection({ Text = "Lost Soul" })
        self:Toggle("Auto Save Lost Soul", "Deteksi prompt Save Lost Soul; prioritas lalu kembali",
            function() return self.Flags.Soul end, function(v) self.Flags.Soul = v end)
        AutoTab:CreateSection({ Text = "Quest" })
        self:Toggle("Auto Claim Quest", "Klaim lewat menu Quest / Daily / Global tanpa require",
            function() return self.Flags.Quest end, function(v) self.Flags.Quest = v end)
        for _, kind in ipairs({ "Utama", "Daily", "Event" }) do
            self:Toggle("Quest: " .. kind, "Sertakan kategori ini saat Auto Claim Quest ON",
                function() return self.QuestKinds[kind] end, function(v) self.QuestKinds[kind] = v end)
        end
    end

    -- v2.1: native prompt/UI backend. Tidak require modul internal game.
    A.Version = "2.1-native"
    A.Prompts = setmetatable({}, { __mode = "k" })
    A.Scene = { Crops = {}, Seats = {} }
    A.NextPromptId = 0
    A.SceneVersion = 0
    A.ScanReady = false
    A.NativeCounts = {}

    function A:RememberPrompt(prompt)
        if not prompt:IsA("ProximityPrompt") or self.Prompts[prompt] then return end
        self.NextPromptId += 1
        self.Prompts[prompt] = { id = self.NextPromptId }
    end

    function A:NativeAction(prompt)
        local action = trim(prompt.ActionText):lower()
        local names = {
            ["assign seat"] = "Seat", ["take order"] = "Order",
            ["cook"] = "Cook", ["serve"] = "Serve", ["pick up"] = "Pickup",
            ["wash"] = "Wash", ["harvest"] = "harvest", ["save"] = "soul",
            ["panen"] = "harvest", ["masak"] = "Cook", ["cuci"] = "Wash",
            ["sajikan"] = "Serve", ["ambil pesanan"] = "Order",
        }
        local kind = names[action]
        if kind == "soul" and not (prompt.ObjectText or ""):lower():find("lost soul", 1, true) then return nil end
        return kind
    end

    function A:RefreshCrops()
        local names, labels, seen = {}, {}, {}
        local function add(name)
            if type(name) ~= "string" or name == "" or seen[name] then return end
            seen[name] = true names[#names + 1] = name labels[name] = name
        end
        local directory = ReplicatedStorage:FindFirstChild("__DIRECTORY")
        local entity = directory and directory:FindFirstChild("Entity")
        local crops = entity and entity:FindFirstChild("Crop")
        if crops then
            for _, child in ipairs(crops:GetChildren()) do
                if child:IsA("ModuleScript") then add(child.Name:match("@ (.+)$") or child.Name) end
            end
        end
        local things = Workspace:FindFirstChild("__THINGS")
        local restaurants = things and things:FindFirstChild("Restaurants")
        local scene = { Crops = {}, Seats = {} }
        if restaurants then
            for _, rest in ipairs(restaurants:GetChildren()) do
                local entities = rest:FindFirstChild("Entities")
                if entities then
                    for i, model in ipairs(entities:GetChildren()) do
                        if model:IsA("Model") or model:IsA("BasePart") then
                            local name = model.Name:match("^(.-)_[%x%-]+$") or model.Name
                            local low = name:lower()
                            if low:find("crop", 1, true) then
                                add(name)
                                scene.Crops[#scene.Crops + 1] = { name = name, model = model, pos = model:GetPivot().Position }
                            elseif low:find("chair", 1, true) or low:find("stool", 1, true) or low:find("seat", 1, true) then
                                scene.Seats[#scene.Seats + 1] = { name = name, model = model, pos = model:GetPivot().Position }
                            end
                        end
                        if i % 500 == 0 then task.wait() end
                    end
                end
            end
        end
        table.sort(names)
        self.Scene, self.CropNames, self.CropLabels = scene, names, labels
        self.SceneVersion += 1
        if self.CropGuiOpen then self:RenderCropList() end
        return #names
    end

    function A:NearestScene(prompt, list)
        local pos = promptPos(prompt)
        if not pos then return nil end
        local closest, distance = nil, 7
        for _, entry in ipairs(list) do
            if entry.model.Parent then
                local d = (entry.pos - pos).Magnitude
                if d < distance then closest, distance = entry, d end
            end
        end
        return closest
    end

    function A:NativeCrop(prompt)
        local record = self.Prompts[prompt]
        if record and record.cropVersion == self.SceneVersion then return record.cropName end
        local name = self.CropLabels[prompt.ObjectText]
        if not name then
            local model = prompt:FindFirstAncestorOfClass("Model")
            local base = model and (model.Name:match("^(.-)_[%x%-]+$") or model.Name)
            if base and self.CropLabels[base] then name = base end
        end
        if not name then
            local nearest = self:NearestScene(prompt, self.Scene.Crops)
            name = nearest and nearest.name
        end
        if record then record.cropVersion, record.cropName = self.SceneVersion, name end
        return name
    end

    function A:CropSelected(prompt)
        if self.AllCrops then return true end
        local name = self:NativeCrop(prompt)
        return name ~= nil and self.SelectedCrops[name] == true
    end

    function A:FindNative(kind)
        local candidates = {}
        for prompt, record in pairs(self.Prompts) do
            if prompt.Parent and prompt.Enabled and self:NativeAction(prompt) == kind then
                local accepted = true
                if kind == "harvest" then accepted = self:CropSelected(prompt) end
                -- Pick Up juga dipakai item event. Piring berasal dari kursi,
                -- dengan ObjectText kosong dalam script Customer Plates.
                if kind == "Pickup" then
                    accepted = prompt.ObjectText == "" and self:NearestScene(prompt, self.Scene.Seats) ~= nil
                end
                if accepted and self:Eligible("prompt:" .. record.id) then
                    candidates[#candidates + 1] = { prompt = prompt, record = record, key = "prompt:" .. record.id }
                end
            end
        end
        -- Giliran per-target, bukan selalu target pertama dari pairs().
        table.sort(candidates, function(x, y)
            local a, b = x.record.lastUsed or 0, y.record.lastUsed or 0
            if a == b then return x.record.id < y.record.id end
            return a < b
        end)
        return candidates[1]
    end

    function A:TargetStamp()
        local out = {}
        for _, key in ipairs({ "TargetStoveId", "TargetCustomerId", "TargetCustomerRecipeId", "TargetDishwasherId", "HoldingDirtyDish" }) do
            out[#out + 1] = tostring(player:GetAttribute(key))
        end
        return table.concat(out, "|")
    end

    function A:TriggerNative(payload, token, label)
        local prompt = payload.prompt
        if not prompt.Parent or not prompt.Enabled then return end
        local pos = promptPos(prompt)
        if not pos then return end
        local radius = prompt.MaxActivationDistance
        if radius <= 0 then return end
        local offset = math.min(2, radius * 0.25)
        if not self:MoveTo(CFrame.new(pos + Vector3.new(0, math.min(1.5, offset), offset)), token) then return end
        if not self:Active(token) or not prompt.Parent or not prompt.Enabled then return end
        local before = self:TargetStamp()
        local duration = math.max(prompt.HoldDuration, 0)
        local sent, err = false, nil
        if type(fireproximityprompt) == "function" then
            -- Satu cara per percobaan agar aksi tidak terpanggil berulang.
            local start = os.clock()
            while self:Active(token) and os.clock() - start < duration do task.wait(0.05) end
            if not self:Active(token) then return end
            sent, err = pcall(fireproximityprompt, prompt)
        else
            sent, err = pcall(function()
                prompt:InputHoldBegin()
                local start = os.clock()
                while self:Active(token) and os.clock() - start < duration + 0.08 do task.wait(0.05) end
                prompt:InputHoldEnd()
            end)
            pcall(function() prompt:InputHoldEnd() end)
        end
        payload.record.lastUsed = os.clock()
        if not sent then self:Result(payload.key, false, tostring(err), label) return end
        task.wait(0.35)
        local confirmed = not prompt.Parent or not prompt.Enabled or before ~= self:TargetStamp()
        if confirmed then self:Result(payload.key, true, nil, label)
        else
            self.Cooldowns[payload.key] = os.clock() + 2
            self.Status = label .. ": input terkirim; menunggu perubahan game"
        end
    end

    function A:QuestKind(gui, button)
        local name = gui.Name:lower()
        if name == "dailyquests" then return "Daily" end
        if name == "globalquests" or name == "tacoquests" then return "Event" end
        if name ~= "quests" then return nil end
        local row = button.Parent
        while row and row.Parent and row.Parent.Name ~= "Quests" do row = row.Parent end
        if row and row.Name:match("^%(") then return "Utama" end
        return "Event"
    end

    function A:FindQuestButton()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return nil end
        for _, gui in ipairs(pg:GetChildren()) do
            local name = gui.Name:lower()
            if gui:IsA("ScreenGui") and gui.Enabled and
                (name == "quests" or name == "dailyquests" or name == "globalquests" or name == "tacoquests") then
                for _, button in ipairs(gui:GetDescendants()) do
                    if button:IsA("GuiButton") and (button.Name == "Claim" or button.Name == "ClaimAll" or button.Name == "ClaimPlacement")
                        and button.Active and button.AbsoluteSize.X > 0 and isShown(button) then
                        local kind = self:QuestKind(gui, button)
                        local key = "questui:" .. button:GetFullName()
                        if kind and self.QuestKinds[kind] and self:Eligible(key) then
                            return { button = button, kind = kind, key = key }
                        end
                    end
                end
            end
        end
    end

    function A:QuestOpener()
        if os.clock() < (self.NextQuestOpen or 0) then return nil end
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return nil end
        self.QuestPage = (self.QuestPage or 0) % 3 + 1
        local wanted = ({ "Quests", "DailyQuests", "GlobalQuests" })[self.QuestPage]
        if wanted == "DailyQuests" then
            if not self.QuestKinds.Daily then return nil end
            for prompt, record in pairs(self.Prompts) do
                if prompt.Parent and prompt.Enabled and prompt.ActionText:lower() == "daily quest" then
                    return { open = true, guiName = wanted, prompt = prompt, record = record, key = "quest:open:daily" }
                end
            end
        else
            if wanted == "GlobalQuests" and not self.QuestKinds.Event then return nil end
            if wanted == "Quests" and not self.QuestKinds.Utama and not self.QuestKinds.Event then return nil end
            local main = pg:FindFirstChild("MainRight")
            local right = main and main:FindFirstChild("Right")
            local quests = right and right:FindFirstChild("Quests")
            local button = quests and quests:FindFirstChild(wanted == "Quests" and "Rewards" or "GlobalQuests")
            if button and button:IsA("GuiObject") and isShown(button) and button.AbsoluteSize.X > 0 then
                return { open = true, guiName = wanted, opener = button }
            end
            if wanted == "Quests" then
                for _, b in ipairs(pg:GetDescendants()) do
                    if b:IsA("GuiButton") and b.Name == "Quests" and b.Parent.Name == "ButtonsList" and isShown(b) then
                        return { open = true, guiName = wanted, opener = b }
                    end
                end
            end
        end
    end

    function A:ClickNativeGui(button)
        local ancestor = button.Parent
        while ancestor do
            if ancestor:IsA("ScrollingFrame") then
                local delta = button.AbsolutePosition.Y - ancestor.AbsolutePosition.Y - ancestor.AbsoluteSize.Y * 0.4
                local maximum = math.max(0, ancestor.AbsoluteCanvasSize.Y - ancestor.AbsoluteSize.Y)
                ancestor.CanvasPosition = Vector2.new(ancestor.CanvasPosition.X, math.clamp(ancestor.CanvasPosition.Y + delta, 0, maximum))
            end
            ancestor = ancestor.Parent
        end
        task.wait(0.05)
        local x, y = guiCenter(button, false)
        return ClickAt(x, y)
    end

    function A:CloseNativeQuest(name)
        local pg = player:FindFirstChild("PlayerGui")
        local gui = pg and pg:FindFirstChild(name)
        if not gui then return end
        for _, button in ipairs(gui:GetDescendants()) do
            if button:IsA("GuiButton") and button.Name == "Close" and isShown(button) then
                self:ClickNativeGui(button) return
            end
        end
    end

    function A:Diagnostics()
        local counts, lines = {}, { "Backend: native prompts/UI (tanpa require)", self:Snapshot(),
            "Scan: " .. tostring(self.ScanReady), "Tanaman dikenal: " .. #self.CropNames }
        for prompt in pairs(self.Prompts) do
            if prompt.Parent and prompt.Enabled then
                local kind = self:NativeAction(prompt) or prompt.ActionText
                counts[kind] = (counts[kind] or 0) + 1
            end
        end
        for k, n in pairs(counts) do lines[#lines + 1] = tostring(k) .. ": " .. n .. " prompt aktif" end
        if self.LastError ~= "" then lines[#lines + 1] = "Error: " .. self.LastError end
        local message = table.concat(lines, "\n")
        print("[SeeLeooo Diagnosa]\n" .. message)
        if setclipboard then pcall(setclipboard, message) end
        notify("Diagnosa Auto", message, 10)
    end

    function A:RegisterJobs()
        self.Jobs = {}
        for _, spec in ipairs({ {"Seat", "Assign Seat"}, {"Order", "Take Order"},
            {"Cook", "Cook"}, {"Serve", "Serve"}, {"Pickup", "Pickup Dirty Plates"}, {"Wash", "Wash"},
            {"harvest", "Harvest"}, {"soul", "Save Lost Soul"} }) do
            local kind, title = spec[1], spec[2]
            local function enabled() return kind == "harvest" and AutoHarvest or
                (kind == "soul" and self.Flags.Soul or self.Flags[kind]) end
            self:AddJob(kind, title, enabled, function()
                if (kind == "Pickup" or kind == "Seat" or kind == "Order") and self:HandsBusy() then return nil end
                return self:FindNative(kind)
            end, function(p, token) self:TriggerNative(p, token, title) end)
        end
        self:AddJob("quest", "Claim Quest", function() return self.Flags.Quest end,
            function() if self.Focused then return self:FindQuestButton() or self:QuestOpener() end end,
            function(p, token)
                if not self.Focused or not self:Active(token) then return end
                if p.open then
                    self.NextQuestOpen = os.clock() + 10
                    if p.prompt then self:TriggerNative(p, token, "Buka Daily Quest")
                    elseif p.opener and p.opener.Parent then self:ClickNativeGui(p.opener) end
                    task.wait(0.3)
                end
                local claim = p.button and p or self:FindQuestButton()
                if self:Active(token) and claim and claim.button.Parent and isShown(claim.button) then
                    self:ClickNativeGui(claim.button)
                    self.Cooldowns[claim.key] = os.clock() + 3
                    self.Status = "Quest " .. claim.kind .. ": klik klaim terkirim"
                    task.wait(0.2)
                end
                if p.open then self:CloseNativeQuest(p.guiName) end
            end, 1)
        self:AddJob("meteor", "Claim Meteor", function() return AutoClaimMeteor end,
            function()
                for prompt, record in pairs(self.Prompts) do
                    if prompt.Parent and prompt.Enabled and self:Eligible("prompt:" .. record.id) then
                        local model = prompt:FindFirstAncestorOfClass("Model")
                        if model and (model.Name == "CarnivalCrateLarge" or model.Name == "CarnivalCrateSmall") then
                            return { prompt = prompt, record = record, key = "prompt:" .. record.id }
                        end
                    end
                end
            end, function(p, token) self:TriggerNative(p, token, "Meteor") end, 1)
        self:AddJob("macro", "Macro Proses Ikan", function()
            return (PR.Requested or PR.Auto) and not PR.Stop and not PR.Recording
        end, function() if self.Focused and #PR.Steps > 0 and PR.GuiClickPos then return true end end,
            function(_, token)
                PR.Busy = true
                if AF.MacroRunOnce and self:Active(token) then AF.MacroRunOnce(token) end
                PR.Busy = false
            end, 0.5)
        self:AddJob("click", "Auto Click UI", function() return AutoClickUI end, function()
            if self.Focused and not self:HandsBusy() and #UIClickPositions > 0 then
                self.UIIndex = self.UIIndex % #UIClickPositions + 1 return UIClickPositions[self.UIIndex]
            end
        end, function(p, token) if self:Active(token) then ClickAt(p.X, p.Y) end end, UIClickDelay)
        self:AddJob("key", "Auto Press Key", function() return AutoPressKey end,
            function() if self.Focused and not self:HandsBusy() then return PressKeyCode end end,
            function(key, token)
                if not self:Active(token) then return end
                local ok, err = pcall(function()
                    VirtualInputManager:SendKeyEvent(true, key, false, game) task.wait(0.02)
                end)
                pcall(function() VirtualInputManager:SendKeyEvent(false, key, false, game) end)
                if not ok then error(err) end
            end, PressKeyDelay)
        self:AddJob("afk", "Anti AFK", function() return antiAfkActive end,
            function() return self.AfkRequested end, function()
                self.AfkRequested = false VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new())
            end, 1)
    end

    function A:Start()
        self:RegisterJobs()
        task.spawn(function()
            while Running do
                pcall(function() self:UpdateDashboard() self:SyncUI() end)
                task.wait(0.5)
            end
        end)
        track(UserInputService.WindowFocused:Connect(function() self.Focused = true end))
        track(UserInputService.WindowFocusReleased:Connect(function() self.Focused = false end))
        track(player.CharacterAdded:Connect(function() self.Epoch += 1 self.RefreshRequested = true end))
        track(Workspace.DescendantAdded:Connect(function(value) self:RememberPrompt(value) end))
        track(Workspace.DescendantRemoving:Connect(function(value) if self.Prompts[value] then self:ForgetPrompt(value) end end))
        task.spawn(function()
            self.Status = "Memindai prompt game..."
            local stack, processed = { Workspace }, 0
            while #stack > 0 and Running and not self.ShuttingDown do
                local value = table.remove(stack)
                self:RememberPrompt(value)
                for _, child in ipairs(value:GetChildren()) do stack[#stack+1]=child end
                processed+=1
                if processed%1000==0 then task.wait() end
            end
            if not Running or self.ShuttingDown then return end
            self.ScanReady = true
            self.Status = "Siap; " .. self.NextPromptId .. " prompt terdeteksi"
        end)
        task.spawn(function()
            local lastRefresh, lastFishOn, lastMaintenance, lastSnapshot = os.clock(), false, os.clock(), -1
            while Running do
                local ok, err = pcall(function()
                    if not self.ScanReady then return end
                    self.HeartbeatAt = os.clock()
                    if os.clock() - lastSnapshot >= 1 then
                        lastSnapshot = os.clock()
                        local fridge = self:GameGui("Fridge")
                        if fridge then self:ReadFridgeSnapshot(fridge) end
                    end
                    if os.clock() - lastMaintenance >= 30 then self:Housekeep() lastMaintenance=os.clock() end
                    if self.ManualPause then self.Status="Dijeda manual; toggle tetap tersimpan" return end
                    if os.clock() < self.RetryUntil then self.Status="Jeda error; lanjut otomatis setelah 30 detik" return end
                    local root=getHRP()
                    if root and root.Anchored and not FreezeCharacter then self.Status="Menunggu karakter yang dikunci game" return end
                    local currentCamera=workspace.CurrentCamera
                    if currentCamera and currentCamera.CameraType == Enum.CameraType.Scriptable and not freecamActive then
                        self.Status="Menunggu kamera/cutscene game" return
                    end
                    if AF.On and not lastFishOn then self.NextWorldAction = os.clock() + 0.9 end
                    lastFishOn = AF.On
                    if self.RefreshRequested or os.clock() - lastRefresh >= 30 then
                        self.RefreshRequested = false lastRefresh = os.clock() self:RefreshCrops()
                    end
                    if self.Busy then return end
                    if freecamActive then self.Status = "Dijeda: freecam aktif" return end
                    if self:CaptureInput() then self.Status = "Dijeda: modal game / rekaman / pengisian input" return end
                    if os.clock() < self.NextWorldAction then return end
                    for _, entry in ipairs(self.Jobs) do
                        if entry.id == "click" then entry.interval = UIClickDelay end
                        if entry.id == "key" then entry.interval = PressKeyDelay end
                        if entry.id == "sell" then entry.interval = self.SellInterval end
                        if entry.id == "inventory" and self.InventoryRequested then entry.nextAt=0 end
                    end
                    local job, payload = self:PickJob()
                    if job then self:WithAction(job, payload)
                    else self.Status = "Menunggu prompt sesuai toggle / tombol klaim quest terbuka" end
                end)
                if not ok then
                    self.LastError = tostring(err) self.Status = "Auto ERROR: " .. tostring(err)
                    warn("[SeeLeooo Auto] " .. tostring(err))
                    task.wait(2)
                end
                task.wait(0.15)
            end
        end)
    end

    A.SaleIcons = {
        ["Apple"] = "rbxassetid://123474902236664",
        ["Banana"] = "rbxassetid://93752866398322",
        ["Beef"] = "rbxassetid://133491467970661",
        ["Candy Corn"] = "rbxassetid://95011843407729",
        ["Carrot"] = "rbxassetid://116717280409745",
        ["Cheese"] = "rbxassetid://92174002667682",
        ["Chicken"] = "rbxassetid://98331169063449",
        ["Coconut"] = "rbxassetid://110314195977794",
        ["Cod"] = "rbxassetid://92904773670349",
        ["Coffee Beans"] = "rbxassetid://129309780800015",
        ["Corn"] = "rbxassetid://121343365009258",
        ["Egg"] = "rbxassetid://116968662530681",
        ["Flour"] = "rbxassetid://83381221231538",
        ["Glow Mushroom"] = "rbxassetid://76439132865458",
        ["Honey"] = "rbxassetid://101184555340228",
        ["Jack-o'-Lantern Pumpkin"] = "rbxassetid://94978913626767",
        ["Lamb Chops"] = "rbxassetid://90043769198494",
        ["Lemon"] = "rbxassetid://102123972476947",
        ["Lettuce"] = "rbxassetid://79523706961700",
        ["Lobster"] = "rbxassetid://100267461734028",
        ["Milk"] = "rbxassetid://85432417915348",
        ["Mushroom"] = "rbxassetid://120290605152247",
        ["Onion"] = "rbxassetid://100626749539831",
        ["Pineapple"] = "rbxassetid://92613216839144",
        ["Pork"] = "rbxassetid://112346985266010",
        ["Potato"] = "rbxassetid://123386294434710",
        ["Pumpkin"] = "rbxassetid://87232328353341",
        ["Salmon"] = "rbxassetid://101445170229287",
        ["Shrimp"] = "rbxassetid://80567687921469",
        ["Sugar"] = "rbxassetid://119547221753876",
        ["Sugar Cane"] = "rbxassetid://84917836525898",
        ["Swordfish"] = "rbxassetid://113375695902832",
        ["Tea Leaves"] = "rbxassetid://91476591146603",
        ["Tomato"] = "rbxassetid://70470124242848",
        ["Truffles"] = "rbxassetid://100746313085765",
        ["Tuna"] = "rbxassetid://107431982513400",
        ["Watermelon"] = "rbxassetid://115521701506837",
        ["Wheat"] = "rbxassetid://93921031055906",
    }


    -- v2.2: sell only configured excess, through the normal fridge UI.
    A.Version = "2.2-fridge"
    A.Flags.Sell = false
    A.SellRules = {}
    A.SellRevision = 0
    A.SellCursor = 0
    A.SellInterval = 15
    A.SellVisited = {}

    function A:SaleAmount(stock, keep)
        if type(stock) ~= "number" or type(keep) ~= "number" or stock < 0 or keep < 0 or stock > 1e15 or keep > 1e12
            or stock ~= math.floor(stock) or keep ~= math.floor(keep) then return nil end
        return math.max(0, stock - keep)
    end

    function A:ParseSaleQuestion(title)
        local name, digits = title:match("^How many (.-) do you want to sell%? %(You have ([%d,]+)%)$")
        if not name then return nil end
        return name, tonumber((digits:gsub(",", "")))
    end

    function A:ValidateSaleMessage(message, name, amount)
        local digits, item = message:match("^Sell ([%d,]+)x (.-) for .+%?$")
        return item == name and tonumber(((digits or ""):gsub(",", ""))) == amount
    end

    function A:Path(root, path)
        for name in path:gmatch("[^/]+") do root = root and root:FindFirstChild(name) end
        return root
    end

    function A:GameGui(name)
        local pg = player:FindFirstChild("PlayerGui")
        local gui = pg and pg:FindFirstChild(name)
        return gui and gui:IsA("ScreenGui") and gui.Enabled and gui or nil
    end

    function A:GameModalOpen()
        return self:GameGui("TextInput") ~= nil or self:GameGui("Message") ~= nil or self:GameGui("Fridge") ~= nil
    end

    function A:ScriptAt(x, y)
        local roots = { CoreGui, player:FindFirstChild("PlayerGui") }
        for _, root in ipairs(roots) do
            if root then
                for _, gui in ipairs(root:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled and
                        (gui.Name:find("Proxy", 1, true) or gui.Name:find("SeeLeooo", 1, true)) then
                        local inset = gui.IgnoreGuiInset and Vector2.zero or GuiService:GetGuiInset()
                        for _, obj in ipairs(gui:GetDescendants()) do
                            if obj:IsA("GuiObject") and isShown(obj) and
                                (obj:IsA("GuiButton") or obj:IsA("TextBox") or obj.BackgroundTransparency < 0.95) then
                                local p, s = obj.AbsolutePosition + inset, obj.AbsoluteSize
                                if x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then return true end
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    function A:WaitSale(predicate, token, revision, timeout)
        local untilAt = os.clock() + (timeout or 3)
        repeat
            if not self:Active(token) or revision ~= self.SellRevision then return nil end
            local result = predicate()
            if result then return result end
            task.wait(0.08)
        until os.clock() >= untilAt
        return nil
    end

    function A:CancelSaleDialogs()
        -- Only called after this job opened a sale dialog; never approves a modal.
        local gui = self:GameGui("TextInput")
        local cancel = gui and self:Path(gui, "Message/Content/Cancel")
        local title = gui and self:Path(gui, "Message/Content/Title")
        if cancel and title and title.Text:match("^How many .- do you want to sell%?") then self:ClickNativeGui(cancel) task.wait(0.12) end
        gui = self:GameGui("Message")
        local no = gui and self:Path(gui, "Message/Content/No")
        local message = gui and self:Path(gui, "Message/Content/Message")
        local custom = gui and self:Path(gui, "Message/Content/CustomMessage")
        local text = message and message.Visible and message.Text or (custom and custom.Text or "")
        if no and text:match("^Sell ") then self:ClickNativeGui(no) task.wait(0.12) end
    end

    function A:SaleRows(gui)
        local items = self:Path(gui, "Fridge/Frame/Content/Items")
        local rows = {}
        if items then
            for _, row in ipairs(items:GetChildren()) do
                if row:IsA("GuiButton") and row:FindFirstChild("Content") then rows[#rows + 1] = row end
            end
        end
        table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        return rows
    end

    function A:SaleRowName(row)
        local icon = self:Path(row, "Content/Icon")
        if not icon then return nil end
        local asset=icon.Image:match("%d+")
        for name,image in pairs(self.SaleIcons) do
            if icon.Image==image or asset and asset==image:match("%d+") then return name end
        end
    end

    function A:PickSaleRow(rows)
        for _, row in ipairs(rows) do
            local name = self:SaleRowName(row)
            if name and self.SellRules[name] ~= nil and os.clock() >= (self.SellVisited[name] or 0) then
                return row
            end
        end
        -- Unidentified rows are never clicked or used to discover a sale target.
        return nil
    end

    function A:RunSaleGui(payload, token)
        local revision = self.SellRevision
        local opened, ownsModal = false, false
        local ok, err = xpcall(function()
            self.LastError=""
            local gui = self:OpenFridge(payload,token)
            opened = gui~=nil
            if not gui then error(self.UILastFailure) end
            local rows = self:WaitSale(function()
                local current=self:SaleRows(gui)
                return #current>0 and current or nil
            end,token,revision,5)
            if not rows then self.Status="Fridge: belum ada item siap / kosong" return end
            self:ResolveFridge(gui)
            self:ReadFridgeSnapshot(gui)
            local row = self:PickSaleRow(rows)
            if not row then self.Status = "Fridge: stok pilihan belum ada / menunggu pemeriksaan berikutnya" return end
                        local pickedName = self:SaleRowName(row)
            -- Use the original GUI sale flow: select ONE item, then enter the excess.
            local entry=self.FridgeRows and self.FridgeRows[row]
            local bridge=self.FridgeBridge
            local price=self:Path(row,"Content/Price")
            if bridge and entry and self:SelectFridgeEntry(bridge,entry) then
                self:WaitUI(function() return price and price.Visible end,token,1)
            end
            for _,other in ipairs(rows) do
                local mark=self:Path(other,"Content/Price")
                if other~=row and mark and mark.Visible then
                    if not self:PressUI(other,function() return not mark.Visible end,token) then
                        error("Gagal melepas item lain: "..self.UILastFailure)
                    end
                end
            end
            if not self:Active(token) or revision~=self.SellRevision then return end
            if not (price and price.Visible) then
                if not self:PressUI(row,function() return price and price.Visible end,token) then
                    error("Gagal memilih item target: "..self.UILastFailure)
                end
            end
            if not self:WaitSale(function() return price and price.Visible end,token,revision) then
                error("Pemilihan item belum terkonfirmasi")
            end
            local selected = 0
            for _, other in ipairs(self:SaleRows(gui)) do
                local p = self:Path(other, "Content/Price")
                if p and p.Visible then selected += 1 end
            end
            if selected ~= 1 then error("Batal: pilihan fridge bukan tepat satu barang") end
            local selection = self:Path(gui, "Fridge/Frame/Content/Bottom/Buttons/SellSelection")
            ownsModal = true
            if not selection or not self:PressUI(selection,function() return self:GameGui("TextInput")~=nil end,token) then
                error("Sell Selection: "..self.UILastFailure)
            end
            local form = self:WaitSale(function() return self:GameGui("TextInput") end, token, revision)
            if not form then error("Dialog jumlah jual tidak muncul") end
            local title = self:Path(form, "Message/Content/Title")
            local name, stock = self:ParseSaleQuestion(title and title.Text or "")
            if not name or not stock then error("Batal: nama/jumlah stok pada dialog tidak terbaca pasti") end
                        -- cocokkan nama di dialog dengan aturan jual (bukan dari baris GUI yang bisa berubah)
            local intended
            for ruleName in pairs(self.SellRules) do
                if trim(ruleName):lower()==trim(name):lower() then intended=ruleName break end
            end
            if not intended then
                self.Status="Fridge: "..name.." tidak ada di aturan jual"
                return
            end
            -- pengaman: kalau nama target awal masih diketahui, harus sama dengan dialog
            if pickedName and trim(pickedName):lower()~=trim(name):lower() then
                error("Batal: dialog "..name.." tidak sesuai target "..tostring(pickedName))
            end
            self.SellVisited[intended] = os.clock() + self.SellInterval
            if self.PendingNames[intended] then self.Status=name..": menunggu konfirmasi penjualan sebelumnya" return end
            local keep = self.SellRules[intended]
            if keep == nil then self.Status = "Fridge: " .. name .. " tidak dipilih untuk dijual" return end
            local quantity = self:SaleAmount(stock, keep)
            if not quantity or quantity == 0 then self.Status = name .. ": stok " .. stock .. ", batas simpan " .. keep return end
            local box = self:Path(form, "Message/Content/Holder/UserInput")
            local submit = self:Path(form, "Message/Content/Submit")
            if not box or not submit then error("Kolom jumlah / Submit tidak ditemukan") end
            if not self:Active(token) or revision~=self.SellRevision then return end
            if not self:SubmitSaleAmount(form,box,submit,quantity,token) then error("Jumlah jual: "..self.UILastFailure) end
            local messageGui = self:WaitSale(function() return self:GameGui("Message") end, token, revision)
            if not messageGui then error("Konfirmasi jual tidak muncul") end
            local message = self:Path(messageGui, "Message/Content/Message")
            local custom = self:Path(messageGui, "Message/Content/CustomMessage")
            local text = message and message.Visible and message.Text or (custom and custom.Text or "")
            if not self:ValidateSaleMessage(text, name, quantity) then error("Batal: konfirmasi tidak sesuai barang/jumlah yang dihitung") end
            if self.SellRules[intended] ~= keep or not self:Active(token) or revision ~= self.SellRevision then return end
            local yes = self:Path(messageGui, "Message/Content/Yes")
            if not yes or not self:PressUI(yes,function() return not self:GameGui("Message") end,token) then error("Konfirmasi Sell: "..self.UILastFailure) end
            self:RecordSale(intended, quantity, stock, keep, text)
            local dismissed = self:WaitSale(function() return not self:GameGui("Message") end, token, revision)
            if dismissed then
                ownsModal = false
                self.Status = "Jual " .. quantity .. " " .. name .. "; batas simpan " .. keep .. " (menunggu stok game)"
            end
        end, function(e) return tostring(e) end)
        if ownsModal then self:CancelSaleDialogs() end
        if opened and not self:GameGui("TextInput") and not self:GameGui("Message") then
            local untilAt = os.clock() + 0.6
            while not self:GameGui("Fridge") and os.clock() < untilAt do task.wait(0.05) end
            local refreshed = self:GameGui("Fridge")
            if refreshed then task.wait(0.3) self:ReadFridgeSnapshot(refreshed) end
            self:CloseNativeQuest("Fridge")
        end
        if not ok then self.LastError = tostring(err) self.Status = "Auto Sell: " .. tostring(err) end
    end

    function A:BuildSellUI()
        AutoTab:CreateSection({ Text = "Fridge: Jual Kelebihan" })
        self:Toggle("Auto Sell Kelebihan", "Hanya barang beraturan; jumlah jual = stok - batas simpan",
            function() return self.Flags.Sell end, function(v) self.Flags.Sell = v end)
        local names, directory = {}, ReplicatedStorage:FindFirstChild("__DIRECTORY")
        local currencies = directory and directory:FindFirstChild("Currency")
        if currencies then
            for _, module in ipairs(currencies:GetChildren()) do
                local name = module.Name:match("@ (.+)$")
                if name and self.SaleIcons[name] then names[#names + 1] = name end
            end
        end
        if #names == 0 then for name in pairs(self.SaleIcons) do names[#names + 1] = name end end
        table.sort(names)
        self.SellChoice = names[1]
        AutoTab:CreateDropdown({ Title = "Barang untuk Aturan Jual", Options = names, Multiple = false,
            Callback = function(v) self.SellChoice = type(v) == "table" and v[1] or v end })
        safeCreateInput(AutoTab, { Title = "Batas Simpan Barang", Default = "200", Placeholder = "Bilangan bulat; contoh 200",
            Callback = function(v) self.SellKeepInput = tostring(v) end })
        self.SellKeepInput = "200"
        AutoTab:CreateButton({ Title = "Simpan Aturan Barang",
            Description = "Tambahkan beberapa barang satu per satu; barang lain tidak dijual",
            Callback = function()
                local keep = tonumber(self.SellKeepInput)
                if not self.SellChoice or not keep or keep < 0 or keep > 1e12 or keep ~= math.floor(keep) then
                    notify("Aturan Jual", "Pilih barang dan isi batas bulat 0 sampai 1000000000000", 4) return
                end
                self.SellRules[self.SellChoice] = keep self.SellRevision += 1
                notify("Aturan Jual", self.SellChoice .. ": simpan " .. keep .. ", jual kelebihannya", 4)
            end })
        AutoTab:CreateButton({ Title = "Hapus Aturan Barang Terpilih", Callback = function()
            if self.SellChoice then self.SellRules[self.SellChoice] = nil self.SellRevision += 1 end
        end })
        AutoTab:CreateButton({ Title = "Lihat Semua Aturan Jual", Callback = function()
            local rows = {}
            for name, keep in pairs(self.SellRules) do rows[#rows + 1] = name .. ": simpan " .. keep end
            table.sort(rows) notify("Aturan Jual", #rows > 0 and table.concat(rows, "\n") or "Belum ada aturan; tidak ada barang yang dijual", 10)
        end })
        AutoTab:CreateSlider({ Title = "Jeda Cek Fridge (detik)", Min = 5, Max = 120, Default = 15,
            Callback = function(v) self.SellInterval = v end })
    end

    local baseExport, baseImport, baseBuildUI, baseRegisterJobs = A.Export, A.Import, A.BuildUI, A.RegisterJobs
    function A:Export()
        local data = baseExport(self)
        data.SellRules = table.clone(self.SellRules) data.SellInterval = self.SellInterval
        return data
    end
    function A:Import(data)
        if type(data) == "table" and type(data.SellRules) == "table" then
            local rules = {}
            for name, keep in pairs(data.SellRules) do
                if type(name) == "string" and type(keep) == "number" and keep >= 0 and keep <= 1e12 and keep == math.floor(keep) then rules[name] = keep end
            end
            self.SellRules = rules self.SellRevision += 1
        end
        if type(data) == "table" and type(data.SellInterval) == "number" then self.SellInterval = math.clamp(data.SellInterval, 5, 120) end
        baseImport(self, data)
    end
    function A:BuildUI() baseBuildUI(self) self:BuildSellUI() end
    function A:RegisterJobs()
        baseRegisterJobs(self)
        self:AddJob("sell", "Fridge: Jual Kelebihan", function() return self.Flags.Sell end,
            function()
                if not self.Focused or not next(self.SellRules) or self:HandsBusy() or self:GameModalOpen() then return nil end
                return self:FridgePrompt()
            end, function(p, token) self:RunSale(p, token) end, self.SellInterval)
    end

    A.Version = "2.3-restaurant"
    A.Flags.Honey, A.Flags.FishFarm, A.Flags.Tips, A.Flags.Register = false, false, false, false
    A.PriorityHarvest, A.StockMonitor, A.DashboardVisible = true, true, true
    A.LowStockTarget, A.StockMaxAge, A.MonitorInterval = 100, 120, 45
    A.Stocks, A.SaleHistory, A.PendingSales = {}, {}, {}
    A.HistoryLimit, A.HistorySerial = 100, 0
    A.PendingNames = {}
    A.PromptBuckets = {}
    A.RetryUntil, A.ConsecutiveErrors, A.ManualPause = 0, 0, false
    A.PriorityCache, A.PriorityCacheAt = {}, -100

    function A:ModelKind(name)
        name = name:lower():gsub("[^%a%d]", "")
        if name:find("beehive",1,true) then return "Honey" end
        if name:find("fishfarm",1,true) then return "FishFarm" end
        if name:find("tipjar",1,true) then return "Tips" end
        if name:find("cashregister",1,true) or name == "corruptedregister" then return "Register" end
    end

    local oldNativeAction = A.NativeAction
    function A:NativeAction(prompt)
        local action = trim(prompt.ActionText):lower()
        if action == "collect" or action == "claim" then
            local model = prompt:FindFirstAncestorOfClass("Model")
            if model then
                local base = model.Name:match("^(.-)_[%x%-]+$") or model.Name
                local kind = self:ModelKind(base)
                if action == "collect" and (kind == "Honey" or kind == "FishFarm") then return kind end
                if action == "claim" and (kind == "Tips" or kind == "Register") then return kind end
            end
            return nil -- Claim/Collect di lokasi lain tidak disentuh.
        end
        return oldNativeAction(self, prompt)
    end

    function A:RefreshPromptBucket(prompt, record)
        if record.kind and self.PromptBuckets[record.kind] then self.PromptBuckets[record.kind][prompt] = nil end
        record.kind = nil
        if prompt.Parent and prompt.Enabled then
            local kind = self:NativeAction(prompt)
            if kind then
                self.PromptBuckets[kind] = self.PromptBuckets[kind] or setmetatable({}, { __mode = "k" })
                self.PromptBuckets[kind][prompt] = record record.kind = kind
            end
        end
    end

    function A:RememberPrompt(prompt)
        if not prompt:IsA("ProximityPrompt") or self.Prompts[prompt] or self.ShuttingDown then return end
        self.NextPromptId += 1
        local record = { id = self.NextPromptId }
        self.Prompts[prompt] = record
        self:RefreshPromptBucket(prompt, record)
        if prompt.Changed then
            record.connection = prompt.Changed:Connect(function(property)
                if property == "Enabled" or property == "ActionText" or property == "ObjectText" then
                    self:RefreshPromptBucket(prompt, record)
                end
            end)
        end
    end

    function A:ForgetPrompt(prompt)
        local record = self.Prompts[prompt]
        if not record then return end
        if record.connection then record.connection:Disconnect() end
        if record.kind and self.PromptBuckets[record.kind] then self.PromptBuckets[record.kind][prompt] = nil end
        self.Cooldowns["prompt:" .. record.id] = nil
        self.Prompts[prompt] = nil
    end

    function A:ParseStock(text)
        text = trim(tostring(text)):gsub("^x", ""):gsub(",", ""):gsub("%s+", "")
        if text:match("^%d+$") then return tonumber(text), true end
        local digits, unit = text:match("^(%d+%.?%d*)([KkMmBbTt])$")
        if not digits then return nil end
        local multipliers = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
        return tonumber(digits) * multipliers[unit:lower()], false
    end

    function A:RecordStock(name, value, exact)
        if type(name) ~= "string" or type(value) ~= "number" or value < 0 or value > 1e15 then return end
        local previous = self.Stocks[name]
        -- Approximate badges must not overwrite a recently read exact dialog.
        if previous and previous.exact and not exact and os.clock() - previous.at < 5 then return end
        self.Stocks[name] = { value = value, exact = exact == true, at = os.clock() }
        if exact then
            for i = #self.PendingSales, 1, -1 do
                local sale = self.PendingSales[i]
                if sale.name == name and os.clock() - sale.at > 0.15 and value <= sale.before - sale.quantity then
                    sale.status = "stok turun teramati" sale.after = value
                    if self.PendingNames[name] == sale then self.PendingNames[name] = nil end
                    table.remove(self.PendingSales, i)
                end
            end
        end
    end

    function A:StorageFresh()
        return self.Storage and os.clock() - self.Storage.at <= self.StockMaxAge
    end

    function A:StorageFull()
        return self:StorageFresh() and self.Storage.capacity > 0 and self.Storage.used >= self.Storage.capacity
    end

    function A:ReadFridgeSnapshot(gui)
        local storage = self:Path(gui, "Fridge/Frame/Content/Bottom/Storage/Title")
        if storage then
            local used, capacity = storage.Text:match("Storage:%s*([%d,]+)%s*/%s*([%d,]+)")
            used = used and tonumber((used:gsub(",", "")))
            capacity = capacity and tonumber((capacity:gsub(",", "")))
            if used and capacity then self.Storage = { used = used, capacity = capacity, at = os.clock() } end
        end
        local rows = self:SaleRows(gui)
        for _, row in ipairs(rows) do
            local name = self:SaleRowName(row)
            local amount = self:Path(row, "Content/Quantity/Title") or self:Path(row, "Content/Quantity/Amount")
            if name and amount then
                local value, exact = self:ParseStock(amount.Text)
                if value then self:RecordStock(name, value, exact) end
            end
        end
        -- A missing tile is not assumed to be zero: it may be loading.
        self.LastInventoryAt = os.clock()
    end

    local oldParseSaleQuestion = A.ParseSaleQuestion
    function A:ParseSaleQuestion(title)
        local name, amount = oldParseSaleQuestion(self, title)
        if name and amount then self:RecordStock(name, amount, true) end
        return name, amount
    end

    function A:RecordSale(name, quantity, before, keep, quote)
        self.HistorySerial += 1
        local entry = { id = self.HistorySerial, name = name, quantity = quantity,
            before = before, keep = keep, quote = quote, at = os.clock(), status = "dikirim; belum terkonfirmasi" }
        self.SaleHistory[#self.SaleHistory + 1] = entry
        self.PendingSales[#self.PendingSales + 1] = entry
        self.PendingNames[name] = entry
        while #self.SaleHistory > self.HistoryLimit do table.remove(self.SaleHistory, 1) end
        while #self.PendingSales > self.HistoryLimit do table.remove(self.PendingSales, 1) end
        return entry
    end

    local oldPickSaleRow = A.PickSaleRow
    function A:PickSaleRow(rows)
        local eligible = {}
        for _, row in ipairs(rows) do
            local name = self:SaleRowName(row)
            if not name or not self.PendingNames[name] then eligible[#eligible + 1] = row end
        end
        return oldPickSaleRow(self, eligible)
    end

    function A:HarvestPriority(prompt)
        if not self.PriorityHarvest then return 2 end
        local crop = self:NativeCrop(prompt)
        if not crop then return 2 end
        local ingredient = crop:gsub(" Crop$", "")
        if ingredient == "Tea" then ingredient = "Tea Leaves" end
        if ingredient == "Mega Pumpkin" then ingredient = "Pumpkin" end
        local stock = self.Stocks[ingredient]
        if not stock or os.clock() - stock.at > self.StockMaxAge then return 2 end
        local target = self.SellRules[ingredient] or self.LowStockTarget
        if target <= 0 then return 2 end
        return math.min(2, stock.value / target)
    end

    function A:FindNative(kind)
        local candidate, bestPriority, bestUsed, bestId
        local oldest, oldestTime
        for prompt, record in pairs(self.PromptBuckets[kind] or {}) do
            if prompt.Parent and prompt.Enabled and self:Eligible("prompt:" .. record.id) then
                local accepted = true
                if kind == "harvest" then accepted = self:CropSelected(prompt) and not self:StorageFull() end
                if kind == "Pickup" then accepted = prompt.ObjectText == "" and self:NearestScene(prompt, self.Scene.Seats) ~= nil end
                if accepted then
                    local payload = { prompt = prompt, record = record, key = "prompt:" .. record.id }
                    local used = record.lastUsed or 0
                    if not oldestTime or used < oldestTime then oldest, oldestTime = payload, used end
                    local priority = kind == "harvest" and self:HarvestPriority(prompt) or 2
                    if not candidate or priority < bestPriority or
                        (priority == bestPriority and (used < bestUsed or used == bestUsed and record.id < bestId)) then
                        candidate, bestPriority, bestUsed, bestId = payload, priority, used, record.id
                    end
                end
            end
        end
        -- Every sixth harvest turn serves the oldest eligible target, so low-stock
        -- prioritization cannot permanently starve another selected ingredient.
        if kind == "harvest" and candidate then
            self.HarvestTurns = (self.HarvestTurns or 0) + 1
            if self.HarvestTurns % 6 == 0 then return oldest end
        end
        return candidate
    end

    function A:Housekeep()
        for prompt in pairs(self.Prompts) do if not prompt.Parent then self:ForgetPrompt(prompt) end end
        for key, untilAt in pairs(self.Cooldowns) do if untilAt < os.clock() - 300 then self.Cooldowns[key] = nil end end
        for i = #self.PendingSales, 1, -1 do
            if os.clock() - self.PendingSales[i].at > 180 then
                self.PendingSales[i].status = "tidak terkonfirmasi" table.remove(self.PendingSales, i)
            end
        end
        if self.DashboardGui and not self.DashboardGui.Parent then self.DashboardGui = nil end
    end

    function A:MonitorNeeded()
        return self.StockMonitor and (AutoHarvest or self.Flags.Sell or self.Flags.Honey or self.Flags.FishFarm)
    end

    function A:FridgePrompt()
        local best,distance
        local hrp=getHRP()
        for prompt,record in pairs(self.Prompts) do
            if prompt.Parent and prompt.ActionText:lower()=="open fridge" then
                local pos=promptPos(prompt)
                local d=pos and hrp and (pos-hrp.Position).Magnitude
                if d and (not distance or d<distance) then
                    best,distance={prompt=prompt,record=record,key="fridge:open"},d
                end
            end
        end
        return best
    end

    function A:MonitorInventory(payload, token)
        if not self:OpenFridge(payload,token) then return end
        local untilAt = os.clock() + 3
        local gui
        repeat
            gui = self:GameGui("Fridge")
            if gui or not self:Active(token) then break end
            task.wait(0.08)
        until os.clock() >= untilAt
        if gui then
            task.wait(0.2)
            self:ReadFridgeSnapshot(gui)
            self:CloseNativeQuest("Fridge")
        else self.Status = "Storage: fridge belum bisa dibuka" end
    end

    function A:DashboardText()
        local storage = "Storage: belum dibaca"
        if self.Storage then
            local age = math.max(0, math.floor(os.clock() - self.Storage.at))
            local percent = self.Storage.capacity > 0 and math.floor(100 * self.Storage.used / self.Storage.capacity) or 0
            storage = string.format("Storage: %d/%d (%d%%) | %ds lalu%s", self.Storage.used, self.Storage.capacity,
                percent, age, age > self.StockMaxAge and " [lama]" or "")
        end
        local sales = "Penjualan: " .. #self.SaleHistory .. " riwayat"
        local last = self.SaleHistory[#self.SaleHistory]
        if last then sales = last.name .. " x" .. last.quantity .. " | " .. last.status end
        local sum = 0 for _, keep in pairs(self.SellRules) do sum += keep end
        if self.Storage and sum >= self.Storage.capacity then storage ..= "\nBatas simpan total >= kapasitas; kurangi aturan" end
        return "SeeLeooo v2.4\n" .. storage .. "\n" .. sales .. "\n" .. self.Status
    end

    function A:UpdateDashboard()
        if not self.DashboardVisible then if self.DashboardGui then self.DashboardGui.Enabled = false end return end
        if not self.DashboardGui then
            local gui = Instance.new("ScreenGui")
            gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "SeeLeooo_AutoDashboard", false, 90
            gui.Parent = CoreGui
            local label = Instance.new("TextLabel")
            label.Size, label.Position = UDim2.fromOffset(360, 125), UDim2.new(0, 12, 1, -155)
            label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            label.BackgroundTransparency = 0.2
            label.TextColor3, label.TextSize = Color3.fromRGB(255, 240, 100), 12
            label.Font = Enum.Font.Code
            label.TextWrapped = true
            label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
            label.Parent = gui
            self.DashboardGui, self.DashboardLabel = gui, label
        end
        self.DashboardGui.Enabled = true
        self.DashboardLabel.Text = self:DashboardText()
    end

    local oldActive, oldPickJob, oldWithAction, oldBuildUI = A.Active, A.PickJob, A.WithAction, A.BuildUI
    function A:Active(token) return not self.ShuttingDown and not self.ManualPause and oldActive(self, token) end
    function A:PickJob()
        if self.ManualPause or os.clock() < self.RetryUntil then return nil end
        return oldPickJob(self)
    end
    function A:WithAction(job, payload)
        local pause, root = AF.Paused, getHRP()
        local home, anchored = root and root.CFrame, root and root.Anchored
        local previousFailure = self.FailureSerial or 0
        local executed, ok = pcall(oldWithAction, self, job, payload)
        if not executed then
            self.LastError = job.name .. ": " .. tostring(ok)
            self.FailureSerial=(self.FailureSerial or 0)+1
            if root and getHRP() == root then pcall(function() root.CFrame=home root.Anchored=anchored end) end
            AF.Paused=pause PR.Busy=false
            self.Busy=false self.CurrentEnabled=nil self.ActionRoot=nil self.StartedAt=nil
            job.nextAt=os.clock()+5
            ok=false
        end
        if not ok and (self.FailureSerial or 0)>previousFailure then
            self.ConsecutiveErrors += 1
            if self.ConsecutiveErrors >= 3 then
                self.RetryUntil = os.clock() + 30 self.ConsecutiveErrors = 0
                self.Status = "Jeda 30 detik: error berulang; lihat Diagnosa"
            end
        elseif ok then self.ConsecutiveErrors = 0 end
        return ok
    end

    function A:BuildUI()
        oldBuildUI(self)
        AutoTab:CreateSection({ Text = "Produksi & Uang" })
        for _, entry in ipairs({ {"Honey","Auto Collect Honey"}, {"FishFarm","Auto Collect Fish Farm"},
            {"Tips","Auto Claim Tip Jar"}, {"Register","Auto Claim Cash Register"} }) do
            local key = entry[1]
            self:Toggle(entry[2], "Prompt milik restoran sendiri; ikut antrean bersama",
                function() return self.Flags[key] end, function(v) self.Flags[key] = v end)
        end
        AutoTab:CreateSection({ Text = "Prioritas & Pemantauan" })
        self:Toggle("Prioritas Panen Stok Rendah", "Gunakan stok terbaru; tetap beri giliran bahan lain",
            function() return self.PriorityHarvest end, function(v) self.PriorityHarvest = v end)
        self:Toggle("Pantau Storage Otomatis", "Periksa fridge berkala ketika harvest/collect/sell aktif",
            function() return self.StockMonitor end, function(v) self.StockMonitor = v end)
        self:Toggle("Indikator Storage & Auto", "Tampilkan data stok beserta umur pembacaannya",
            function() return self.DashboardVisible end, function(v) self.DashboardVisible = v end)
        AutoTab:CreateSlider({Title="Target Stok Rendah",Min=10,Max=1000,Default=100,
            Callback=function(v) self.LowStockTarget=v end})
        self:Toggle("Jeda Semua Auto (Tetap Simpan Toggle)", "Hentikan tahap berikutnya; matikan lagi untuk lanjut",
            function() return self.ManualPause end, function(v) self.ManualPause = v end)
        AutoTab:CreateButton({Title="Aktifkan Paket Restoran",Description="Restoran, panen, koleksi, quest, monitor; jual hanya bila ada aturan",
            Callback=function()
                for _,k in ipairs({"Seat","Order","Cook","Serve","Pickup","Wash","Honey","FishFarm","Tips","Register","Quest"}) do self.Flags[k]=true end
                AutoHarvest=true self.PriorityHarvest=true self.StockMonitor=true self.ManualPause=false
                self.Flags.Sell=next(self.SellRules)~=nil
                self:SyncUI() notify("Auto", "Paket restoran aktif. Fishing/macro tetap sesuai pilihan sendiri.",5)
            end})
        AutoTab:CreateButton({Title="Lihat / Salin Riwayat Penjualan",Callback=function()
            local lines={"Riwayat sesi (dikirim bukan bukti transaksi berhasil):"}
            for _,s in ipairs(self.SaleHistory) do
                lines[#lines+1]=string.format("#%d %s x%d | simpan %d | %s",s.id,s.name,s.quantity,s.keep,s.status)
            end
            local text=table.concat(lines,"\n") print(text)
            if setclipboard then pcall(setclipboard,text) end
            notify("Riwayat", #self.SaleHistory.." catatan; disalin bila clipboard tersedia",5)
        end})
        AutoTab:CreateButton({Title="Periksa Storage Sekarang",Callback=function() self.InventoryRequested=true end})
        AutoTab:CreateButton({Title="Reset Penjualan Belum Terkonfirmasi",Description="Periksa riwayat dan stok sebelum mencoba ulang",
            Callback=function()
                for _,s in pairs(self.PendingNames) do s.status="dilepas manual untuk pemeriksaan ulang" end
                self.PendingNames={} self.PendingSales={} self.SellVisited={}
                notify("Penjualan","Blokir transaksi tidak terkonfirmasi direset",4)
            end})
    end

    local oldRegisterJobs, oldExport, oldImport = A.RegisterJobs, A.Export, A.Import
    function A:RegisterJobs()
        oldRegisterJobs(self)
        for _,spec in ipairs({{"Honey","Collect Honey"},{"FishFarm","Collect Fish Farm"},{"Tips","Claim Tip Jar"},{"Register","Claim Cash Register"}}) do
            local kind,label=spec[1],spec[2]
            self:AddJob(kind,label,function() return self.Flags[kind] end,function()
                if (kind=="Honey" or kind=="FishFarm") and self:StorageFull() then return nil end
                return self:FindNative(kind)
            end,function(p,token) self:TriggerNative(p,token,label) end,1)
        end
        self:AddJob("inventory","Periksa Storage",function() return self.InventoryRequested or self:MonitorNeeded() end,
            function()
                if self:GameModalOpen() or not self.Focused then return nil end
                return self:FridgePrompt()
            end,function(p,token) self:MonitorInventory(p,token) self.InventoryRequested=false end,self.MonitorInterval)
    end
    function A:Export()
        local d=oldExport(self)
        d.PriorityHarvest,d.StockMonitor,d.DashboardVisible=self.PriorityHarvest,self.StockMonitor,self.DashboardVisible
        d.LowStockTarget=self.LowStockTarget
        return d
    end
    function A:Import(d)
        if type(d)=="table" then
            for _,key in ipairs({"PriorityHarvest","StockMonitor","DashboardVisible"}) do if type(d[key])=="boolean" then self[key]=d[key] end end
            if type(d.LowStockTarget)=="number" then self.LowStockTarget=math.clamp(d.LowStockTarget,10,1000) end
        end
        oldImport(self,d)
    end

    function A:Shutdown()
        self.ShuttingDown=true self:StopAll()
        for prompt in pairs(self.Prompts) do self:ForgetPrompt(prompt) end
        if self.DashboardGui then self.DashboardGui:Destroy() self.DashboardGui=nil end
    end

    local stopV23=A.StopAll
    function A:StopAll()
        self.ManualPause=false self.InventoryRequested=false
        stopV23(self)
    end

    -- UI v3: verify the expected state transition before advancing.
    A.UILastMethod, A.UILastFailure, A.UIAttempt = "belum dipakai", "", 0

    function A:WaitUI(changed, token, seconds)
        local deadline=os.clock()+(seconds or 0.8)
        repeat
            local ok,result=pcall(changed)
            if ok and result then return true end
            if token~=nil and not self:Active(token) then return false end
            task.wait(0.05)
        until os.clock()>=deadline
        return false
    end

    function A:PrepareUI(button)
        if not button or not button.Parent or not button:IsA("GuiButton") then return false end
        local ancestor=button.Parent
        while ancestor do
            if ancestor:IsA("ScrollingFrame") then
                local delta=button.AbsolutePosition-ancestor.AbsolutePosition
                    -(ancestor.AbsoluteWindowSize-button.AbsoluteSize)*0.5
                ancestor.CanvasPosition=Vector2.new(
                    math.clamp(ancestor.CanvasPosition.X+delta.X,0,math.max(0,ancestor.AbsoluteCanvasSize.X-ancestor.AbsoluteWindowSize.X)),
                    math.clamp(ancestor.CanvasPosition.Y+delta.Y,0,math.max(0,ancestor.AbsoluteCanvasSize.Y-ancestor.AbsoluteWindowSize.Y)))
            end
            ancestor=ancestor.Parent
        end
        task.wait(0.12)
        return button.Parent~=nil and isShown(button) and button.AbsoluteSize.X>0 and button.AbsoluteSize.Y>0
    end

    -- Move only while calibrating. Never click an unverified inset candidate.
    function A:HoverPoint(button,token)
        if not self.Focused then return nil end
        local hovered=false
        local enter=button.MouseEnter:Connect(function() hovered=true end)
        local leave=button.MouseLeave:Connect(function() hovered=false end)
        local result
        local ok,err=pcall(function()
            VirtualInputManager:SendMouseMoveEvent(1,1,game)
            task.wait(0.04)
            local lo=button.AbsolutePosition
            local hi=lo+button.AbsoluteSize
            local parent=button.Parent
            while parent do
                if parent:IsA("GuiObject") and parent.ClipsDescendants then
                    local p,z=parent.AbsolutePosition,parent.AbsoluteSize
                    lo=Vector2.new(math.max(lo.X,p.X),math.max(lo.Y,p.Y))
                    hi=Vector2.new(math.min(hi.X,p.X+z.X),math.min(hi.Y,p.Y+z.Y))
                end
                parent=parent.Parent
            end
            if hi.X-lo.X<2 or hi.Y-lo.Y<2 then return end
            local mid=(lo+hi)*0.5
            local inset=GuiService:GetGuiInset()
            local sg=button:FindFirstAncestorOfClass("ScreenGui")
            local first=sg and not sg.IgnoreGuiInset and inset or Vector2.zero
            for _,offset in ipairs({first,Vector2.zero,inset,-inset}) do
                if token~=nil and not self:Active(token) then return end
                if not button.Parent or not isShown(button) then return end
                local point=mid+offset
                VirtualInputManager:SendMouseMoveEvent(point.X,point.Y,game)
                task.wait(0.08)
                if hovered then
                    result={point.X,point.Y,position=button.AbsolutePosition,size=button.AbsoluteSize}
                    return
                end
            end
        end)
        enter:Disconnect() leave:Disconnect()
        if not ok then self.UILastFailure=tostring(err) end
        return result
    end

    function A:PressUI(button,changed,token)
        local function done()
            if not changed then return false end
            local ok,value=pcall(changed)
            return ok and value==true
        end
        local function active()
            return Running and (token==nil or self:Active(token))
        end
        if done() then return true end
        if not active() or not self:PrepareUI(button) then self.UILastFailure="Tombol belum siap" return false end
        local function verify(method,sent)
            if not sent then return false end
            if not changed or self:WaitUI(changed,token,2) then
                self.UILastMethod=method self.UILastFailure="" return true
            end
            return false
        end
        -- Dispatch Activated ONCE; all game/FX listeners receive the same activation.
        -- Run outside the worker because SellSelection waits for the quantity dialog.
        if type(firesignal)=="function" then
            local sent=false
            task.spawn(function()
                local ok,err=pcall(firesignal,button.Activated)
                sent=ok
                if not ok then self.UILastFailure=tostring(err) end
            end)
            if self:WaitUI(done,token,2) then self.UILastMethod="Activated"; self.UILastFailure="" return true end
            if not changed and sent then return true end
        end
        if done() then return true end
        if not active() then return false end
        if type(getconnections)=="function" then
            local ok,list=pcall(getconnections,button.Activated)
            local dispatched=false
            if ok and type(list)=="table" then
                for _,connection in ipairs(list) do
                    if not active() or done() then break end
                    local fn,fire,enabled
                    pcall(function() fn=connection.Function fire=connection.Fire enabled=connection.Enabled end)
                    if enabled~=false and (type(fn)=="function" or type(fire)=="function") then
                        dispatched=true
                        task.spawn(function()
                            local called,err=pcall(function()
                                if type(fire)=="function" then fire(connection) else fn() end
                            end)
                            if not called then self.UILastFailure=tostring(err) end
                        end)
                    end
                end
            end
            if verify("Activated listeners",dispatched) then return true end
        end
        if done() then return true end
        if not active() or not self.Focused or not self:PrepareUI(button) then return false end
        if not button.Active then self.UILastFailure="Tombol sedang tidak aktif: "..button.Name return false end
        local point=self:HoverPoint(button,token)
        if done() then return true end
        if not active() then return false end
        if point and button.AbsolutePosition==point.position and button.AbsoluteSize==point.size then
            if verify("MouseEnter terverifikasi",ClickAt(point[1],point[2])) then return true end
        end
        if done() then return true end
        self.UILastFailure="Tidak ada perubahan UI: "..button.Name.." (cek fokus/overlay)"
        self.Status=self.UILastFailure
        return false
    end

    function A:OpenFridge(payload,token)
        if self:GameGui("Fridge") then return self:GameGui("Fridge") end
        local prompt=payload and payload.prompt
        if not prompt or not prompt.Parent then self.UILastFailure="Prompt kulkas hilang" return nil end
        local pos=promptPos(prompt)
        if not pos then return nil end
        local radius=prompt.MaxActivationDistance
        if radius<=0 then return nil end
        local offset=math.min(2,radius*0.35)
        if not self:MoveTo(CFrame.lookAt(pos+Vector3.new(0,0.5,offset),pos),token) then return nil end
        local function ready() return self:GameGui("Fridge")~=nil end
        local function active() return self:Active(token) and prompt.Parent~=nil end
        -- Prompts refresh every second in this game's client; allow them to enable after movement.
        local untilAt=os.clock()+2
        while active() and not prompt.Enabled and os.clock()<untilAt do task.wait(0.05) end
        if not active() or not prompt.Enabled then self.UILastFailure="Prompt kulkas belum aktif" return nil end
        if type(fireproximityprompt)=="function" then
            pcall(fireproximityprompt,prompt)
            if self:WaitUI(ready,token,2) then return self:GameGui("Fridge") end
        end
        if not active() then return nil end
        local held=pcall(function() prompt:InputHoldBegin() end)
        if held then
            local finish=os.clock()+math.max(0,prompt.HoldDuration)+0.15
            while active() and os.clock()<finish and not ready() do task.wait(0.03) end
        end
        pcall(function() prompt:InputHoldEnd() end)
        if self:WaitUI(ready,token,2) then return self:GameGui("Fridge") end
        -- Last fallback uses the prompt's real key, with a matching key-up even on cancellation.
        if active() and self.Focused and prompt.KeyboardKeyCode~=Enum.KeyCode.Unknown then
            local cam=workspace.CurrentCamera
            if cam then cam.CFrame=CFrame.lookAt(pos+Vector3.new(0,3,6),pos) end
            task.wait(0.15)
            local key=prompt.KeyboardKeyCode
            pcall(function()
                VirtualInputManager:SendKeyEvent(true,key,false,game)
                local finish=os.clock()+math.max(0,prompt.HoldDuration)+0.15
                while active() and os.clock()<finish and not ready() do task.wait(0.03) end
            end)
            pcall(function() VirtualInputManager:SendKeyEvent(false,key,false,game) end)
            if self:WaitUI(ready,token,2) then return self:GameGui("Fridge") end
        end
        self.UILastFailure="Kulkas tidak membuka GUI setelah prompt/hold/key"
        return nil
    end

    function A:SubmitSaleAmount(form,box,submit,quantity,token)
        if type(quantity)~="number" or quantity<1 or quantity~=math.floor(quantity) then return false end
        local focused=UserInputService:GetFocusedTextBox()
        if focused and focused~=box then self.UILastFailure="Input lain sedang dipakai" return false end
        local text=string.format("%.0f",quantity)
        local function messageOpen() return self:GameGui("Message")~=nil end

        -- 1) isi kotak jumlah (kelebihan = stok - batas simpan)
        self.OwnedTextBox=box
        local ok,err=pcall(function()
            box:CaptureFocus()
            task.wait(0.1)
            box.Text=text
            task.wait(0.15)
        end)
        if not (ok and box.Parent~=nil and box.Text==text and self:Active(token)) then
            pcall(function() box:ReleaseFocus(false) end)
            self.OwnedTextBox=nil
            self.UILastFailure="Gagal isi jumlah jual: "..tostring(err or box.Text)
            return false
        end
        self:FridgeLog("INPUT","jumlah kelebihan stok = "..text)

        -- 2) cara utama: Enter (ReleaseFocus true), sama seperti script lama
        pcall(function() box:ReleaseFocus(true) end)
        self.OwnedTextBox=nil
        if self:WaitUI(messageOpen,token,1.2) then
            self.UILastMethod="TextBox Enter"
            return true
        end

        -- 3) cadangan: pastikan angka masih ada, lalu tekan Submit
        if box.Parent and box.Text~=text then
            pcall(function() box.Text=text end)
            task.wait(0.1)
        end
        if not box.Parent or box.Text~=text then
            self.UILastFailure="Angka jumlah hilang sebelum Submit"
            return false
        end
        return self:PressUI(submit,messageOpen,token)
    end

    function A:CloseNativeQuest(name)
        local gui=self:GameGui(name)
        if not gui then return end
        for _,button in ipairs(gui:GetDescendants()) do
            if button:IsA("GuiButton") and button.Name=="Close" and isShown(button) then
                return self:PressUI(button,function() return not self:GameGui(name) end)
            end
        end
    end

    function A:CancelSaleDialogs()
        local gui=self:GameGui("TextInput")
        local title=gui and self:Path(gui,"Message/Content/Title")
        local cancel=gui and self:Path(gui,"Message/Content/Cancel")
        if cancel and title and title.Text:match("^How many .- do you want to sell%?") then
            self:PressUI(cancel,function() return not self:GameGui("TextInput") end)
        end
        gui=self:GameGui("Message")
        local message=gui and self:Path(gui,"Message/Content/Message")
        local custom=gui and self:Path(gui,"Message/Content/CustomMessage")
        local text=message and message.Visible and message.Text or (custom and custom.Text or "")
        local no=gui and self:Path(gui,"Message/Content/No")
        if no and text:match("^Sell ") then self:PressUI(no,function() return not self:GameGui("Message") end) end
    end

    local uiActive=A.Active
    function A:Active(token)
        local box=UserInputService:GetFocusedTextBox()
        if box and box~=self.OwnedTextBox then return false end
        return uiActive(self,token)
    end

    local registerUIJobs=A.RegisterJobs
    function A:RegisterJobs()
        registerUIJobs(self)
        for _,job in ipairs(self.Jobs) do
            if job.id=="quest" then
                job.run=function(p,token)
                    if not self:Active(token) then return end
                    if p.open then
                        self.NextQuestOpen=os.clock()+10
                        if p.prompt then self:TriggerNative(p,token,"Buka Daily Quest")
                        elseif p.opener then
                            if not self:PressUI(p.opener,function() return self:GameGui(p.guiName)~=nil end,token) then return end
                        end
                        self:WaitUI(function() return self:FindQuestButton()~=nil end,token,0.8)
                    end
                    local claim=p.button and p or self:FindQuestButton()
                    if claim and self:Active(token) then
                        local button=claim.button
                        local sent=self:PressUI(button,function() return not button.Parent or not isShown(button) end,token)
                        self.Cooldowns[claim.key]=os.clock()+(sent and 3 or 6)
                        self.Status=sent and ("Quest "..claim.kind..": tombol klaim berubah") or self.UILastFailure
                    end
                    if p.open then self:CloseNativeQuest(p.guiName) end
                end
            end
        end
    end

    local diagnoseUI=A.Diagnostics
    local snapshotUI=A.Snapshot
    function A:Snapshot()
        return snapshotUI(self).."\nUI terakhir: "..self.UILastMethod.."\nfiresignal="..type(firesignal).." | getconnections="..type(getconnections)
    end
    function A:Diagnostics()
        local text=string.format("UI: firesignal=%s getconnections=%s | terakhir=%s | %s",
            type(firesignal),type(getconnections),self.UILastMethod,self.UILastFailure)
        print("[SeeLeooo UI] "..text)
        self.LastError=self.UILastFailure~="" and text or self.LastError
        diagnoseUI(self)
    end

    A.Version="2.6.1-fridge-gui"
    A.QuestInterval=120
    A.PanelPositions={}

    function A:CaptureRunSelection()
        local pending=self.PendingMacroResume
        return {Flags=table.clone(self.Flags),Harvest=AutoHarvest,Meteor=AutoClaimMeteor,
            Click=AutoClickUI,Key=AutoPressKey,Fishing=AF.On,AntiAfk=antiAfkActive,
            Macro=pending~=nil or not PR.Stop and (PR.Auto or PR.Requested or PR.Busy) or false,
            MacroAuto=pending and pending.auto or PR.Auto,MacroStep=pending and pending.step or PR.NextStep or 1}
    end

    function A:HasRunSelection(s)
        if type(s)~="table" then return false end
        for _,v in pairs(type(s.Flags)=="table" and s.Flags or {}) do if v==true then return true end end
        for _,k in ipairs({"Harvest","Meteor","Click","Key","Fishing","AntiAfk","Macro"}) do if s[k]==true then return true end end
        return false
    end

    local stopV24=A.StopAll
    function A:StopAll()
        local selected=self:CaptureRunSelection()
        if self:HasRunSelection(selected) then self.LastRunSelection=selected end
        self.PendingMacroResume=nil
        stopV24(self)
    end

    function A:FinishPendingPlay()
        local p=self.PendingMacroResume
        if p and not self.Busy and not PR.Busy then
            self.PendingMacroResume=nil
            if p.epoch==self.Epoch and not self.ShuttingDown and #PR.Steps>0 and PR.GuiClickPos and not PR.Recording then
                PR.Auto=p.auto PR.Requested=true PR.Stop=false
                PR.NextStep=math.clamp(p.step,1,#PR.Steps)
            end
        end
    end

    function A:PlaySelected()
        if self.ShuttingDown then return false end
        local current=self:CaptureRunSelection()
        local selected=self:HasRunSelection(current) and current or self.LastRunSelection
        if not self:HasRunSelection(selected) then notify("Play Auto","Belum ada pilihan auto. Aktifkan toggle yang diinginkan dulu.",4) return false end
        for k in pairs(self.Flags) do self.Flags[k]=selected.Flags and selected.Flags[k]==true or false end
        AutoHarvest=selected.Harvest==true AutoClaimMeteor=selected.Meteor==true
        AutoClickUI=selected.Click==true and #UIClickPositions>0
        AutoPressKey=selected.Key==true
        AF.On=selected.Fishing==true and AF.Pos~=nil
        antiAfkActive=selected.AntiAfk==true
        local macro=selected.Macro==true and #PR.Steps>0 and PR.GuiClickPos~=nil and not PR.Recording
        if PR.Busy and PR.Stop and macro then
            self.PendingMacroResume={epoch=self.Epoch,auto=selected.MacroAuto==true,step=tonumber(selected.MacroStep) or 1}
        elseif not PR.Busy then
            PR.Auto=macro and selected.MacroAuto==true or false
            PR.Requested=macro PR.Stop=not macro
            PR.NextStep=math.clamp(tonumber(selected.MacroStep) or 1,1,math.max(1,#PR.Steps))
        end
        self.ManualPause=false self.RetryUntil=0 self.ConsecutiveErrors=0
        self.LastRunSelection=self:CaptureRunSelection()
        self.Status="Play: pilihan auto dilanjutkan"
        self:SyncUI()
        notify("Play Auto","Melanjutkan pilihan aktif/terakhir sebelum Stop",3)
        return true
    end

    function A:CleanRunSelection(s)
        if type(s)~="table" then return nil end
        local clean={Flags={}}
        for k in pairs(self.Flags) do clean.Flags[k]=type(s.Flags)=="table" and s.Flags[k]==true or false end
        for _,k in ipairs({"Harvest","Meteor","Click","Key","Fishing","AntiAfk","Macro","MacroAuto"}) do clean[k]=s[k]==true end
        local step=(type(s.MacroStep)=="number" or type(s.MacroStep)=="string") and tonumber(s.MacroStep) or 1
        if not step or step~=step then step=1 end
        clean.MacroStep=math.clamp(step,1,200)
        return clean
    end

    function A:SetQuestInterval(value)
        local n=tonumber(value)
        if not n or n~=n or n<5 or n>3600 then return false end
        self.QuestInterval=math.floor(n)
        for _,job in ipairs(self.Jobs) do
            if job.id=="quest" then job.interval=self.QuestInterval job.nextAt=os.clock()+self.QuestInterval end
        end
        return true
    end

    function A:RememberPosition(key,panel)
        local p=panel.Position
        self.PanelPositions[key]={p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset}
    end

    function A:ApplyPanelPosition(key,panel)
        local p=self.PanelPositions[key]
        if type(p)=="table" and #p==4 then panel.Position=UDim2.new(p[1],p[2],p[3],p[4]) end
    end

    function A:MakeDraggable(handle,panel,key)
        local dragging,start,position,touch
        handle.Active=true
        self:ApplyPanelPosition(key,panel)
        local connections={}
        connections[#connections+1]=handle.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                dragging=true start=input.Position position=panel.Position
                touch=input.UserInputType==Enum.UserInputType.Touch and input or nil
            end
        end)
        connections[#connections+1]=UserInputService.InputChanged:Connect(function(input)
            if not dragging or not panel.Parent then return end
            if input.UserInputType~=Enum.UserInputType.MouseMovement and input~=touch then return end
            local d=input.Position-start
            local camera=workspace.CurrentCamera
            local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
            local anchor,size=panel.AnchorPoint,panel.AbsoluteSize
            local x=position.X.Scale*viewport.X+position.X.Offset+d.X
            local y=position.Y.Scale*viewport.Y+position.Y.Offset+d.Y
            local minX,minY=8+anchor.X*size.X,8+anchor.Y*size.Y
            local maxX=math.max(minX,viewport.X-(1-anchor.X)*size.X-8)
            local maxY=math.max(minY,viewport.Y-(1-anchor.Y)*size.Y-8)
            panel.Position=UDim2.fromOffset(math.clamp(x,minX,maxX),math.clamp(y,minY,maxY))
        end)
        connections[#connections+1]=UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or input==touch) then
                dragging=false touch=nil self:RememberPosition(key,panel)
            end
        end)
        local gui=panel:FindFirstAncestorOfClass("ScreenGui")
        local destroyHook
        if gui then destroyHook=gui.Destroying:Connect(function()
            for _,c in ipairs(connections) do c:Disconnect() end
            if destroyHook then destroyHook:Disconnect() end
        end) end
    end

    function A:Round(object,radius)
        local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,radius or 10) c.Parent=object
    end

    function A:PickerButton(parent,text,position,size,callback)
        local b=Instance.new("TextButton")
        b.Position,b.Size=position,size
        b.BackgroundColor3=Color3.fromRGB(44,48,58)
        b.TextColor3=Color3.fromRGB(255,226,110)
        b.Font,b.TextSize,b.Text=text and Enum.Font.GothamBold or Enum.Font.Gotham,12,text
        b.Parent=parent self:Round(b,8)
        b.Activated:Connect(callback)
        return b
    end

    function A:CreatePicker(title,key,close)
        local gui=Instance.new("ScreenGui")
        gui.Name="SeeLeooo_"..key gui.ResetOnSpawn=false gui.DisplayOrder=200 gui.Parent=CoreGui
        local panel=Instance.new("Frame")
        panel.AnchorPoint=Vector2.new(0.5,0.5) panel.Position=UDim2.fromScale(0.5,0.5)
        panel.Size=UDim2.new(0.92,0,0.85,0) panel.BackgroundColor3=Color3.fromRGB(18,21,28)
        panel.Parent=gui self:Round(panel,14)
        local constraint=Instance.new("UISizeConstraint") constraint.MaxSize=Vector2.new(640,560) constraint.Parent=panel
        local stroke=Instance.new("UIStroke") stroke.Color=Color3.fromRGB(120,104,52) stroke.Thickness=1 stroke.Parent=panel
        local heading=Instance.new("TextLabel")
        heading.Position=UDim2.fromOffset(16,8) heading.Size=UDim2.new(1,-68,0,42)
        heading.BackgroundTransparency=1 heading.Text="⋮⋮  "..title.."  ·  geser di sini"
        heading.TextColor3=Color3.fromRGB(255,225,100) heading.Font=Enum.Font.GothamBold heading.TextSize=15
        heading.TextXAlignment=Enum.TextXAlignment.Left heading.Parent=panel
        self:PickerButton(panel,"×",UDim2.new(1,-46,0,14),UDim2.fromOffset(30,30),close)
        self:MakeDraggable(heading,panel,key)
        local search=Instance.new("TextBox")
        search.Position=UDim2.fromOffset(14,58) search.Size=UDim2.new(1,-28,0,34)
        search.BackgroundColor3=Color3.fromRGB(31,35,45) search.TextColor3=Color3.new(1,1,1)
        search.PlaceholderText="Cari nama barang..." search.Text="" search.TextSize=14 search.ClearTextOnFocus=false
        search.Parent=panel self:Round(search,8)
        local caption=Instance.new("TextLabel")
        caption.Position=UDim2.fromOffset(14,133) caption.Size=UDim2.new(1,-28,0,22)
        caption.BackgroundTransparency=1 caption.TextColor3=Color3.fromRGB(180,190,207) caption.TextSize=12
        caption.TextXAlignment=Enum.TextXAlignment.Left caption.Parent=panel
        local list=Instance.new("ScrollingFrame")
        list.Position=UDim2.fromOffset(14,160) list.Size=UDim2.new(1,-28,1,-220)
        list.BackgroundTransparency=1 list.BorderSizePixel=0 list.ScrollBarThickness=5
        list.ScrollBarImageColor3=Color3.fromRGB(235,198,75) list.Parent=panel
        return {gui=gui,panel=panel,search=search,caption=caption,list=list}
    end

    function A:IngredientIcon(crop)
        local name=crop:gsub(" Crop$","")
        if name=="Tea" then name="Tea Leaves" elseif name=="Mega Pumpkin" then name="Pumpkin" end
        return self.SaleIcons[name] or ""
    end

    function A:RenderCropList()
        if not self.CropList then return end
        for _,c in ipairs(self.CropList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local query=(self.CropSearch.Text or ""):lower()
        local index,selected=0,0
        for _,v in pairs(self.SelectedCrops) do if v then selected+=1 end end
        for _,name in ipairs(self.CropNames) do
            if query=="" or name:lower():find(query,1,true) then
                local id=self.CropLabels[name]
                local row=self:PickerButton(self.CropList,"",UDim2.fromOffset(0,index*60),UDim2.new(1,-8,0,54),function()
                    self.SelectedCrops[id]=not self.SelectedCrops[id] or nil self.AllCrops=false self:SyncUI()
                end)
                row.BackgroundColor3=self.SelectedCrops[id] and Color3.fromRGB(56,61,38) or Color3.fromRGB(31,35,45)
                local icon=Instance.new("ImageLabel") icon.BackgroundTransparency=1 icon.Size=UDim2.fromOffset(42,42)
                icon.Position=UDim2.fromOffset(8,6) icon.Image=self:IngredientIcon(name) icon.Parent=row
                local label=Instance.new("TextLabel") label.BackgroundTransparency=1 label.Size=UDim2.new(1,-68,1,0)
                label.Position=UDim2.fromOffset(58,0) label.Text=(self.SelectedCrops[id] and "[✓]  " or "[ ]  ")..name
                label.TextXAlignment=Enum.TextXAlignment.Left label.TextColor3=Color3.fromRGB(240,240,240)
                label.Font=Enum.Font.Gotham label.TextSize=14 label.Parent=row
                index+=1
            end
        end
        self.CropList.CanvasSize=UDim2.fromOffset(0,index*60)
        self.CropCaption.Text=self.AllCrops and "SEMUA TANAMAN · termasuk jenis baru" or (selected.." tanaman dipilih")
    end

    function A:OpenCropPicker()
        if self.Busy or PR.Recording or self.SellGuiOpen then notify("Tanaman","Selesaikan aksi/panel lain dulu",3) return end
        if not self.CropGui then
            local p=self:CreatePicker("Pilih Tanaman","CropPicker",function() self.CropGuiOpen=false if self.CropGui then self.CropGui.Enabled=false end end)
            self.CropGui,self.CropList,self.CropSearch,self.CropCaption,self.CropPanel=p.gui,p.list,p.search,p.caption,p.panel
            self:PickerButton(p.panel,"Semua Tanaman",UDim2.fromOffset(14,101),UDim2.new(0.5,-20,0,28),function() self.AllCrops=true self:SyncUI() end)
            self:PickerButton(p.panel,"Kosongkan",UDim2.new(0.5,6,0,101),UDim2.new(0.5,-20,0,28),function() self.AllCrops=false self.SelectedCrops={} self:SyncUI() end)
            self:PickerButton(p.panel,"Selesai",UDim2.new(0,14,1,-48),UDim2.new(1,-28,0,34),function() self.CropGuiOpen=false p.gui.Enabled=false end)
            p.search:GetPropertyChangedSignal("Text"):Connect(function() self:RenderCropList() end)
        end
        self.CropGuiOpen=true self.CropGui.Enabled=true self.RefreshRequested=true self:RenderCropList()
    end

    function A:SaleNames()
        local names,seen={},{}
        for name in pairs(self.SaleIcons) do names[#names+1]=name seen[name]=true end
        for name in pairs(self.SellRules) do if not seen[name] then names[#names+1]=name end end
        table.sort(names) return names
    end

    function A:SaveSaleDraft(draft)
        local rules={}
        for name,item in pairs(draft) do
            if item.enabled then
                local n=tonumber(item.keep)
                if not n or n<0 or n>1e12 or n~=math.floor(n) then return false,"Batas tidak valid: "..name end
                rules[name]=n
            end
        end
        self.SellRules=rules self.SellRevision+=1 self.SellVisited={}
        return true
    end

    function A:RenderSalePicker()
        local p=self.SellPicker
        if not p then return end
        for _,c in ipairs(p.list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local query=p.search.Text:lower()
        local index,count=0,0
        for _,d in pairs(self.SaleDraft) do if d.enabled then count+=1 end end
        for _,name in ipairs(self:SaleNames()) do
            if query=="" or name:lower():find(query,1,true) then
                local item=self.SaleDraft[name]
                local row=Instance.new("Frame") row.Position=UDim2.fromOffset(0,index*66)
                row.Size=UDim2.new(1,-8,0,60) row.BackgroundColor3=Color3.fromRGB(31,35,45) row.Parent=p.list self:Round(row,9)
                local check
                check=self:PickerButton(row,item.enabled and "✓" or "",UDim2.fromOffset(8,16),UDim2.fromOffset(28,28),function()
                    item.enabled=not item.enabled check.Text=item.enabled and "✓" or ""
                    local n=0 for _,d in pairs(self.SaleDraft) do if d.enabled then n+=1 end end
                    p.caption.Text=n.." barang dipilih · yang tidak dicentang tidak dijual"
                end)
                local icon=Instance.new("ImageLabel") icon.BackgroundTransparency=1 icon.Position=UDim2.fromOffset(44,8)
                icon.Size=UDim2.fromOffset(44,44) icon.Image=self.SaleIcons[name] or "" icon.Parent=row
                local label=Instance.new("TextLabel") label.BackgroundTransparency=1 label.Position=UDim2.fromOffset(98,0)
                label.Size=UDim2.new(1,-218,1,0) label.Text=name label.TextWrapped=true label.TextXAlignment=Enum.TextXAlignment.Left
                label.TextColor3=Color3.fromRGB(240,240,240) label.Font=Enum.Font.Gotham label.TextSize=13 label.Parent=row
                local box=Instance.new("TextBox") box.Position=UDim2.new(1,-110,0,24) box.Size=UDim2.fromOffset(100,28)
                box.BackgroundColor3=Color3.fromRGB(18,21,28) box.TextColor3=Color3.fromRGB(255,226,110)
                box.Text=item.keep box.ClearTextOnFocus=false box.TextSize=14 box.Parent=row self:Round(box,6)
                box:GetPropertyChangedSignal("Text"):Connect(function() item.keep=box.Text end)
                local hint=Instance.new("TextLabel") hint.Position=UDim2.new(1,-110,0,4) hint.Size=UDim2.fromOffset(100,16)
                hint.BackgroundTransparency=1 hint.Text="SIMPAN" hint.TextSize=10 hint.TextColor3=Color3.fromRGB(160,173,190) hint.Parent=row
                index+=1
            end
        end
        p.list.CanvasSize=UDim2.fromOffset(0,index*66)
        p.caption.Text=count.." barang dipilih · yang tidak dicentang tidak dijual"
    end

    function A:OpenSalePicker()
        if self.Busy or PR.Recording or self.CropGuiOpen then notify("Fridge","Selesaikan aksi/panel lain dulu",3) return end
        if not self.SellPicker then
            local p=self:CreatePicker("Fridge · Pilih Barang & Batas","SellPicker",function() self.SellGuiOpen=false if self.SellPicker then self.SellPicker.gui.Enabled=false end end)
            self.SellPicker=p
            local function selectVisible(value)
                local query=p.search.Text:lower()
                for name,item in pairs(self.SaleDraft) do if query=="" or name:lower():find(query,1,true) then item.enabled=value end end
                self:RenderSalePicker()
            end
            self:PickerButton(p.panel,"Centang hasil",UDim2.fromOffset(14,101),UDim2.new(0.5,-20,0,28),function() selectVisible(true) end)
            self:PickerButton(p.panel,"Hapus centang hasil",UDim2.new(0.5,6,0,101),UDim2.new(0.5,-20,0,28),function() selectVisible(false) end)
            self:PickerButton(p.panel,"Simpan Pilihan",UDim2.new(0,14,1,-48),UDim2.new(0.65,-20,0,34),function()
                local ok,err=self:SaveSaleDraft(self.SaleDraft)
                if not ok then notify("Fridge",err,4) return end
                self.SellGuiOpen=false p.gui.Enabled=false notify("Fridge","Pilihan barang dan batas simpan disimpan",3)
            end)
            self:PickerButton(p.panel,"Batal",UDim2.new(0.65,6,1,-48),UDim2.new(0.35,-20,0,34),function() self.SellGuiOpen=false p.gui.Enabled=false end)
            p.search:GetPropertyChangedSignal("Text"):Connect(function() self:RenderSalePicker() end)
        end
        self.SaleDraft={}
        for _,name in ipairs(self:SaleNames()) do self.SaleDraft[name]={enabled=self.SellRules[name]~=nil,keep=tostring(self.SellRules[name] or 200)} end
        self.SellGuiOpen=true self.SellPicker.gui.Enabled=true self:RenderSalePicker()
    end

    function A:BuildSellUI()
        AutoTab:CreateSection({Text="Fridge: Jual Kelebihan"})
        self:Toggle("Auto Sell Kelebihan","Hanya barang tercentang; setiap barang punya batas sendiri",
            function() return self.Flags.Sell end,function(v) self.Flags.Sell=v end)
        AutoTab:CreateButton({Title="Pilih Barang Fridge (Ikon & Multi)",Description="Centang beberapa barang dan atur batas per barang",Callback=function() self:OpenSalePicker() end})
        AutoTab:CreateButton({Title="Lihat Aturan Jual",Callback=function()
            local lines={} for name,keep in pairs(self.SellRules) do lines[#lines+1]=name..": simpan "..keep end table.sort(lines)
            notify("Fridge",#lines>0 and table.concat(lines,"\n") or "Belum ada barang dipilih",8)
        end})
        AutoTab:CreateSlider({Title="Jeda Cek Fridge (detik)",Min=5,Max=120,Default=15,Callback=function(v) self.SellInterval=v end})
    end

    local captureV24,buildV24,registerV24,exportV24,importV24,shutdownV24,updateHudV24,actionV24=A.CaptureInput,A.BuildUI,A.RegisterJobs,A.Export,A.Import,A.Shutdown,A.UpdateDashboard,A.WithAction
    function A:WithAction(job,payload)
        local ok=actionV24(self,job,payload)
        self:FinishPendingPlay()
        return ok
    end
    function A:CaptureInput() return self.LoadingProfile or self.SellGuiOpen or captureV24(self) end
    function A:BuildUI()
        buildV24(self)
        AutoTab:CreateSection({Text="Jadwal Quest & Posisi Panel"})
        local questInterval=AutoTab:CreateSlider({Title="Interval Cek Quest (detik)",Min=5,Max=3600,
            Default=self.QuestInterval,Callback=function(v) self:SetQuestInterval(v) end})
        SettingsUI:Bind(questInterval,function() return self.QuestInterval end)
        AutoTab:CreateButton({Title="Cek Quest Sekarang",Callback=function()
            self.QuestRequested=true for _,job in ipairs(self.Jobs) do if job.id=="quest" then job.nextAt=0 end end
        end})
        AutoTab:CreateButton({Title="Reset Posisi Panel Tambahan",Callback=function()
            self.PanelPositions={}
            if self.CropPanel then self.CropPanel.Position=UDim2.fromScale(0.5,0.5) end
            if self.SellPicker then self.SellPicker.panel.Position=UDim2.fromScale(0.5,0.5) end
            if self.DashboardLabel then self.DashboardLabel.Position=UDim2.new(0,12,1,-155) end
            if self.FishDragBound then self.FishDragBound.Position=UDim2.new(0,10,0.35,0) end
        end})
    end
    function A:RegisterJobs()
        registerV24(self)
        for _,job in ipairs(self.Jobs) do if job.id=="quest" then
            local enabled,probe,run=job.enabled,job.probe,job.run
            job.interval=self.QuestInterval
            job.enabled=function() return self.QuestRequested or enabled() end
            job.probe=function() return self.Focused and {cycle=true} or nil end
            job.run=function(_,token)
                local ok,err=pcall(function()
                    -- One interval means one cycle through the three supported quest pages.
                    for _=1,3 do
                        if not self:Active(token) then break end
                        self.NextQuestOpen=0
                        local payload
                        for _=1,3 do payload=probe() if payload then break end end
                        if payload then run(payload,token) end
                    end
                end)
                self.QuestRequested=false
                job.nextAt=os.clock()+self.QuestInterval
                if not ok then error(err) end
            end
        end end
    end
    function A:UpdateDashboard()
        updateHudV24(self)
        if self.DashboardGui and self.DashboardDragBound~=self.DashboardGui then
            self.DashboardDragBound=self.DashboardGui self:Round(self.DashboardLabel,10)
            self:MakeDraggable(self.DashboardLabel,self.DashboardLabel,"Dashboard")
        end
        local fish=CoreGui:FindFirstChild("SeeLeooo_HUD")
        local label=fish and fish:FindFirstChild("Label")
        if label and self.FishDragBound~=label then self.FishDragBound=label self:Round(label,8) self:MakeDraggable(label,label,"FishingHUD") end
    end
    function A:Export()
        local d=exportV24(self)
        d.QuestInterval=self.QuestInterval d.PanelPositions=table.clone(self.PanelPositions) d.LastRunSelection=self:CleanRunSelection(self.LastRunSelection)
        return d
    end
    function A:Import(d)
        if type(d)=="table" then
            if d.QuestInterval~=nil then self:SetQuestInterval(d.QuestInterval) end
            if type(d.LastRunSelection)=="table" then self.LastRunSelection=self:CleanRunSelection(d.LastRunSelection) end
            if type(d.PanelPositions)=="table" then
                for key,p in pairs(d.PanelPositions) do
                    local valid=type(key)=="string" and type(p)=="table" and #p==4
                    if valid then for _,v in ipairs(p) do if type(v)~="number" or v~=v or math.abs(v)>1e6 then valid=false end end end
                    if valid then self.PanelPositions[key]={p[1],p[2],p[3],p[4]} end
                end
            end
        end
        importV24(self,d)
        if self.CropPanel then self:ApplyPanelPosition("CropPicker",self.CropPanel) end
        if self.SellPicker then self:ApplyPanelPosition("SellPicker",self.SellPicker.panel) end
        if self.DashboardLabel then self:ApplyPanelPosition("Dashboard",self.DashboardLabel) end
        if self.FishDragBound then self:ApplyPanelPosition("FishingHUD",self.FishDragBound) end
    end
    function A:Shutdown()
        self.SellGuiOpen=false
        if self.SellPicker then self.SellPicker.gui:Destroy() self.SellPicker=nil end
        shutdownV24(self)
    end

end


-- =========================================================

-- v2.6.1 fridge: identify live items; all sales use the normal GUI quantity/confirmation flow.
-- No fixed slot number, no unknown-item probing, no fabricated remote names.
do
    local A=Automation

    local function normalize(value)
        return trim(tostring(value or "")):lower():gsub("%s+"," ")
    end

    local function upvalues(fn)
        local values={}
        local bulk=type(getupvalues)=="function" and getupvalues
            or (type(debug)=="table" and debug.getupvalues)
        if type(bulk)=="function" then
            local ok,result=pcall(bulk,fn)
            if ok and type(result)=="table" then
                for _,value in pairs(result) do values[#values+1]=value end
                return values
            end
        end
        local single=type(getupvalue)=="function" and getupvalue
            or (type(debug)=="table" and debug.getupvalue)
        if type(single)=="function" then
            for index=1,40 do
                local ok,first,second=pcall(single,fn,index)
                if not ok or first==nil and second==nil then break end
                -- Standard debug returns name,value; executor variants usually return value.
                local value=second~=nil and second or first
                values[#values+1]=value
            end
        end
        return values
    end

    function A:FridgeLog(stage,text)
        self.FridgeLastStatus=stage..": "..tostring(text)
        self.Status="Fridge "..self.FridgeLastStatus
        plog("FRIDGE",self.FridgeLastStatus)
        if (stage=="GUI CADANGAN" or stage=="ERROR") and os.clock()>=(self.FridgeNotifyAt or 0) then
            self.FridgeNotifyAt=os.clock()+60
            notify("Fridge",self.FridgeLastStatus.." | lihat Diagnosa Fridge",7)
        end
    end

    function A:ResolveFridge(gui)
        local items=self:Path(gui,"Fridge/Frame/Content/Items")
        local bridge={rows={},entries={},items=items}
        local seen,visited={},0
        local function visit(fn,depth)
            if type(fn)~="function" or seen[fn] or depth>3 or visited>=160 then return end
            seen[fn]=true visited+=1
            for _,value in ipairs(upvalues(fn)) do
                if type(value)=="table" then
                    local active,config=rawget(value,"_active"),rawget(value,"_config")
                    if type(active)=="table" and type(config)=="table" and config.Parent==items then
                        bridge.renderer=value
                        visit(config.Requirement,depth+1)
                        visit(config.Update,depth+1)
                    end
                    if type(rawget(value,"Get"))=="function" and type(rawget(value,"Sell"))=="function"
                        and rawget(value,"Changed")~=nil then bridge.api=value end
                elseif type(value)=="function" then visit(value,depth+1) end
            end
        end
        local function inspect(button)
            if not button or type(getconnections)~="function" then return end
            local ok,list=pcall(getconnections,button.Activated)
            if not ok or type(list)~="table" then return end
            for _,connection in ipairs(list) do
                local fn
                pcall(function() fn=connection.Function end)
                visit(fn,0)
            end
        end
        inspect(self:Path(gui,"Fridge/Frame/Content/Bottom/Buttons/SellSelection"))
        for i,row in ipairs(self:SaleRows(gui)) do
            inspect(row)
            if bridge.renderer and bridge.api then break end
            if i%16==0 then task.wait() end
        end
        if bridge.renderer then
            for entry,row in pairs(bridge.renderer._active) do
                if type(entry)=="table" and type(entry._id)=="string" and type(entry.SellPrice)=="number"
                    and row.Parent==items then
                    bridge.rows[row]=entry
                    bridge.entries[#bridge.entries+1]={entry=entry,row=row}
                end
            end
        end
        self.FridgeRows=bridge.rows
        self.FridgeBridge=bridge
        return bridge
    end

    function A:FridgeRule(entry)
        local id,display=normalize(entry._id),normalize(entry.DisplayName)
        local match,keep
        for name,value in pairs(self.SellRules) do
            if normalize(name)==id or display~="" and normalize(name)==display then
                if match and keep~=value then return nil,nil,"aturan nama/ID bertentangan" end
                if self:SaleAmount(0,value)==nil then return nil,nil,"batas simpan tidak valid" end
                match,keep=name,value
            end
        end
        return match,keep
    end

    function A:SaleRowName(row)
        local entry=self.FridgeRows and self.FridgeRows[row]
        if entry then return self:FridgeRule(entry) or entry.DisplayName or entry._id end
        -- Legacy UI fallback accepts a known, unique icon only.
        local icon=self:Path(row,"Content/Icon")
        if not icon then return nil end
        local asset=icon.Image:match("rbxassetid://(%d+)") or icon.Image:match("[?&]id=(%d+)")
        local matched
        for name,image in pairs(self.SaleIcons) do
            local other=image:match("rbxassetid://(%d+)") or image:match("[?&]id=(%d+)")
            if icon.Image==image or asset and asset==other then
                if matched and matched~=name then return nil end
                matched=name
            end
        end
        return matched
    end

    function A:PickSaleRow(rows)
        local candidates={}
        for _,row in ipairs(rows) do
            local name=self:SaleRowName(row)
            if name and self.SellRules[name]~=nil and not self.PendingNames[name]
                and os.clock()>=(self.SellVisited[name] or 0) then
                candidates[#candidates+1]=row
            end
        end
        table.sort(candidates,function(left,right) return self:SaleRowName(left)<self:SaleRowName(right) end)
        if #candidates==0 then return nil end
        self.SellCursor=(self.SellCursor or 0)%#candidates+1
        return candidates[self.SellCursor]
    end

    function A:SelectFridgeEntry(bridge,entry)
        if not bridge.renderer or not bridge.renderer._active[entry] then return false end
        local ok=pcall(function()
            for item in pairs(bridge.renderer._active) do
                bridge.renderer:SetValue(item,"Active",item==entry)
            end
        end)
        return ok
    end

    function A:ClearSalePending(record)
        if self.PendingNames[record.name]==record then self.PendingNames[record.name]=nil end
        for i=#self.PendingSales,1,-1 do
            if self.PendingSales[i]==record then table.remove(self.PendingSales,i) end
        end
    end

    function A:RunSale(payload,token)
        if not self:Active(token) then return end
        self:RunSaleGui(payload,token)
        self:FridgeLog(self.LastError~="" and "ERROR" or "GUI",self.LastError~="" and self.LastError or self.Status)
    end

    local oldSnapshot=A.Snapshot
    function A:Snapshot()
        return oldSnapshot(self).."\nFridge terakhir: "..tostring(self.FridgeLastStatus or "belum jalan")
    end
    local oldBuild=A.BuildUI
    function A:BuildUI()
        oldBuild(self)
        AutoTab:CreateButton({Title="Diagnosa Fridge (Salin Log)",Description="Target nama/ID dan hasil server transaksi terakhir",
            Callback=function()
                local lines={"SeeLeooo v2.6 Fridge",self.FridgeLastStatus or "belum ada percobaan",
                    "getconnections="..type(getconnections),
                    "upvalues="..tostring(type(getupvalues)=="function" or type(debug)=="table" and
                        (type(debug.getupvalues)=="function" or type(debug.getupvalue)=="function"))}
                for name,keep in pairs(self.SellRules) do lines[#lines+1]="Aturan: "..name.." | simpan "..keep end
                for _,line in ipairs(LogBuf) do if line:find("FRIDGE",1,true) then lines[#lines+1]=line end end
                local text=table.concat(lines,"\n")
                print(text)
                if type(setclipboard)=="function" then pcall(setclipboard,text) end
                notify("Fridge",self.FridgeLastStatus or "Aktifkan Auto Sell dulu",8)
            end})
    end
end

-- FISHING TAB : AUTO FISHING + PROSES + JUAL (dalam satu blok)
-- Cara kerja fishing: dengerin paket jadwal gigit dari server, lalu
-- klik virtual (handler klik milik game) tepat di window gigit.
-- =========================================================
do
    local function clickPos()
        if not Automation.Focused or freecamActive or Automation:CaptureInput() then return end
        if AF.Pos then ClickAt(AF.Pos.X, AF.Pos.Y) end
    end

    -- ---------- Scheduler reel per sesi ----------
    local function scheduleReel(sess)
        task.spawn(function()
            local wins = {}
            for _, w in ipairs(sess.Windows or {}) do wins[#wins + 1] = w end
            table.sort(wins)
            local dur = sess.Duration or 4

            for _, w in ipairs(wins) do
                if AF.Cur ~= sess or not AF.On then return end
                if workspace:GetServerTimeNow() > w + dur - 0.3 then continue end -- window sudah lewat

                local offset = AF.Turbo and 0.12 or AF.ReelOffset
                local target = w + offset
                while AF.Cur == sess and AF.On and workspace:GetServerTimeNow() < target do
                    task.wait()
                end

                for _ = 0, (AF.Retry and 3 or 0) do
                    if AF.Cur ~= sess or not AF.On then return end
                    if workspace:GetServerTimeNow() > w + dur then break end
                    AF.Reels += 1
                    clickPos() -- sesi lagi cast -> klik = REEL
                    task.wait(AF.Turbo and 0.18 or 0.25)
                end
            end
        end)
    end

    -- ---------- Listener paket dari server ----------
    local function onNet(...)
        local n = select("#", ...)
        local a1, a2 = ...

        if type(a1) == "table" then
            -- Paket gigit: 1 tabel berisi BobberWindows, NpcId nil, Player = kita
            if n == 1 and rawget(a1, "BobberWindows") ~= nil
                and rawget(a1, "NpcId") == nil and rawget(a1, "Player") == player then
                local sess = {
                    Id = rawget(a1, "Id"),
                    Windows = rawget(a1, "BobberWindows"),
                    Duration = rawget(a1, "BobberDuration"),
                }
                AF.Cur = sess
                if AF.On then scheduleReel(sess) end
            end
        elseif type(a1) == "number" then
            local cur = AF.Cur
            if cur and a1 == cur.Id then
                if n >= 2 and type(a2) == "table" and rawget(a2, "W") ~= nil then
                    -- Fishing_Success(id, {Id, W, A})
                    AF.Cur = nil
                    AF.Caught += 1
                    recordCatch(a2)
                elseif n == 1 then
                    -- Fishing_Clear(id)
                    AF.Cur = nil
                    AF.Missed += 1
                end
            end
        end
    end

    local hooked = 0
    local net = ReplicatedStorage:FindFirstChild("Network")
    if net then
        for _, r in ipairs(net:GetDescendants()) do
            if r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent") then
                hooked += 1
                track(r.OnClientEvent:Connect(function(...)
                    pcall(onNet, ...)
                end))
            end
        end
    end

    -- ---------- Loop utama fishing ----------
    task.spawn(function()
        local fails = 0
        while Running do
            if AF.On and AF.Pos and not AF.Paused and not Automation.ManualPause and os.clock() >= Automation.RetryUntil and not freecamActive and not Automation:CaptureInput() then
                if not AF.Cur then
                    clickPos() -- belum cast -> klik = CAST ke air
                    local t0 = os.clock()
                    while Running and not AF.Cur and os.clock() - t0 < 3 and AF.On do
                        task.wait()
                    end

                    if AF.Cur then
                        fails = 0
                        local sess = AF.Cur
                        local lastEnd = 0
                        for _, w in ipairs(sess.Windows or {}) do
                            if w > lastEnd then lastEnd = w end
                        end
                        lastEnd = lastEnd + (sess.Duration or 4) + 2

                        while Running and AF.Cur == sess and AF.On
                            and workspace:GetServerTimeNow() < lastEnd do
                            task.wait()
                        end
                        if AF.Cur == sess then -- timeout, sesi dianggap habis
                            AF.Cur = nil
                            AF.Missed += 1
                        end
                        task.wait(AF.Turbo and 0.2 or AF.Between)
                    elseif AF.On and not AF.Paused then
                        fails += 1
                        AF.Failed += 1
                        if AF.AutoEquip then
                            pressSlotKey(AF.EquipSlot)
                            task.wait(0.8)
                        end
                        if fails >= 3 then
                            fails = 0
                            if PR.On then
                                AF.NeedProcess = true
                                notify("Auto Fish",
                                    "Cast gagal 3x (ice box penuh?) -> proses ikan dijalankan", 4)
                                task.wait(2)
                            else
                                notify("Auto Fish",
                                    "Cast gagal 3x. Cek: pancingan dipegang? ice box penuh? posisi klik di air & <40 stud?", 5)
                                task.wait(3)
                            end
                        else
                            task.wait(1)
                        end
                    end
                else
                    task.wait(0.2)
                end
            else
                task.wait(0.3)
            end
        end
    end)

    -- =====================================================
    -- MACRO PROSES (STABIL)
    -- Rekam: E station + 1x klik GUI
    -- Putar : teleport ke posisi rekaman → E → klik GUI
    -- =====================================================
    PR.Auto = PR.Auto or false
    PR.Stop = false

    local function isLibGui(obj)
        local sg = obj and obj:FindFirstAncestorOfClass("ScreenGui")
        if not sg then return false end
        local n = sg.Name
        return n == "ProxyInterface" or n == "ProxyFloat" or n == "ProxyNotification"
    end

    -- Cari prompt dekat pos / dekat player (2 cara)
    local function findPromptHere(pos)
        local hrp = getHRP()
        local origin = pos or (hrp and hrp.Position)
        if not origin then return nil end

        local best, bestD = nil, 12
        local ok, parts = pcall(function()
            return workspace:GetPartBoundsInRadius(origin, 12)
        end)
        if ok and parts then
            local checked = {}
            for _, part in ipairs(parts) do
                local root = part:FindFirstAncestorOfClass("Model") or part
                if not checked[root] then
                    checked[root] = true
                    local pr = root:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if pr then
                        local pp = promptPos(pr)
                        if pp then
                            local d = (pp - origin).Magnitude
                            if d < bestD then
                                best, bestD = pr, d
                            end
                        end
                    end
                end
            end
        end
        if best then return best end

        -- fallback pelan tapi jarang dipakai
        return findNearestPrompt(origin, 12)
    end

    local function openStation(prompt)
        if not prompt then return false end

        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 25)
        end)

        for _ = 1, 4 do
            if PR.Stop then return false end
            pcall(function()
                if fireproximityprompt then fireproximityprompt(prompt) end
            end)
            pcall(function()
                prompt:InputHoldBegin()
                task.wait(0.12)
                prompt:InputHoldEnd()
            end)
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.07)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)
            task.wait(0.1)
        end
        return true
    end

    local Rec = { Conns = {}, Last = nil, Active = false }

    local function addStep(step)
        if #PR.Steps>=200 then
            Rec.Active=false PR.Recording=false
            for _,c in ipairs(Rec.Conns) do pcall(function() c:Disconnect() end) end
            Rec.Conns={}
            notify("Macro","Batas 200 station tercapai; rekaman dihentikan",4) return
        end
        local now = os.clock()
        step.dt = Rec.Last and (now - Rec.Last) or 0
        Rec.Last = now
        local h = getHRP()
        step.cf = h and h.CFrame or nil
        if not step.pos and h then step.pos = h.Position end
        PR.Steps[#PR.Steps + 1] = step
        plog("[REKAM] #" .. #PR.Steps, step.t, step.action or "")
        notify("Rekam", "Station #" .. #PR.Steps .. " tersimpan", 2)
    end

    local function stopRecord()
        for _, c in ipairs(Rec.Conns) do pcall(function() c:Disconnect() end) end
        Rec.Conns = {}
        if Rec.Active then
            Rec.Active = false
            PR.Recording = false
            local guiOk = PR.GuiClickPos and "GUI OK" or "GUI BELUM"
            notify("Rekam", #PR.Steps .. " station | " .. guiOk, 4)
        end
    end
    AF.MacroStop = stopRecord

    local function startRecord()
        if Automation.Busy then notify("Rekam", "Tunggu aksi auto selesai dulu", 3) return end
        PR.Requested, PR.Auto, PR.NextStep = false, false, 1
        stopRecord()
        PR.Steps = {}
        Rec.Last = nil
        Rec.Active = true
        PR.Recording = true
        notify("Rekam Station", "Tekan E di tiap station. Stop: F3", 6)

        Rec.Conns[#Rec.Conns + 1] = UserInputService.InputBegan:Connect(function(input, gp)
            if not Rec.Active then return end
            -- JANGAN cek gp: E di prompt selalu gameProcessed=true

            if input.KeyCode == Enum.KeyCode.E then
                local now = os.clock()
                if Rec.LastKeyE and (now - Rec.LastKeyE) < 0.45 then return end
                Rec.LastKeyE = now

                local h = getHRP()
                addStep({
                    t = "station",
                    action = "E",
                    pos = h and h.Position or nil,
                })
            end
        end)
    end

    local function setGuiPos()
        Automation.Selecting = true
        notify("Set GUI", "Klik tombol proses di layar sekarang...", 5)
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local loc = UserInputService:GetMouseLocation()
            local pg = player:FindFirstChild("PlayerGui")
            if pg then
                local ok, objs = pcall(function()
                    return pg:GetGuiObjectsAtPosition(loc.X, loc.Y - GuiService:GetGuiInset().Y)
                end)
                if ok and objs then
                    for _, o in ipairs(objs) do
                        if isLibGui(o) then return end
                    end
                end
            end
            PR.GuiClickPos = loc
            Automation.Selecting = false
            notify("Set GUI", string.format("Disimpan (%d, %d)", loc.X, loc.Y), 3)
            conn:Disconnect()
        end)
        track(conn)
    end
    AF.MacroSetGui = setGuiPos

    local function teleportTo(cf)
        local hrp = getHRP()
        if not hrp or not cf then return end
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(PR.MoveWait or 0.08)
    end

    local function clickProcessGui()
        if not PR.GuiClickPos then return false end
        local restore = hideLibUi()
        local p = PR.GuiClickPos
        if not ClickAt(p.X, p.Y) then restore() return false end
        task.wait(0.05)
        if not ClickAt(p.X, p.Y) then restore() return false end
        task.wait(PR.AfterClick or 0.2)
        restore()
        return true
    end

    local function pressE(times)
        if not Automation.Focused then return end
        for _ = 1, (times or 2) do
            if PR.Stop then return end
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.04)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)
            task.wait(0.06)
        end
    end

    local function tryFireNearPrompt()
        local hrp = getHRP()
        if not hrp then return end
        local ok, parts = pcall(function()
            return workspace:GetPartBoundsInRadius(hrp.Position, 10)
        end)
        if not ok or not parts then return end
        local checked = {}
        for _, part in ipairs(parts) do
            local root = part:FindFirstAncestorOfClass("Model") or part
            if not checked[root] then
                checked[root] = true
                local pr = root:FindFirstChildWhichIsA("ProximityPrompt", true)
                if pr then
                    pcall(function()
                        pr.HoldDuration = 0
                        pr.RequiresLineOfSight = false
                        pr.MaxActivationDistance = 30
                        if fireproximityprompt then fireproximityprompt(pr) end
                        pr:InputHoldBegin()
                        task.wait(0.1)
                        pr:InputHoldEnd()
                    end)
                    return
                end
            end
        end
    end

    local function runMacro()
        if PR.Busy or PR.Requested then return end
        if #PR.Steps == 0 or not PR.GuiClickPos then
            notify("Macro", "Set GUI dan rekam station dulu (F3)", 3)
            return
        end
        if PR.Recording then notify("Macro", "Stop rekam dulu (F3)", 3) return end
        PR.Stop = false
        PR.Requested = true
        notify("Macro", "Masuk antrean auto", 2)
    end

    AF.MacroRunOnce = function(token)
        -- Satu station per giliran supaya macro panjang tidak memonopoli worker.
        local index = PR.NextStep or 1
        local step = PR.Steps[index]
        if not step or not Automation:Active(token) then PR.NextStep = 1 return end
        if step.t == "station" then
            if not Automation:MoveTo(step.cf, token) then return end
            tryFireNearPrompt()
            if not Automation:Active(token) then return end
            pressE(2)
            task.wait(PR.GuiWait or 0.25)
            if not Automation:Active(token) or PR.Stop then return end
            if not clickProcessGui() then PR.Requested = true return end
            pcall(closeFishGui)
        end
        index += 1
        if index > #PR.Steps then
            PR.Runs += 1
            PR.NextStep = 1
            if not PR.Auto then PR.Requested = false end
            notify("Macro", "Selesai x" .. tostring(PR.Runs), 2)
        else
            PR.NextStep = index
            PR.Requested = true
        end
    end

    local function stopMacro()
        PR.Stop = true
        PR.Auto = false
        PR.Requested = false
        PR.NextStep = 1
        notify("Macro", "Stop...", 2)
    end

    AF.MacroPlay = runMacro
    AF.MacroStopPlay = stopMacro
    AF.MacroToggleRec = function()
        if PR.Recording then stopRecord() else startRecord() end
    end

    -- ---------- HUD ----------
    local function setHud(v)
        if v then
            if AF.HudGui then return end
            local sg = Instance.new("ScreenGui")
            sg.Name = "SeeLeooo_HUD"
            sg.ResetOnSpawn = false
            sg.Parent = CoreGui

            local lb = Instance.new("TextLabel")
            lb.Name = "Label"
            lb.Size = UDim2.new(0, 230, 0, 96)
            lb.Position = UDim2.new(0, 10, 0.35, 0)
            lb.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            lb.BackgroundTransparency = 0.35
            lb.BorderSizePixel = 0
            lb.TextColor3 = Color3.fromRGB(255, 255, 255)
            lb.Font = Enum.Font.Code
            lb.TextSize = 13
            lb.TextXAlignment = Enum.TextXAlignment.Left
            lb.TextYAlignment = Enum.TextYAlignment.Top
            lb.Parent = sg
            AF.HudGui = sg

            task.spawn(function()
                while Running and AF.HudGui == sg do
                    local st = AF.Paused and "PAUSE (proses/jual)" or (AF.On and "ON" or "OFF")
                    pcall(function()
                        lb.Text = string.format(
                            " Auto Fish: %s%s\n Dapat: %d | Miss: %d | Gagal: %d\n Terakhir: %s\n Macro proses: %d kali%s",
                            st, AF.Turbo and " (Turbo)" or "",
                            AF.Caught, AF.Missed, AF.Failed,
                            tostring(AF.LastFish or "-"), PR.Runs, PR.Recording and " | REKAM" or "")
                    end)
                    task.wait(0.5)
                end
            end)
        else
            if AF.HudGui then
                AF.HudGui:Destroy()
                AF.HudGui = nil
            end
        end
    end
    AF.SetHud = setHud

-- ===================== UI =====================
FishingTab:CreateSection({ Text = "Auto Fishing" })

    FishingTab:CreateButton({
        Title = "1) Set Posisi Air",
        Description = "Pegang pancingan dulu, klik tombol ini, lalu klik di AIR (<40 stud)",
        Callback = function()
            Automation.Selecting = true
            notify("Auto Fish", "Klik di AIR sekarang!", 4)
            local conn
            conn = UserInputService.InputBegan:Connect(function(input)
                local t = input.UserInputType
                if t == Enum.UserInputType.MouseButton1 then
                    AF.Pos = UserInputService:GetMouseLocation()
                elseif t == Enum.UserInputType.Touch then
                    AF.Pos = Vector2.new(input.Position.X, input.Position.Y)
                else
                    return
                end
                Automation.Selecting = false
                notify("Auto Fish", string.format("Posisi air: %d, %d", AF.Pos.X, AF.Pos.Y), 3)
                conn:Disconnect()
            end)
            track(conn)
        end,
    })

    FishingTab:CreateButton({
        Title = "Test Klik (Cast/Reel)",
        Description = "Tes 1x klik di posisi air",
        Callback = function()
            if not AF.Pos then
                notify("Auto Fish", "Set posisi air dulu!", 3)
                return
            end
            if Automation.Busy then notify("Auto Fish", "Tunggu aksi auto selesai dulu", 3) return end
            clickPos()
        end,
    })

    FishingTab:CreateToggle({
        Title = "Auto Fish (F2)",
        Description = "Cast + reel otomatis tepat di window gigit",
        Default = false,
        Callback = function(v)
            if v and not AF.Pos then
                notify("Auto Fish", "Set posisi air dulu!", 3)
                AF.On = false
                return
            end
            AF.On = v
            if not v then AF.Cur = nil end
            notify("Auto Fish", v and ("ON | listener: " .. hooked .. " remote")
                or ("OFF | dapat: " .. AF.Caught), 3)
        end,
    })

    FishingTab:CreateToggle({
        Title = "Freeze Character",
        Description = "Kunci posisi character (sama dengan di tab Misc)",
        Default = false,
        Callback = function(v) setFreeze(v) end,
    })

    FishingTab:CreateToggle({
        Title = "Retry Reel",
        Description = "Klik reel ulang kalau window masih terbuka",
        Default = true,
        Callback = function(v) AF.Retry = v end,
    })

    FishingTab:CreateToggle({
        Title = "Mode Turbo",
        Description = "Reel 0.12s setelah window buka, jeda cast 0.2s (abaikan slider)",
        Default = false,
        Callback = function(v)
            AF.Turbo = v
            notify("Auto Fish", v and "Turbo ON" or "Turbo OFF", 2)
        end,
    })

    FishingTab:CreateSlider({
        Title = "Reel Offset (ms setelah window buka)",
        Min = 50, Max = 1500, Default = 250,
        Callback = function(v) AF.ReelOffset = v / 1000 end,
    })

    FishingTab:CreateSlider({
        Title = "Jeda Antar Cast (x0.1 detik)",
        Min = 1, Max = 30, Default = 4,
        Callback = function(v) AF.Between = v / 10 end,
    })

    FishingTab:CreateToggle({
        Title = "Auto Equip Rod",
        Description = "Tekan tombol slot rod saat cast gagal",
        Default = false,
        Callback = function(v) AF.AutoEquip = v end,
    })

    FishingTab:CreateSlider({
        Title = "Slot Rod di Toolbar (1-9)",
        Min = 1, Max = 9, Default = 1,
        Callback = function(v) AF.EquipSlot = math.floor(v) end,
    })

    FishingTab:CreateToggle({
        Title = "Hotkey F2 (On/Off Auto Fish)",
        Default = true,
        Callback = function(v) AF.Hotkey = v end,
    })

    FishingTab:CreateToggle({
        Title = "HUD Status",
        Description = "Tampilkan status fishing di layar",
        Default = false,
        Callback = function(v) setHud(v) end,
    })


    FishingTab:CreateButton({
        Title = "Lihat Tangkapan",
        Description = "Daftar lengkap ada di console (F9)",
        Callback = function()
            local rows = {}
            for id, e in pairs(AF.CatchLog) do
                rows[#rows + 1] = { id = id, n = e.n, w = e.maxW }
            end
            table.sort(rows, function(a, b) return a.n > b.n end)
            local lines = {}
            for i, r in ipairs(rows) do
                print(string.format("[Tangkapan] %s x%d | terberat %.2fkg", r.id, r.n, r.w))
                if i <= 6 then
                    lines[#lines + 1] = string.format("%s x%d (%.1fkg)", r.id, r.n, r.w)
                end
            end
            notify("Tangkapan", #rows > 0 and table.concat(lines, "\n") or "Belum ada tangkapan", 8)
        end,
    })

    FishingTab:CreateButton({
        Title = "Reset Statistik & Tangkapan",
        Callback = function()
            AF.Caught, AF.Missed, AF.Failed, AF.Reels, AF.LastFish = 0, 0, 0, 0, nil
            AF.CatchLog = {}
            PR.LastCaught = 0
            notify("Auto Fish", "Statistik direset", 2)
        end,
    })

    -- =====================================================
    -- Spy: rekam aksi manual (klik, prompt, GUI yang muncul)
    -- =====================================================
    local Spy = { On = false, Conns = {} }

    local function spyStop()
        Spy.On = false
        for _, c in ipairs(Spy.Conns) do pcall(function() c:Disconnect() end) end
        Spy.Conns = {}
    end
    AF.SpyStop = spyStop

    local SPY_SKIP = {
        W = true, A = true, S = true, D = true, Space = true,
        LeftShift = true, LeftControl = true, Unknown = true,
    }

    local function spyStart()
        spyStop()
        Spy.On = true
        plog("==== SPY AKTIF. Lakukan proses / jual ikan MANUAL sekarang ====")
        local mouse = player:GetMouse()

        Spy.Conns[#Spy.Conns + 1] = UserInputService.InputBegan:Connect(function(input, gp)
            local t = input.UserInputType
            if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
                local loc = UserInputService:GetMouseLocation()
                local tgt = mouse.Target
                local names = {}
                local pg = player:FindFirstChild("PlayerGui")
                if pg then
                    local okG, objs = pcall(function()
                        return pg:GetGuiObjectsAtPosition(loc.X, loc.Y - GuiService:GetGuiInset().Y)
                    end)
                    if okG and objs then
                        for _, g in ipairs(objs) do
                            names[#names + 1] = g:GetFullName() .. " (" .. g.ClassName .. ")"
                            if #names >= 4 then break end
                        end
                    end
                end
                plog(string.format("[SPY] KLIK (%d,%d) gp=%s | dunia: %s | hit: %s | GUI: %s",
                    loc.X, loc.Y, tostring(gp), tgt and tgt:GetFullName() or "nil",
                    tostring(mouse.Hit and mouse.Hit.Position or "nil"),
                    #names > 0 and table.concat(names, " ; ") or "-"))
                local h = getHRP()
                if h then plog("[SPY] posisi char:", tostring(h.Position)) end
            elseif t == Enum.UserInputType.Keyboard then
                if not SPY_SKIP[input.KeyCode.Name] then
                    plog("[SPY] KEY", input.KeyCode.Name, "gp=" .. tostring(gp))
                end
            end
        end)

        pcall(function()
            local PPS = game:GetService("ProximityPromptService")
            Spy.Conns[#Spy.Conns + 1] = PPS.PromptTriggered:Connect(function(pr)
                plog("[SPY] PROMPT DITEKAN:", pr:GetFullName(), "| aksi:", pr.ActionText,
                    "| obj:", pr.ObjectText, "| hold:", pr.HoldDuration)
            end)
            Spy.Conns[#Spy.Conns + 1] = PPS.PromptShown:Connect(function(pr)
                plog("[SPY] prompt muncul:", pr:GetFullName(), "|", pr.ActionText)
            end)
        end)

        task.spawn(function()
            local last = {}
            while Running and Spy.On do
                local cur = {}
                local pg = player:FindFirstChild("PlayerGui")
                if pg then
                    for _, d in ipairs(pg:GetDescendants()) do
                        if d:IsA("GuiObject") then
                            local nm = d.Name:lower()
                            if (nm:find("fish") or nm:find("fridge") or nm:find("cut")
                                or nm:find("sell") or nm:find("station") or nm:find("market")
                                or nm:find("shop") or nm:find("confirm"))
                                and d.AbsoluteSize.X > 0 and isShown(d) then
                                cur[d:GetFullName()] = d.ClassName .. " " .. d.AbsoluteSize.X .. "x" .. d.AbsoluteSize.Y
                            end
                        end
                    end
                end
                local printed = 0
                for k, v in pairs(cur) do
                    if not last[k] and printed < 25 then
                        printed += 1
                        plog("[SPY] GUI muncul:", k, "|", v)
                    end
                end
                for k in pairs(last) do
                    if not cur[k] and printed < 25 then
                        printed += 1
                        plog("[SPY] GUI hilang:", k)
                    end
                end
                last = cur
                task.wait(0.5)
            end
        end)
    end

    -- =====================================================
    -- UI : MACRO PROSES IKAN
    -- =====================================================
    FishingTab:CreateSection({ Text = "Proses Ikan" })

    FishingTab:CreateButton({
        Title = "1. Set Posisi GUI",
        Description = "Klik sekali di tombol proses ikan",
        Callback = function()
            if AF.MacroSetGui then AF.MacroSetGui() end
        end,
    })

    FishingTab:CreateButton({
        Title = "2. Rekam / Stop Station (F3)",
        Description = "Tekan E di tiap station saja",
        Callback = function()
            if AF.MacroToggleRec then AF.MacroToggleRec() end
        end,
    })

    FishingTab:CreateButton({
        Title = "3. Putar / Stop (F4)",
        Description = "Jalan = stop | Idle = putar",
        Callback = function()
            if PR.Busy or PR.Requested then
                if AF.MacroStopPlay then AF.MacroStopPlay() end
            else
                task.spawn(function()
                    if AF.MacroPlay then AF.MacroPlay() end
                end)
            end
        end,
    })

    FishingTab:CreateToggle({
        Title = "Auto Putar",
        Description = "ON = ulang terus sampai Stop",
        Default = false,
        Callback = function(v)
            PR.Auto = v
            if v then
                if #PR.Steps == 0 or not PR.GuiClickPos then
                    notify("Macro", "Set GUI + rekam station dulu", 3)
                    PR.Auto = false
                    return
                end
                if not PR.Busy then
                    task.spawn(function()
                        if AF.MacroPlay then AF.MacroPlay() end
                    end)
                end
            else
                PR.Stop = true
            end
        end,
    })

    FishingTab:CreateSlider({
        Title = "Speed Pindah",
        Description = "1 lambat | 10 cepat",
        Min = 1,
        Max = 10,
        Default = 6,
        Callback = function(v)
            PR.Speed=v
            local t = (11 - v) / 10
            PR.MoveWait   = 0.05 + t * 0.25
            PR.StepWait   = 0.04 + t * 0.10
            PR.GuiWait    = 0.40 + t * 0.50
            PR.AfterClick = 0.20 + t * 0.30
        end,
    })

    FishingTab:CreateButton({
        Title = "Hapus Station Saja",
        Description = "GUI tetap tersimpan",
        Callback = function()
            PR.Steps = {}
            PR.Requested = false
            PR.NextStep = 1
            PR.Stop = true
            notify("Macro", "Station dihapus", 2)
        end,
    })
    -- =====================================================
    -- UI : DIAGNOSA
    -- =====================================================
    FishingTab:CreateSection({ Text = "Diagnosa (Spy)" })

    FishingTab:CreateToggle({
        Title = "Rekam Aksi (Spy)",
        Description = "Nyalakan, lalu proses/jual ikan MANUAL. Hasil di console (F9)",
        Default = false,
        Callback = function(v)
            if v then
                spyStart()
            else
                spyStop()
                plog("==== SPY BERHENTI ====")
            end
        end,
    })

    FishingTab:CreateButton({
        Title = "Dump GUI Sekarang",
        Description = "Buka GUI proses/jual dulu, lalu tekan ini",
        Callback = function()
            dumpGui("manual")
            notify("Dump GUI", "Selesai. Lihat console (F9)", 3)
        end,
    })

    FishingTab:CreateButton({
        Title = "Salin Log ke Clipboard",
        Description = "Paste hasilnya ke chat",
        Callback = function()
            local txt = table.concat(LogBuf, "\n")
            if setclipboard then
                pcall(setclipboard, txt)
                notify("Log", "Disalin (" .. #LogBuf .. " baris). Paste ke chat.", 4)
            else
                notify("Log", "setclipboard tidak ada. Ambil dari console (F9).", 4)
            end
        end,
    })

    if hooked == 0 then
        notify("Auto Fish", "Folder ReplicatedStorage.Network tidak ketemu, listener tidak aktif", 5)
    end
end

-- =========================================================
-- AUTO TAB : AUTO CLICK UI
-- =========================================================
Automation:BuildUI()

AutoTab:CreateSection({ Text = "Auto Click UI" })

AutoTab:CreateToggle({
    Title = "Auto Click UI",
    Description = "Klik berulang di posisi UI",
    Default = false,
    Callback = function(v)
        AutoClickUI = v
        if v and #UIClickPositions == 0 then
            notify("Auto Click UI", "Tambah posisi click dulu!", 3)
            AutoClickUI = false
        end
    end,
})

AutoTab:CreateSlider({
    Title = "Click Delay",
    Min = 0.1, Max = 3, Default = 0.4,
    Callback = function(v) UIClickDelay = v end,
})

AutoTab:CreateButton({
    Title = "Tambah Posisi Click",
    Description = "Klik di UI setelah tekan tombol ini",
    Callback = function()
        if IsSettingUIClick then return end
        if #UIClickPositions>=16 then notify("Auto Click","Batas 16 posisi",3) return end
        IsSettingUIClick = true
        notify("Auto Click UI", "Klik di UI SEKARANG!", 4)
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local pos = UserInputService:GetMouseLocation()
                table.insert(UIClickPositions, pos)
                notify("Auto Click UI", string.format("Posisi #%d (%d, %d)", #UIClickPositions, pos.X, pos.Y), 3)
                IsSettingUIClick = false
                conn:Disconnect()
            end
        end)
        track(conn)
    end,
})

AutoTab:CreateButton({
    Title = "Hapus Semua Posisi Click",
    Callback = function()
        UIClickPositions = {}
        AutoClickUI = false
        notify("Auto Click UI", "Semua posisi dihapus", 2)
    end,
})

-- =========================================================
-- AUTO TAB : AUTO CLAIM
-- =========================================================
AutoTab:CreateSection({ Text = "Auto Claim" })

AutoTab:CreateToggle({
    Title = "Auto Claim Meteor",
    Description = "Claim CarnivalCrate di __DEBRIS",
    Default = false,
    Callback = function(v)
        AutoClaimMeteor = v
        if v then ClaimedMeteors = {} end
    end,
})

-- =========================================================
-- AUTO TAB : AUTO PRESS KEY
-- =========================================================
AutoTab:CreateSection({ Text = "Auto Press Key" })

AutoTab:CreateToggle({
    Title = "Auto Press Key",
    Description = "Tekan tombol keyboard berulang (default: E)",
    Default = false,
    Callback = function(v)
        AutoPressKey = v
        if v then
            notify("Auto Press Key", "ON — " .. PressKeyName .. " | Delay: " .. tostring(PressKeyDelay), 3)
        else
            notify("Auto Press Key", "OFF", 2)
        end
    end,
})

-- Slider skala 0.01 (2 = 0.02 detik, 8 = 0.08, 100 = 1.00)
AutoTab:CreateSlider({
    Title = "Press Delay (x0.01 detik)",
    Min = 1,
    Max = 200,
    Default = 8,
    Callback = function(v) PressKeyDelay = v / 100 end,
})

safeCreateInput(AutoTab, {
    Title = "Delay Manual (detik)",
    Name = "Press Delay Manual",
    Placeholder = "Contoh: 0.05 / 0.08 / 0.12",
    PlaceholderText = "Contoh: 0.05 / 0.08 / 0.12",
    Default = "0.08",
    Callback = function(text)
        local n = tonumber((tostring(text):gsub(",", "."))) -- support koma 0,05
        if n and n >= 0.01 and n <= 2 then
            PressKeyDelay = n
            notify("Delay", "Set ke " .. tostring(n) .. " detik", 2)
        else
            notify("Delay", "Isi angka 0.01 - 2 (contoh: 0.05)", 3)
        end
    end,
})

AutoTab:CreateButton({
    Title = "Set Key (default: E)",
    Description = "Klik lalu tekan 1 tombol keyboard",
    Callback = function()
        if IsSettingPressKey then return end
        IsSettingPressKey = true
        notify("Auto Press Key", "Tekan 1 tombol keyboard SEKARANG!", 4)
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                PressKeyCode = input.KeyCode
                PressKeyName = input.KeyCode.Name
                IsSettingPressKey = false
                conn:Disconnect()
                notify("Auto Press Key", "Tombol: " .. PressKeyName, 3)
            end
        end)
        track(conn)
    end,
})

-- =========================================================
-- MISC TAB
-- =========================================================
MiscTab:CreateSection({ Text = "ESP Player" })

MiscTab:CreateToggle({
    Title = "ESP Player",
    Description = "Highlight + nama player di atas kepala",
    Default = false,
    Callback = function(v)
        espPlayerActive = v
        if not v then
            for _, c in ipairs(playerESPFolder:GetChildren()) do c:Destroy() end
        end
    end,
})

-- ---------- Teleport Player (refresh diperbaiki) ----------
MiscTab:CreateSection({ Text = "Teleport Player" })

do
    local function getPlayerOptions()
        local opts = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then table.insert(opts, plr.Name) end
        end
        table.sort(opts)
        if #opts == 0 then table.insert(opts, "(No players)") end
        return opts
    end

    local function setSelected(name)
        getgenv().SeeLeooo_SelectedPlayer = name
    end

    -- cari player dari nama persis / sebagian nama / display name
    local function resolvePlayer(q)
        if not q or q == "" or q == "(No players)" then return nil end
        local exact = Players:FindFirstChild(q)
        if exact and exact:IsA("Player") then return exact end
        local ql = q:lower()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                if plr.Name:lower():find(ql, 1, true) or plr.DisplayName:lower():find(ql, 1, true) then
                    return plr
                end
            end
        end
        return nil
    end

    local playerDropdown = MiscTab:CreateDropdown({
        Title = "Select Player",
        Description = "Pilih player target",
        Options = getPlayerOptions(),
        Multiple = false,
        Callback = function(selected)
            setSelected(type(selected) == "table" and selected[1] or selected)
        end,
    })

    local dumped = false
    local METHODS = {
        "SetOptions", "UpdateOptions", "Refresh", "RefreshOptions", "SetValues",
        "SetList", "SetItems", "UpdateList", "Update", "Reload", "Set",
    }

    local function refreshPlayerDropdown(silent)
        local opts = getPlayerOptions()
        getgenv().SeeLeooo_PlayerList = opts

        local used
        if playerDropdown then
            pcall(function()
                if playerDropdown.Options ~= nil then
                    playerDropdown.Options = opts
                    used = "Options"
                end
            end)
            for _, m in ipairs(METHODS) do
                if used then break end
                local okf, f = pcall(function() return playerDropdown[m] end)
                if okf and type(f) == "function" then
                    if pcall(f, playerDropdown, opts) or pcall(f, opts) then
                        used = m
                    end
                end
            end
        end

        if opts[1] and opts[1] ~= "(No players)" then
            local cur = getgenv().SeeLeooo_SelectedPlayer
            if not cur or not Players:FindFirstChild(cur) then
                setSelected(opts[1])
            end
        end

        if not silent then
            notify("Player List", string.format("%d player | Target: %s%s",
                (opts[1] == "(No players)") and 0 or #opts,
                tostring(getgenv().SeeLeooo_SelectedPlayer or "-"),
                used and (" via " .. used) or " | pakai ▶◀"), 4)
        end
        return true
    end

    MiscTab:CreateButton({
        Title = "🔄 Refresh Player List",
        Callback = function() refreshPlayerDropdown(false) end,
    })

    -- Cadangan 1: pilih player dengan tombol berikutnya / sebelumnya (selalu pakai data live)
    local cycleIdx = 0
    local function cyclePlayer(dir)
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then list[#list + 1] = plr.Name end
        end
        table.sort(list)
        if #list == 0 then
            notify("Player", "Tidak ada player lain", 2)
            return
        end
        cycleIdx = ((cycleIdx - 1 + dir) % #list) + 1
        setSelected(list[cycleIdx])
        notify("Player", string.format("Target: %s (%d/%d)", list[cycleIdx], cycleIdx, #list), 2)
    end

    MiscTab:CreateButton({
        Title = "Player Berikutnya ▶",
        Description = "Pilih target dari daftar player yang ada sekarang",
        Callback = function() cyclePlayer(1) end,
    })

    MiscTab:CreateButton({
        Title = "◀ Player Sebelumnya",
        Callback = function() cyclePlayer(-1) end,
    })

    -- Cadangan 2: ketik sebagian nama / display name
    safeCreateInput(MiscTab, {
        Title = "Cari Player (ketik nama)",
        Name = "Cari Player",
        Placeholder = "Sebagian nama / display name",
        PlaceholderText = "Sebagian nama / display name",
        Default = "",
        Callback = function(text)
            local plr = resolvePlayer(trim(text))
            if plr then
                setSelected(plr.Name)
                notify("Player", "Target: " .. plr.Name, 2)
            else
                notify("Player", "Player tidak ditemukan", 3)
            end
        end,
    })

    MiscTab:CreateButton({
        Title = "🚀 Teleport to Selected Player",
        Callback = function()
            local plr = resolvePlayer(getgenv().SeeLeooo_SelectedPlayer)
            if not plr then
                notify("Teleport", "Pilih player dulu (atau player sudah keluar)", 3)
                return
            end
            local hrp = plr.Character and (plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character.PrimaryPart)
            local myHRP = getHRP()
            if hrp and myHRP then
                myHRP.CFrame = hrp.CFrame * CFrame.new(0, 0, 3)
                notify("Teleport", "Teleport ke " .. plr.Name, 2)
            else
                notify("Teleport", "Character belum load", 3)
            end
        end,
    })

    -- daftar otomatis ke-update saat ada yang masuk / keluar
    track(Players.PlayerAdded:Connect(function()
        task.delay(1, function() refreshPlayerDropdown(true) end)
    end))
    track(Players.PlayerRemoving:Connect(function()
        task.delay(0.5, function() refreshPlayerDropdown(true) end)
    end))
end

-- ---------- Teleport CFrame ----------
MiscTab:CreateSection({ Text = "Teleport CFrame" })

safeCreateInput(MiscTab, {
    Title = "CFrame / Position",
    Name = "CFrame Input",
    Placeholder = "10, 20, 30  atau  CFrame.new(10,20,30)",
    PlaceholderText = "10, 20, 30  atau  CFrame.new(10,20,30)",
    Default = "",
    Callback = function(text)
        cframeInput = tostring(text or "")
        notify("CFrame", "Input tersimpan", 2)
    end,
})

MiscTab:CreateButton({
    Title = "🚀 Teleport to CFrame",
    Callback = function()
        if cframeInput == "" then
            notify("Teleport", "Isi CFrame dulu di input atas!", 3)
            return
        end
        local hrp = getHRP()
        if not hrp then
            notify("Teleport", "Character tidak ditemukan", 3)
            return
        end
        local success, result = pcall(function()
            if cframeInput:lower():find("cframe") then
                return loadstring("return " .. cframeInput)()
            end
            local nums = {}
            for num in cframeInput:gmatch("[-%d%.]+") do
                table.insert(nums, tonumber(num))
            end
            if #nums >= 3 then
                return CFrame.new(nums[1], nums[2], nums[3])
            end
            error("invalid")
        end)
        if success and typeof(result) == "CFrame" then
            hrp.CFrame = result
            notify("Teleport", "Berhasil!", 2)
        else
            notify("Teleport", "Format salah!\nContoh: 10, 20, 30", 4)
        end
    end,
})

-- ---------- Waypoint ----------
MiscTab:CreateSection({ Text = "Waypoint" })

do
    local function curWP() return WP.List[WP.Idx] end

    safeCreateInput(MiscTab, {
        Title = "Nama Waypoint",
        Name = "Nama Waypoint",
        Placeholder = "Contoh: Air, Station, Jual",
        PlaceholderText = "Contoh: Air, Station, Jual",
        Default = "",
        Callback = function(text) WP.NameInput = trim(text) end,
    })

    MiscTab:CreateButton({
        Title = "💾 Simpan Waypoint (posisi sekarang)",
        Callback = function()
            local hrp = getHRP()
            if not hrp then notify("Waypoint", "Character tidak ditemukan", 3) return end
            local name = WP.NameInput ~= "" and WP.NameInput or ("WP" .. (#WP.List + 1))
            for i, w in ipairs(WP.List) do
                if w.Name == name then
                    w.CF = hrp.CFrame
                    WP.Idx = i
                    notify("Waypoint", "Diperbarui: " .. name, 2)
                    return
                end
            end
            WP.List[#WP.List + 1] = { Name = name, CF = hrp.CFrame }
            WP.Idx = #WP.List
            notify("Waypoint", string.format("Disimpan: %s (%d total)", name, #WP.List), 2)
        end,
    })

    MiscTab:CreateButton({
        Title = "Waypoint Berikutnya ▶",
        Callback = function()
            if #WP.List == 0 then notify("Waypoint", "Belum ada waypoint", 2) return end
            WP.Idx = (WP.Idx % #WP.List) + 1
            notify("Waypoint", string.format("%s (%d/%d)", curWP().Name, WP.Idx, #WP.List), 2)
        end,
    })

    MiscTab:CreateButton({
        Title = "◀ Waypoint Sebelumnya",
        Callback = function()
            if #WP.List == 0 then notify("Waypoint", "Belum ada waypoint", 2) return end
            WP.Idx = ((WP.Idx - 2) % #WP.List) + 1
            notify("Waypoint", string.format("%s (%d/%d)", curWP().Name, WP.Idx, #WP.List), 2)
        end,
    })

    MiscTab:CreateButton({
        Title = "🚀 Teleport ke Waypoint Terpilih",
        Callback = function()
            local w = curWP()
            if not w then notify("Waypoint", "Belum ada waypoint terpilih", 2) return end
            local hrp = getHRP()
            if hrp then
                hrp.CFrame = w.CF
                notify("Waypoint", "Teleport ke " .. w.Name, 2)
            end
        end,
    })

    MiscTab:CreateButton({
        Title = "📋 Daftar Waypoint",
        Callback = function()
            if #WP.List == 0 then notify("Waypoint", "Belum ada waypoint", 2) return end
            local names = {}
            for i, w in ipairs(WP.List) do
                names[#names + 1] = (i == WP.Idx and "> " or "") .. w.Name
            end
            notify("Waypoint", table.concat(names, "\n"), 6)
        end,
    })

    MiscTab:CreateButton({
        Title = "🗑 Hapus Waypoint Terpilih",
        Callback = function()
            local w = curWP()
            if not w then notify("Waypoint", "Belum ada waypoint terpilih", 2) return end
            table.remove(WP.List, WP.Idx)
            WP.Idx = #WP.List > 0 and math.min(WP.Idx, #WP.List) or 0
            notify("Waypoint", "Dihapus: " .. w.Name, 2)
        end,
    })
end

-- ---------- Freecam ----------
MiscTab:CreateSection({ Text = "Freecam" })

MiscTab:CreateToggle({
    Title = "Freecam",
    Description = "F1 Start/Stop — character tidak ikut gerak",
    Default = false,
    Callback = function(v)
        if v then startFreecam() else stopFreecam() end
    end,
})

MiscTab:CreateSlider({
    Title = "Freecam Speed",
    Min = 1, Max = 10, Default = 2,
    Callback = function(v) freecamSpeed = v end,
})

MiscTab:CreateButton({
    Title = "▶ Start Freecam (F1)",
    Callback = function() startFreecam() end,
})

MiscTab:CreateButton({
    Title = "⏹ Stop Freecam (F1)",
    Callback = function() stopFreecam() end,
})

-- ---------- Movement ----------
MiscTab:CreateSection({ Text = "Movement" })

MiscTab:CreateToggle({
    Title = "Freeze Character",
    Description = "Kunci posisi character (sama dengan di tab RAR)",
    Default = false,
    Callback = function(v) setFreeze(v) end,
})

MiscTab:CreateToggle({
    Title = "Infinite Jump",
    Default = false,
    Callback = function(v) infiniteJumpActive = v end,
})

MiscTab:CreateSlider({
    Title = "Walk Speed",
    Min = 16, Max = 300, Default = 16,
    Callback = function(v)
        walkSpeedVal = v
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})

MiscTab:CreateSlider({
    Title = "Jump Power",
    Min = 50, Max = 300, Default = 50,
    Callback = function(v)
        jumpPowerVal = v
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v
        end
    end,
})

MiscTab:CreateButton({
    Title = "NoClip = Hold Z",
    Description = "Tahan Z untuk tembus tembok",
    Callback = function()
        notify("NoClip", "Tahan Z", 3)
    end,
})

-- =========================================================
-- SETTINGS
-- =========================================================
SettingsTab:CreateSection({ Text = "Utility" })

SettingsTab:CreateToggle({
    Title = "Anti AFK",
    Default = false,
    Callback = function(v)
        antiAfkActive = v
        if v then notify("Anti AFK", "Aktif!", 2) end
    end,
})

SettingsTab:CreateToggle({
    Title = "Auto Rejoin (kalau disconnect/kick)",
    Description = "Rejoin otomatis. Taruh script di folder autoexec biar jalan lagi",
    Default = false,
    Callback = function(v)
        Opt.AutoRejoin = v
        notify("Auto Rejoin", v and "ON" or "OFF", 2)
    end,
})

SettingsTab:CreateToggle({
    Title = "Mode Hemat (3D off, grafik rendah)",
    Description = "Layar kosong, FPS dibatasi. Cocok buat AFK",
    Default = false,
    Callback = function(v)
        setLowGfx(v)
        notify("Mode Hemat", v and "ON" or "OFF", 2)
    end,
})

SettingsTab:CreateSection({ Text = "Setelan" })

Profiles.Input=SettingsTab:CreateTextBox({
    Title="Nama Profil",Default="Default",Placeholder="Contoh: Farm Malam",MaxLength=64,
    Callback=function(value) Profiles.Name=trim(value) end,
})
Profiles.Dropdown=SettingsTab:CreateDropdown({
    Title="Pilih Profil",Options=Profiles:Names(),Default="Default",
    AutoReload=function() return Profiles:Names() end,
    Callback=function(value)
        local name=type(value)=="table" and value[1] or value
        if type(name)=="string" then Profiles:Choose(name) end
    end,
})
SettingsTab:CreateButton({Title="Simpan Profil",Description="Simpan konfigurasi dan fitur aktif dengan nama di atas",Callback=saveSettings})
SettingsTab:CreateButton({Title="Muat Profil",Description="Terapkan profil pilihan beserta toggle dan nilai tampilannya",Callback=loadSettings})

SettingsTab:CreateSection({ Text = "Server" })

SettingsTab:CreateButton({
    Title = "🔄 Rejoin Server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, player)
    end,
})

SettingsTab:CreateButton({
    Title = "🌐 Hop Server (Sepi)",
    Callback = function()
        notify("Hop", "Mencari server sepi...", 3)
        local ok, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            ))
        end)
        if ok and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                    return
                end
            end
        end
        notify("Hop", "Gagal menemukan server sepi")
    end,
})

local function unloadScript()
        Automation:Shutdown()
        restoreNoClip()
        if Automation.CropGui then Automation.CropGui:Destroy() end
        Running = false -- hentikan semua loop
        stopFreecam()

        espPlayerActive = false
        infiniteJumpActive = false
        noClipActive = false
        antiAfkActive = false
        AF.On = false
        AF.Cur = nil
        PR.On = false
        Opt.AutoRejoin = false
        AutoClickUI = false
        AutoClaimMeteor = false
        AutoHarvest = false
        AutoPressKey = false
        setFreeze(false, true)
        if Opt.LowGfx then setLowGfx(false) end
        if AF.HudGui then pcall(function() AF.HudGui:Destroy() end) AF.HudGui = nil end
        if AF.SpyStop then pcall(AF.SpyStop) end
        if AF.MacroStop then pcall(AF.MacroStop) end

        playerESPFolder:Destroy()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        pcall(function() Window:Destroy() end)
        notify("SeeLeooo", "Unloaded", 2)
end

SettingsTab:CreateButton({Title="Unload Script", Callback=unloadScript})

-- =========================================================
-- AUTO REJOIN (hook error/kick)
-- =========================================================
local function doRejoin()
    if not Running or not Opt.AutoRejoin or Opt.Rejoining then return end
    local message=""
    pcall(function() message=GuiService:GetErrorMessage() end)
    message=message:lower()
    if not (message:find("disconnect",1,true) or message:find("kicked",1,true) or
        message:find("connection",1,true) or message:find("error code: 277",1,true) or message:find("error code: 279",1,true)) then return end
    if Opt.LastRejoin and os.clock()-Opt.LastRejoin<60 then return end
    Opt.LastRejoin=os.clock()
    Opt.Rejoining = true
    notify("Auto Rejoin", "Terputus, rejoin dalam 3 detik...", 3)
    task.wait(3)
    if not Running or not Opt.AutoRejoin then Opt.Rejoining=false return end
    pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
    task.wait(10)
    Opt.Rejoining = false
end

pcall(function()
    track(GuiService.ErrorMessageChanged:Connect(function()
        local msg = ""
        pcall(function() msg = GuiService:GetErrorMessage() end)
        if msg and msg ~= "" then doRejoin() end
    end))
end)

task.spawn(function()
    pcall(function()
        local gui = CoreGui:WaitForChild("RobloxPromptGui", 5)
        local ov = gui and gui:WaitForChild("promptOverlay", 5)
        if ov then
            track(ov.ChildAdded:Connect(function(c)
                if c.Name == "ErrorPrompt" then doRejoin() end
            end))
        end
    end)
end)

-- =========================================================
-- KEYBINDS
-- =========================================================
track(UserInputService.InputBegan:Connect(function(input, gp)
    -- tombol gerak freecam hanya dicatat saat freecam aktif
    if freecamActive then
        if input.KeyCode == Enum.KeyCode.W then freecamKeys.W = true end
        if input.KeyCode == Enum.KeyCode.A then freecamKeys.A = true end
        if input.KeyCode == Enum.KeyCode.S then freecamKeys.S = true end
        if input.KeyCode == Enum.KeyCode.D then freecamKeys.D = true end
        if input.KeyCode == Enum.KeyCode.Q then freecamKeys.Q = true end
        if input.KeyCode == Enum.KeyCode.E then freecamKeys.E = true end
        if input.KeyCode == Enum.KeyCode.LeftShift then freecamKeys.LeftShift = true end
    end

    if gp then return end

    if input.KeyCode == Enum.KeyCode.F1 then
        toggleFreecam()
    end

    -- F2 = on/off Auto Fish
    if input.KeyCode == Enum.KeyCode.F2 and AF.Hotkey then
        if AF.On then
            AF.On = false
            AF.Cur = nil
            notify("Auto Fish", "OFF (F2) | dapat: " .. AF.Caught, 2)
        elseif AF.Pos then
            AF.On = true
            notify("Auto Fish", "ON (F2)", 2)
        else
            notify("Auto Fish", "Set posisi air dulu!", 3)
        end
    end

    -- F3 = mulai/stop rekam macro, F4 = putar macro
    if input.KeyCode == Enum.KeyCode.F3 and AF.MacroToggleRec then
        AF.MacroToggleRec()
    end
    if input.KeyCode == Enum.KeyCode.F4 then
        if PR.Busy or PR.Requested then
            if AF.MacroStopPlay then AF.MacroStopPlay() end
        elseif AF.MacroPlay then
            task.spawn(AF.MacroPlay)
        end
    end
    if input.KeyCode == Enum.KeyCode.Z then
        noClipActive = true
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then freecamKeys.W = false end
    if input.KeyCode == Enum.KeyCode.A then freecamKeys.A = false end
    if input.KeyCode == Enum.KeyCode.S then freecamKeys.S = false end
    if input.KeyCode == Enum.KeyCode.D then freecamKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Q then freecamKeys.Q = false end
    if input.KeyCode == Enum.KeyCode.E then freecamKeys.E = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then freecamKeys.LeftShift = false end

    if input.KeyCode == Enum.KeyCode.Z then
        noClipActive = false
        restoreNoClip()
    end
end))

track(RunService.Stepped:Connect(updateNoClip))

track(UserInputService.JumpRequest:Connect(function()
    if infiniteJumpActive then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

track(player.Idled:Connect(function()
    if antiAfkActive then
        Automation.AfkRequested = true
    end
end))

track(player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if FreezeCharacter then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = true
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end
end))

-- =========================================================
-- ESP PLAYER (Highlight + Billboard Nama + Jarak)
-- =========================================================
local function clearPlayerESP()
    for _, c in ipairs(playerESPFolder:GetChildren()) do
        c:Destroy()
    end
end

local function createPlayerESP(plr)
    if plr == player or not plr.Character then return end
    local char = plr.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "HL_" .. plr.Name
    hl.Adornee = char
    hl.FillColor = Color3.fromRGB(0, 255, 100)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.65
    hl.OutlineTransparency = 0
    hl.Parent = playerESPFolder

    -- Billboard Nama
    local bgui = Instance.new("BillboardGui")
    bgui.Name = "Name_" .. plr.Name
    bgui.Adornee = hrp
    bgui.Size = UDim2.new(0, 160, 0, 40)
    bgui.StudsOffset = Vector3.new(0, 3.2, 0)
    bgui.AlwaysOnTop = true
    bgui.MaxDistance = math.huge
    bgui.Parent = playerESPFolder

    local frame = Instance.new("Frame", bgui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0

    local txt = Instance.new("TextLabel", frame)
    txt.Name = "Label"
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.fromRGB(0, 255, 120)
    txt.TextStrokeTransparency = 0.3
    txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 13
    txt.Text = plr.Name .. "\n0 m"
end

local function refreshPlayerESP()
    if not espPlayerActive then clearPlayerESP() return end
    for _,child in ipairs(playerESPFolder:GetChildren()) do
        local name=child.Name:match("^HL_(.+)") or child.Name:match("^Name_(.+)")
        local plr=name and Players:FindFirstChild(name)
        if name and (not plr or not plr.Character or child:IsA("Highlight") and child.Adornee~=plr.Character) then child:Destroy() end
    end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=player and not playerESPFolder:FindFirstChild("HL_"..plr.Name) then
            local old=playerESPFolder:FindFirstChild("Name_"..plr.Name) if old then old:Destroy() end
            createPlayerESP(plr)
        end
    end
end

-- Update jarak nama player (5 Hz).
local espElapsed=0
track(RunService.RenderStepped:Connect(function(dt)
    espElapsed+=dt
    if espElapsed<0.2 then return end
    espElapsed=0
    if not espPlayerActive then return end
    local myHRP = getHRP()
    if not myHRP then return end
    local myPos = myHRP.Position

    for _, child in ipairs(playerESPFolder:GetChildren()) do
        if child:IsA("BillboardGui") and child.Name:sub(1, 5) == "Name_" then
            local label = child:FindFirstChild("Label", true)
            local adornee = child.Adornee
            if label and adornee and adornee:IsA("BasePart") then
                local dist = (adornee.Position - myPos).Magnitude
                local name = child.Name:sub(6)
                label.Text = string.format("%s\n%d m", name, math.floor(dist))
            end
        end
    end
end))

task.spawn(function()
    while Running do
        task.wait(2)
        if espPlayerActive then refreshPlayerESP() end
    end
end)

track(Players.PlayerAdded:Connect(function(plr)
    track(plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if espPlayerActive then refreshPlayerESP() end
    end))
end))

track(Players.PlayerRemoving:Connect(function()
    task.wait(0.3)
    if espPlayerActive then refreshPlayerESP() end
end))

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then
        track(plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            if espPlayerActive then refreshPlayerESP() end
        end))
    end
end

-- =========================================================
-- Semua auto menggunakan worker bersama (lihat SHARED AUTOMATION).
-- =========================================================

-- Runtime getters also keep hotkeys, Play/Stop, and duplicated Freeze toggles honest.
do
    local getters={
        ["Auto Fish (F2)"]=function() return AF.On end,
        ["Freeze Character"]=function() return FreezeCharacter end,
        ["Retry Reel"]=function() return AF.Retry end,
        ["Mode Turbo"]=function() return AF.Turbo end,
        ["Reel Offset (ms setelah window buka)"]=function() return AF.ReelOffset*1000 end,
        ["Jeda Antar Cast (x0.1 detik)"]=function() return AF.Between*10 end,
        ["Auto Equip Rod"]=function() return AF.AutoEquip end,
        ["Slot Rod di Toolbar (1-9)"]=function() return AF.EquipSlot end,
        ["Hotkey F2 (On/Off Auto Fish)"]=function() return AF.Hotkey end,
        ["HUD Status"]=function() return AF.HudGui~=nil end,
        ["Auto Putar"]=function() return PR.Auto and not PR.Stop end,
        ["Speed Pindah"]=function() return PR.Speed or 6 end,
        ["Auto Click UI"]=function() return AutoClickUI end,
        ["Click Delay"]=function() return UIClickDelay end,
        ["Auto Claim Meteor"]=function() return AutoClaimMeteor end,
        ["Auto Press Key"]=function() return AutoPressKey end,
        ["Press Delay (x0.01 detik)"]=function() return PressKeyDelay*100 end,
        ["Delay Manual (detik)"]=function() return tostring(PressKeyDelay) end,
        ["Jeda Cek Fridge (detik)"]=function() return Automation.SellInterval end,
        ["Target Stok Rendah"]=function() return Automation.LowStockTarget end,
        ["Freecam"]=function() return freecamActive end,
        ["Freecam Speed"]=function() return freecamSpeed end,
        ["Infinite Jump"]=function() return infiniteJumpActive end,
        ["Walk Speed"]=function() return walkSpeedVal end,
        ["Jump Power"]=function() return jumpPowerVal end,
        ["ESP Player"]=function() return espPlayerActive end,
        ["Anti AFK"]=function() return antiAfkActive end,
        ["Auto Rejoin (kalau disconnect/kick)"]=function() return Opt.AutoRejoin end,
        ["Mode Hemat (3D off, grafik rendah)"]=function() return Opt.LowGfx end,
    }
    for _,entry in ipairs(SettingsUI.Controls) do
        if getters[entry.title] then entry.get=getters[entry.title] end
    end
end
Automation:SyncUI()

SeeLeoooEnv.SeeLeoooRuntime = {Unload=unloadScript, Busy=function() return Automation.Busy or Automation.SaleInFlight~=nil end}
-- Pemulihan UI tersangkut: tutup fridge/dialog buatan script kalau macet
do
    local A = Automation

    -- 1) catat kalau fridge dibuka oleh script
    local baseOpenFridge = A.OpenFridge
    function A:OpenFridge(payload, token)
        local wasOpen = self:GameGui("Fridge") ~= nil
        local gui = baseOpenFridge(self, payload, token)
        if not wasOpen and (gui or self:GameGui("Fridge")) then
            self.OwnedFridgeAt = os.clock()
        end
        return gui
    end

    -- 2) tutup paksa dialog + fridge
    function A:ForceCloseModals()
        self.Status = "Fridge: menutup UI yang tersangkut"
        plog("FRIDGE", "watchdog menutup UI yang tersangkut")
        pcall(function() self:CancelSaleDialogs() end)
        if self:GameGui("Fridge") then
            pcall(function() self:CloseNativeQuest("Fridge") end)
        end
        -- cadangan terakhir: sembunyikan langsung
        for _, name in ipairs({ "Message", "TextInput", "Fridge" }) do
            local g = self:GameGui(name)
            if g then pcall(function() g.Enabled = false end) end
        end
        self.OwnedFridgeAt = nil
        self.OwnedTextBox = nil
        -- beri jeda supaya job jual tidak langsung mengulang
        for _, job in ipairs(self.Jobs) do
            if job.id == "sell" or job.id == "inventory" then
                job.nextAt = os.clock() + 10
            end
        end
    end

    function A:ModalWatchdog()
        if not self:GameModalOpen() then
            self.OwnedFridgeAt = nil
            return
        end
        if self.Busy or not self.OwnedFridgeAt then return end -- UI milik pemain: jangan disentuh
        if os.clock() - self.OwnedFridgeAt < 8 then return end
        self:ForceCloseModals()
    end

    task.spawn(function()
        while Running do
            pcall(function() Automation:ModalWatchdog() end)
            task.wait(1)
        end
    end)

    -- 3) batas waktu satu aksi: 60 detik
    local baseActive = A.Active
    function A:Active(token)
        if self.StartedAt and os.clock() - self.StartedAt > 60 then return false end
        return baseActive(self, token)
    end
end
Automation:Start()

notify("SeeLeooo", "Loaded! Fishing + Restoran + Harvest + Lost Soul + Quest\nF1=Freecam F2=Fish F3=Rekam F4=Putar", 5)
print("[SeeLeooo] Ready | v2.6.1 | Fridge GUI: pilih item > input kelebihan > submit > konfirmasi")