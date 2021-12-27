local nevermore = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"));
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/Library.lua"))()
local ESP = loadstring(game:HttpGet("https://kiriot22.com/releases/ESP.lua"))()

local services = setmetatable({}, { __index = function(s, key)
	return game:GetService(key)
end })

local client = services.Players.LocalPlayer;

-- silent target
local onCircleStateUpdated do
	local circle = Drawing.new('Circle') do
		circle.Visible = false;
		circle.Color = Color3.new(1, 1, 1)
		circle.Thickness = 1;
		circle.Transparency = 1;
	end

	function onCircleStateUpdated(state)
		if type(state) == 'boolean' then
			circle.Visible = state;
		elseif type(state) == 'number' then
			circle.Radius = state
		elseif typeof(state) == 'Color3' then
			circle.Color = state;
		end
	end

	services.RunService.Heartbeat:Connect(function()
		local origin = services.UserInputService:GetMouseLocation()

		circle.Position = origin

		local targets = {};
		local cCharacter = client.Character

		if (not cCharacter) then
			return
		end

		for _, plr in next, services.Players:GetPlayers() do
			if plr == client then
				continue
			end

			local character = plr.Character;
			local humanoid = (character and character:FindFirstChildWhichIsA('Humanoid'))
			local head = (character and character:FindFirstChild('Head'))

			if (not humanoid) or (humanoid.Health <= 0) or (character.Parent == cCharacter.Parent) then
				continue
			end

			local vector, visible = workspace.CurrentCamera:WorldToViewportPoint(head.Position)
			if (not visible) then
				continue
			end

			local vector = Vector2.new(vector.X, vector.Y)
			local distance = math.floor((vector - origin).magnitude)

			if Toggles.showCircle and Toggles.showCircle.Value then
				if distance > Options.circleRadius.Value then
					continue
				end
			end

			targets[#targets + 1] = { plr, distance }
		end

		table.sort(targets, function(a, b) return a[2] < b[2] end)

		local target = targets[1]
		if target then
			library._target = target[1]
		else
			library._target = nil
		end
	end)
end

-- visuals
do
	ESP:Toggle(false);

	ESP.FaceCamera = true;
	ESP.TeamMates = false;
	ESP.Names = false;
	ESP.Tracers = false;
	ESP.Boxes = false;

	function ESP.Overrides.IsTeamMate(player)
		if player.Character and client.Character then
			return (player.Character.Parent == client.Character.Parent)
		end
	end

	function ESP.Overrides.GetColor(character)
		local plr = ESP:GetPlrFromChar(character)
		if plr then
			local isSameTeam = ESP:IsTeamMate(plr)
			if (Toggles.highlightTarget and Toggles.highlightTarget.Value and plr == library._target) then
				return Options.highlightColor.Value
			end
			return (isSameTeam and Options.allyColor.Value or Options.enemyColor.Value)
		end
		return nil
	end

	function ESP.Overrides.GetTeam(plr)
		if plr.Character then
			return plr.Character.Parent
		end
		return nil
	end	
end

-- game hooks
do
	-- stupid identity bullshit
	local set_identity = (type(syn) == 'table' and syn.set_thread_identity) or setidentity or setthreadcontext
	local get_identity = (type(syn) == 'table' and syn.get_thread_identity) or getidentity or getthreadcontext

	local current_identity = get_identity()
	set_identity(2)

	-- anti ClientWatchdog
	local clientRemoteEvent = nevermore('RemoteEvent'):GetClient()
	local actionType = nevermore('ActionType')
		
	local actionTypeMap = {}

	for name, index in next, actionType do
		actionTypeMap[index] = name;
	end

	local oldSendToServer = clientRemoteEvent.SendToServer
	function clientRemoteEvent:SendToServer(action, ...)
		local args = { ... }

		if (action == actionType.RequestReportStatus) then
			if type(args[1]) == 'table' then
				-- hi greg, i think i figured out why your game kicks me
				-- thats not nice, tbh do I even need this bypass here?
				-- oh well, have fun friend.

				-- p.s. your context check doesn't work, try something new. i like to see fun stuff
				-- <3 you
				table.clear(args[1])
			end
		end

		return oldSendToServer(self, action, unpack(args))
	end

	-- silent aim hooks (theres like 9 billion projectile types)
	local baseTool = nevermore('BaseTool')

	local oldFireBullet = baseTool._fireBullet
	local oldFireStraight = baseTool._fireStraightProjectile
	local oldFireArced = baseTool._fireArcProjectile
	local oldIfCanReload = baseTool.IfCanReloadThen

	local parts = { 'Head', 'UpperTorso', 'LowerTorso', 'RightUpperArm', 'LeftUpperArm', 'RightUpperLeg', 'LeftUpperLeg' }

	function baseTool:_fireStraightProjectile(...)
		local arguments = {...}
		local origin = arguments[2]

		if Toggles.silentAim.Value and library._target and (math.random(1, 100) <= Options.hitChance.Value) then
			local tCharacter = library._target.Character;
			local tHumanoid = tCharacter and tCharacter:FindFirstChildWhichIsA('Humanoid')
			local part = parts[math.random(#parts)]

			if tHumanoid and tHumanoid.Health > 0 and tCharacter:FindFirstChild(part) then
				arguments[7] = Vector3.new()
				arguments[3] = CFrame.lookAt(origin, tCharacter[part].Position).lookVector
			end
		end

		return oldFireStraight(self, unpack(arguments))
	end

	function baseTool:_fireBullet(...)
		local arguments = {...}
		local origin = arguments[3]

		if Toggles.silentAim.Value and library._target and (math.random(1, 100) <= Options.hitChance.Value) then
			local tCharacter = library._target.Character;
			local tHumanoid = tCharacter and tCharacter:FindFirstChildWhichIsA('Humanoid')
			local part = parts[math.random(#parts)]

			if tHumanoid and tHumanoid.Health > 0 and tCharacter:FindFirstChild(part) then
				arguments[4] = CFrame.lookAt(origin, tCharacter[part].Position).lookVector
			end
		end

		return oldFireBullet(self, unpack(arguments))
	end

	function baseTool:_fireArcProjectile(...)
		local arguments = {...}
		local origin = arguments[2]

		if Toggles.silentAim.Value and library._target and (math.random(1, 100) <= Options.hitChance.Value) then
			local tCharacter = library._target.Character;
			local tHumanoid = tCharacter and tCharacter:FindFirstChildWhichIsA('Humanoid')
			local part = parts[math.random(#parts)]

			if tHumanoid and tHumanoid.Health > 0 and tCharacter:FindFirstChild(part) then
				arguments[9] = Vector3.new()
				arguments[3] = CFrame.lookAt(origin, tCharacter[part].Position).lookVector
			end
		end

		return oldFireArced(self, unpack(arguments))
	end

	function baseTool:IfCanReloadThen(...)
		local arguments = {...}
		if Toggles.instantReload.Value and type(arguments[2]) == 'number' then
			arguments[2] = 1/1000
		end
		return oldIfCanReload(self, unpack(arguments))
	end

	local oldGetSpreadInfluence = baseTool._getSpreadInfluence
	function baseTool:_getSpreadInfluence(...)
		local result = oldGetSpreadInfluence(self, ...)
		result *= ((100 - Options.spreadScale.Value) / 100) --> 100% reduction = 0% spread lol
		return result
	end

	set_identity(current_identity)
end

library:SetWatermarkVisibility(false)

local window = library:CreateWindow('Q-Clash') do 
	local main = window:AddTab('Main') do
		local column = main:AddLeftTabbox() do
			local section = column:AddTab('Combat') do
				section:AddToggle('silentAim', { Text = 'Silent aim' })
				section:AddSlider('hitChance', { Text = 'Hit chance' , Min = 0, Max = 100, Default = 0, Rounding = 0, Suffix = '%' })
				section:AddToggle('showCircle', { Text = 'Show circle' }):AddColorPicker('circleColor', { Default = Color3.new(1, 1, 1) })
				section:AddSlider('circleRadius', { Text = 'Circle radius', Min = 0, Max = 300, Default = 0, Rounding = 0 })
				section:AddToggle('highlightTarget', { Text = 'Highlight target' }):AddColorPicker('highlightColor', { Default = Color3.new(1, 1, 1) })

				Options.circleRadius:OnChanged(function()
					onCircleStateUpdated(Options.circleRadius.Value)
				end)

				Options.circleColor:OnChanged(function()
					onCircleStateUpdated(Options.circleColor.Value)
				end)

				Toggles.showCircle:OnChanged(function()
					onCircleStateUpdated(Toggles.showCircle.Value)
				end)
			end

			local section = column:AddTab('Gun mods') do
				section:AddSlider('spreadScale', { Text = 'Spread reducer', Min = 0, Max = 100, Default = 0, Rounding = 0 })
				section:AddToggle('instantReload', { Text = 'Instant reload' })
			end
		end

		local column = main:AddLeftTabbox() do
			local section = column:AddTab('Visuals') do
				section:AddToggle('ESPEnabled', { Text = 'Enabled' }):OnChanged(function()
					ESP:Toggle(Toggles.ESPEnabled.Value)
				end)

				section:AddToggle('ESPShowTeams', { Text = 'Show teammates' }):OnChanged(function()
					ESP.TeamMates = Toggles.ESPShowTeams.Value
				end)

				section:AddToggle('ESPShowNames', { Text = 'Show names' }):OnChanged(function()
					ESP.Names = Toggles.ESPShowNames.Value
				end)

				section:AddToggle('ESPShowTracers', { Text = 'Show tracers' }):OnChanged(function()
					ESP.Tracers = Toggles.ESPShowTracers.Value
				end)

				section:AddToggle('ESPShowBoxes', { Text = 'Show boxes' }):OnChanged(function()
					ESP.Boxes = Toggles.ESPShowBoxes.Value
				end)

				section:AddLabel('Player colors'):AddColorPicker('allyColor', { Default = Color3.fromRGB(0, 255, 140) }):AddColorPicker('enemyColor', { Default = Color3.fromRGB(255, 25, 25) })
			end
		end

		local column = main:AddRightTabbox() do
			local section = column:AddTab('Credits') do
				section:AddLabel('wally (BigTimbob @ v3rm) - Script')
				section:AddLabel('Kiriot22 - ESP library')
				section:AddLabel('Inori - UI library')

				section:AddLabel('Updated 12/26/21')
				section:AddButton('Copy discord server', function()
					 setclipboard("https://wally.cool/discord")
					 library:Notify('Copied discord to clipboard!')
				end)
			end
		end
	end
end

library:Notify('Script fully loaded!')
library:Notify('Press "RightShift" to toggle the menu!')