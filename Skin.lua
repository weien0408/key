-- [[ 1. SAFETY INITIALIZATION & CONFIGURATION SYSTEM ]]
if not game:IsLoaded() then 
    game.Loaded:Wait() 
end

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local FileName = "YUNUKE_CONFIG_MAX.json"

-- 遊戲檢查限制 (創作者 ID 驗證)
if game.CreatorId ~= 3461453 then
    LocalPlayer:Kick("Not Supported game")
    return
end

-- 配置設定檔
local Settings = {
    AutoSaveLoadEnabled = true, -- 換伺服器自動保持開關
    
    AimbotEnabled = false, 
    SilentAimEnabled = false, 
    WallbangEnabled = false, 
    AimbotKey = "B",
    AimbotPart = "Head", 
    AimbotSmoothness = 50, 
    AimbotTeamCheck = false, 
    AimbotWallCheck = false,
    AimbotHolding = false, 
    AutoFireEnabled = false, 
    AutoFireDelay = 0.05,
    unlockskin = false, -- 新增解鎖皮膚開關狀態紀錄
    
    ESPEnabled = false, ESPNames = false, ESPDistances = false, ESPHealth = false, ESPTeamCheck = false,
    ESPColorR = 255, ESPColorG = 255, ESPColorB = 255, ESPRainbow = false,
    
    CrosshairEnabled = false, CrosshairSize = 12, CrosshairGap = 8, CrosshairSpinSpeed = 150,
    CrosshairColorR = 255, CrosshairColorG = 255, CrosshairColorB = 255, CrosshairRainbow = false,
    FOVEnabled = false, FOVRadius = 150, FOVColorR = 255, FOVColorG = 255, FOVColorB = 255, FOVRainbow = false,
    
    FlyEnabled = false, FlySpeed = 200, NoclipEnabled = false,
    SpinEnabled = false, SpinSpeed = 99999,
    WalkSpeedEnabled = false, WalkSpeedValue = 100, JumpPowerEnabled = false, JumpPowerValue = 50,
    InfiniteJumpEnabled = false, StickToHeadEnabled = false, UpsideDownEnabled = false,
    
    VoidModeEnabled = false,
    
    NightModeEnabled = false, DarkMapEnabled = false,
    ChatSpamEnabled = false, ChatSpamText = "ezz", ChatSpamDelay = 3,
    HideKey = "RightShift", IsBinding = false, IsBindingHide = false,
    
    NoCooldownEnabled = false,
    DeviceMode = "PC",
    
    -- 新增 FFA 功能配置項目
    FFA_AutoHealth = true,
    FFA_AutoAmmo = true,
    FFA_AutoRespawn = true
}

local function SaveSettings()
    local tempSettings = {}
    for k, v in pairs(Settings) do
        tempSettings[k] = v
    end
    
    if not Settings.AutoSaveLoadEnabled then
        tempSettings.WallbangEnabled = false
        tempSettings.SilentAimEnabled = false
        tempSettings.AimbotEnabled = false
        tempSettings.ESPEnabled = false
        tempSettings.unlockskin = false
    end

    local success, encoded = pcall(function() return HttpService:JSONEncode(tempSettings) end)
    if success and writefile then writefile(FileName, encoded) end
end

local function LoadSettings()
    if isfile and isfile(FileName) then
        local success, content = pcall(function() return readfile(FileName) end)
        if success and content ~= "" then
            local decode_success, decoded = pcall(function() return HttpService:JSONDecode(content) end)
            if decode_success and type(decoded) == "table" then
                for k, v in pairs(decoded) do 
                    if Settings[k] ~= nil then 
                        Settings[k] = v 
                    end 
                end
            end
        end
    end
end
LoadSettings()

local lastAutoFireTime, lastChatSpamTime = 0, 0
local OriginalColors, MouseHolding = {}, false
local voidDirection = 1

-- [[ 1.4 SILENT AIM SYSTEM - HIGH PERFORMANCE OPTIMIZED ]]
local X = {}
X.bone = "Head"
X.range = math.huge
X.services = {
    rep = game:GetService("ReplicatedStorage"),
    plr = game:GetService("Players"),
}
X.mod = require(X.services.rep.Modules.Utility)
X.original = X.mod.Raycast
X.cam = workspace.CurrentCamera
X.me = X.services.plr.LocalPlayer

-- 引入快取機制，避免每發子彈都遍歷整個地圖
local lastPoolUpdate = 0
local cachedPool = {}

