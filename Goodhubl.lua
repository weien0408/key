-- [[ 安全加載防護：防止開局 nil 卡死 ]] 
if not game:IsLoaded() then 
    game.Loaded:Wait() 
end

local HttpService = game:GetService("HttpService")
local FileName = "YUNUKE_CONFIG_FINAL.json"

-- 配置設定檔
local Settings = {
    AimbotEnabled = false,
    SilentAimEnabled = false,
    AimbotKey = "B",
    AimbotPart = "Head",          -- 可選: Head, Torso, HumanoidRootPart
    AimbotSmoothness = 1,         -- 平滑度滑塊 (1-30, 1為瞬間鎖定)
    AimbotTeamCheck = false,      -- 智能隊友過濾
    AimbotHolding = false,
    AutoFireEnabled = false,
    AutoFireDelay = 0.05,
    
    ESPEnabled = false,
    ESPBoxes = false,             
    ESPSkeletons = false,         
    ESPNames = false,             
    ESPDistances = false,         
    ESPHealth = false,            
    ESPTeamCheck = false,         
    
    FlyEnabled = false,
    FlySpeed = 200,
    NoclipEnabled = false,
    SpinEnabled = false,
    SpinSpeed = 800,
    DanceEnabled = false,
    DanceID = "131758838511368",
    IsBinding = false,
    
    VoidModeEnabled = false,      -- 虛空模式開關
    
    ChatSpamEnabled = false,      
    ChatSpamText = "ezz",
    ChatSpamDelay = 3,
    
    UpsideDownEnabled = false,
    NightModeEnabled = false,
    CrosshairEnabled = false,
    CrosshairSize = 12,
    CrosshairGap = 8,
    CrosshairSpinSpeed = 150,
    FOVEnabled = false,
    FOVRadius = 150,
    HideKey = "RightShift",
    IsBindingHide = false,
    ControllerSpoofEnabled = false,
    VrSpoofEnabled = false,
    FPSBoostEnabled = false,
    DarkMapEnabled = false,
    Resolution43Enabled = false,
    WalkSpeedEnabled = false,
    WalkSpeedValue = 100,
    InfiniteJumpEnabled = false,
    StickToHeadEnabled = false 
}

local function SaveSettings()
    local success, encoded = pcall(function() return HttpService:JSONEncode(Settings) end)
    if success and writefile then writefile(FileName, encoded) end
end

local function LoadSettings()
    if isfile and isfile(FileName) then
        local success, content = pcall(function() return readfile(FileName) end)
        if success and content ~= "" then
            local decode_success, decoded = pcall(function() 
                return HttpService:JSONDecode(content)
            end)
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

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local lastAutoFireTime = 0
local lastChatSpamTime = 0
local voidDirection = 1

local DarkMapConnection = nil
local OriginalColors = {}

-- ====================================================================
-- [[ Base64 編解碼系統 (Config 分享代碼加密) ]]
-- ====================================================================
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64_encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d%d%d%d', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64_decode(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',b:find(x)-1
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d%d%d%d%d%d', function(x)
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- ====================================================================
-- [[ 高速動畫 SPIN BOT SYSTEM ]]
-- ====================================================================
local spinAnimTrack = nil
local function anim2track(asset_id)
    local success, objs = pcall(function() return game:GetObjects(asset_id) end)
    if success and objs then
        for i = 1, #objs do if objs[i]:IsA("Animation") then return objs[i].AnimationId end end
    end
    return asset_id
end

local function playSpinAnim(character)
    if not Settings.SpinEnabled then return end
    local Hum = character:FindFirstChildWhichIsA("Humanoid")
    if not Hum then return end
    pcall(function()
        for _, track in next, Hum:GetPlayingAnimationTracks() do track:Stop() end
        local animid = "92281817840531"
        if not animid:find("rbxassetid://") then animid = "rbxassetid://" .. animid end
        animid = anim2track(animid)
        local animation = Instance.new("Animation") animation.AnimationId = animid
        local anim = Hum:LoadAnimation(animation) spinAnimTrack = anim
        anim.Priority = Enum.AnimationPriority.Action4 anim:Play() anim:AdjustSpeed(99999)
        anim.Stopped:Connect(function() if Settings.SpinEnabled then playSpinAnim(character) end end)
    end)
end

local function ToggleSpinBot(state)
    Settings.SpinEnabled = state SaveSettings()
    if state then if LocalPlayer.Character then playSpinAnim(LocalPlayer.Character) end
    else
        if spinAnimTrack then pcall(function() spinAnimTrack:Stop() end) spinAnimTrack = nil end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            for _, track in next, LocalPlayer.Character.Humanoid:GetPlayingAnimationTracks() do track:Stop() end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid", 10) task.wait(0.5)
    if Settings.SpinEnabled then playSpinAnim(character) end
end)

