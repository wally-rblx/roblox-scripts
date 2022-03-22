local services = setmetatable({}, { __index = function(self, key) return game:GetService(key) end })
local client = services.Players.LocalPlayer;

local request = request or http_request
if type(syn) == 'table' and type(syn.request) == 'function' then
	request = syn.request
end

local KickClient, LoadFromGithub do
	function KickClient(reason)
		return client:Kick(reason)
	end

	local function GetUrl(url)
		local response = request({ Url = url, Method = 'GET' })

		local success = response.Success;
		local body = response.Body;

		if not success then
			return false, 'Request failed. StatusCode: ' .. response.StatusCode
		end

		return true, body
	end

	function LoadFromGithub(owner, repo, file)
		local url = 'https://raw.githubusercontent.com/' .. owner .. '/' .. repo .. '/main/' .. file
		local success, body = GetUrl(url)

		if not success then
			return KickClient('Failed to fetch from github. ' .. table.concat({ 'Url:', url, '\n', 'Error:', tostring(body) }))
		end

		local fn, err = loadstring(body)
		if not fn then
			return KickClient('Failed to load from github. ' .. table.concat({ 'Url:', url, '\n', 'Error:', tostring(err) }))
		end

		local results = { pcall(fn) }
		local success = table.remove(results, 1)

		if not success then
			return KickClient('Failed to execute from github. ' .. table.concat({ 'Url:', url, '\n', 'Error:', tostring(results[1]) }))
		end

		return unpack(results)
	end
end

local ESP = LoadFromGithub('Kiriot22',   'ESP-lib', 'ESP.lua')
local UI  = LoadFromGithub('wally-rblx', 'LinoriaLib', 'Library.lua')

local ThemeManager = LoadFromGithub('wally-rblx', 'LinoriaLib', 'addons/ThemeManager.lua')
local SaveManager  = LoadFromGithub('wally-rblx', 'LinoriaLib', 'addons/SaveManager.lua')

-- Library addons
SaveManager:IgnoreThemeSettings()
ThemeManager:SetLibrary(UI)
ThemeManager:SetFolder('frontlines-cheat')
SaveManager:SetFolder('frontlines-cheat')

-- Utility functions

local globals, utils, enums do
	local ctr = 0;
	while true do
		local gc = getgc(true)
		for i = 1, #gc do
			local o = gc[i]
			if type(o) == 'table' then
				if rawget(o, 'gbl_sol_state') and rawget(o, 'fpv_sol_recoil') then
					globals = o;
				elseif rawget(o, 'sol_state_class') and rawget(o, 'sol_firearm_operation') then
					enums = o;
				elseif rawget(o, 'gbus') and rawget(o.gbus, 'EVENT_ENUM') then
					utils = o;
				end
			end
		end
		if enums and globals and utils then break end

		ctr = ctr + 1
		if ctr > 5 then
			client:Kick('Failed to initiate frontlines-cheat!')
		end
		task.wait(1)
	end
end

local event_enum = utils.gbus.EVENT_ENUM

local global_sol_state = globals.gbl_sol_state
local fpv_sol_recoil = globals.fpv_sol_recoil
local fpv_sol_spread = globals.fpv_sol_spread
local fpv_sol_equipment = globals.fpv_sol_equipment
local fpv_sol_multipliers = globals.fpv_sol_multipliers

local sol_state_class = enums.sol_state_class;
local sol_firearm_operation = enums.sol_firearm_operation;
local sol_time_sequence_value = enums.sol_time_sequence_value;

local getCharacter, getTeam, getHealth, getPlayerFromChar do
	local function getPlayerSolId(player)
		for idx, plr in next, globals.cli_names do
			if player.Name == plr then
				return idx
			end
		end
	end

	function getCharacter(player)
		local id = getPlayerSolId(player)
		if not id then return end

		return global_sol_state.r15_models[id]
	end

	function getTeam(player)
		local id = getPlayerSolId(player)
		if not id then return end

		return globals.cli_teams[id]
	end	

	function getHealth(player)
		local id = getPlayerSolId(player)
		if not id then return 0 end

		local health = globals.gbl_sol_healths[id]
		if not health then return 0 end

		return health
	end

	function getPlayerFromChar(character)
		for id, model in next, global_sol_state.r15_models do
			if model == character then
				local name = globals.cli_names[id]
				if name then
					return services.Players:FindFirstChild(name)
				end
			end
		end
	end