local function updateTargetPool()
    local now = os.clock()
    if now - lastPoolUpdate < 0.25 and #cachedPool > 0 then 
        return cachedPool 
    end
    lastPoolUpdate = now
    
    local pool = {}
    -- 1. 高效率優先獲取玩家 Character
    local allPlayers = X.services.plr:GetPlayers()
    for i = 1, #allPlayers do
        local p = allPlayers[i]
        if p ~= X.me and p.Character then
            pool[#pool+1] = p.Character
        end
    end
    -- 2. 每隔 0.25 秒才低頻遍歷一次 workspace 的其他潛在目標（如 HurtEffect 或 NPC）
    local wsChildren = workspace:GetChildren()
    for i = 1, #wsChildren do
        local v = wsChildren[i]
        if v.Name == "HurtEffect" then
            local cChildren = v:GetChildren()
            for j = 1, #cChildren do
                local c = cChildren[j]
                if c.ClassName ~= "Highlight" then pool[#pool+1] = c end
            end
        elseif v:FindFirstChildOfClass("Humanoid") and not X.services.plr:GetPlayerFromCharacter(v) then
            pool[#pool+1] = v
        end
    end
    cachedPool = pool
    return pool
end

X.mod.Raycast = function(...)
    local args = {...}
    if not Settings.SilentAimEnabled or args[4] ~= 999 then return X.original(...) end
    X.bone = Settings.AimbotPart
    
    local cx = X.cam.ViewportSize.X / 2
    local cy = X.cam.ViewportSize.Y / 2
    local winner, record = nil, X.range
    local pool = updateTargetPool() -- 使用高效率快取池
    
    for i = 1, #pool do
        local v = pool[i]
        if v == X.me.Character or not v.Parent then continue end
        
        local root = v:FindFirstChild("HumanoidRootPart") or (v:IsA("BasePart") and v)
        local targetPart = v:FindFirstChild(X.bone) or root
        if not targetPart then continue end
        
        if Settings.AimbotTeamCheck then
            local pl = X.services.plr:GetPlayerFromCharacter(v)
            if pl and (pl:GetAttribute("TeamID") == X.me:GetAttribute("TeamID") or pl.Team == X.me.Team) then 
                continue 
            end
        end
        
        local p, vis = X.cam:WorldToViewportPoint(targetPart.Position)
        if not vis then continue end
        local d = (Vector2.new(cx, cy) - Vector2.new(p.X, p.Y)).Magnitude
        
        if Settings.FOVEnabled and d > Settings.FOVRadius then continue end
        
        if d < record then 
            winner, record = targetPart, d 
        end
    end
    
    if winner then
        args[3] = winner.Position
    end
    return X.original(table.unpack(args))
end



-- [[ 1.4.5 ORIGINAL DESYNC WALLBANG SYSTEM ]]
local __a1b2c3 = setmetatable({}, {
    __index = function(__d4e5f6, __g7h8i9)
        local __j0k1l2, __m3n4o5 = pcall(function()
            return game:GetService(__g7h8i9)
        end)
        if __m3n4o5 then
            return cloneref(__m3n4o5)
        end
        return nil
    end
})

local __p6q7r8 = getgenv()
if __p6q7r8.__s9t0u1 then
    __p6q7r8.__s9t0u1:Shutdown()
end

local __v2w3x4 = __a1b2c3.Players
local __y5z6a7 = __a1b2c3.RunService
local __b8c9d0 = __a1b2c3.ReplicatedStorage
local __e1f2g3 = __a1b2c3.Workspace
local __h4i5j6 = __a1b2c3.UserInputService
local __k7l8m9 = __v2w3x4.LocalPlayer
local __n0o1p2 = __e1f2g3.CurrentCamera
local __q3r4s5 = __k7l8m9.PlayerScripts
local __t6u7v8 = require(__q3r4s5.Modules.ItemTypes.Gun)
local __w9x0y1 = require(__b8c9d0.Modules.Utility)

local __z2a3b4 = setmetatable({}, {
    __index = function(_, __c5d6e7)
        local __f8g9h0 = __k7l8m9.Character
        if not __f8g9h0 then return nil end
        if __c5d6e7 == "__root" then
            return __f8g9h0:FindFirstChild("HumanoidRootPart")
        elseif __c5d6e7 == "__head" then
            return __f8g9h0:FindFirstChild("Head")
        end
        return nil
    end
})

__p6q7r8.__s9t0u1 = {}

do
    local __i1j2k3 = __p6q7r8.__s9t0u1

    function __i1j2k3:__init()
        self.__active = true
        self.__target = nil
        self.__desync = false
        self.__conn1 = nil
        self.__conn2 = nil
        self.__task1 = nil
        self.__oldfunc = nil
        self:__setup()
    end

    function __i1j2k3:__setup()
        self.__conn1 = __y5z6a7.Heartbeat:Connect(function()
            if not self.__active or not Settings.WallbangEnabled then return end
            self.__target = self:__find()
        end)

        local __l4m5n6 = __t6u7v8.StartShooting
        self.__oldfunc = __l4m5n6
        __t6u7v8.StartShooting = function(__o7p8q9, ...)
            local __r0s1t2 = {__l4m5n6(__o7p8q9, ...)}
            
            if not Settings.WallbangEnabled or not __o7p8q9.ClientFighter or not __o7p8q9.ClientFighter.IsLocalPlayer then
                return unpack(__r0s1t2)
            end

            local __u3v4w5 = __r0s1t2[3]
            if not __u3v4w5 or typeof(__u3v4w5) ~= "table" then
                return unpack(__r0s1t2)
            end

            __r0s1t2[4] = true
            local __x6y7z8 = self.__target

            if not self.__active or not __x6y7z8 or not __x6y7z8.Character then
                return unpack(__r0s1t2)
            end

            if not self.__desync or self.__curr ~= __x6y7z8 then
                self:__desync_start(__x6y7z8)
                task.wait(0.1)
            end

            if self.__task1 then
                task.cancel(self.__task1)
                self.__task1 = nil
            end

            local __a9b0c1 = __x6y7z8.Character:FindFirstChild("Head")
            if not __a9b0c1 then return unpack(__r0s1t2) end

            local __d2e3f4 = __a9b0c1.Position
            local __g5h6i7 = __a9b0c1.CFrame
            local __j8k9l0 = __d2e3f4 - Vector3.new(0, 5, 0)
            local __m1n2o3 = CFrame.lookAt(__j8k9l0, __d2e3f4)
            local __p4q5r6 = __g5h6i7:ToObjectSpace(CFrame.new(__d2e3f4 + Vector3.new(math.random(), math.random(), math.random())))

            __u3v4w5[utf8.char(0)] = __w9x0y1:EncodeCFrame(CFrame.new(__j8k9l0, __d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
            __u3v4w5[utf8.char(1)] = __w9x0y1:EncodeCFrame(CFrame.new(__d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
            __u3v4w5[utf8.char(2)] = __a9b0c1
            __u3v4w5[utf8.char(3)] = __w9x0y1:EncodeCFrame(__p4q5r6)

            self.__task1 = task.delay(0.15, function()
                self:__desync_stop()
            end)

            return unpack(__r0s1t2)
        end
    end

    function __i1j2k3:__find()
        local myChar = __k7l8m9.Character
        if not myChar then return nil end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
       
        local closest = nil
        local closestDist = math.huge
        local MAX_DISTANCE = 200

        for _, player in next, __v2w3x4:GetPlayers() do
            if player == __k7l8m9 then continue end
            if player:GetAttribute("TeamID") == __k7l8m9:GetAttribute("TeamID") then continue end
           
            local char = player.Character
            if not char then continue end

            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            
            if not (root and head and hum and hum.Health > 0) then continue end
           
            local dist = (myRoot.Position - root.Position).Magnitude
            
            if dist > MAX_DISTANCE then continue end
            
            if dist < closestDist then
                closestDist = dist
                closest = player
            end
        end
        
        return closest
    end

    function __i1j2k3:__desync_start(__c3d4e5)
        if self.__conn2 then self.__conn2:Disconnect() end
        self.__desync = true
        self.__curr = __c3d4e5

        self.__conn2 = __y5z6a7.Heartbeat:Connect(function()
            if not self.__desync or not Settings.WallbangEnabled then return end
            local __f6g7h8 = __z2a3b4.__root
            if not __f6g7h8 then return end

            local __i9j0k1 = __c3d4e5.Character and __c3d4e5.Character:FindFirstChild("HumanoidRootPart")
            if not __i9j0k1 then
                self:__desync_stop()
                return
            end

            local __l2m3n4 = __f6g7h8.CFrame
            local __o5p6q7 = __f6g7h8.Velocity
            local __r8s9t0 = __f6g7h8.RotVelocity

            __f6g7h8.CFrame = __i9j0k1.CFrame * CFrame.new(0, -5, 0)

            __y5z6a7:BindToRenderStep("__restore", 101, function()
                __f6g7h8.CFrame = __l2m3n4
                __f6g7h8.Velocity = __o5p6q7
                __f6g7h8.RotVelocity = __r8s9t0
                __y5z6a7:UnbindFromRenderStep("__restore")
            end)
        end)
    end

    function __i1j2k3:__desync_stop()
        self.__desync = false
        self.__curr = nil
        if self.__conn2 then
            self.__conn2:Disconnect()
            self.__conn2 = nil
        end
    end

    __i1j2k3:__init()
end


-- [[ 1.5 FIXED NO-LAG COOLDOWN & WEAPON MOD SYSTEM ]]
local function ApplyWeaponMods()
    if not Settings.NoCooldownEnabled then return end
    pcall(function()
        for _, gcVal in pairs(getgc(true)) do
            if type(gcVal) == "table" then
                if rawget(gcVal, "ShootCooldown") then gcVal["ShootCooldown"] = 0 end
                if rawget(gcVal, "ShootSpread") then gcVal["ShootSpread"] = 0 end
                if rawget(gcVal, "ShootRecoil") then gcVal["ShootRecoil"] = 0 end
            end
        end
    end)
end

-- [[ 1.6 SIMULATED DEVICE CHANGING SYSTEM ]]
local function ApplyDeviceSimulation(mode)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local rep = remotes and remotes:FindFirstChild("Replication")
    local fighter = rep and rep:FindFirstChild("Fighter")
    local setControls = fighter and fighter:FindFirstChild("SetControls")
    
    if setControls then
        task.spawn(function()
            local YourDevice = "MouseKeyboard"
            local WantedDevice = "MouseKeyboard"
            if mode == "PC" then WantedDevice = "MouseKeyboard"
            elseif mode == "Touch" then WantedDevice = "Touch"
            elseif mode == "Gamepad" then WantedDevice = "Gamepad" end
            setControls:FireServer(YourDevice)
            task.wait(0.3)
            setControls:FireServer(WantedDevice)
        end)
    end
end

-- [[ 1.8 LIGHTWEIGHT TEAM CHECK SYSTEM ]]
local function IsTeammate(player)
    if player:GetAttribute("TeamID") == LocalPlayer:GetAttribute("TeamID") then return true end
    if LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then return true end
    return false
end

-- [[ 2. CORE INTELLIGENCE ALGORITHMS ]]
local function IsPlayerVisible(targetPart)
    if not Settings.AimbotWallCheck then return true end
    local char = LocalPlayer.Character if not char then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char, targetPart.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(Camera.CFrame.Position, targetPart.Position - Camera.CFrame.Position, rayParams)
    return result == nil
end

-- [[ 2.5 SPIN BOT ANIMATION LOGIC ]]
local function anim2track(asset_id)
    local success, objs = pcall(function()
        return game:GetObjects(asset_id)
    end)
    if success and objs and #objs > 0 then
        for i = 1, #objs do
            if objs[i]:IsA("Animation") then
                return objs[i].AnimationId
            end
        end
    end
    return asset_id
end

local animid = "92281817840531"
if not animid:find("rbxassetid://") then
    animid = "rbxassetid://" .. animid
end
animid = anim2track(animid)

local spinAnimation = Instance.new("Animation")
spinAnimation.AnimationId = animid

local function playAnim(character)
    if not Settings.SpinEnabled then return end
    local Hum = character:FindFirstChildWhichIsA("Humanoid")
    if not Hum then return end
    
    for _, track in next, Hum:GetPlayingAnimationTracks() do 
        track:Stop() 
    end
    
    local anim = Hum:LoadAnimation(spinAnimation)
    anim.Priority = Enum.AnimationPriority.Action4
    anim:Play()
    anim:AdjustSpeed(Settings.SpinSpeed)
    
    anim.Stopped:Connect(function() 
        if Settings.SpinEnabled then 
            playAnim(character) 
        end 
    end)
end

local function ToggleSpinBot(state)
    Settings.SpinEnabled = state
    SaveSettings()
    if state then
        if LocalPlayer.Character then playAnim(LocalPlayer.Character) end
    else
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            for _, track in next, LocalPlayer.Character.Humanoid:GetPlayingAnimationTracks() do 
                track:Stop() 
            end
        end
    end
end

-- [[ 2.8 FFA AUTO RESPAWN LOGIC ]]
LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid")
    if Settings.SpinEnabled then playAnim(character) end
    if Settings.NoCooldownEnabled then task.wait(1) ApplyWeaponMods() end
    
    -- FFA 自動復活綁定
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        if not Settings.FFA_AutoRespawn then return end
        task.spawn(function()
            while Settings.FFA_AutoRespawn do
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    break
                end
                if keypress and keyrelease then
                    keypress(0x20)
                    task.wait(0.1)
                    keyrelease(0x20)
                end
                task.wait(0.1)
            end
        end)
    end)
end)

local function ApplyDarkMap(state)
    if state then
        for _, v in ipairs(workspace:GetDescendants()) do
            if (v:IsA("Part") or v:IsA("MeshPart")) and v.Color == Color3.fromRGB(151, 153, 163) then 
                OriginalColors[v] = v.Color 
                v.Color = Color3.fromRGB(30, 35, 38) 
            end
        end
    else
        for p, c in pairs(OriginalColors) do if p and p.Parent then p.Color = c end end 
        table.clear(OriginalColors)
    end
end

local function GetRoot(char) return char and char:FindFirstChild("HumanoidRootPart") end

local function GetNearestPlayer(maxDist)
    local target, dist = nil, maxDist or math.huge
    local myRoot = GetRoot(LocalPlayer.Character) if not myRoot then return nil end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") and p.Character.Humanoid.Health > 0 then
            if Settings.ESPTeamCheck and IsTeammate(p) then continue end
            local d = (myRoot.Position - p.Character.Head.Position).Magnitude
            if d < dist then dist = d target = p end
        end
    end
    return target
end

local function GetRainbowColor() return Color3.fromHSV(tick() % 5 / 5, 1, 1) end

-- [[ 4. HIGH-PERFORMANCE CLEAN ESP RENDERING ENGINE ]]
local function CreateESP(player)
    local HealthOutline = Drawing.new("Square")
    local HealthBar = Drawing.new("Square")
    local NameT = Drawing.new("Text") NameT.Size = 13 NameT.Center = true NameT.Outline = true
    local DistT = Drawing.new("Text") DistT.Size = 11 DistT.Center = true DistT.Outline = true
    local HPText = Drawing.new("Text") HPText.Size = 11 HPText.Outline = true HPText.Color = Color3.new(1,1,1)

    local function Hide()
        HealthOutline.Visible = false HealthBar.Visible = false
        NameT.Visible = false DistT.Visible = false HPText.Visible = false
    end

    RunService.RenderStepped:Connect(function()
        if Settings.ESPEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player ~= LocalPlayer then
            if Settings.ESPTeamCheck and IsTeammate(player) then Hide() return end
            local char = player.Character local hum = char.Humanoid
            local pos, onScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
            if onScreen then
                local sX, sY = 2200 / pos.Z, 3200 / pos.Z
                local bPos = Vector2.new(pos.X - sX/2, pos.Y - sY/2)
                local espCol = Color3.fromRGB(Settings.ESPColorR, Settings.ESPColorG, Settings.ESPColorB)
                if Settings.ESPRainbow then espCol = GetRainbowColor() end
                
                NameT.Color = espCol DistT.Color = espCol
                if Settings.ESPNames then 
                    NameT.Text = player.Name 
                    NameT.Position, NameT.Visible = Vector2.new(pos.X, bPos.Y - 16), true 
                else NameT.Visible = false end
                
                if Settings.ESPDistances then 
                    DistT.Text = math.floor((Camera.CFrame.Position - char.HumanoidRootPart.Position).Magnitude).." studs" 
                    DistT.Position, DistT.Visible = Vector2.new(pos.X, bPos.Y + sY + 2), true 
                else DistT.Visible = false end

                if Settings.ESPHealth then
                    local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    HealthOutline.Size, HealthOutline.Position, HealthOutline.Visible = Vector2.new(5, sY + 2), Vector2.new(bPos.X - 7, bPos.Y - 1), true
                    HealthBar.Size, HealthBar.Position, HealthBar.Color, HealthBar.Visible = Vector2.new(3, sY * pct), Vector2.new(bPos.X - 6, bPos.Y + (sY * (1 - pct))), Color3.fromHSV(pct * 0.3, 1, 1), true
                    HPText.Text = math.floor(hum.Health).."HP" 
                    HPText.Position, HPText.Visible = Vector2.new(bPos.X - 32, bPos.Y + (sY * (1 - pct)) - 2), true
                else HealthOutline.Visible, HealthBar.Visible, HPText.Visible = false, false, false end
            else Hide() end
        else 
            Hide() 
            if not player.Parent then HealthOutline:Remove() HealthBar:Remove() NameT:Remove() DistT:Remove() HPText:Remove() end 
        end
    end)
end

for _, v in pairs(Players:GetPlayers()) do if v ~= LocalPlayer then CreateESP(v) end end
Players.PlayerAdded:Connect(CreateESP)

-- [[ 5. MODERN ANIMATED UI ENGINE ]]
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui")) ScreenGui.Name = "YUNUKE_PIXEL_ANIMATED" ScreenGui.ResetOnSpawn = false
local OpenBtn = Instance.new("TextButton", ScreenGui) OpenBtn.Size, OpenBtn.Position = UDim2.new(0, 80, 0, 35), UDim2.new(0, 15, 0.45, 0)
OpenBtn.BackgroundColor3, OpenBtn.BackgroundTransparency = Color3.fromRGB(20, 20, 25), 0.2 OpenBtn.Text, OpenBtn.TextColor3, OpenBtn.Font, OpenBtn.TextSize = "OPEN", Color3.new(1,1,1), Enum.Font.GothamBold, 13
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 8) local OpenStroke = Instance.new("UIStroke", OpenBtn) OpenStroke.Color = Color3.fromRGB(80, 80, 90)

local MainFrame = Instance.new("Frame", ScreenGui) MainFrame.Size, MainFrame.Position = UDim2.new(0, 480, 0, 380), UDim2.new(0.5, -240, 0.5, -190)
MainFrame.BackgroundColor3, MainFrame.BackgroundTransparency, MainFrame.Visible = Color3.fromRGB(18, 18, 24), 0.15, false
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12) local MainStroke = Instance.new("UIStroke", MainFrame) MainStroke.Color, MainStroke.Transparency = Color3.new(1,1,1), 0.6 MainFrame.ClipsDescendants = true

local Header = Instance.new("Frame", MainFrame) Header.Size = UDim2.new(1, 0, 0, 40) Header.BackgroundColor3, Header.BackgroundTransparency = Color3.new(1,1,1), 0.9 Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)
local Title = Instance.new("TextLabel", Header) Title.Size, Title.Position, Title.BackgroundTransparency = UDim2.new(1, -10, 1, 0), UDim2.new(0, 15, 0, 0), 1
Title.Text, Title.TextColor3, Title.Font, Title.TextSize, Title.TextXAlignment = "GOOD HUB ANIMATED v6", Color3.new(1,1,1), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left

local TWEEN_UI = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
OpenBtn.MouseButton1Click:Connect(function() 
    MainFrame.Visible = not MainFrame.Visible OpenBtn.Text = MainFrame.Visible and "CLOSE" or "OPEN" 
    if MainFrame.Visible then MainFrame.Size = UDim2.new(0, 0, 0, 0) TweenService:Create(MainFrame, TWEEN_UI, {Size = UDim2.new(0, 480, 0, 380)}):Play() end
end)

local TabHolder = Instance.new("Frame", MainFrame) TabHolder.Size, TabHolder.Position = UDim2.new(0, 110, 1, -55), UDim2.new(0, 8, 0, 48) TabHolder.BackgroundColor3, TabHolder.BackgroundTransparency = Color3.fromRGB(30, 30, 40), 0.4 Instance.new("UICorner", TabHolder).CornerRadius = UDim.new(0, 8)
local TabListLayout = Instance.new("UIListLayout", TabHolder) TabListLayout.Padding = UDim.new(0, 4)
local ContentHolder = Instance.new("Frame", MainFrame) ContentHolder.Size, ContentHolder.Position = UDim2.new(1, -140, 1, -55), UDim2.new(0, 125, 0, 48) ContentHolder.BackgroundTransparency = 1

local Pages = {}
local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame", ContentHolder) Page.Size, Page.BackgroundTransparency, Page.Visible, Page.ScrollBarThickness, Page.CanvasSize = UDim2.new(1, 0, 1, 0), 1, false, 0, UDim2.new(0,0,0,0)
    local Layout = Instance.new("UIListLayout", Page) Layout.Padding = UDim.new(0, 6) Pages[name] = Page
    local TabBtn = Instance.new("TextButton", TabHolder) TabBtn.Size, TabBtn.BackgroundTransparency = UDim2.new(1, 0, 0, 32), 1
    TabBtn.Text, TabBtn.TextColor3, TabBtn.Font, TabBtn.TextSize, TabBtn.TextXAlignment = "  " .. name:upper(), Color3.fromRGB(160, 160, 170), Enum.Font.GothamSemibold, 12, Enum.TextXAlignment.Left Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)
    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end Page.Visible = true
        for _, b in pairs(TabHolder:GetChildren()) do if b:IsA("TextButton") then TweenService:Create(b, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(160, 160, 170), BackgroundTransparency = 1}):Play() end end
        TweenService:Create(TabBtn, TweenInfo.new(0.3), {TextColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.85}):Play()
    end)
    return Page
