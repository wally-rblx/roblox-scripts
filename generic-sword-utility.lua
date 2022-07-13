local services = setmetatable({}, { __index = function(self, key) return game:GetService(key) end })

local players = services.Players
local client = players.LocalPlayer

local Settings = {
	AutoAttack = false,
	AttackSpeed = 0.1,
	AttackDistance = 15,
	FreeForAll = false,
}

local ui = loadstring(game:HttpGet('https://raw.githubusercontent.com/Kinlei/MaterialLua/master/Module.lua'))()
local window = ui.Load({ Title = 'Generic sword utility', SizeX = 360, SizeY = 350, Theme = "Dark" })
do
	local main = window.New({ Title = 'Main' })
	do
		main.Toggle({
			Text = 'Auto attack',
			Callback = function(state)
				warn(state)
				Settings.AutoAttack = state
			end,
		})

		main.Label({ Text = 'Configuration' })
		main.Toggle({
			Text = 'Free for all',
			Callback = function(state)
				Settings.FreeForAll = state
			end,
		})

		main.Slider({
			Text = 'Attack speed (ms)', Min = 0, Max = 1000, Def = 100,
			Callback = function(value)
				Settings.AttackSpeed = value / 1000
			end
		})

		main.Slider({
			Text = 'Attack distance', Min = 0, Max = 25, Def = 15,
			Callback = function(value)
				Settings.Distance = value / 1000
			end
		})
	end
end

local Util = {}
do
	function Util.GetEnemiesInRange()
		local enemies = {}

		local origin = client.Character.HumanoidRootPart.Position
		for i, player in next, players:GetPlayers() do
			if player == client then continue end
			if player.Team == client.Team and (not Settings.FreeForAll) then continue end

			local character = player.Character
			local humanoid = character and character:findFirstChild('Humanoid')
			local root = character and character:findFirstChild('HumanoidRootPart')

			if (not root) or (not humanoid) or (humanoid.Health <= 0) then 
				continue 
			end

			local distance = math.floor((root.Position - origin).magnitude)
			if distance <= Settings.AttackDistance then
				table.insert(enemies, player)
			end
		end

		return enemies
	end

	function Util.AttackTarget(tool, enemy)
		local parts = enemy.Character:GetChildren()

		for _, part in next, parts do
			if part:IsA('BasePart') and enemy:DistanceFromCharacter(part.Position) <= 10 then
				firetouchinterest(tool.Handle, part, 0)
				firetouchinterest(tool.Handle, part, 1)
			end
		end
	end

	if game.PlaceId == 7688166467 then
		function Util.AttackTarget(tool, enemy)
			game.ReplicatedStorage.detection:FireServer(enemy)
		end
	end
end

local lastAttack = 0
services.RunService.Heartbeat:Connect(function(dt)
	lastAttack = lastAttack + dt

	if lastAttack > Settings.AttackSpeed then
		lastAttack = 0

		local character = client.Character
		local humanoid = character and character:findFirstChild('Humanoid')
		local root = character and character:findFirstChild('HumanoidRootPart')

		local tool = character and character:findFirstChildOfClass('Tool')
		if tool and tool:findFirstChild('Handle') then
			if root and humanoid and humanoid.Health > 0 then
				local enemies = Util.GetEnemiesInRange()
				if #enemies > 0 then
					tool:Activate()
					for _, enemy in next, enemies do
						Util.AttackTarget(tool, enemy)
					end
				end
			end
		end
	end
end)