-- ====================================================================
-- [[ 環境優化函數組 ]]
-- ====================================================================
local function ApplyDarkMap(state)
    local darkColor = Color3.fromRGB(30, 35, 38)
    local targetColor = Color3.fromRGB(151, 153, 163)
    local function isColorClose(c1, c2, threshold)
        threshold = (threshold or 10) / 255
        return math.abs(c1.R - c2.R) < threshold and math.abs(c1.G - c2.G) < threshold and math.abs(c1.B - c2.B) < threshold
    end
    if state then
        for _, v in ipairs(workspace:GetDescendants()) do
            if (v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) and isColorClose(v.Color, targetColor) then
                OriginalColors[v] = v.Color v.Color = darkColor
            end
        end
        DarkMapConnection = workspace.DescendantAdded:Connect(function(desc)
            if (desc:IsA("Part") or desc:IsA("MeshPart") or desc:IsA("UnionOperation")) and isColorClose(desc.Color, targetColor) then
                OriginalColors[desc] = desc.Color desc.Color = darkColor
            end
        end)
    else
        if DarkMapConnection then DarkMapConnection:Disconnect() DarkMapConnection = nil end
        for part, origColor in pairs(OriginalColors) do if part and part.Parent then part.Color = origColor end end
        table.clear(OriginalColors)
    end
end

local function ApplyFPSBoost(state)
    if state then
        settings().Rendering.QualityLevel = 1
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("MeshPart") then v.Material = Enum.Material.Plastic v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false
            elseif v:IsA("Explosion") then v.Visible = false end
        end
        Lighting.GlobalShadows = false Lighting.FogEnd = 9e9 settings().Physics.PhysicsEnvironmentalThrottle = 1
    else
        settings().Rendering.QualityLevel = Enum.QualityLevel.Default Lighting.GlobalShadows = true
    end
end

local function ApplyControllerSpoof(state)
    pcall(function()
        local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Replication"):WaitForChild("Fighter"):WaitForChild("SetControls")
        remote:FireServer(state and "Gamepad" or "MouseKeyboard")
    end)
end

local function ApplyVRSpoof(state)
    pcall(function()
        local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Replication"):WaitForChild("Fighter"):WaitForChild("SetControls")
        remote:FireServer(state and "VR" or "MouseKeyboard")
    end)
end

local danceAnim = Instance.new("Animation") danceAnim.AnimationId = "rbxassetid://" .. Settings.DanceID
local currentDanceTrack, loadedDanceChar = nil, nil

local function GetRoot(char) return char and char:FindFirstChild("HumanoidRootPart") end

-- ====================================================================
-- [[ 射線檢查功能：判斷目標是否暴露在視野中（沒被牆壁遮擋） ]]
-- ====================================================================
local function IsPlayerVisible(targetPart)
    if not targetPart or not LocalPlayer.Character then return false end
    
    -- 建立無視清單：自己與目標人物的所有配件均不能阻擋射線
    local ignoreList = {LocalPlayer.Character, targetPart.Parent, Camera}
    
    -- 起點為相機位置，終點為目標部位位置
    local startPos = Camera.CFrame.Position
    local endPos = targetPart.Position
    local direction = endPos - startPos
    
    local ray = Ray.new(startPos, direction)
    local hitPart, hitPosition = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
    
    -- 如果射線沒有撞擊到任何地圖上的其他障礙物，代表該目標在視野內
    if hitPart == nil then
        return true
    end
    return false
end

-- ====================================================================
-- [[ 1000x1000 螢幕範圍 ＋ 看到人才鎖定 ]]
-- ====================================================================
local function GetNearestPlayer()
    local target, shortestMouseDist = nil, math.huge
    local myCharacter = LocalPlayer.Character
    if not myCharacter or not myCharacter:FindFirstChild("HumanoidRootPart") then return nil end

    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local limitX, limitY = 500, 500

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local partName = Settings.AimbotPart or "Head"
            local targetPart = p.Character:FindFirstChild(partName) or p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            
            if targetPart and hum and hum.Health > 0 then
                -- 隊友檢查
                if Settings.AimbotTeamCheck and p.Team == LocalPlayer.Team then continue end

                -- 螢幕 2D 座標轉換
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local deltaX = math.abs(screenPos.X - screenCenter.X)
                    local deltaY = math.abs(screenPos.Y - screenCenter.Y)
                    
                    -- 檢查是否在 1000x1000 框格範圍之內
                    if deltaX <= limitX and deltaY <= limitY then
                        -- 【新增核心】：只有當眼睛看得到該玩家時，才計入自瞄鎖定目標
                        if IsPlayerVisible(targetPart) then
                            local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                            if mouseDist < shortestMouseDist then
                                shortestMouseDist = mouseDist 
                                target = p
                            end
                        end
                    end
                end
            end
        end
    end
    return target
end