end

local function AddHoverAnim(obj)
    obj.MouseEnter:Connect(function() TweenService:Create(obj, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play() end)
    obj.MouseLeave:Connect(function() TweenService:Create(obj, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play() end)
end

local function AddToggle(parent, text, key, callback)
    local Btn = Instance.new("TextButton") Btn.Size, Btn.BackgroundColor3, Btn.BackgroundTransparency = UDim2.new(1, -5, 0, 34), Color3.fromRGB(40, 40, 50), 0.5 Btn.Parent = parent Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6) AddHoverAnim(Btn)
    local L = Instance.new("TextLabel") L.Size, L.Position, L.BackgroundTransparency, L.Text, L.TextColor3, L.Font, L.TextSize, L.TextXAlignment = UDim2.new(1, -50, 1, 0), UDim2.new(0, 10, 0, 0), 1, text:upper(), Color3.fromRGB(230, 230, 235), Enum.Font.GothamMedium, 11, Enum.TextXAlignment.Left L.Parent = Btn
    local S = Instance.new("TextLabel") S.Size, S.Position, S.BackgroundTransparency, S.Text, S.TextColor3, S.Font, S.TextSize = UDim2.new(0, 40, 1, 0), UDim2.new(1, -45, 0, 0), 1, Settings[key] and "●" or "○", Settings[key] and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 75, 75), Enum.Font.GothamBold, 13 S.Parent = Btn
    Btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key] SaveSettings() S.Text = Settings[key] and "●" or "○"
        TweenService:Create(S, TweenInfo.new(0.2), {TextColor3 = Settings[key] and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 75, 75)}):Play()
        if callback then callback(Settings[key]) end
    end)
    parent.CanvasSize = UDim2.new(0, 0, 0, parent.UIListLayout.AbsoluteContentSize.Y + 10)