end

-- Aimbot target selection
local aimbot = {} do
	local function isInCircle(point, center, radius)
		local rX = point.x - center.x
		local rY = point.y - center.y

		return (rX*rX) + (rY*rY) <= radius*radius
	end

	local circle = Drawing.new('Circle')
		circle.Position = Vector2.new()
		circle.Color = Color3.new(1, 1, 1)
		circle.Thickness = 1;
		circle.NumSides = 24;
		circle.Transparency = 1;
		circle.Visible = false;

	function aimbot.UpdateCircleState(value)
		if type(value) == 'number' then circle.Radius = value end
		if type(value) == 'boolean' then circle.Visible = value end
		if typeof(value) == 'Color3' then circle.Color = value end
	end

	services.RunService.Heartbeat:Connect(function(dt)
		local center = workspace.CurrentCamera.ViewportSize / 2
		circle.Position = center

		local clientCharacter = getCharacter(client)
		local clientHealth = getHealth(client)
		local clientTeam = getTeam(client)

		if not clientCharacter then return end
		if clientHealth <= 0 then return end

		local Choices = {}
		for _, plr in next, services.Players:GetPlayers() do
			if plr == client then continue end

			local character = getCharacter(plr)
			local health = getHealth(plr)
			local team = getTeam(plr)

			local bone = character and character:findFirstChild('Head')
			if health > 0 and character and team ~= clientTeam and bone then
				local pos, vis = workspace.CurrentCamera:WorldToViewportPoint(bone.Position)
				if not vis then continue end

				local screenPos = Vector2.new(pos.X, pos.Y)
				if Toggles.ShowCircle and Toggles.ShowCircle.Value and (not isInCircle(screenPos, center, circle.Radius)) then
					continue
				end

				local distance = math.floor((screenPos - center).magnitude)
				table.insert(Choices, {
					Player = plr,
					Distance = distance,
					Character = character,
				})
			end
		end

		table.sort(Choices, function(a, b)
			return a.Distance < b.Distance
		end)

		local choice = Choices[1]
		if choice then
			local plr = choice.Player;

			aimbot.target = plr;
			ESP.Highlighted = choice.Character
		else
			aimbot.target = nil;
			ESP.Highlighted = nil
		end
	end)
end

-- visuals
do
	ESP:Toggle(false);

	ESP.Players = true
	ESP.FaceCamera = false;
	ESP.TeamMates = false;
	ESP.Names = false;
	ESP.Tracers = false;
	ESP.Boxes = false;

	ESP.HighlightColor = Color3.new(1, 1, 1)
	ESP.Overrides.GetTeam = getTeam
	-- ESP.Overrides.GetPlrFromChar = getPlayerFromChar

	function ESP.Overrides.UpdateAllow(self)
		if self.Player then
			local clientCharacter = getCharacter(client)
			local pHealth = getHealth(self.Player)

			if not clientCharacter or not clientCharacter.Parent then
				return false 
			end

			if pHealth <= 0 then 
				return false 
			end
		end
		return true
	end

	local function GetTeamColor(self)
		local player = self.Player;
		local IsSameTeam = ESP:IsTeamMate(player)

		if Toggles.HighlightTarget and Toggles.HighlightTarget.Value then
			if player == aimbot.target then
				return Options.HighlightColor.Value
			end
		end

		if IsSameTeam then return Options.AllyColor.Value end
		return Options.EnemyColor.Value
	end

	for _, plr in next, services.Players:GetPlayers() do
		if plr == client then continue end

		local character = getCharacter(plr)
		if character then
			ESP:Add(character, { Name = plr.Name, Player = plr, PrimaryPart = character:WaitForChild('HumanoidRootPart', 10), ColorDynamic = GetTeamColor })
		end
	end

	local function onModelAdded(model)
		local plr = getPlayerFromChar(model)
		if not plr then return end
		if plr == client then return end

		ESP:Add(model, { Name = plr.Name, Player = plr, PrimaryPart = model:WaitForChild('HumanoidRootPart', 10), ColorDynamic = GetTeamColor })
	end

	workspace.ChildAdded:Connect(function(object)
		if object.Name == 'r15_rig' then
			task.defer(onModelAdded, object)
		end
	end)
