--// Localized Services & Globals
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local Vec2 = Vector2.new
local Color3_fromRGB = Color3.fromRGB
local math_floor = math.floor
local math_abs = math.abs
local math_max = math.max
local math_clamp = math.clamp
local math_ceil = math.ceil
local math_round = math.round

--// Utility Functions
local function CreateRenderObject(objType)
    return Drawing.new(objType)
end

local function DestroyRenderObject(obj)
    if obj then obj:Remove() end
end

local esp = {
    players = {},
    drawings = {},
    connections = {},
    
    enabled = false,
    ai = false,
    team_check = false,
    use_display_names = false,

    highlights = {
        target = {
            enabled = false,
            current = nil,
            color = Color3_fromRGB(255, 50, 50)
        }
    },

    settings = {
        name = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        box = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        health_bar = {enabled = false, side = "left"},
        health_text = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        distance = {enabled = false, color = Color3_fromRGB(255, 255, 255)},
        weapon = {enabled = false, color = Color3_fromRGB(255, 255, 255)}
    }
}

--// Helper Functions
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

function esp.check_team(v)
    local lp = Players.LocalPlayer
    return lp and v.Team ~= lp.Team
end

function esp:draw(objType, props)
    local d = CreateRenderObject(objType)
    for k, v in pairs(props) do d[k] = v end
    esp.drawings[d] = d
    return d
end

function esp:calculate_bounding_box(char)
    local cCF = Camera.CFrame
    local rootPart = char.HumanoidRootPart
    local rootPos = rootPart.Position
    local headPos = char.Head.Position
    
    local top, top_vis = Camera:WorldToViewportPoint(headPos + (rootPart.CFrame.UpVector * 1.2))
    local bottom, bot_vis = Camera:WorldToViewportPoint(rootPos - (rootPart.CFrame.UpVector * 2.5))

    if not (top_vis or bot_vis) then return nil end

    local height = math_abs(bottom.Y - top.Y)
    local width = math_max(height / 1.5, 6)
    local boxPos = Vec2(math_floor(top.X - width / 2), math_floor(top.Y))
    local boxSize = Vec2(math_ceil(width), math_ceil(height))

    return boxPos, boxSize
end

function esp:new_player(plr)
    local drawings = {
        name = esp:draw("Text", {Size = 14, Center = true, Outline = true, Visible = false, ZIndex = 2}),
        tool = esp:draw("Text", {Size = 14, Center = true, Outline = true, Visible = false, ZIndex = 2}),
        health_text = esp:draw("Text", {Size = 14, Center = true, Outline = true, Visible = false, ZIndex = 3}),
        distance = esp:draw("Text", {Size = 14, Center = true, Outline = true, Visible = false, ZIndex = 2}),
        weapon = esp:draw("Text", {Size = 14, Center = true, Outline = true, Visible = false, ZIndex = 2}),
        box_outline = esp:draw("Square", {Color = Color3_fromRGB(0,0,0), Thickness = 3, Visible = false, ZIndex = 0}),
        box = esp:draw("Square", {Thickness = 1, Visible = false, ZIndex = 1}),
        health_outline = esp:draw("Line", {Thickness = 3, Color = Color3_fromRGB(0,0,0), Visible = false, ZIndex = 0}),
        health = esp:draw("Line", {Thickness = 1, Visible = false, ZIndex = 1})
    }
    esp.players[plr] = drawings
end