-- ====================================================================
-- [[ ESP 繪製系統 ]]
-- ====================================================================
local function CreateESP(player)
    local Box = Drawing.new("Square")
    local HealthBarOutline = Drawing.new("Square") local HealthBar = Drawing.new("Square")
    local NameText = Drawing.new("Text") local DistText = Drawing.new("Text") local Skeleton = {}
    
    local BodyParts = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "LeftUpperArm"}, 
        {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"}, 
        {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"}, {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"}, 
        {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
    }
    local BodyPartsR6 = {{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"}}

    for i = 1, 15 do
        local line = Drawing.new("Line") line.Visible, line.Color, line.Thickness = false, Color3.fromRGB(255, 255, 255), 1
        table.insert(Skeleton, line)
    end
    NameText.Size, NameText.Center, NameText.Outline, NameText.Visible = 13, true, true, false
    DistText.Size, DistText.Center, DistText.Outline, DistText.Visible = 11, true, true, false

    local function HideAll()
        Box.Visible = false HealthBarOutline.Visible = false HealthBar.Visible = false NameText.Visible = false DistText.Visible = false
        for _, l in pairs(Skeleton) do l.Visible = false end
    end

    coroutine.wrap(function()
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if Settings.ESPEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 and player ~= LocalPlayer then
                if Settings.ESPTeamCheck and player.Team == LocalPlayer.Team then HideAll() return end
                local char, hum = player.Character, player.Character.Humanoid
                local position, onScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
                
                if onScreen then
                    local sizeX, sizeY = 2200 / position.Z, 3200 / position.Z
                    local boxPos = Vector2.new(position.X - sizeX / 2, position.Y - sizeY / 2)
                    
                    if Settings.ESPBoxes then Box.Size, Box.Position, Box.Visible = Vector2.new(sizeX, sizeY), boxPos, true else Box.Visible = false end
                    if Settings.ESPHealth then
                        local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        HealthBarOutline.Size, HealthBarOutline.Position, HealthBarOutline.Visible = Vector2.new(5, sizeY + 2), Vector2.new(boxPos.X - 7, boxPos.Y - 1), true
                        HealthBar.Size, HealthBar.Position, HealthBar.Color, HealthBar.Visible = Vector2.new(3, sizeY * pct), Vector2.new(boxPos.X - 6, boxPos.Y + (sizeY * (1 - pct))), Color3.fromHSV(pct * 0.3, 1, 1), true
                    else HealthBarOutline.Visible, HealthBar.Visible = false, false end
                    
                    if Settings.ESPNames then NameText.Text, NameText.Position, NameText.Visible = player.Name, Vector2.new(position.X, boxPos.Y - 16), true else NameText.Visible = false end
                    if Settings.ESPDistances then DistText.Text, DistText.Position, DistText.Visible = math.floor((Camera.CFrame.Position - char.HumanoidRootPart.Position).Magnitude) .. " studs", Vector2.new(position.X, boxPos.Y + sizeY + 2), true else DistText.Visible = false end

                    if Settings.ESPSkeletons then
                        local parts = (hum.RigType == Enum.HumanoidRigType.R15) and BodyParts or BodyPartsR6
                        for i, pair in pairs(parts) do
                            local p1, p2 = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
                            if p1 and p2 and Skeleton[i] then
                                local pos1, vis1 = Camera:WorldToViewportPoint(p1.Position)
                                local pos2, vis2 = Camera:WorldToViewportPoint(p2.Position)
                                if vis1 and vis2 then Skeleton[i].From, Skeleton[i].To, Skeleton[i].Visible = Vector2.new(pos1.X, pos1.Y), Vector2.new(pos2.X, pos2.Y), true else Skeleton[i].Visible = false end
                            end
                        end
                    else for _, l in pairs(Skeleton) do l.Visible = false end end
                else HideAll() end
            else
                HideAll()
                if not player.Parent then connection:Disconnect() Box:Remove() HealthBarOutline:Remove() HealthBar:Remove() NameText:Remove() DistText:Remove() for _, l in pairs(Skeleton) do l:Remove() end end
            end
        end)
    end)()
end

for _, v in pairs(Players:GetPlayers()) do if v ~= LocalPlayer then CreateESP(v) end end
Players.PlayerAdded:Connect(CreateESP)

-- ====================================================================
-- [[ UI 視覺界面系統 ]]
-- ====================================================================
if game:GetService("CoreGui"):FindFirstChild("YUNUKE_PIXEL_FINAL") then game:GetService("CoreGui")["YUNUKE_PIXEL_FINAL"]:Destroy() end
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui")) ScreenGui.Name = "YUNUKE_PIXEL_FINAL" ScreenGui.ResetOnSpawn = false

local OpenBtn = Instance.new("TextButton", ScreenGui) OpenBtn.Size, OpenBtn.Position = UDim2.new(0, 80, 0, 35), UDim2.new(0, 15, 0.45, 0)
OpenBtn.BackgroundColor3, OpenBtn.BackgroundTransparency, OpenBtn.Text, OpenBtn.TextColor3, OpenBtn.Font, OpenBtn.TextSize = Color3.fromRGB(20, 20, 25), 0.2, "OPEN", Color3.new(1,1,1), Enum.Font.GothamBold, 13
Instance.new("UICorner", OpenBtn).CornerRadius = UDim.new(0, 8) local OpenStroke = Instance.new("UIStroke", OpenBtn) OpenStroke.Color = Color3.fromRGB(80, 80, 90)

local MainFrame = Instance.new("Frame", ScreenGui) MainFrame.Size, MainFrame.Position, MainFrame.BackgroundColor3, MainFrame.BackgroundTransparency, MainFrame.Visible = UDim2.new(0, 440, 0, 380), UDim2.new(0.5, -220, 0.5, -190), Color3.fromRGB(18, 18, 24), 0.15, false
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12) local MainStroke = Instance.new("UIStroke", MainFrame) MainStroke.Color, MainStroke.Transparency = Color3.fromRGB(255, 255, 255), 0.4

local Header = Instance.new("Frame", MainFrame) Header.Size, Header.BackgroundColor3, Header.BackgroundTransparency = UDim2.new(1, 0, 0, 40), Color3.fromRGB(255, 255, 255), 0.1
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)
local Title = Instance.new("TextLabel", Header) Title.Size, Title.Position, Title.BackgroundTransparency, Title.Text, Title.TextColor3, Title.Font, Title.TextSize, Title.TextXAlignment = UDim2.new(1, -10, 1, 0), UDim2.new(0, 15, 0, 0), 1, "GOOD HUB v2 (ADVANCED)", Color3.fromRGB(15, 15, 20), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left

OpenBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible OpenBtn.Text = MainFrame.Visible and "CLOSE" or "OPEN" end)

local TabHolder = Instance.new("Frame", MainFrame) TabHolder.Size, TabHolder.Position, TabHolder.BackgroundColor3, TabHolder.BackgroundTransparency = UDim2.new(0, 110, 1, -55), UDim2.new(0, 8, 0, 48), Color3.fromRGB(30, 30, 40), 0.4
Instance.new("UICorner", TabHolder).CornerRadius = UDim.new(0, 8) Instance.new("UIListLayout", TabHolder).Padding = UDim.new(0, 4)

local ContentHolder = Instance.new("Frame", MainFrame) ContentHolder.Size, ContentHolder.Position, ContentHolder.BackgroundTransparency = UDim2.new(1, -140, 1, -55), UDim2.new(0, 125, 0, 48), 1

local Pages = {}
local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame", ContentHolder) Page.Size, Page.BackgroundTransparency, Page.Visible, Page.ScrollBarThickness, Page.CanvasSize = UDim2.new(1, 0, 1, 0), 1, false, 2, UDim2.new(0,0,0,0)
    local Layout = Instance.new("UIListLayout", Page) Layout.Padding = UDim.new(0, 6) Pages[name] = Page
    
    local TabBtn = Instance.new("TextButton", TabHolder) TabBtn.Size, TabBtn.BackgroundTransparency, TabBtn.Text, TabBtn.TextColor3, TabBtn.Font, TabBtn.TextSize, TabBtn.TextXAlignment = UDim2.new(1, 0, 0, 32), 1, "  " .. name:upper(), Color3.fromRGB(160, 160, 170), Enum.Font.GothamSemibold, 12, Enum.TextXAlignment.Left
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)
    
    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end Page.Visible = true
        for _, b in pairs(TabHolder:GetChildren()) do if b:IsA("TextButton") then b.TextColor3, b.BackgroundTransparency = Color3.fromRGB(160, 160, 170), 1 end end
        TabBtn.TextColor3, TabBtn.BackgroundColor3, TabBtn.BackgroundTransparency = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255), 0.85
    end)
    return Page
end

local function AddToggle(parent, text, key, callback)
    local Btn = Instance.new("TextButton", parent) Btn.Size, Btn.BackgroundColor3, Btn.BackgroundTransparency, Btn.Text = UDim2.new(1, -5, 0, 34), Color3.fromRGB(40, 40, 50), 0.5, ""
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    local L = Instance.new("TextLabel", Btn) L.Size, L.Position, L.BackgroundTransparency, L.Text, L.TextColor3, L.Font, L.TextSize, L.TextXAlignment = UDim2.new(1, -50, 1, 0), UDim2.new(0, 10, 0, 0), 1, text:upper(), Color3.fromRGB(230, 230, 235), Enum.Font.GothamMedium, 12, Enum.TextXAlignment.Left
    local S = Instance.new("TextLabel", Btn) S.Size, S.Position, S.BackgroundTransparency, S.Text, S.TextColor3, S.Font, S.TextSize = UDim2.new(0, 40, 1, 0), UDim2.new(1, -45, 0, 0), 1, Settings[key] and "●" or "○", Settings[key] and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 75, 75), Enum.Font.GothamBold, 13
    Btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key] SaveSettings() S.Text = Settings[key] and "●" or "○" S.TextColor3 = Settings[key] and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 75, 75)
        if callback then callback(Settings[key]) end
    end)
    parent.CanvasSize = UDim2.new(0, 0, 0, parent.UIListLayout.AbsoluteContentSize.Y + 5)
end

local function AddSlider(parent, text, max, min, key, callback)
    local Frame = Instance.new("Frame", parent) Frame.Size, Frame.BackgroundTransparency = UDim2.new(1, -5, 0, 50), 1
    local L = Instance.new("TextLabel", Frame) L.Size, L.Position, L.Text, L.TextColor3, L.Font, L.TextSize, L.BackgroundTransparency, L.TextXAlignment = UDim2.new(1, 0, 0, 22), UDim2.new(0, 4, 0, 0), text:upper() .. ": " .. Settings[key], Color3.fromRGB(200, 200, 210), Enum.Font.GothamMedium, 11, 1, Enum.TextXAlignment.Left
    local Bar = Instance.new("TextButton", Frame) Bar.Size, Bar.Position, Bar.BackgroundColor3, Bar.BackgroundTransparency, Bar.Text = UDim2.new(1, -8, 0, 10), UDim2.new(0, 4, 0, 26), Color3.fromRGB(45, 45, 55), 0.4, ""
    Instance.new("UICorner", Bar).CornerRadius = UDim.new(0, 4)
    local Fill = Instance.new("Frame", Bar) Fill.Size, Fill.BackgroundColor3 = UDim2.new(math.clamp((Settings[key] - min) / (max - min), 0, 1), 0, 1, 0), Color3.fromRGB(0, 160, 255)
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 4)
    local dragging = false
    local function move(input)
        local pos = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * pos) Settings[key] = value SaveSettings() L.Text = text:upper() .. ": " .. value Fill.Size = UDim2.new(pos, 0, 1, 0) if callback then callback(value) end
    end
    Bar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true move(input) end end)
    Bar.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then move(input) end end)
    parent.CanvasSize = UDim2.new(0, 0, 0, parent.UIListLayout.AbsoluteContentSize.Y + 5)