end

-- game modifications
do
	local spread = fpv_sol_spread.spread
	local attitude_delta = fpv_sol_recoil.attitude_delta

	setmetatable(fpv_sol_spread, {
		__index = function(self, key)
			if key == 'spread' then 
				if Toggles.NoSpread and Toggles.NoSpread.Value then return 0 end
				return spread
			end
			return rawget(self, key)
		end,
		__newindex = function(self, key, value)
			if key == 'spread' then spread = value; return end
			rawset(self, key, value)
		end
	})

	setmetatable(fpv_sol_recoil, {
		__index = function(self, key)
			if key == 'attitude_delta' then
				if Toggles.NoRecoil and Toggles.NoRecoil.Value then return Vector3.new() end
				return attitude_delta
			end
			return rawget(self, key)
		end,
		__newindex = function(self, key, value)
			if key == 'attitude_delta' then attitude_delta = value; return end
			rawset(self, key, value)
		end
	})

	rawset(fpv_sol_spread, 'spread', nil)
	rawset(fpv_sol_recoil, 'attitude_delta', nil)

	local function ApplyWeaponMods(equipment)
		local reload_params = equipment.reload_params
		local recoil_params = equipment.recoil_params

		local aim_sway_params = equipment.aim_sway_params
		local time_sequences = equipment.time_sequences

		if not reload_params or not aim_sway_params then return end

		local function applyProxyMetatable(tbl, events)
			if getmetatable(tbl) then return end

			local cache = {}
			for key in next, events do
				cache[key] = tbl[key]
			end

			setmetatable(tbl, {
				__index = function(self, key)
					local fn = events[key]
					if fn and cache[key] then
						local result = fn(cache[key])
						if result then
							return result
						end
						return cache[key]
					end
					return rawget(self, key)
				end,
				__newindex = function(self, key, value)
					if events[key] then
						cache[key] = value
						return
					end
					rawset(self, key, value)
				end
			})

			for key in next, events do
				rawset(tbl, key, nil)
			end
		end

		local function SpoofReloadTime(old)
			if Toggles.NoReload and Toggles.NoReload.Value then 
				return 0.01
			end
		end

		local function SpoofReloadVector(old)
			if Toggles.NoReload and Toggles.NoReload.Value then 
				return { Vector3.new(0, sol_time_sequence_value.AMMO_IN), Vector3.new(0.01, sol_time_sequence_value.END), }
			end
		end

		local function SpoofFireRate(old)
			if Toggles.FastFire and Toggles.FastFire.Value then
				return old * Options.FastFireMult.Value
			end
		end

		applyProxyMetatable(reload_params, {
			dry_reload_duration = SpoofReloadTime,
			tac_reload_duration = SpoofReloadTime,
		})

		applyProxyMetatable(time_sequences, {
			[Vector3.new(sol_state_class.FIREARM_OPERATION, sol_firearm_operation.TAC_RELOAD)] = SpoofReloadVector,
			[Vector3.new(sol_state_class.FIREARM_OPERATION, sol_firearm_operation.DRY_RELOAD)] = SpoofReloadVector,

			[Vector3.new(sol_state_class.FIREARM_OPERATION, sol_firearm_operation.TAC_RELOAD_START)] = SpoofReloadVector,
			[Vector3.new(sol_state_class.FIREARM_OPERATION, sol_firearm_operation.DRY_RELOAD_START)] = SpoofReloadVector,

			[Vector3.new(sol_state_class.FIREARM_OPERATION, sol_firearm_operation.RELOAD_INCR)] = SpoofReloadVector,
			[Vector3.new(sol_state_class.FIREARM_OPERATION, sol_firearm_operation.RELOAD_END)] = SpoofReloadVector,
		})

		applyProxyMetatable(fpv_sol_multipliers, {
			fire_rate = SpoofFireRate,
		})
	end

	if fpv_sol_equipment.curr_equipment then
		ApplyWeaponMods(fpv_sol_equipment.curr_equipment)
	end

	local friendly_params
	local enemy_params

	local OldTrigEvent = nil
	local function TrigEventProxy(event, ...)	
		local args = { ... }

		if event == event_enum.FPV_SOL_BULLET_SPAWN then
			local stack = debug.getstack(3)

			local discharge_params = nil
	        for idx, obj in next, stack do
	            if type(obj) == 'table' and type(rawget(obj, 'fire_params')) == 'table' then 
	                discharge_params = obj;
	                break
	            end
	        end

			if Toggles.SilentAim.Value and aimbot.target and discharge_params then
				local character = getCharacter(aimbot.target)
				local bone = character and character:findFirstChild('Head')

				if bone then
					local fire_params = discharge_params.fire_params
                	local fire_multipliers = discharge_params.fire_multipliers
                	local velocity = fire_params.muzzle_velocity * fire_multipliers.muzzle_velocity;
                	local velocity_mult = Toggles.BulletVelocity.Value and Options.BulletVelocityMult.Value or 1

                	args[4] = CFrame.lookAt(args[3], bone.CFrame.p).lookVector * (velocity * velocity_mult)
				end
			end

			if friendly_params and enemy_params then
			--	friendly_params.FilterDescendantsInstances = Toggles.Wallbang.Value and { workspace:findFirstChild('workspace') } or {}
			--	enemy_params.FilterDescendantsInstances = Toggles.Wallbang.Value and { workspace:findFirstChild('workspace') } or {}
			end
		elseif event == event_enum.FPV_SOL_EQUIP then
			ApplyWeaponMods(fpv_sol_equipment.curr_equipment)
		end

		return OldTrigEvent(event, unpack(args))
	end

	OldTrigEvent = hookfunction(utils.gbus.trig_event, function(...)
		return TrigEventProxy(...)
	end)

	-- hookfunction didn't work here :(
	local OldEvalUdho = utils.math_util.eval_udho
	local function EvalUdhoProxy(...)
		if Toggles.NoRecoil and Toggles.NoRecoil.Value and debug.info(2, 's'):find('recoil_anim') then
			return 0, 0
		end
		return OldEvalUdho(...)
	end
	utils.math_util.eval_udho = EvalUdhoProxy

	local spawn_bullet = nil;

	for _, fn in next, getgc() do
		if type(fn) == 'function' then 
			if islclosure(fn) and (not is_synapse_function(fn)) then
				local upvalues = getupvalues(fn)
				for _, upv in next, upvalues do
					if upv == OldEvalUdho then
						setupvalue(fn, _, EvalUdhoProxy)
					end
				end

				if getinfo(fn).name == 'spawn_bullet' then
					spawn_bullet = fn
				end
			end
		end
	end

	if spawn_bullet then
		friendly_params = getupvalue(spawn_bullet, 5)
		enemy_params = getupvalue(spawn_bullet, 7)
	end
