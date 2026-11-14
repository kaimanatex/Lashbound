local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local feedback=RS:WaitForChild("LashboundV5Remotes"):WaitForChild("Feedback")
local gui=Instance.new("ScreenGui")
gui.Name="LashboundCabinDialogue"
gui.DisplayOrder=18
gui.ResetOnSpawn=false
gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local frame=Instance.new("Frame")
frame.AnchorPoint=Vector2.new(.5,1)
frame.Position=UDim2.fromScale(.5,.91)
frame.Size=UDim2.fromOffset(520,160)
frame.BackgroundColor3=Color3.fromRGB(57,38,27)
frame.BackgroundTransparency=.05
frame.Visible=false
frame.Parent=gui
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(231,185,110);stroke.Thickness=2;stroke.Parent=frame
local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-60,0,36)
title.Position=UDim2.fromOffset(18,7)
title.BackgroundTransparency=1
 title.TextColor3=Color3.fromRGB(255,222,166)
title.Font=Enum.Font.GothamBlack;title.TextScaled=true;title.Parent=frame
local text=Instance.new("TextLabel")
text.Size=UDim2.new(1,-38,0,72);text.Position=UDim2.fromOffset(18,48)
text.BackgroundTransparency=1;text.TextColor3=Color3.fromRGB(245,238,218)
text.TextWrapped=true;text.Font=Enum.Font.Gotham; text.TextSize=17;text.Parent=frame
local nextButton=Instance.new("TextButton")
nextButton.Size=UDim2.fromOffset(150,28);nextButton.Position=UDim2.new(1,-166,1,-34)
nextButton.Text="NEXT / CLOSE";nextButton.TextScaled=true;nextButton.Font=Enum.Font.GothamBold
nextButton.TextColor3=Color3.new(1,1,1);nextButton.BackgroundColor3=Color3.fromRGB(131,85,55)
nextButton.Parent=frame
local lines,index={},0
local function advance()
    index+=1
    if index>#lines then frame.Visible=false;return end
    text.Text=lines[index]
    nextButton.Text=index==#lines and "CLOSE" or "NEXT"
end
nextButton.Activated:Connect(advance)
feedback.OnClientEvent:Connect(function(kind,who,content)
    if kind~="LobbyDialogue" or type(content)~="table" then return end
    lines=content;index=0;title.Text=tostring(who)
    frame.Visible=true;advance()
end)
local function resize()
    local cam=workspace.CurrentCamera
    if not cam then return end
    frame.Size=UDim2.fromOffset(math.min(520,cam.ViewportSize.X-20),160)
end
resize()