end

local function AddCycle(parent, text, options, key, callback)
    local Btn = Instance.new("TextButton", parent) Btn.Size, Btn.BackgroundColor3, Btn.BackgroundTransparency, Btn.Text = UDim2.new(1, -5, 0, 34), Color3.fromRGB(40, 40, 50), 0.5, ""
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)
    local L = Instance.new("TextLabel", Btn) L.Size, L.Position, L.BackgroundTransparency, L.Text, L.TextColor3, L.Font, L.TextSize, L.TextXAlignment = UDim2.new(1, -120, 1, 0), UDim2.new(0, 10, 0, 0), 1, text:upper(), Color3.fromRGB(230, 230, 235), Enum.Font.GothamMedium, 12, Enum.TextXAlignment.Left
    local S = Instance.new("TextLabel", Btn) S.Size, S.Position, S.BackgroundTransparency, S.Text, S.TextColor3, S.Font, S.TextSize, S.TextXAlignment = UDim2.new(0, 100, 1, 0), UDim2.new(1, -110, 0, 0), 1, tostring(Settings[key]):upper(), Color3.fromRGB(0, 180, 255), Enum.Font.GothamBold, 12, Enum.TextXAlignment.Right
    Btn.MouseButton1Click:Connect(function()
        local idx = 1 for i, opt in ipairs(options) do if opt:lower() == tostring(Settings[key]):lower() then idx = i break end end
        local nextIdx = idx + 1 if nextIdx > #options then nextIdx = 1 end Settings[key] = options[nextIdx] SaveSettings() S.Text = tostring(Settings[key]):upper() if callback then callback(Settings[key]) end
    end)
    parent.CanvasSize = UDim2.new(0, 0, 0, parent.UIListLayout.AbsoluteContentSize.Y + 5)
end

local CombatPage = CreatePage("Combat") local VisualPage = CreatePage("Visual") local MovePage = CreatePage("Move") local MiscPage = CreatePage("Misc")

-- 註冊按鈕組
AddToggle(CombatPage, "Aimbot", "AimbotEnabled")
AddToggle(CombatPage, "Silent Aim", "SilentAimEnabled")
AddCycle(CombatPage, "Aimbot Part", {"Head", "Torso", "HumanoidRootPart"}, "AimbotPart")
AddSlider(CombatPage, "Aimbot Smoothness", 30, 1, "AimbotSmoothness")
AddToggle(CombatPage, "Aimbot Team Check", "AimbotTeamCheck")
AddToggle(CombatPage, "Auto Fire", "AutoFireEnabled")
AddSlider(CombatPage, "Auto Fire Delay", 10, 1, "AutoFireDelay", function(v) Settings.AutoFireDelay = v/100 end)

AddToggle(VisualPage, "ESP Master Toggle", "ESPEnabled")
AddToggle(VisualPage, "ESP Boxes", "ESPBoxes")
AddToggle(VisualPage, "ESP Skeletons", "ESPSkeletons")
AddToggle(VisualPage, "ESP Names", "ESPNames")
AddToggle(VisualPage, "ESP Distances", "ESPDistances")
AddToggle(VisualPage, "ESP Health", "ESPHealth")
AddToggle(VisualPage, "ESP Team Check", "ESPTeamCheck")
AddToggle(VisualPage, "Crosshair Switch", "CrosshairEnabled")
AddSlider(VisualPage, "Crosshair Size", 30, 4, "CrosshairSize")
AddSlider(VisualPage, "Crosshair Gap", 20, 0, "CrosshairGap")
AddSlider(VisualPage, "Crosshair Speed", 400, 0, "CrosshairSpinSpeed")
AddToggle(VisualPage, "FOV Circle", "FOVEnabled")
AddSlider(VisualPage, "FOV Radius", 400, 30, "FOVRadius")

-- Move 頁面
AddToggle(MovePage, "Void Mode (Y 0-1000)", "VoidModeEnabled")
AddToggle(MovePage, "Fly Hack", "FlyEnabled")
AddSlider(MovePage, "Fly Speed", 500, 20, "FlySpeed")
AddToggle(MovePage, "Noclip Walls", "NoclipEnabled")
AddToggle(MovePage, "SpinBot Animation", "SpinEnabled", ToggleSpinBot)
AddSlider(MovePage, "Spin Speed (Legacy)", 2000, 100, "SpinSpeed")
AddToggle(MovePage, "WalkSpeed Bypass", "WalkSpeedEnabled")
AddSlider(MovePage, "WalkSpeed Value", 250, 16, "WalkSpeedValue")
AddToggle(MovePage, "Infinite Jump", "InfiniteJumpEnabled")
AddToggle(MovePage, "Stick To Head", "StickToHeadEnabled")

-- Misc 頁面
AddToggle(MiscPage, "Chat Spam", "ChatSpamEnabled")
AddSlider(MiscPage, "Chat Spam Delay", 10, 1, "ChatSpamDelay")

