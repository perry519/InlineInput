local function valid_library(library)
return type(library) == "table"
	and type(library.RegisterInput) == "function"
	and type(library.EnsureInput) == "function"
	and type(library.AttachHostInputs) == "function"
end

if valid_library(_G.InlineInput) then
	return _G.InlineInput
end

local function script_dir()
	local source = debug and debug.getinfo and debug.getinfo(1, "S").source or nil

	if type(source) ~= "string" then
		return nil
	end

	if string.sub(source, 1, 1) == "@" then
		source = string.sub(source, 2)
	end

	return string.match(source, "^(.*[/\\])[^/\\]+$")
end

local function add_candidate(candidates, path)
	if type(path) == "string" and path ~= "" then
		table.insert(candidates, path)
	end
end

local candidates = {}
local base_path = script_dir()

add_candidate(candidates, base_path and base_path .. "inlineinput.lua")
add_candidate(candidates, ModPath and ModPath .. "inlineinput.lua")
add_candidate(candidates, "InlineInput/inlineinput.lua")
add_candidate(candidates, "mods/InlineInput/inlineinput.lua")

for _, path in ipairs(candidates) do
	local ok, loaded = pcall(dofile, path)
	local library = ok and loaded or _G.InlineInput

	if valid_library(library) then
		return library
	end
end

return nil