end

local function AddSlider(parent, text, max, min, key, callback)
    local Frame = Instance.new("Frame") Frame.Size, Frame.BackgroundTransparency = UDim2.new(1, -5, 0, 48), 1 Frame.Parent = parent
    local L = Instance.new("TextLabel") L.Size, L.Position, L.BackgroundTransparency = UDim2.new(1, 0, 0, 20), UDim2.new(0, 4, 0, 0), 1
    local displayVal = Settings[key] if key == "AimbotSmoothness" then displayVal = string.format("%.2f", Settings[key]/100) end
    L.Text, L.TextColor3, L.Font, L.TextSize, L.TextXAlignment = text:upper() .. ": " .. displayVal, Color3.fromRGB(200, 200, 210), Enum.Font.GothamMedium, 11, Enum.TextXAlignment.Left L.Parent = Frame
    local Bar = Instance.new("TextButton") Bar.Size, Bar.Position, Bar.BackgroundColor3, Bar.BackgroundTransparency = UDim2.new(1, -8, 0, 8), UDim2.new(0, 4, 0, 24), Color3.fromRGB(45, 45, 55), 0.4 Bar.Parent = Frame Instance.new("UICorner", Bar).CornerRadius = UDim.new(0, 4)
    local Fill = Instance.new("Frame") Fill.Size, Fill.BackgroundColor3 = UDim2.new(math.clamp((Settings[key]-min)/(max-min), 0, 1), 0, 1, 0), Color3.new(1, 1, 1) Fill.Parent = Bar Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 4)
    local drag = false
    local function Update()
        local r = math.clamp((UserInputService:GetMouseLocation().X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (r * (max - min))) Settings[key] = val TweenService:Create(Fill, TweenInfo.new(0.1), {Size = UDim2.new(r, 0, 1, 0)}):Play()
        local outVal = val if key == "AimbotSmoothness" then outVal = string.format("%.2f", val/100) end
        L.Text = text:upper() .. ": " .. outVal if callback then callback(val) end
    end
    Bar.MouseButton1Down:Connect(function() drag = true end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and drag then drag = false SaveSettings() end end)
    RunService.RenderStepped:Connect(function() if drag then Update() end end)
    parent.CanvasSize = UDim2.new(0, 0, 0, parent.UIListLayout.AbsoluteContentSize.Y + 10)
end

local function AddCycle(parent, text, options, key, callback)
    local Btn = Instance.new("TextButton") Btn.Size, Btn.BackgroundColor3, Btn.BackgroundTransparency = UDim2.new(1, -5, 0, 34), Color3.fromRGB(40, 40, 50), 0.5 Btn.Parent = parent Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6) AddHoverAnim(Btn)
    local L = Instance.new("TextLabel") L.Size, L.Position, L.BackgroundTransparency, L.Text, L.TextColor3, L.Font, L.TextSize, L.TextXAlignment = UDim2.new(1, -120, 1, 0), UDim2.new(0, 10, 0, 0), 1, text:upper(), Color3.fromRGB(230, 230, 235), Enum.Font.GothamMedium, 11, Enum.TextXAlignment.Left L.Parent = Btn
    local S = Instance.new("TextLabel") S.Size, S.Position, S.BackgroundTransparency, S.Text, S.TextColor3, S.Font, S.TextSize, S.TextXAlignment = UDim2.new(0, 100, 1, 0), UDim2.new(1, -105, 0, 0), 1, tostring(Settings[key]):upper(), Color3.fromRGB(0, 180, 255), Enum.Font.GothamBold, 11, Enum.TextXAlignment.Right S.Parent = Btn
    Btn.MouseButton1Click:Connect(function()
        local idx = 1 for i, o in ipairs(options) do if o:lower() == tostring(Settings[key]):lower() then idx = i break end end
        local nIdx = idx + 1 if nIdx > #options then nIdx = 1 end Settings[key] = options[nIdx] SaveSettings() S.Text = tostring(Settings[key]):upper() if callback then callback(options[nIdx]) end
    end)
    parent.CanvasSize = UDim2.new(0, 0, 0, parent.UIListLayout.AbsoluteContentSize.Y + 10)