local ChatTextBox = Instance.new("TextBox", MiscPage) ChatTextBox.Size, ChatTextBox.BackgroundColor3, ChatTextBox.BackgroundTransparency, ChatTextBox.PlaceholderText, ChatTextBox.Text, ChatTextBox.TextColor3, ChatTextBox.Font, ChatTextBox.TextSize = UDim2.new(1, -5, 0, 32), Color3.fromRGB(40, 40, 50), 0.5, "Input Spam Text & Enter...", Settings.ChatSpamText, Color3.new(1, 1, 1), Enum.Font.Gotham, 12 Instance.new("UICorner", ChatTextBox).CornerRadius = UDim.new(0, 6) ChatTextBox.FocusLost:Connect(function(enter) if enter then Settings.ChatSpamText = ChatTextBox.Text SaveSettings() end end)
local DanceIDBox = Instance.new("TextBox", MiscPage) DanceIDBox.Size, DanceIDBox.BackgroundColor3, DanceIDBox.BackgroundTransparency, DanceIDBox.PlaceholderText, DanceIDBox.Text, DanceIDBox.TextColor3, DanceIDBox.Font, DanceIDBox.TextSize = UDim2.new(1, -5, 0, 32), Color3.fromRGB(40, 40, 50), 0.5, "Input Dance ID & Enter...", Settings.DanceID, Color3.new(1, 1, 1), Enum.Font.Gotham, 12 Instance.new("UICorner", DanceIDBox).CornerRadius = UDim.new(0, 6) DanceIDBox.FocusLost:Connect(function(enter) if enter then Settings.DanceID = DanceIDBox.Text SaveSettings danceAnim.AnimationId = "rbxassetid://" .. Settings.DanceID if currentDanceTrack then currentDanceTrack:Stop() currentDanceTrack = nil end loadedDanceChar = nil end end)

local function PolishSpecialButton(btn, color) btn.Font, btn.BorderSizePixel, btn.BackgroundColor3, btn.BackgroundTransparency = Enum.Font.GothamBold, 0, color, 0.3 Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6) end
local SkinBtn = Instance.new("TextButton", MiscPage) SkinBtn.Size, SkinBtn.Text, SkinBtn.TextColor3, SkinBtn.TextSize = UDim2.new(1, -5, 0, 32), "DANCE ANIMATION BYPASS", Color3.new(1,1,1), 12 PolishSpecialButton(SkinBtn, Color3.fromRGB(200, 40, 150))
SkinBtn.MouseButton1Click:Connect(function() local char = LocalPlayer.Character if char and char:FindFirstChildOfClass("Humanoid") then local hum = char:FindFirstChildOfClass("Humanoid") if loadedDanceChar ~= char or not currentDanceTrack then currentDanceTrack = hum:LoadAnimation(danceAnim) currentDanceTrack.Looped = true loadedDanceChar = char end Settings.DanceEnabled = not Settings.DanceEnabled if Settings.DanceEnabled then currentDanceTrack:Play() else currentDanceTrack:Stop() end end end)

AddToggle(MiscPage, "Anti Controller Spoof", "ControllerSpoofEnabled", ApplyControllerSpoof)
AddToggle(MiscPage, "Anti VR Spoof", "VrSpoofEnabled", ApplyVRSpoof)
AddToggle(MiscPage, "FPS Boost Optimization", "FPSBoostEnabled", ApplyFPSBoost)
AddToggle(MiscPage, "Dark Theme Map", "DarkMapEnabled", ApplyDarkMap)
AddToggle(MiscPage, "Resolution Stretch 4:3", "Resolution43Enabled")
AddToggle(MiscPage, "Invert Character (UpsideDown)", "UpsideDownEnabled")
AddToggle(MiscPage, "Midnight Mode", "NightModeEnabled")

-- CONFIG SHARE SYSTEM 面板
local ConfigLabel = Instance.new("TextLabel", MiscPage) ConfigLabel.Size, ConfigLabel.BackgroundTransparency, ConfigLabel.Text, ConfigLabel.TextColor3, ConfigLabel.Font, ConfigLabel.TextSize = UDim2.new(1, -5, 0, 20), 1, "—— CONFIG SHARE SYSTEM ——", Color3.fromRGB(150, 150, 160), Enum.Font.GothamBold, 11
local ConfigBox = Instance.new("TextBox", MiscPage) ConfigBox.Size, ConfigBox.BackgroundColor3, ConfigBox.BackgroundTransparency, ConfigBox.PlaceholderText, ConfigBox.Text, ConfigBox.TextColor3, ConfigBox.Font, ConfigBox.TextSize, ConfigBox.ClearTextOnFocus = UDim2.new(1, -5, 0, 34), Color3.fromRGB(25, 25, 35), 0.3, "Paste or Export Share Code Here...", "", Color3.fromRGB(0, 230, 255), Enum.Font.Gotham, 11, false Instance.new("UICorner", ConfigBox).CornerRadius = UDim.new(0, 6) local ConfigBoxStroke = Instance.new("UIStroke", ConfigBox) ConfigBoxStroke.Color = Color3.fromRGB(0, 140, 255)
local BtnFrame = Instance.new("Frame", MiscPage) BtnFrame.Size, BtnFrame.BackgroundTransparency = UDim2.new(1, -5, 0, 32), 1 local BtnGrid = Instance.new("UIGridLayout", BtnFrame) BtnGrid.CellSize, BtnGrid.Padding = UDim2.new(0.31, 0, 1, 0), UDim2.new(0.03, 0, 0, 0)
local ExportBtn = Instance.new("TextButton", BtnFrame) ExportBtn.Text = "EXPORT" PolishSpecialButton(ExportBtn, Color3.fromRGB(0, 150, 100)) ExportBtn.TextColor3, ExportBtn.TextSize = Color3.new(1,1,1), 11
local ImportBtn = Instance.new("TextButton", BtnFrame) ImportBtn.Text = "IMPORT" PolishSpecialButton(ImportBtn, Color3.fromRGB(200, 100, 0)) ImportBtn.TextColor3, ImportBtn.TextSize = Color3.new(1,1,1), 11
local CopyBtn = Instance.new("TextButton", BtnFrame) CopyBtn.Text = "COPY" PolishSpecialButton(CopyBtn, Color3.fromRGB(60, 60, 80)) CopyBtn.TextColor3, CopyBtn.TextSize = Color3.new(1,1,1), 11

