-- Lashbound V48: shift-style CAMERA LOCK, never a first/third-person switch.
-- V / R3 / on-screen button. Keeps current zoom and camera mode.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local settings=UserSettings():GetService("UserGameSettings")
local locked=false
local previousRotation=nil
local previousAutoRotate=nil
local button
local SHOULDER=Vector3.new(1.65,.35,0)
local renderName="LashboundMouseLockMaintain"
local function updateAppearance()
    if button then
        button.Text=locked and "LOCK: ON" or "LOCK: OFF"
        button.BackgroundColor3=locked and Color3.fromRGB(34,114,100) or Color3.fromRGB(25,28,38)
    end
end
local function configureCharacter()
    local character=player.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    if hum then
        if locked then
            hum.AutoRotate=true
            hum.CameraOffset=SHOULDER
        else
            hum.CameraOffset=Vector3.zero
            if previousAutoRotate~=nil then hum.AutoRotate=previousAutoRotate end
        end
    end
end
local function setLocked(value)
    if locked==value then return end
    locked=value
    player:SetAttribute("LashboundCameraLocked",locked)
    RunService:UnbindFromRenderStep(renderName)
    if locked then
        previousRotation=settings.RotationType
        local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        previousAutoRotate=hum and hum.AutoRotate or true
        settings.RotationType=Enum.RotationType.CameraRelative
        if UIS.MouseEnabled then
            UIS.MouseBehavior=Enum.MouseBehavior.LockCenter
            RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+1,function()
                if locked and not UIS:GetFocusedTextBox() and UIS.MouseBehavior~=Enum.MouseBehavior.LockCenter then
                    UIS.MouseBehavior=Enum.MouseBehavior.LockCenter
                end
            end)
        end
    else
        settings.RotationType=previousRotation or Enum.RotationType.MovementRelative
        if UIS.MouseEnabled then UIS.MouseBehavior=Enum.MouseBehavior.Default end
    end
    configureCharacter()
    updateAppearance()
end
UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.V or input.KeyCode==Enum.KeyCode.ButtonR3 then
        setLocked(not locked)
    end
end)
local gui=Instance.new("ScreenGui")
gui.Name="LashboundCameraToggleGui"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=64
gui.Parent=player:WaitForChild("PlayerGui")
button=Instance.new("TextButton")
button.Name="CameraLockToggle"
button.AnchorPoint=Vector2.new(1,1)
button.Size=UDim2.fromOffset(114,40)
button.BackgroundTransparency=.08
button.TextScaled=true
button.TextColor3=Color3.fromRGB(255,255,255)
button.Font=Enum.Font.GothamBold
button.Selectable=true
button.ZIndex=21
button.Parent=gui
Instance.new("UICorner",button).CornerRadius=UDim.new(0,9)
local function positionButton()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local h=camera.ViewportSize.Y
    button.Size=h<560 and UDim2.fromOffset(99,35) or UDim2.fromOffset(114,40)
    button.Position=UDim2.new(1,-12,1,h<560 and -246 or -305)
end
local cameraConnection
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera=workspace.CurrentCamera
    if camera then cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(positionButton) end
    positionButton()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
button.Activated:Connect(function()setLocked(not locked)end)
player.CharacterAdded:Connect(function()
    task.defer(function()
        local ch=player.Character
        if ch then ch:WaitForChild("Humanoid",5) end
        configureCharacter()
    end)
end)
player:SetAttribute("LashboundCameraLocked",false)
updateAppearance()
