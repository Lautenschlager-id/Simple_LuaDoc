--[[
	Documentation Format:
	- Starts with "Doc" and long comment
	- ~
		^ "Admin only"
	- "Description"
	- @param type
		* type1|type2|...
	- @param optional_type*
	- >return_type
	- !type
]]

local _STATIC = { }

local generateFileName = function(from)
	if not _STATIC[from] then
		_STATIC[from] = {
			properties = { },
			methods = { },
			hasAdminFields = false
		}
	end
	return _STATIC[from]
end
local ast = "![admin_only](https://i.imgur.com/GWJg6TA.png)"

local generate = function(fileName, content)
	string.gsub(content, "%-%-%[%[%Doc\n(.-)%]%]\n(.-)\n", function(info, func)
		local str = { }
		local src = generateFileName(fileName)

		local description = string.match(info, "\"(.-)\"\n")
		if description then
			description = (string.gsub(description, "	*\r?\n	*", "<br>"))
		end

		local adminOnly = (string.find(info, "~\n") and ast or "")
		
		local type = string.match(info, "	+!(%S+)")
		if not type then -- Function
			local from, name, parameters = string.match(func, "([%w_]+)%.([%w_]+) ?= ?function(%(.-%))")
			if from then
				src = generateFileName(from)
			else
				name, parameters = string.match(func, "([%w_]+) ?= ?function(%(.-%))")
			end
			if adminOnly ~= "" and not src.hasAdminFields then
				src.hasAdminFields = true
			end
			src = src.methods

			str[1] = "### " .. adminOnly .. name .. parameters
			if #parameters > 2 then -- not empty
				local params, counter = { }, 0
				string.gsub(string.sub(parameters, 2, -2), "[^, ]+", function(param)
					local param_type = string.match(info, "@" .. param .. " (%S+)\n")
					if param_type then
						counter = counter + 1

						local optional = string.sub(param_type, -1) == '*' and #param_type > 1
						params[counter] = ">| " .. param .. " | `" .. string.gsub((optional and string.sub(param_type, 1, -2) or param_type), '|', "` \\| `") .. "` | " .. (optional and "✔" or "") .. " |"
					end
				end)
				if #params > 0 then
					str[2] = ">| Parameter | Type | Optional |"
					str[3] = ">|-|-|:-:|"
					str[4] = table.concat(params, '\n')
				end
			end
			str[#str + 1] = '>'

			if description then
				str[#str + 1] = ">" .. description
			end

			local ret = string.match(info, ">(%S+)\n")
			if ret then
				if description then
					str[#str + 1] = '>'
				end

				local o, counter = { }, 0
				string.gsub(ret, "[^|]+", function(t)
					counter = counter + 1
					o[counter] = t
				end)

				str[#str + 1] = ">**Returns:** `" .. table.concat(o, "` | `") .. "`"
			end

			src[#src + 1] = table.concat(str, '\n') .. "\n"
		else
			local from, name = string.match(func, "([%w_]+)%.([%w_]+) ?=")
			if from then
				src = generateFileName(from)
			else
				src = src
				name = string.match(func, "([%w_]+) ?=")
			end
			if adminOnly ~= "" and not src.hasAdminFields then
				src.hasAdminFields = true
			end
			src = src.properties

			src[#src + 1] = "| " .. adminOnly .. name .. " | " .. type .. " | " .. description .. " |"
		end
	end)
end
local writeFile = function(file)
	local properties = #_STATIC[file].properties > 0 and "## Properties\n| Name | Type | Description |\n|-|-|-|\n" .. table.concat(_STATIC[file].properties, '\n') or nil
	local methods = #_STATIC[file].methods > 0 and "## Static Methods\n" .. table.concat(_STATIC[file].methods, '\n') or ""

	if not properties and methods == "" then
		return
	end
	
	local doc = io.open("Documentation/" .. tostring(file) .. ".md", "w+")
	doc:write((_STATIC[file].hasAdminFields and (ast .. " **Admin-only fields/methods**\n***\n") or "") .. (properties and (properties .. "\n") or "") .. methods)
	doc:flush()
	doc:close()
end

for k, v in next, {
	"filename",
	"filename",
	"filename"
} do
	local file = io.open(v .. ".lua", 'r')
	generate(string.match(v, "([%w_]+)$"), file:read("*a"))
	file:close()
end

for k, v in next, _STATIC do
	writeFile(k)
end