end

-- [[ 6. MENU TABS REGISTERING ]]
local CombatPage = CreatePage("Combat")
local VisualPage = CreatePage("ESP Config")
local VisualColor = CreatePage("ESP Colors")
local CrosshairPage = CreatePage("FOV & Aim")
local MovePage = CreatePage("Movement")
local FFABoostersPage = CreatePage("FFA Boosters") -- 🌟 註冊新增的 FFA Boosters 頁面
local MiscPage = CreatePage("Misc")

AddToggle(CombatPage, "跨服保持", "AutoSaveLoadEnabled")

-- 皮膚解鎖按鈕
AddToggle(CombatPage, "Unlock All Skin (External)", "unlockskin", function(state)
    if state then
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/dB7rK4xC/raw"))()
        end)
        if not success then
            warn("外部皮膚解鎖腳本載入失敗: " .. tostring(err))
        end
    end
end)

AddToggle(CombatPage, "No Cooldown/Recoil/Spread", "NoCooldownEnabled", function(state) if state then ApplyWeaponMods() end end)
AddToggle(CombatPage, "Wallbang (Desync Method)", "WallbangEnabled")
AddToggle(CombatPage, "Silent Aim (Raycast)", "SilentAimEnabled")
AddToggle(CombatPage, "Camera Aimbot", "AimbotEnabled")

