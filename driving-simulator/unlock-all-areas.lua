local import = getrenv().shared.import;
local remote = getrenv().shared.remote;
local asset = getrenv().shared.asset

local old = getupvalue(import, 1)
setupvalue(import, 1, function() return script end) 

local areaDiscovered = remote('/AreaDiscovered')
for _, area in next, asset("/DiscoverableAreas"):GetChildren() do
    areaDiscovered:FireServer(area.Name)
end