ExportBtn.MouseButton1Click:Connect(function() local success, encoded = pcall(function() return HttpService:JSONEncode(Settings) end) if success then ConfigBox.Text = base64_encode(encoded) ConfigLabel.Text = "EXPORTED SUCCESS!" task.delay(2, function() ConfigLabel.Text = "—— CONFIG SHARE SYSTEM ——" end) end end)
ImportBtn.MouseButton1Click:Connect(function() local code = ConfigBox.Text if code and code ~= "" then local dSuccess, rawJson = pcall(function() return base64_decode(code) end) if dSuccess then local jSuccess, decodedTable = pcall(function() return HttpService:JSONDecode(rawJson) end) if jSuccess and type(decodedTable) == "table" then for k, v in pairs(decodedTable) do if Settings[k] ~= nil then Settings[k] = v end end SaveSettings() ConfigLabel.Text = "IMPORT SUCCESS!" ApplyDarkMap(Settings.DarkMapEnabled) ApplyFPSBoost(Settings.FPSBoostEnabled) ToggleSpinBot(Settings.SpinEnabled) return end end end ConfigLabel.Text = "INVALID SHARE CODE!" task.delay(2, function() ConfigLabel.Text = "—— CONFIG SHARE SYSTEM ——" end) end)
CopyBtn.MouseButton1Click:Connect(function() if ConfigBox.Text ~= "" and setclipboard then setclipboard(ConfigBox.Text) ConfigLabel.Text = "COPIED TO CLIPBOARD!" task.delay(2, function() ConfigLabel.Text = "—— CONFIG SHARE SYSTEM ——" end) end end)

Pages["Combat"].Visible = true
MiscPage.CanvasSize = UDim2.new(0, 0, 0, MiscPage.UIListLayout.AbsoluteContentSize.Y + 15)

-- ====================================================================
-- [[ 鍵盤滑鼠主事件監聽 ]]
-- ====================================================================
local MouseHolding = false
UserInputService.InputBegan:Connect(function(i, g)
    if not g and i.KeyCode.Name == "P" then
        Settings.IsBinding = true Title.Text = "PRESS ANY KEY TO BIND AIMBOT..."
        local c; c = UserInputService.InputBegan:Connect(function(input) if input.KeyCode.Name ~= "Unknown" then Settings.AimbotKey = input.KeyCode.Name Settings.IsBinding = false Title.Text = "GOOD HUB v2 (ADVANCED)" SaveSettings() c:Disconnect() end end) return
    end
    if not g and i.KeyCode.Name == "L" then
        Settings.IsBindingHide = true Title.Text = "PRESS ANY KEY TO BIND HIDE..."
        local c; c = UserInputService.InputBegan:Connect(function(input) if input.KeyCode.Name ~= "Unknown" then Settings.HideKey = input.KeyCode.Name Settings.IsBindingHide = false Title.Text = "GOOD HUB v2 (ADVANCED)" SaveSettings() c:Disconnect() end end) return
    end
    if not g and (i.KeyCode.Name == Settings.HideKey or i.UserInputType.Name == Settings.HideKey) then ScreenGui.Enabled = not ScreenGui.Enabled end
    if i.UserInputType == Enum.UserInputType.MouseButton1 then MouseHolding = true end
    if not g and (i.KeyCode.Name == Settings.AimbotKey or i.UserInputType.Name == Settings.AimbotKey) then Settings.AimbotHolding = true end
end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then MouseHolding = false end if i.KeyCode.Name == Settings.AimbotKey or i.UserInputType.Name == Settings.AimbotKey then Settings.AimbotHolding = false end end)
UserInputService.JumpRequest:Connect(function() if Settings.InfiniteJumpEnabled and LocalPlayer.Character then local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid") if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end)

local crosshairLines = {} for i = 1, 4 do local line = Drawing.new("Line") line.Visible, line.Color, line.Thickness = false, Color3.fromRGB(15, 30, 150), 2.5 table.insert(crosshairLines, line) end
local crosshairText = Drawing.new("Text") crosshairText.Visible, crosshairText.Color, crosshairText.Text, crosshairText.Size, crosshairText.Center, crosshairText.Outline, crosshairText.Font = false, Color3.fromRGB(15, 30, 150), "goodhub", 16, true, true, 2
local FOVCircle = Drawing.new("Circle") FOVCircle.Color, FOVCircle.Thickness, FOVCircle.NumSides, FOVCircle.Filled, FOVCircle.Transparency = Color3.fromRGB(0, 255, 140), 1.5, 64, false, 0.7

-- ====================================================================
-- [[ 每幀物理循環處理（自瞄與移動） ]]
-- ====================================================================
RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    local root = GetRoot(char)
    local hum = char and char:FindFirstChild("Humanoid")
    
    if hum and root then
        if Settings.WalkSpeedEnabled and not Settings.VoidModeEnabled then
            hum.WalkSpeed = Settings.WalkSpeedValue
        end

        -- Void Mode 幽靈穿透與傳送
        if Settings.VoidModeEnabled then
            root.Velocity = Vector3.zero
            root.RotVelocity = Vector3.zero
            
            local currentY = root.Position.Y
            if voidDirection == 1 then
                if currentY < 1000 then
                    root.CFrame = root.CFrame * CFrame.new(0, 250, 0)
                else
                    voidDirection = -1
                end
            else
                if currentY > 0 then
                    root.CFrame = root.CFrame * CFrame.new(0, -250, 0)
                else
                    voidDirection = 1
                end
            end
        end
    end

    if Settings.ChatSpamEnabled and tick() - lastChatSpamTime >= Settings.ChatSpamDelay then
        local chatChannel = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
        if chatChannel then chatChannel:FireServer(Settings.ChatSpamText, "All") else pcall(function() game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(Settings.ChatSpamText) end) end
        lastChatSpamTime = tick()
    end

    -- 1000x1000 自瞄與自動開火（此處已套用可視玩家過濾）
    if (Settings.AimbotEnabled and Settings.AimbotHolding) or (Settings.SilentAimEnabled and MouseHolding) then
        local target = GetNearestPlayer()
        if target and target.Character then
            local partName = Settings.AimbotPart or "Head"
            local p = target.Character:FindFirstChild(partName) or target.Character:FindFirstChild("HumanoidRootPart")
            if p then
                if Settings.SilentAimEnabled then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, p.Position)
                else
                    local smoothness = math.clamp(Settings.AimbotSmoothness or 1, 1, 30)
                    TweenService:Create(Camera, TweenInfo.new(smoothness/100, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(Camera.CFrame.Position, p.Position)}):Play()
                end
                if Settings.AutoFireEnabled and tick() - lastAutoFireTime >= Settings.AutoFireDelay then
                    if mouse1click then mouse1click() end lastAutoFireTime = tick()
                end
            end
        end
    end

    if Settings.Resolution43Enabled then Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 0.75, 0, 0, 0, 0.75) end