function esp:update()
    if not esp.enabled then
        for _, drawings in pairs(esp.players) do
            for _, obj in pairs(drawings) do obj.Visible = false end
        end
        return
    end

    local localPlayer = Players.LocalPlayer

    for plr, objects in pairs(esp.players) do
        local char = esp.get_character(plr)
        local valid = char and esp.is_alive(plr)
        
        if valid and esp.team_check then
            valid = esp.check_team(plr)
        end

        if valid then
            local root = char.PrimaryPart
            local _, onScreen = Camera:WorldToViewportPoint(root.Position)
            
            if onScreen then
                local boxPos, boxSize = esp:calculate_bounding_box(char)
                if boxPos then
                    local isTarget = esp.highlights.target.enabled and plr == esp.highlights.target.current
                    local targetCol = isTarget and esp.highlights.target.color
                    local topOff, botOff = 0, 0
                    local h, mh = esp.get_health(plr)
                    local hPerc = math_clamp(h / mh, 0, 1)

                    if esp.settings.box.enabled then
                        objects.box.Position = boxPos
                        objects.box.Size = boxSize
                        objects.box.Color = targetCol or esp.settings.box.color
                        objects.box.Visible = true
                        
                        objects.box_outline.Position = boxPos
                        objects.box_outline.Size = boxSize
                        objects.box_outline.Visible = true
                    else
                        objects.box.Visible = false
                        objects.box_outline.Visible = false
                    end

                    if esp.settings.health_bar.enabled then
                        local side = esp.settings.health_bar.side
                        local hCol = Color3_fromRGB(255, 0, 0):Lerp(Color3_fromRGB(0, 255, 0), hPerc)
                        
                        if side == "left" then
                            objects.health.From = Vec2(boxPos.X - 5, boxPos.Y + boxSize.Y)
                            objects.health.To = Vec2(boxPos.X - 5, boxPos.Y + boxSize.Y - (hPerc * boxSize.Y))
                            objects.health_outline.From = Vec2(boxPos.X - 5, boxPos.Y + boxSize.Y + 1)
                            objects.health_outline.To = Vec2(boxPos.X - 5, boxPos.Y - 1)
                        elseif side == "right" then
                            objects.health.From = Vec2(boxPos.X + boxSize.X + 5, boxPos.Y + boxSize.Y)
                            objects.health.To = Vec2(boxPos.X + boxSize.X + 5, boxPos.Y + boxSize.Y - (hPerc * boxSize.Y))
                            objects.health_outline.From = Vec2(boxPos.X + boxSize.X + 5, boxPos.Y + boxSize.Y + 1)
                            objects.health_outline.To = Vec2(boxPos.X + boxSize.X + 5, boxPos.Y - 1)
                        elseif side == "top" then
                            topOff = 5
                            objects.health.From = Vec2(boxPos.X, boxPos.Y - 5)
                            objects.health.To = Vec2(boxPos.X + (hPerc * boxSize.X), boxPos.Y - 5)
                            objects.health_outline.From = Vec2(boxPos.X - 1, boxPos.Y - 5)
                            objects.health_outline.To = Vec2(boxPos.X + boxSize.X + 1, boxPos.Y - 5)
                        elseif side == "bottom" then
                            botOff = 5
                            objects.health.From = Vec2(boxPos.X, boxPos.Y + boxSize.Y + 5)
                            objects.health.To = Vec2(boxPos.X + (hPerc * boxSize.X), boxPos.Y + boxSize.Y + 5)
                            objects.health_outline.From = Vec2(boxPos.X - 1, boxPos.Y + boxSize.Y + 5)
                            objects.health_outline.To = Vec2(boxPos.X + boxSize.X + 1, boxPos.Y + boxSize.Y + 5)
                        end
                        objects.health.Color = hCol
                        objects.health.Visible = true
                        objects.health_outline.Visible = true
                    else
                        objects.health.Visible = false
                        objects.health_outline.Visible = false
                    end

                    if esp.settings.name.enabled then
                        objects.name.Text = (esp.use_display_names and plr.DisplayName) or plr.Name
                        objects.name.Color = targetCol or esp.settings.name.color
                        objects.name.Position = Vec2(boxPos.X + boxSize.X / 2, boxPos.Y - 18 - topOff)
                        objects.name.Visible = true
                    else objects.name.Visible = false end

                    if esp.settings.distance.enabled then
                        local dist = math_round((root.Position - Camera.CFrame.Position).Magnitude / 3)
                        objects.distance.Text = dist .. "m"
                        objects.distance.Color = targetCol or esp.settings.distance.color
                        objects.distance.Position = Vec2(boxPos.X + boxSize.X / 2, boxPos.Y + boxSize.Y + botOff)
                        objects.distance.Visible = true
                        botOff = botOff + 14
                    else objects.distance.Visible = false end

                    if esp.settings.weapon.enabled then
                        objects.weapon.Text = esp.get_tool(plr)
                        objects.weapon.Color = targetCol or esp.settings.weapon.color
                        objects.weapon.Position = Vec2(boxPos.X + boxSize.X / 2, boxPos.Y + boxSize.Y + botOff)
                        objects.weapon.Visible = true
                    else objects.weapon.Visible = false end

                    if esp.settings.health_text.enabled then
                        objects.health_text.Text = tostring(math_floor(h))
                        objects.health_text.Position = Vec2(boxPos.X - 25, boxPos.Y + boxSize.Y - (hPerc * boxSize.Y))
                        objects.health_text.Visible = true
                    else objects.health_text.Visible = false end
                    
                    continue
                end
            end
        end
        for _, obj in pairs(objects) do obj.Visible = false end
    end
end

for _, v in ipairs(Players:GetPlayers()) do
    if v ~= Players.LocalPlayer then esp:new_player(v) end
end

esp.connections.added = Players.PlayerAdded:Connect(function(p) esp:new_player(p) end)
esp.connections.removed = Players.PlayerRemoving:Connect(function(p)
    if esp.players[p] then
        for _, v in pairs(esp.players[p]) do DestroyRenderObject(v) end
        esp.players[p] = nil
    end
end)

esp.connections.render = RunService.RenderStepped:Connect(function()
    esp:update()
end)

getgenv().esp = esp