AddCycle(CombatPage, "Target Part", {"Head", "Torso", "HumanoidRootPart"}, "AimbotPart")
AddSlider(CombatPage, "Cam Smoothness (0~1)", 100, 1, "AimbotSmoothness")
AddToggle(CombatPage, "Wall Check", "AimbotWallCheck")
AddToggle(CombatPage, "Team Check", "AimbotTeamCheck")
AddToggle(CombatPage, "Auto Fire", "AutoFireEnabled")
AddSlider(CombatPage, "Fire Delay", 10, 1, "AutoFireDelay", function(v) Settings.AutoFireDelay = v/100 end)

AddToggle(VisualPage, "ESP Master Switch", "ESPEnabled")
AddToggle(VisualPage, "ESP Names", "ESPNames")
AddToggle(VisualPage, "ESP Distances", "ESPDistances")
AddToggle(VisualPage, "ESP Health Display", "ESPHealth")
AddToggle(VisualPage, "ESP Team Check", "ESPTeamCheck")

AddToggle(VisualColor, "Rainbow ESP", "ESPRainbow")
AddSlider(VisualColor, "ESP Red Color", 255, 0, "ESPColorR")
AddSlider(VisualColor, "ESP Green Color", 255, 0, "ESPColorG")
AddSlider(VisualColor, "ESP Blue Color", 255, 0, "ESPColorB")

AddToggle(CrosshairPage, "Crosshair Master", "CrosshairEnabled")
AddToggle(CrosshairPage, "Crosshair Rainbow", "CrosshairRainbow")
AddSlider(CrosshairPage, "Crosshair Size", 50, 1, "CrosshairSize")
AddSlider(CrosshairPage, "Crosshair Gap", 30, 1, "CrosshairGap")

AddToggle(CrosshairPage, "FOV Circle Master", "FOVEnabled")
AddToggle(CrosshairPage, "FOV Rainbow", "FOVRainbow")
AddSlider(CrosshairPage, "FOV Radius Size", 800, 10, "FOVRadius")

AddToggle(MovePage, "Void Mode (Y 0-1000)", "VoidModeEnabled")
AddToggle(MovePage, "Stick To Head", "StickToHeadEnabled")
AddToggle(MovePage, "Fly", "FlyEnabled")
AddSlider(MovePage, "Fly Speed", 1000, 10, "FlySpeed")
AddToggle(MovePage, "Noclip", "NoclipEnabled")