end

local window = UI:CreateWindow('Frontlines') do
	local tMain = window:AddTab('Main') 

	local gAimbot  = tMain:AddLeftGroupbox('Silent aim')
	local gVisuals = tMain:AddRightGroupbox('Visuals')

	do
		gAimbot:AddToggle('SilentAim', { Text = 'Silent aim' })
		-- gAimbot:AddToggle('Wallbang', { Text = 'Wallbang' })

		gAimbot:AddToggle('ShowCircle', { Text = 'Show circle' }):AddColorPicker('CircleColor', { Default = Color3.new(1, 1, 1) })
		gAimbot:AddSlider('CircleRadius', { Text = 'Circle radius', Min = 0, Max = 300, Default = 0, Rounding = 0 })
		gAimbot:AddToggle('HighlightTarget', { Text = 'Highlight target' }):AddColorPicker('HighlightColor', { Default = Color3.new(1, 1, 1) })

		gVisuals:AddToggle('ESPEnabled', { Text = 'Enabled' })
		gVisuals:AddDropdown('ESPFlags', { Text = 'ESP Flags', Multi = true, Values = { 'Names', 'Boxes', 'Tracers', } })
		gVisuals:AddDropdown('ESPOptions', { Text = 'ESP Options', Multi = true, Values = { 'Show team', 'Face camera' } })

		gVisuals:AddLabel('Player colors')
			:AddColorPicker('AllyColor', { Default = Color3.fromRGB(0, 255, 140), Title = 'Ally color' })
			:AddColorPicker('EnemyColor', { Default = Color3.fromRGB(255, 25, 25), Title = 'Enemy color' });

		Toggles.ShowCircle:OnChanged(function() aimbot.UpdateCircleState(Toggles.ShowCircle.Value) end)
		Options.CircleColor:OnChanged(function() aimbot.UpdateCircleState(Options.CircleColor.Value) end)
		Options.CircleRadius:OnChanged(function() aimbot.UpdateCircleState(Options.CircleRadius.Value) end)

		Toggles.ESPEnabled:OnChanged(function() ESP:Toggle(Toggles.ESPEnabled.Value) end)
		Options.ESPFlags:OnChanged(function()
			local map = Options.ESPFlags.Value

			ESP.Names = map.Names or false
			ESP.Boxes = map.Boxes or false
			ESP.Tracers = map.Tracers or false
		end)

		Options.ESPOptions:OnChanged(function()
			local map = Options.ESPOptions.Value

			ESP.FaceCamera = map['Face camera'] or false
			ESP.TeamMates = map['Show team'] or false
		end)
	end

	local gModifications = tMain:AddLeftTabbox()
	local tWeapons = gModifications:AddTab('Weapons')

	do
		tWeapons:AddToggle('NoSpread', { Text = 'No spread' })
		tWeapons:AddToggle('NoRecoil', { Text = 'No recoil' })
		tWeapons:AddToggle('NoReload', { Text = 'Instant reload' })
		tWeapons:AddToggle('FastFire', { Text = 'Fire rate' })
		tWeapons:AddSlider('FastFireMult', { Text = 'Fire rate multiplier', Min = 1, Max = 2, Rounding = 1, Default = 1 })

		tWeapons:AddToggle('BulletVelocity', { Text = 'Increased bullet velocity' })
		tWeapons:AddSlider('BulletVelocityMult', { Text = 'Velocity multiplier', Min = 1, Max = 2, Rounding = 1, Default = 1 })
	end

	local tSettings = window:AddTab('UI Settings') do
		ThemeManager:ApplyToTab(tSettings)

		local tSaveSettings = tSettings:AddRightGroupbox('Save settings')
		local tCredits = tSettings:AddRightGroupbox('Credits')

		tSaveSettings:AddButton('Save settings', function()
			if SaveManager:Save('Default') then
				UI:Notify('Saved settings!', 2)
			else
				UI:Notify('Failed to save settings', 2)
			end
		end)
		tSaveSettings:AddButton('Load settings', function()
			if SaveManager:Load('Default') then
				UI:Notify('Loaded settings!', 2)
			else
				UI:Notify('Failed to save settings', 2)
			end
		end)

		tCredits:AddLabel('wally - Script')
		tCredits:AddLabel('Inori - UI library')
		tCredits:AddLabel('Kiriot22 - ESP library')

		tCredits:AddButton('Copy discord invite', function()
			if pcall(setclipboard, 'https://wally.cool/discord') then
				UI:Notify('Copied discord invite!', 3)
			else
				UI:Notify('Failed to copy discord invite!', 3)
			end
		end)
	end
end

UI:Notify('Frontlines script loaded!', 3)
UI:Notify('Press RightControl to open the menu!', 3)