
if game:GetService("CoreGui"):FindFirstChild("YunukeKeySystem") then
    game:GetService("CoreGui").YunukeKeySystem:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local KeyInput = Instance.new("TextBox")
local SubmitBtn = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")


ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.Name = "YunukeKeySystem"
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Position = UDim2.new(0.5, -125, 0.5, -75)
MainFrame.Size = UDim2.new(0, 250, 0, 150)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 10)


Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Font = Enum.Font.GothamBold
Title.Text = "Yunuke Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16


KeyInput.Parent = MainFrame
KeyInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
KeyInput.Position = UDim2.new(0.1, 0, 0.35, 0)
KeyInput.Size = UDim2.new(0.8, 0, 0, 35)
KeyInput.Font = Enum.Font.Gotham
KeyInput.PlaceholderText = "Enter Key Here..."
KeyInput.Text = ""
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.TextSize = 14

local InputCorner = Instance.new("UICorner", KeyInput)


SubmitBtn.Parent = MainFrame
SubmitBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
SubmitBtn.Position = UDim2.new(0.1, 0, 0.65, 5)
SubmitBtn.Size = UDim2.new(0.8, 0, 0, 35)
SubmitBtn.Font = Enum.Font.GothamBold
SubmitBtn.Text = "Verify Key"
SubmitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SubmitBtn.TextSize = 14

local BtnCorner = Instance.new("UICorner", SubmitBtn)


local Keys = {
    ["KSIW-EI12-QSID1-DSQK"] = true,
    ["SDQII-1EID-XQWSOKD-SMC"] = true,
    ["131-DQSKD-1239DS"] = true,
    ["312JDS-QWKDJLSQD-123E19KDS"] = true
    ["SISHJ1-1283JK-12193KSKASQ"] = true
}

SubmitBtn.MouseButton1Click:Connect(function()
    local input = KeyInput.Text
    
    if Keys[input] then
        SubmitBtn.Text = "Success!"
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        
        task.wait(1)
        
    
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/weien0408/yunuke/refs/heads/main/Yunuke%20hub.lua"))()
        end)
        
        if success then
            ScreenGui:Destroy()
        else
            SubmitBtn.Text = "Error Loading Script"
            warn("Error: " .. err)
        end
    else
        SubmitBtn.Text = "Invalid Key!"
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        task.wait(1.5)
        SubmitBtn.Text = "Verify Key"
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
    end
end)
