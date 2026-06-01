local HttpService = game:GetService("HttpService")

local obbyFolder = workspace:WaitForChild("Obby")

local function serializeInstance(obj)
	if not obj:IsA("BasePart") and #obj:GetChildren() == 0 then
		return nil
	end
	
	local className = obj.ClassName
	local shape = if obj:IsA("Part") then obj.Shape.Name else "Block"
    if obj:IsA("WedgePart") then
        className = "Part"
        shape = "Wedge"
    elseif obj:IsA("CornerWedgePart") then
        className = "Part"
        shape = "CornerWedge"
    end

	if obj.Name == "SpawnLocation" then
		className = "Spawn"
	elseif obj.Name == "Truss" then
		className = "Truss"
	end

	local data = {
		ObbyName = obbyFolder.ObbyName.Value,
		Name = obj.Name,
		ClassName = className,
		Shape = shape,
		Children = {}
	}

	
	if obj:IsA("BasePart") then
		data.Properties = {
			Size = {
				X = obj.Size.X,
				Y = obj.Size.Y,
				Z = obj.Size.Z
			},
			
			Rotation = {
				X = obj.Rotation.X,
				Y = obj.Rotation.Y,
				Z = obj.Rotation.Z
			},


			Position = {
				X = obj.Position.X,
				Y = obj.Position.Y,
				Z = obj.Position.Z
			},

			Color = {
				R = obj.Color.R,
				G = obj.Color.G,
				B = obj.Color.B
			},
		}
	end


	for _, child in ipairs(obj:GetChildren()) do
		local serialized = serializeInstance(child)
		if serialized then
			table.insert(data.Children, serialized)
		end
	end

	return data
end


local function prettyPrint(json)
	local formatted = ""
	local indent = 0
	local inString = false

	for i = 1, #json do
		local char = json:sub(i, i)
		local prevChar = json:sub(i - 1, i - 1)

		if char == '"' and prevChar ~= "\\" then
			inString = not inString
		end

		if not inString then
			if char == "{" or char == "[" then
				indent += 1
				formatted ..= char .. "\n" .. string.rep("    ", indent)

			elseif char == "}" or char == "]" then
				indent -= 1
				formatted ..= "\n" .. string.rep("    ", indent) .. char

			elseif char == "," then
				formatted ..= char .. "\n" .. string.rep("    ", indent)

			else
				formatted ..= char
			end
		else
			formatted ..= char
		end
	end

	return formatted
end


local obbyNameValue = obbyFolder:FindFirstChild("ObbyName")
local obbyDifficultyValue = obbyFolder:FindFirstChild("ObbyDifficulty")
local obbyCreatorValue = obbyFolder:FindFirstChild("ObbyCreator")
local actualObbyName = obbyNameValue and obbyNameValue.Value or obbyFolder.Name
local obbyCreator = obbyCreatorValue and obbyCreatorValue.Value or "John Orp"
local obbyDifficulty = obbyDifficultyValue and obbyDifficultyValue.Value or "not defined"

local finalPayload: {[string]: any} = {
	ObbyName = actualObbyName,
	Difficulty = obbyDifficulty,
	Creator = obbyCreator,
	Data = serializeInstance(obbyFolder)
}


local json = HttpService:JSONEncode(finalPayload)


local url = "http://127.0.0.1:5000/save-obby"

local success, response = pcall(function()
	return HttpService:PostAsync(url, json, Enum.HttpContentType.ApplicationJson)
end)

if success then
	print(" Successfully sent to Flask server! Check your PC folder.")
else
	warn("❌ Failed to send data to Flask app. Reason: " .. tostring(response))
end