end)

-- 主渲染與 StickToHead 循環
RunService.RenderStepped:Connect(function()
    Lighting.ClockTime = Settings.NightModeEnabled and 0 or 14
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    if Settings.CrosshairEnabled then
        local theta = math.rad(tick() * Settings.CrosshairSpinSpeed)
        local size, gap = Settings.CrosshairSize, Settings.CrosshairGap
        local directions = {Vector2.new(math.cos(theta), math.sin(theta)), Vector2.new(-math.sin(theta), math.cos(theta)), Vector2.new(-math.cos(theta), -math.sin(theta)), Vector2.new(math.sin(theta), -math.cos(theta))}
        for i, dir in ipairs(directions) do crosshairLines[i].From, crosshairLines[i].To, crosshairLines[i].Visible = center + dir * gap, center + dir * (gap + size), true end
        crosshairText.Position, crosshairText.Visible = center + Vector2.new(0, gap + size + 5), true
    else for _, l in pairs(crosshairLines) do l.Visible = false end crosshairText.Visible = false end

    if Settings.FOVEnabled then FOVCircle.Position, FOVCircle.Radius, FOVCircle.Visible = center, Settings.FOVRadius, true else FOVCircle.Visible = false end

    if Settings.StickToHeadEnabled and not Settings.VoidModeEnabled then
        local target = GetNearestPlayer()
        if target and target.Character and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local tHead = target.Character:FindFirstChild("Head")
            if tHead then LocalPlayer.Character.HumanoidRootPart.CFrame = tHead.CFrame * CFrame.new(0, 0, 2) end
        end
    end
end)

-- 飛行與無衝突模式
RunService.PreAnimation:Connect(function(dt)
    local char = LocalPlayer.Character local root = char and char:FindFirstChild("HumanoidRootPart") local hum = char and char:FindFirstChild("Humanoid")
    if not root or not hum then return end

    if Settings.FlyEnabled and not Settings.VoidModeEnabled then
        hum:ChangeState(Enum.HumanoidStateType.Physics) root.Velocity = Vector3.zero local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then root.CFrame += (dir.Unit * Settings.FlySpeed * dt) end
    elseif hum:GetState() == Enum.HumanoidStateType.Physics and not Settings.VoidModeEnabled then hum:ChangeState(7) end

    if not Settings.SpinEnabled and not Settings.FlyEnabled then hum.AutoRotate = true end
    if Settings.UpsideDownEnabled then root.CFrame *= CFrame.Angles(0, 0, math.rad(180)) end
end)

-- 物理碰撞管理（確保 Noclip 與 VoidMode 的完全穿透性）
RunService.Stepped:Connect(function() 
    if (Settings.NoclipEnabled or Settings.StickToHeadEnabled or Settings.VoidModeEnabled) and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then 
                v.CanCollide = false
                if Settings.VoidModeEnabled then
                    v.Velocity = Vector3.zero
                end
            end
        end
    end
end)
