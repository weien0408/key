
local CorrectKey = "SUD1UDjd-Hiod129-74311du7UH1-.Y7D8y"
local ScriptURL = "https://raw.githubusercontent.com/weien0408/goodhub/refs/heads/main/goodhub.lua"


local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local Title = Instance.new("TextLabel")
local KeyInput = Instance.new("TextBox")
local SubmitBtn = Instance.new("TextButton")
local BtnCorner = Instance.new("UICorner")


ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.Name = "GoodHubKeySystem"


MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -90)
MainFrame.Size = UDim2.new(0, 300, 0, 180)
MainFrame.Active = true
MainFrame.Draggable = true

UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame


Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 50)
Title.Text = "GoodHub Verification"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1
Title.TextSize = 22
Title.Font = Enum.Font.GothamBold


KeyInput.Parent = MainFrame
KeyInput.Position = UDim2.new(0.1, 0, 0.35, 0)
KeyInput.Size = UDim2.new(0.8, 0, 0, 35)
KeyInput.PlaceholderText = "Paste Key Here..."
KeyInput.Text = ""
KeyInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.Font = Enum.Font.Gotham
KeyInput.TextSize = 14
KeyInput.ClearTextOnFocus = false

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 8)
InputCorner.Parent = KeyInput


SubmitBtn.Parent = MainFrame
SubmitBtn.Position = UDim2.new(0.2, 0, 0.7, 0)
SubmitBtn.Size = UDim2.new(0.6, 0, 0, 40)
SubmitBtn.Text = "Verify"
SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 210)
SubmitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SubmitBtn.Font = Enum.Font.GothamBold
SubmitBtn.TextSize = 18

BtnCorner.CornerRadius = UDim.new(0, 10)
BtnCorner.Parent = SubmitBtn


SubmitBtn.MouseButton1Click:Connect(function()
    if KeyInput.Text == CorrectKey then
        SubmitBtn.Text = "Success!"
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        
        task.wait(0.5)
        ScreenGui:Destroy()
        

        loadstring(game:HttpGet(ScriptURL))()
    else
        SubmitBtn.Text = "Invalid Key"
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        
        task.wait(1)
        SubmitBtn.Text = "Verify"
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 210)
    end
end)
