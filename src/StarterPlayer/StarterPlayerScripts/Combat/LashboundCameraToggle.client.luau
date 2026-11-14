-- Camera toggle: V on keyboard, R3 on PlayStation/Xbox; touch button on mobile.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local first=false
local minZoom,maxZoom=6,18
local button
local function apply()
    player.CameraMode=first and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
    if not first then
        player.CameraMinZoomDistance=minZoom
        player.CameraMaxZoomDistance=maxZoom
    end
    if button then button.Text=first and "CAMERA: 1P" or "CAMERA: 3P" end
end
local function toggle()
    if not first then
        minZoom=math.max(0.5,player.CameraMinZoomDistance)
        maxZoom=math.max(minZoom,player.CameraMaxZoomDistance)
    end
    first=not first
    apply()
end
UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.V or input.KeyCode==Enum.KeyCode.ButtonR3 then toggle() end
end)
do
    local gui=Instance.new("ScreenGui")
    gui.Name="LashboundCameraToggleGui"
    gui.ResetOnSpawn=false
    gui.DisplayOrder=36
    gui.Parent=player:WaitForChild("PlayerGui")
    button=Instance.new("TextButton")
    button.Name="CameraToggle"
    button.Size=UDim2.fromOffset(112,42)
    button.AnchorPoint=Vector2.new(1,1)
    button.Position=UDim2.new(1,-14,1,-305)
    button.BackgroundColor3=Color3.fromRGB(25,28,38)
    button.TextColor3=Color3.new(1,1,1)
    button.TextScaled=true
    button.ZIndex=20
    button.Font=Enum.Font.GothamBold
    button.Parent=gui
    Instance.new("UICorner",button).CornerRadius=UDim.new(0,8)
    button.Activated:Connect(toggle)
end
player.CharacterAdded:Connect(function() task.defer(apply) end)
apply()