-- 綁定 SpinBot 動畫與速度控制
AddToggle(MovePage, "Spin Bot (Anim)", "SpinEnabled", ToggleSpinBot)
AddSlider(MovePage, "Spin Speed", 99999, 1, "SpinSpeed", function(v)
    if Settings.SpinEnabled and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
        if Hum then
            for _, track in next, Hum:GetPlayingAnimationTracks() do
                if track.Animation.AnimationId == spinAnimation.AnimationId then
                    track:AdjustSpeed(v)
                end
            end
        end
    end
end)

AddToggle(MovePage, "Walk Speed", "WalkSpeedEnabled")
AddSlider(MovePage, "Speed Value", 500, 16, "WalkSpeedValue")
AddToggle(MovePage, "Jump Power", "JumpPowerEnabled")
AddSlider(MovePage, "Jump Value", 500, 50, "JumpPowerValue")
AddToggle(MovePage, "Infinite Jump", "InfiniteJumpEnabled")
AddToggle(MovePage, "Upside Down", "UpsideDownEnabled")

-- 🌟 塞入 FFA Boosters 頁面裡面的功能按鈕
AddToggle(FFABoostersPage, "Auto Health", "FFA_AutoHealth")
AddToggle(FFABoostersPage, "Auto Ammo", "FFA_AutoAmmo")
AddToggle(FFABoostersPage, "Auto Respawn", "FFA_AutoRespawn")

AddCycle(MiscPage, "Device Mode", {"PC", "Touch", "Gamepad"}, "DeviceMode", function(sm) ApplyDeviceSimulation(sm) end)
AddToggle(MiscPage, "Dark Map", "DarkMapEnabled", function(v) ApplyDarkMap(v) end)
AddToggle(MiscPage, "Night Mode", "NightModeEnabled")
AddToggle(MiscPage, "Chat Spam", "ChatSpamEnabled")
AddSlider(MiscPage, "Spam Delay (s)", 10, 1, "ChatSpamDelay")

local ChatInput = Instance.new("TextBox", MiscPage) ChatInput.Size = UDim2.new(1, -5, 0, 32) ChatInput.BackgroundColor3, ChatInput.BackgroundTransparency = Color3.fromRGB(40, 40, 50), 0.5
ChatInput.PlaceholderText, ChatInput.Text, ChatInput.TextColor3, ChatInput.Font, ChatInput.TextSize = "Spam Content...", Settings.ChatSpamText, Color3.new(1,1,1), Enum.Font.Gotham, 12
Instance.new("UICorner", ChatInput).CornerRadius = UDim.new(0, 6) ChatInput.FocusLost:Connect(function(e) if e then Settings.ChatSpamText = ChatInput.Text SaveSettings() end end)

local BindBtn = Instance.new("TextButton", MiscPage) BindBtn.Size, BindBtn.BackgroundColor3 = UDim2.new(1, -5, 0, 32), Color3.fromRGB(55, 55, 65) BindBtn.Text, BindBtn.TextColor3, BindBtn.Font, BindBtn.TextSize = "AIM KEY: ["..Settings.AimbotKey.."]", Color3.new(1,1,1), Enum.Font.GothamBold, 12
Instance.new("UICorner", BindBtn).CornerRadius = UDim.new(0, 6) AddHoverAnim(BindBtn) BindBtn.MouseButton1Click:Connect(function() Settings.IsBinding = true BindBtn.Text = "... PRESS ANY KEY ..." end)

local HideBtn = Instance.new("TextButton", MiscPage) HideBtn.Size, HideBtn.BackgroundColor3 = UDim2.new(1, -5, 0, 32), Color3.fromRGB(55, 55, 65) HideBtn.Text, HideBtn.TextColor3, HideBtn.Font, HideBtn.TextSize = "HIDE KEY: ["..Settings.HideKey.."]", Color3.new(1,1,1), Enum.Font.GothamBold, 12
Instance.new("UICorner", HideBtn).CornerRadius = UDim.new(0, 6) AddHoverAnim(HideBtn) HideBtn.MouseButton1Click:Connect(function() Settings.IsBindingHide = true HideBtn.Text = "... PRESS ANY KEY ..." end)

Pages["Combat"].Visible = true

-- [[ 7. RUNSERVICE LOOP & CONTROLS ]]
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = i.Position startPos = MainFrame.Position end end)
UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - dragStart MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

UserInputService.InputBegan:Connect(function(i, g)
    if Settings.IsBinding then local k = (i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode.Name) or i.UserInputType.Name Settings.AimbotKey = k BindBtn.Text = "AIM KEY: ["..k.."]" Settings.IsBinding = false SaveSettings() return end
    if Settings.IsBindingHide then local k = (i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode.Name) or i.UserInputType.Name Settings.HideKey = k HideBtn.Text = "HIDE KEY: ["..k.."]" Settings.IsBindingHide = false SaveSettings() return end
    if not g and (i.KeyCode.Name == Settings.HideKey or i.UserInputType.Name == Settings.HideKey) then ScreenGui.Enabled = not ScreenGui.Enabled end
    if i.UserInputType == Enum.UserInputType.MouseButton1 then MouseHolding = true end
    if not g and (i.KeyCode.Name == Settings.AimbotKey or i.UserInputType.Name == Settings.AimbotKey) then Settings.AimbotHolding = true end
end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then MouseHolding = false end if i.KeyCode.Name == Settings.AimbotKey or i.UserInputType.Name == Settings.AimbotKey then Settings.AimbotHolding = false end end)
UserInputService.JumpRequest:Connect(function() if Settings.InfiniteJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end end)

local crosshairLines = {} for i=1,4 do crosshairLines[i] = Drawing.new("Line") crosshairLines[i].Thickness = 2.5 end
local FOVCircle = Drawing.new("Circle") FOVCircle.Thickness, FOVCircle.NumSides = 1.5, 60

