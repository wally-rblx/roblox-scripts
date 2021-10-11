local nevermore = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"));
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/wally-rblx/uwuware-ui/main/main.lua"))()
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

			if library.flags.showCircle then
				if distance > library.flags.circleRadius then
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
			if (library.flags.highlightTarget and plr == library._target) then
				return library.flags.highlightColor
			end
			return (isSameTeam and library.flags.allyColor or library.flags.enemyColor)
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

		if library.flags.silentAim and library._target and (math.random(1, 100) <= library.flags.hitChance) then
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

		if library.flags.silentAim and library._target and (math.random(1, 100) <= library.flags.hitChance) then 
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

		if library.flags.silentAim and library._target and (math.random(1, 100) <= library.flags.hitChance) then
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
		if library.flags.instantReload and type(arguments[2]) == 'number' then
			arguments[2] = 1/1000
		end
		return oldIfCanReload(self, unpack(arguments))
	end

	local oldGetSpreadInfluence = baseTool._getSpreadInfluence
	function baseTool:_getSpreadInfluence(...)
		local result = oldGetSpreadInfluence(self, ...)
		result *= ((100 - library.flags.spreadScale) / 100) --> 100% reduction = 0% spread lol
		return result
	end

	set_identity(current_identity)
end

local window = library:CreateWindow('Q-Clash') do
	local section = window:AddFolder('Combat') do
		section:AddToggle({ text = 'Silent aim', flag = 'silentAim' })
		section:AddSlider({ text = 'Hit chance', flag = 'hitChance', min = 0, max = 100, value = 100 })

		section:AddToggle({ text = 'Show circle', flag = 'showCircle', callback = onCircleStateUpdated })
		section:AddSlider({ text = 'Circle radius', min = 0, max = 300, flag = 'circleRadius', callback = onCircleStateUpdated })
		section:AddColor({ text = 'Circle color', flag = 'circleColor', callback = onCircleStateUpdated })

		section:AddToggle({ text = 'Highlight target', flag = 'highlightTarget' })
		section:AddColor({ text = 'Highlight color', flag = 'highlightColor' })
	end

	local section = window:AddFolder('Gun mods') do
		section:AddSlider({ text = 'Spread reducer', flag = 'spreadScale', min = 0, max = 100, value = 0 })
		section:AddToggle({ text = 'Instant reload', flag = 'instantReload' })
	end

	local section = window:AddFolder('Visuals') do
		section:AddToggle({ text = 'Enabled', callback = function(state) ESP:Toggle(state) end })
		section:AddToggle({ text = 'Show teammates', callback = function(state) ESP.TeamMates = state; end })
		section:AddToggle({ text = 'Text', callback = function(state) ESP.Names = state; end })
		section:AddToggle({ text = 'Tracers', callback = function(state) ESP.Tracers = state; end })
		section:AddToggle({ text = 'Boxes', callback = function(state) ESP.Boxes = state; end  })

		section:AddColor({ text = 'Ally color', flag = 'allyColor', color = Color3.fromRGB(0, 255, 140) })
		section:AddColor({ text = 'Enemy color', flag = 'enemyColor', color = Color3.fromRGB(255, 25, 25) })
	end

	local section = window:AddFolder('Credits') do
		section:AddLabel({ text = 'Script by wally (BigTimbob)' })
		section:AddLabel({ text = 'UI library by Jan' })
	end
end

library:Init()
