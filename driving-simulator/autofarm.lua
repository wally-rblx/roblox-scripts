local services = setmetatable({}, { __index = function(self, key) return game:GetService(key) end })
local client = services.Players.LocalPlayer;

local config = shared.config
if type(config) ~= 'table' then
	return client:Kick('Invalid config')
end

if shared.tasks then
	for i = #shared.tasks, 1, -1 do
		local thread = table.remove(shared.tasks, i)
		if type(thread) == 'thread' then
			coroutine.close(thread)
		elseif type(thread) == 'RBXScriptSignal' then
			thread:Disconnect()
		end
	end
end


if shared.Menu then 
	shared.Menu:Cleanup() 
end

shared.tasks = {}

local Menu = {} do
	shared.Menu = Menu;

	Menu.Storage = {}
	Menu.Labels = {}

	local function Update(object, props)
		for k, v in next, props do
			object[k] = v
		end
	end

	local function Draw(class, props)
		local object = Drawing.new(class)
		Update(object, props)
		return object
	end

	function Menu:DrawLabel(props)
		local position = self.Start;
		if next(self.Labels) then
			position = self.Offset(self.Labels[#self.Labels], 2)
		end

		local label = Draw('Text', {
			Font = Drawing.Fonts.Plex,
			Size = 15,
			Color = props.Color or Color3.new(1, 1, 1),

			Text = props.Text,
			Position = position,

			Transparency = 1,
			Visible = true,

			Center = true,
			Outline = true,
			OutlineColor = Color3.new(),

			ZIndex = 2,
		})

		table.insert(self.Labels, label)
		
		if props.Type then
			self.Storage[props.Type] = label;
		end
	end

	function Menu.Offset(Label, Offset)
		return Label.Position + Vector2.new(0, Label.TextBounds.Y + (Offset or 0))
	end

	function Menu.SetStatus(str, color)
		Menu.Storage.Status.Text = 'status: ' .. str;
		if color then
			Menu.Storage.Status.Color = color
		end
		Menu:DrawBackground()
	end

	function Menu:Cleanup()
		for i = 1, #self.Labels do
			Label.Visible = false;
			Label:Remove()
		end

		table.clear(self.Labels)
		table.clear(self.Storage)

		if self.Background then
			self.Background.Visible = false;
			self.Background:Remove()

			self.Background = nil;
		end
	end

	function Menu:DrawBackground()
		local list = {}
		for _, lbl in next, self.Labels do
			table.insert(list, lbl)
		end

		local function GetSortedResults(list, fn)
			table.sort(list, fn)
			return list[1], list[#list]
		end

		local longest = GetSortedResults(list, function(p0, p1)
			return p0.TextBounds.X > p1.TextBounds.X
		end)

		local top, bottom = GetSortedResults(list, function(p0, p1)
			return p0.Position.Y < p1.Position.Y
		end)

		local position = Vector2.new(longest.Position.X, top.Position.Y)
		local size = Vector2.new(longest.TextBounds.X, (bottom.Position.Y + bottom.TextBounds.Y) - top.Position.Y)

		position = position - Vector2.new((longest.TextBounds.X / 2) + 6, 0)
		size = size + Vector2.new(10, 3)

		local square = Menu.Background or Draw('Square', {})
		Menu.Background = square

		Update(square, {
			Position = position,
			Size = size,

			Transparency = 0.75,

			Filled = true,
			Visible = true,
			Color = Color3.new(),
		})
	end

	Menu.ViewportSize = workspace.CurrentCamera.ViewportSize
	Menu.Start = Vector2.new(Menu.ViewportSize.X / 2, 5)
end

local is_host = client.Name == config.host;

local import = getrenv().shared.import;
local remote = getrenv().shared.remote;
local asset = getrenv().shared.asset

setupvalue(import, 1, function() return script end) 

local imports = {}
	imports.carTracker = import("/pcar/CarTracker")
	imports.carPlacer = import("/pcar/CarPlacer")
	imports.clientCarBus = import("/pcar/ClientCarDataBus.client")
	imports.carRefUtil = import("/pcar/CarRefUtil")
	imports.interactionClient = import('/game/Interaction.client')
	imports.clientRaceState = import('/prace/ClientRaceState.client')
	imports.interactionList = getupvalue(imports.interactionClient.new, 3)
	imports.formatNumber = import('/game/FormatMilesValue')
	imports.leaderboardUi = import('/gui/Races/RaceLeaderboardUI.client')

local remotes = {}
	remotes.spawnCar = remote("/cms/SpawnCarRequest")
	remotes.enterCar = remote("/cms/EnteringCar")
	remotes.racerTermination = remote("/races/SignalRacerTermination")
	remotes.forfeit = remote("/races/Forfeit")

local assets = {}
	assets.races = asset('/races')
	assets.discoverables = asset("/DiscoverableAreas")

local storage = {} do
	for _, race in next, assets.races:GetChildren() do
		local module = race:FindFirstChild('Module')
		local data = require(module)

		if data.name == config.race then
			storage.race = race
			storage.raceData = data
			break
		end
	end

	if not storage.race then
		return client:Kick('Failed to find race!')
	end

	storage.Earned = 0
	storage.Finished = {}

	function imports.leaderboardUi:show()
		task.defer(self.exit, self)
	end
end

Menu:DrawLabel({ Text = 'driving simulator - autofarm', })
Menu:DrawLabel({ Text = 'status: none', Type = 'Status' })

if is_host then
	Menu:DrawLabel({ Text = 'you are the host!', Color = Color3.fromRGB(0, 255, 140), })

	Menu:DrawLabel({ Text = string.format('race: %q', storage.raceData.name) })

	Menu:DrawLabel({ Text = 'money earned: 0', Type = 'Earned' })
	Menu:DrawLabel({ Text = 'elapsed time: 0', Type = 'Elapsed' })
else
	Menu:DrawLabel({ Text = string.format('host account: %q', type(config.host) == 'string' and config.host or 'invalid host name') })
	Menu:DrawLabel({ Text = 'you are a bot', })
	Menu:DrawLabel({ Text = 'elapsed time: 0', Type = 'Elapsed' })
end

Menu:DrawBackground()

table.insert(shared.tasks, remotes.racerTermination.OnClientEvent:Connect(function(id, obj)
	if is_host and obj.name == client.Name and (not obj.dnf) then
		storage.Earned = storage.Earned + obj.reward
		Menu.Storage.Earned.Text = string.format('money earned: %s', imports.formatNumber(storage.Earned, 1))
	end

	storage.Finished[obj.name] = true
end))


local thread = nil

local startArea = storage.race.StartArea
local raceState = storage.race:FindFirstChild('State');
local raceStart = storage.race:FindFirstChild('StartAreaCFrame').Value;

-- Utilities
local Utilities = {} do
	function Utilities.GetSpawnedCar(player)
		for _, obj in next, workspace['$cars']:GetChildren() do
			local state = obj:FindFirstChild('State')
			if state and state.Owner.Value == player then
				return obj
			end
		end
	end

	function Utilities.GetInteractionByName(name)
		for _, inter in next, imports.interactionList do
			if inter._name == name then
				return inter
			end
		end
	end

	function Utilities.ExecuteInGameCtx(fn, ...)
		local identity = syn.get_thread_identity()

		syn.set_thread_identity(2)
		local results = { pcall(fn, ...) }
		syn.set_thread_identity(identity)

		assert(results[1], results[2])
		return unpack(results, 2)
	end

	function Utilities.Teleport(car, cf)
		car:SetPrimaryPartCFrame(cf)
		car.PrimaryPart.CanCollide = false
		car.PrimaryPart.Velocity = Vector3.new()
	end

	function Utilities.GetCar()
		local car = imports.carTracker.getCarFromDriver(client)
		if car then
			return car
		end

		local spawned = Utilities.GetSpawnedCar(client)
		if not spawned then
			local id = imports.clientCarBus.getOwnedCarIds()[1]
			local fullName = imports.carRefUtil.getLongName(id)

			Menu.SetStatus(string.format('spawning a car (%s)', fullName))

			local results = { remotes.spawnCar:InvokeServer(id) }
			if not results[1] then
				Menu.SetStatus('unable to spawn car', Color3.fromRGB(255, 50, 50))
				return false
			else
				Menu.SetStatus'spawned our car'
			end

			spawned = Utilities.GetSpawnedCar(client)
		end

		Menu.SetStatus'going to our car!'

		local drive = Utilities.GetInteractionByName('Drive')
		if not drive then
			Menu.SetStatus('unable to find drive interaction', Color3.fromRGB(255, 50, 50))
			return false
		end

		client.Character:SetPrimaryPartCFrame(spawned.PrimaryPart.CFrame * CFrame.new(0, 3, 0))
		Utilities.ExecuteInGameCtx(function()
			drive:trySynthesizeInteraction(spawned.Body.DriverDummy.SeatAttachment)
		end)

		return spawned
	end
end

-- anticheat
do
	local gc = getgc(true)
	for i = 1, #gc do
		local obj = gc[i]
		if type(obj) == 'table' and type(rawget(obj, '_kill')) == 'function' then
			obj._kill = function() end
		end
	end
end

if is_host then
	setfpscap(60)
else
	setfpscap(20)
	services.RunService:Set3dRenderingEnabled(false)
end

for _, connection in next, getconnections(client.Idled) do
	connection:Disable()
end

local function time_thread()
	Menu.Storage.Elapsed.Text = 'elapsed time: 00:00:00'

	local start = os.time()
	while true do
		wait(1)
		local elapsed = os.time() - start
		local time = DateTime.fromUnixTimestamp(elapsed):ToUniversalTime()

		Menu.Storage.Elapsed.Text = 'elapsed time: ' .. string.format('%02d:%02d:%02d', time.Hour, time.Minute, time.Second)
		Menu:DrawBackground()
	end
end

local function main_thread()
	while true do
		task.wait()

		table.clear(storage.Finished)

		local car = Utilities.GetCar()
		if car == false then break end

		local rootPart = car:WaitForChild('RootPart')
		Menu.SetStatus('looking for race')
			
		if raceState.RaceActive.Value then
			Menu.SetStatus('waiting for current race to finish!')
			raceState.RaceActive:GetPropertyChangedSignal('Value'):Wait()
		end

		Menu.SetStatus('waiting for current race to start!')

		while not raceState.RaceActive.Value do
			task.wait()

			local plrList = game.Players:GetPlayers()
			table.sort(plrList, function(p0, p1)
				return p0.UserId < p1.UserId
			end)

			local num = #plrList
			local idx = table.find(plrList, client)

			local angle = (idx / num) * 2 * math.pi
			local x = math.cos(angle) * (startArea.Size.Z / 3.25)
			local z = math.sin(angle) * (startArea.Size.Z / 3.25)

			local distance = math.floor((car.PrimaryPart.Position - raceStart.p).magnitude)
			if distance > startArea.Size.Z / 2 then
				local cf = raceStart * CFrame.new(x, 5, z)
				Utilities.Teleport(car, CFrame.new(cf.p))
			end
		end

		Menu.SetStatus('race has started!')
		if not imports.clientRaceState.racing then
			Menu.SetStatus('we did not get in the race :(')
			wait(1)
			continue
		end

		if is_host then
			if not rootPart.Anchored then
				Menu.SetStatus'waiting for car to be anchored'
				rootPart:GetPropertyChangedSignal('Anchored'):Wait()
			end
			if rootPart.Anchored then
				Menu.SetStatus'waiting for car to be unanchored'
				rootPart:GetPropertyChangedSignal('Anchored'):Wait()
			end

			Menu.SetStatus'waiting for colliders'

			local checkpoints = storage.race.Checkpoints:GetChildren()
			local colliders = workspace['$raceColliders']:WaitForChild(storage.race.Name)
			local numCheckpoints = colliders:WaitForChild('NumCheckpoints').Value;

			Menu.SetStatus'completing the race'
			local checkpointDelay = 0.1
			for lap = 1, storage.raceData.laps do
				for idx = 1, numCheckpoints do
					local obj = storage.race.Checkpoints:FindFirstChild(idx)
					local ref = obj:WaitForChild('ArrowRefCFrame', 10)

					local part = colliders:FindFirstChild(idx)
					Menu.SetStatus(string.format('Lap %d, Checkpoint %d', lap, idx))

					task.spawn(function()
						client:RequestStreamAroundAsync(ref.Value.p, 50)
					end)

					while true do
						part = colliders:FindFirstChild(idx)
						if part then break end

						Utilities.Teleport(car, ref.Value * CFrame.new(0, 4, 0))
						services.RunService.Stepped:Wait()
					end

					Utilities.Teleport(car, part.CFrame)
					firetouchinterest(rootPart, part, 0)
					firetouchinterest(rootPart, part, 1)

					task.wait(checkpointDelay)
				end
				services.RunService.Heartbeat:Wait()
			end

			Menu.SetStatus('waiting for us to finish')
			local timer = tick()
			while task.wait() do
				if not imports.clientRaceState.racing then 
					break
				end
				if tick() - timer > 10 then
					-- we glitched
					remotes.forfeit:FireServer()
					timer = tick()
				end
			end
			Menu.SetStatus('host finished the race!')
		else
			Menu.SetStatus('waiting for host to finish')
			local timer = tick()
			while task.wait() do
				if storage.Finished[config.host] then 
					break
				end
				if tick() - timer > 10 then
					-- we glitched
					remotes.forfeit:FireServer()
					timer = tick()
				end
			end
			Menu.SetStatus('host finished the race!')
			remotes.forfeit:FireServer()
		end
	end
end

local function load_thread(fn)
	local thread = task.spawn(fn)
	table.insert(shared.tasks, thread)
end

load_thread(time_thread)
load_thread(main_thread)
