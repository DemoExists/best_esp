local esp_lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/DemoExists/best_esp/refs/heads/main/esp.lua"))()

esp.enabled = true
for i,v in pairs(esp.settings) do
    v.enabled = true
end
esp.highlights.target.enabled = true

--[[
local esp = {
    players = {},
    drawings = {},
    connections = {},
    
    enabled = false,
    ai = false,      --// implement ur own way for ai, ts is not my problem to do for u, but it supports 
    team_check = false,
    use_display_names = false,

    --// settings for highlighting target
    highlights = {
        target = {
            enabled = false,
            current = nil,
            color = Color3_fromRGB(255, 50, 50)
        }
    },

    --// settings for esp objects
    settings = {
        name = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        box = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        health_bar = {enabled = false, side = "left"},
        health_text = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        distance = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        weapon = {enabled = false, color = Color3_fromRGB(255, 255, 255)}
    }
}




--// overridable functions
function esp.get_character(v)
    if v:IsA("Player") then
        local char = v.Character
        return (char and char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart")) and char or nil
    end
    return (v:FindFirstChild("Head") and v:FindFirstChild("HumanoidRootPart")) and v or nil
end

function esp.get_health(v)
    local char = esp.get_character(v)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health, hum.MaxHealth
    end
    return 0, 100
end

function esp.is_alive(v)
    local h, mh = esp.get_health(v)
    return h > 0
end

function esp.get_tool(v)
    local char = esp.get_character(v)
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        return tool and tool.Name or "Hands"
    end
    return "Hands"
end





--// override example
esp.get_tool = function(v)
    local tool "Hands"
    tool = game:GetService("ReplicatedStorage").Players[tostring(game:GetService("Players").LocalPlayer)].EquippedWeapon.Value
    return tool
end
]]

--// get target function to get target for esp highlight
function get_target()
    local current_target, maximum_distance = nil, math.huge
    for _,v in ipairs(game:GetService("Players"):GetPlayers()) do
        if v == game:GetService("Players").LocalPlayer then continue end
        if not v.Character then continue end
        local hrp = v.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local pos, on_screen = game:GetService("Workspace").CurrentCamera:WorldToViewportPoint(hrp.Position)
        local distance = (Vector2.new(pos.X, pos.Y - game:GetService("GuiService"):GetGuiInset(game:GetService("GuiService")).Y) - Vector2.new(game:GetService("Players").LocalPlayer:GetMouse().X, game:GetService("Players").LocalPlayer:GetMouse().Y)).Magnitude
        if distance > maximum_distance then continue end
        current_target = v
        maximum_distance = distance
    end
    return current_target
end

--// update esp highlight
game:GetService("RunService").RenderStepped:Connect(function()
    local target = get_target()
    if target then esp.highlights.target.current = target else esp.highlights.target.current = nil end
end)