local function GetClosestTarget()
    local target, dist = nil, Settings.FOVEnabled and Settings.FOVRadius or math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            if Settings.AimbotTeamCheck and IsTeammate(p) then continue end
            local pName = Settings.AimbotPart if pName == "Torso" and p.Character:FindFirstChild("UpperTorso") then pName = "UpperTorso" end
            local tPart = p.Character:FindFirstChild(pName)
            if tPart and IsPlayerVisible(tPart) then
                local pos, os = Camera:WorldToViewportPoint(tPart.Position)
                if os then
                    local mag = (Vector2.new(pos.X, pos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if mag < dist then dist = mag target = tPart end
                end
            end
        end
    end
    return target
end

RunService:BindToRenderStep("SOLIX_LOCK", 201, function()
    if Settings.AimbotEnabled then
        local target = GetClosestTarget()
        if target then
            local targetCF = CFrame.new(Camera.CFrame.Position, target.Position)
            local smoothVal = Settings.AimbotSmoothness / 100
            if smoothVal < 1 then Camera.CFrame = Camera.CFrame:Lerp(targetCF, smoothVal) else Camera.CFrame = targetCF end
            if Settings.AutoFireEnabled and tick() - lastAutoFireTime >= Settings.AutoFireDelay then if mouse1click then mouse1click() end lastAutoFireTime = tick() end
        end
    end
end)

-- 🌟 補給包自動吸取的時間變數
local ffaTime = 0

RunService.RenderStepped:Connect(function(dt)
    Lighting.ClockTime = Settings.NightModeEnabled and 0 or 14
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local chCol = Color3.fromRGB(Settings.CrosshairColorR, Settings.CrosshairColorG, Settings.CrosshairColorB)
    if Settings.CrosshairRainbow then chCol = GetRainbowColor() end

    if Settings.CrosshairEnabled then
        local theta = math.rad(tick() * Settings.CrosshairSpinSpeed)
        for i=1,4 do
            local angle = theta + (math.pi/2)*(i-1) local dir = Vector2.new(math.cos(angle), math.sin(angle))
            crosshairLines[i].From, crosshairLines[i].To, crosshairLines[i].Visible = center + (dir * Settings.CrosshairGap), center + (dir * (Settings.CrosshairGap + Settings.CrosshairSize)), true
            crosshairLines[i].Color = chCol
        end
    else for i=1,4 do crosshairLines[i].Visible = false end end
    
    local fovCol = Color3.fromRGB(Settings.FOVColorR, Settings.FOVColorG, Settings.FOVColorB)
    if Settings.FOVRainbow then fovCol = GetRainbowColor() end
    if Settings.FOVEnabled then FOVCircle.Position, FOVCircle.Radius, FOVCircle.Visible = center, Settings.FOVRadius, true FOVCircle.Color = fovCol else FOVCircle.Visible = false end

    if Settings.ChatSpamEnabled and tick() - lastChatSpamTime >= Settings.ChatSpamDelay then
        lastChatSpamTime = tick()
        pcall(function()
            local remote = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
            if remote then remote:FireServer(Settings.ChatSpamText, "All")
            else local tc = game:GetService("TextChatService"):FindFirstChild("TextChannels") and game:GetService("TextChatService").TextChannels:FindFirstChild("RBXGeneral")
                if tc then tc:SendAsync(Settings.ChatSpamText) end
            end
        end)
    end

    local char = LocalPlayer.Character local root = GetRoot(char) local hum = char and char:FindFirstChild("Humanoid")
    if not root or not hum then return end

    -- [[ 🌟 FFA 補給包自動收集核心偵測邏輯 ]]
    ffaTime = ffaTime + dt * 8
    local bounce = math.sin(ffaTime) * 4

    for _, obj in workspace:GetChildren() do
        if obj.Name == "_drop" and obj:IsA("BasePart") then
            if (Settings.FFA_AutoAmmo and obj:FindFirstChild("Ammo")) or
               (Settings.FFA_AutoHealth and obj:FindFirstChild("Health")) then
                obj.Anchored = true
                obj.CFrame = CFrame.new(root.Position + Vector3.new(0, bounce, 0))
                obj.Transparency = 1
                for _, child in pairs(obj:GetDescendants()) do
                    if child:IsA("BasePart") or child:IsA("UnionOperation") or child:IsA("MeshPart") or child:IsA("SpecialMesh") then
                        pcall(function() child.Transparency = 1 end)
                    end
                    if child:IsA("BillboardGui") or child:IsA("SurfaceGui") or child:IsA("ParticleEmitter") or child:IsA("SelectionBox") then
                        pcall(function() child.Enabled = false end)
                    end
                end
            end
        end
    end

    if Settings.VoidModeEnabled then
        root.Velocity = Vector3.zero local currentY = root.Position.Y
        if voidDirection == 1 then if currentY < 1000 then root.CFrame = root.CFrame * CFrame.new(0, 200, 0) else voidDirection = -1 end
        else if currentY > 0 then root.CFrame = root.CFrame * CFrame.new(0, -200, 0) else voidDirection = 1 end end
    end

    if Settings.StickToHeadEnabled and not Settings.VoidModeEnabled then
        local tp = GetNearestPlayer(150) if tp and tp.Character and tp.Character:FindFirstChild("Head") then root.CFrame = tp.Character.Head.CFrame * CFrame.new(0, 3.2, 0) root.Velocity = Vector3.zero end
    end

    if Settings.WalkSpeedEnabled and not Settings.VoidModeEnabled then hum.WalkSpeed = Settings.WalkSpeedValue end
    if Settings.JumpPowerEnabled and not Settings.VoidModeEnabled then hum.UseJumpPower = true hum.JumpPower = Settings.JumpPowerValue end

    if Settings.FlyEnabled and not Settings.StickToHeadEnabled and not Settings.VoidModeEnabled then
        hum:ChangeState(11) root.Velocity = Vector3.zero task.wait() local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then root.CFrame += (dir.Unit * Settings.FlySpeed * 0.016) end
    elseif hum:GetState() == Enum.HumanoidStateType.Physics then hum:ChangeState(7) end

    if not Settings.SpinEnabled and not Settings.FlyEnabled then hum.AutoRotate = true end
    if Settings.UpsideDownEnabled then root.CFrame *= CFrame.Angles(0, 0, math.rad(180)) end
end)

RunService.Stepped:Connect(function() 
    if (Settings.NoclipEnabled or Settings.StickToHeadEnabled or Settings.VoidModeEnabled) and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end 
    end 
end)

print("💎 GOOD HUB v6: FFA BOOSTERS TAB INTEGRATED SUCCESSFULLY!")
