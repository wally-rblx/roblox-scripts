-- West X (The Wild West) 
-- Free trial (12/8/21)

-- Released for the reasons stated in the discord message.
-- Use at your own risk. The game anticheat will detect you. 
-- All logging mechanisms from the script should be disabled, but be cautious.

local SCRIPT_URL = 'https://raw.githubusercontent.com/wally-rblx/roblox-scripts/main/west-x/script.lua'
local SCRIPT_CONTENT = game:HttpGet(SCRIPT_URL)

local encode, decode do
	-- encoder fully remade by me

	-- 11/7/21 rewrote encoder/decoder

	-- shitty useless encoder with "keys" which are fucking useless because the decoder knows exactly how to fetch for the keys 

	-- note: shift argument most likely isnt in original script but i was
	-- unsure how the script determiines it so manually adding shift as an argument works

	-- encoder mixes the string and the key together and shifts them over += shift byte and appends a character at the end so decoder can determine the shift amount 
	-- and resolve it

	function encode(str, key, shift)
		local str = syn.crypt.base64.encode(str:reverse())
		local key = syn.crypt.base64.encode(key):reverse()

		local count = 0
		str = str:gsub('.', function(c)
		  count = count + 1;
		  return c .. key:sub(count, count)
		end):gsub(".", function(c) return string.char(c:byte() + shift) end)

		return str .. string.char(40 + shift)
	end

	-- decoder can figure out shfit based on last char (lastchar is = string.char((40 +- shift))
	-- decoder also resolves the key from the encoded string .. unsure what its for but whatever

	function decode(str)
	    local shift = str:byte(-1, -1) - 40;
	    local str = str:sub(1, -2)

	    local count = 0;

	    local decoded, key = {}, {}

	    str = str:gsub('.', function(c)
	        return string.char(c:byte() - shift)
	    end):gsub('.', function(c)
	        count = count + 1
	        if (count % 2) == 1 then 
	            decoded[#decoded + 1] = c 
	        else
	            key[#key + 1] = c;
	        end

	        return c
	    end)

	    decoded = table.concat(decoded)
	    key = table.concat(key)

	    return syn.crypt.base64.decode(decoded):reverse(), syn.crypt.base64.decode(key:reverse())
	end
end

-- random character func ripped from dex lol
local charset = {}

for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

local function randomString(length)
    local str = ''
    for i = 1, length do
        str = str .. charset[math.random(1, #charset)]
    end
    return str
end

-- main crack
local request
request = replaceclosure(syn.request, function(...)
	if select('#', ...) == 0 then return request(...) end -- NOOB check bypass

	local self = ...
	if type(self) == 'table' and type(rawget(self, 'Url')) == 'string' then
		if self.Url == 'https://blissfuls.world/westx/au.php' then
			-- it was fun to reverse decoder 

           	-- 11/7/2021 update
           	-- changed header names to random every exec & forced server response key have to include the %M param from os.time (included in the encoded string with your key)
           	-- sort headers to find the longest one (the str we want, although we could skip this and make our own key but lazy lel)

			local headerMap = {}

	        for k, v in next, self.Headers do
	            headerMap[#headerMap + 1] = { k, v }
	        end

	        table.sort(headerMap, function(a, b) return #a[2] > #b[2] end)

			local name = headerMap[1][1]
			local str, key = decode(self.Headers[name]) -- whitelist key encoded with %m and random string

			-- changed from just being able to use server key to having to include last 6 chars as %m and 4 other random chars
			local resKey = key:sub(1, 2) .. randomString(28) .. key:sub(1, 2) .. randomString(4)
			local result = encode('Passed', resKey, -1)

			return { Body = result, StatusCode = 200 }
		elseif self.Url == 'https://blissfuls.world/westx/loader' then
			return { Body = SCRIPT_CONTENT, StatusCode = 200 }
		else
			return print('unhandled Uri', self.Url)
		end
	end

	return request(...)
end)


do
	-- cant hookfunction as it seems to crash :(
	setreadonly(syn.websocket, false)
	syn.websocket.connect = function(...) 
		return {
			Send = function() end,
			Close = function() end,

			OnMessage = Instance.new('BindableEvent').Event,
			OnClose = Instance.new('BindableEvent').Event,
		}
	end
	setreadonly(syn.websocket, true)
end

_G.key = game:GetService('HttpService'):GenerateGUID()
loadstring(SCRIPT_CONTENT)()
