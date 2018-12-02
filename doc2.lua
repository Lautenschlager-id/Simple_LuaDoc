--[=[
	Documentation Format:

	--[[@
		@desc description
		@param parameter<type,type> description
		@returns type|type description
	]]
]=]

string.split = function(str, pattern)
	local out, counter = { }, 0
	string.gsub(str, pattern, function(v)
		counter = counter + 1
		out[counter] = v
	end)
	return out
end

table.pairsByIndexes = function(list, f)
	local out = {}
	for index in next, list do
		out[#out + 1] = index
	end
	table.sort(out, f)
	
	local i = 0
	return function()
		i = i + 1
		if out[i] ~= nil then
			return out[i], list[out[i]]
		end
	end
end

local field = {
	["desc"] = function(src, v)
		src[#src + 1] = v
	end,
	["param"] = function(src, v)
		local name, types, description = string.match(v, "^([%w_]+%??)< *(.-) *> +(.-)$")
		local optional = string.sub(name, -1) == '?'

		src[#src + 1] = { (optional and string.sub(name, 1, -2) or name), string.split(types, "[^, ]+"), description, optional }
	end,
	["returns"] = function(src, v)
		local types, description = string.match(v, "^(%S+) +(.-)$")
		src[#src + 1] = { string.split(types, "[^|]+"), description }
	end
}

local _S = { }
local generate = function(fileName, content)
	local files = {
		_STATIC = { },
		_METHODS = { }
	}
	local tmp = {
		_STATIC = { },
		_METHODS = { }
	}

	string.gsub(content, "%-%-%[%[@\r?\n(.-)%]%]\r?\n(.-)\r?\n", function(info, func)
		local data = { }
		for k, v in next, field do
			string.gsub(info, "@" .. k .. " (.-)\r?\n", function(j)
				if not data[k] then
					data[k] = { }
				end

				v(data[k], j)
			end)
		end

		local static = false
		local tbl, fn, p = string.match(func, "([%w_]+)%.([%w_]+) ?= ?function ?%((.-)%)")
		if tbl == "self" then
			if string.find(p, "self") then
				fn = "self:" .. fn
			else
				static = true
			end
			tbl = nil
		end

		local file = { }
		local params = { }
		local hasParam = not not data.param
		if hasParam then
			for i = 1, #data.param do
				params[i] = data.param[i][1]
			end
		end

		file[#file + 1] = ">### " .. fn .. " ( " .. table.concat(params, ", ") .. " )"
		if hasParam then
			file[#file + 1] = ">| Parameter | Type | Required | Description |"
			file[#file + 1] = ">| :-: | :-: | :-: | - |"
			for i = 1, #data.param do
				file[#file + 1] = ">| " .. data.param[i][1] .. " | `" .. table.concat(data.param[i][2], "`, `") .. "` | " .. (data.param[i][4] and "✕" or "✔") .. " | " .. data.param[i][3] .. " |"
			end
			file[#file + 1] = '>'
		end

		file[#file + 1] = ">" .. (data.desc and table.concat(data.desc, "\n>") or "No description.")

		if data.returns then
			file[#file + 1] = '>'
			file[#file + 1] = ">**Returns**"
			file[#file + 1] = '>'
			file[#file + 1] = ">| Type | Description |"
			file[#file + 1] = ">| :-: | - |"
			for i = 1, #data.returns do
				file[#file + 1] = ">| `" .. table.concat(data.returns[i][1], "`, `") .. "` | " .. data.returns[i][2] .. " |"
			end
			file[#file + 1] = ">\n"
		else
			file[#file + 1] = '\n'			
		end

		files[(static and "_STATIC" or "_METHODS")][fn] = file
	end)

	_S[fileName] = {  _STATIC = '', _METHODS = '' }

	for k, v in next, files do
		for i, j in table.pairsByIndexes(v) do
			tmp[k][#tmp[k] + 1] = table.concat(j, '\n')
		end
	end

	for k, v in next, files do
		_S[fileName][k] = table.concat(tmp[k], "\n")
	end
end

local writeFile = function(file, data)
	local doc = io.open("docs/" .. tostring(file) .. ".md", "w+")
	doc:write((data._STATIC and ("## Static Methods\n" .. data._STATIC) or "") .. (data._METHODS and ((data._STATIC and "\n" or "") .. ("## Methods\n" .. data._METHODS)) or ""))
	doc:flush()
	doc:close()
end

for k, v in next, {
	"filename"
} do
	local file = io.open(v .. ".lua", 'r')
	generate(v, file:read("*a"))
	file:close()
end

for k, v in next, _S do
	writeFile(k, v)
end