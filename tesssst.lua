if not getgenv().BeastHubRayfield then
    getgenv().BeastHubRayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end
local Rayfield = getgenv().BeastHubRayfield
local beastHubIcon = 109838189843903

-- local isVerified = ...  -- grab the passed value
local isVerified = getgenv()._bh_isVerified
local expiryText=isVerified==true and "lifetime" or (isVerified and tostring(isVerified) or "Lifetime")
local scriptTitle = "BeastHubXDevsHub | Exp: "..expiryText
if getgenv().BeastHubLoaded then
    if Rayfield then
        Rayfield:Notify({
            Title = "BeastHub",
            Content = "Already running! Press H",
            Duration = 5,
            Image = beastHubIcon
        })
    else
        warn("BeastHub is already running!")
    end    
    return
end
getgenv().BeastHubLoaded = true
getgenv().ConfigLoaded = false

--
getgenv().BeastHubLink = "https://raw.githubusercontent.com/Adobo1/smoothHub1/refs/heads/main/BeastHub.lua"
if not getgenv().BeastHubFunctions then
    --LIVE
    getgenv().BeastHubFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/bhubalt/refs/heads/main/myFunctions2.lua"))()
    --DEV MODE
    -- getgenv().BeastHubFunctions = loadstring(game:HttpGet("https://pastebin.com/raw/SLUMGfXc"))()
end
local myFunctions = getgenv().BeastHubFunctions
--
--local luckGUI = myFunctions.createLuckGUI()

-- ================== MAIN ==================
local Window = Rayfield:CreateWindow({
   Name = scriptTitle,
   Icon = beastHubIcon, --BeastHub logo
   LoadingTitle = "BeastHub",
   LoadingSubtitle = "by Team Forgotten",
   ShowText = "Rayfield",
   Theme = "Default",
   ToggleUIKeybind = "H",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "BeastHub",
      FileName = "userConfig"
   }
})

local beastHubNotifsEnabled = true
local username = game.Players.LocalPlayer.Name
local function beastHubNotify(title, message, duration)
    if beastHubNotifsEnabled then
        Rayfield:Notify({
            Title = title,
            Content = message,
            Duration = duration,
            Image = beastHubIcon
        })
    end
end

local function sendDiscordWebhook(webhookUrl, message)
    -- print("webhookUrl: "..webhookUrl)
    if typeof(webhookUrl) ~= "string" or webhookUrl == "" then
        warn("[Webhook] Invalid webhook URL")
        return
    end
    local payload = game:GetService("HttpService"):JSONEncode({ content = message })
    local req = syn and syn.request or http_request or request
    if not req then
        warn("[Webhook] Your executor does not support HTTP requests!")
        return
    end
    local success, result = pcall(function()
        return req({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = payload
        })
    end)
    if success and result.Success then
        -- print("[Webhook] Message sent successfully!")
    else
        warn("[Webhook] Failed to send: " .. tostring(result and result.StatusCode or result))
    end
end

local function sendDiscordWebhookEmbedHatchMonitoring(webhookUrl,koiRefundCount,sealsRefundCount,hatchSpeed,curEggName,eggCount)
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	if typeof(webhookUrl) ~= "string" or webhookUrl == "" then
		warn("Invalid webhook URL")
		return
	end
	local player = Players.LocalPlayer
	if not player then
		warn("Player not found")
		return
	end

	-- Build Roblox Thumbnails API URL
	local apiUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..player.UserId.."&size=150x150&format=Png&isCircular=true"

	local req = syn and syn.request or http_request or request
	if not req then
		warn("HTTP request not supported")
		return
	end

	local avatarUrl
	local success, response = pcall(function()
		return req({Url = apiUrl, Method = "GET"})
	end)

	if success and response and response.Body then
		local data = HttpService:JSONDecode(response.Body)
		if data.data[1] and data.data[1].imageUrl then
			avatarUrl = data.data[1].imageUrl
		else
			warn("Thumbnail not ready yet, imageUrl is nil")
		end
	else
		warn("Failed to fetch thumbnail from Roblox API")
	end

	local embedData = {
		title = "BHUB Hatch Monitoring",
		color = 9511939,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		fields = {
			{
				name = "Player",
				value = "||"..player.Name.."||",
				inline = true
			},
			{
				name = "Egg",
				value = "Name: "..curEggName.." | "..eggCount.."\nSpeed: "..hatchSpeed,
				inline = true
			},
			{
				name = "Refunds",
				value = "Koi: "..tostring(koiRefundCount).."\nSeals: "..tostring(sealsRefundCount),
				inline = true
			}
		}
	}

	if avatarUrl then
		embedData.thumbnail = {url = avatarUrl}
	end

	local payload = HttpService:JSONEncode({embeds = {embedData}})

	pcall(function()
		req({
			Url = webhookUrl,
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = payload
		})
	end)
end

local function sendPetDataWebhook(webhookUrl, petName, kgMode, baseKG, price, seller)
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local prefix
    if kgMode == "above" then
        prefix = ">"
    else
        prefix = "<"
    end

	if typeof(webhookUrl) ~= "string" or webhookUrl == "" then
		warn("Invalid webhook URL")
		return
	end

	local player = Players.LocalPlayer
	if not player then
		warn("Player not found")
		return
	end

	local PetModule = require(
		ReplicatedStorage
			:WaitForChild("Modules")
			:WaitForChild("GardenGuideModules")
			:WaitForChild("DataModules")
			:WaitForChild("PetData")
	)

	if not PetModule or not PetModule.Data or not PetModule.Data[petName] then
		warn("Pet not found in module")
		return
	end

	local petInfo = PetModule.Data[petName]
	local imageId = petInfo.ImageId
	local numericId
	if type(imageId) == "string" then
		numericId = string.match(imageId, "%d+")
	elseif type(imageId) == "number" then
		numericId = tostring(imageId)
	end

	local thumbnailUrl
	if numericId then
		local thumbEndpoint = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. numericId .. "&size=420x420&format=Png&isCircular=false"
		local req = syn and syn.request or http_request or request
		if req then
			local success, response = pcall(function()
				return req({
					Url = thumbEndpoint,
					Method = "GET"
				})
			end)
			if success and response and response.Body then
				local decoded = HttpService:JSONDecode(response.Body)
				if decoded and decoded.data and decoded.data[1] and decoded.data[1].imageUrl then
					thumbnailUrl = decoded.data[1].imageUrl
				end
			end
		end
	end

	local embedData = {
		-- title = petInfo.Name or petName,
		title = "BeastHub Sniper! "..(petInfo.Name or petName),
		description = petInfo.Description or "No description",
		color = 16744192,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		fields = {
			{
				name = "Rarity",
				value = tostring(petInfo.Rarity),
				inline = true
			},
			{
				name = "Base KG",
				value = prefix..baseKG,
				inline = true
			},
			{
				name = "Price",
				value = price,
				inline = true
			},
			{
				name = "Seller",
				value = "||"..seller.."||",
				inline = true
			}
		}
	}

	if thumbnailUrl then
		embedData.thumbnail = {
			url = thumbnailUrl
		}
	end

	local payload = HttpService:JSONEncode({
        content = "@everyone",
        allowed_mentions = {
            parse = {"everyone"}
        },
		embeds = {embedData}
	})

	local req = syn and syn.request or http_request or request
	if not req then
		warn("HTTP not supported")
		return
	end

	pcall(function()
		req({
			Url = webhookUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = payload
		})
	end)
end

local function sendWebhookHuge(webhookUrl, playerName, petName, curEggName, baseKG, desc)
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local baseNum = tonumber(baseKG)
    local brontoKG = baseNum and string.format("%.2f", baseNum * 1.3) or "N/A"
    local req = syn and syn.request or http_request or request

	if typeof(webhookUrl) ~= "string" or webhookUrl == "" then
		warn("Invalid webhook URL")
		return
	end

	local PetModule = require(
		ReplicatedStorage
			:WaitForChild("Modules")
			:WaitForChild("GardenGuideModules")
			:WaitForChild("DataModules")
			:WaitForChild("PetData")
	)

	if not PetModule or not PetModule.Data or not PetModule.Data[petName] then
		warn("Pet not found in module")
		return
	end

	local petInfo = PetModule.Data[petName]
	local imageId = petInfo.ImageId
	local numericId
	if type(imageId) == "string" then
		numericId = string.match(imageId, "%d+")
	elseif type(imageId) == "number" then
		numericId = tostring(imageId)
	end

	local thumbnailUrl
	if numericId then
		local thumbEndpoint = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. numericId .. "&size=420x420&format=Png&isCircular=false"
		if req then
			local success, response = pcall(function()
				return req({
					Url = thumbEndpoint,
					Method = "GET"
				})
			end)
			if success and response and response.Body then
				local decoded = HttpService:JSONDecode(response.Body)
				if decoded and decoded.data and decoded.data[1] and decoded.data[1].imageUrl then
					thumbnailUrl = decoded.data[1].imageUrl
				end
			end
		end
	end

	local embedData = {
		-- title = petInfo.Name or petName,
		title = "BeastHub Huge Hatch! " .. (petInfo.Name or petName),
		description = tostring(curEggName).." | "..tostring(desc),
		color = 52480,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		fields = {
            {
				name = "Player",
				value = "||"..playerName.."||",
				inline = true
			},
			{
				name = "Rarity",
				value = tostring(petInfo.Rarity),
				inline = true
			},
			{
				name = "Base KG",
				value = tostring(baseKG).." ("..brontoKG.." if +30%)",
				inline = true
			}
		}
	}

	if thumbnailUrl then
		embedData.thumbnail = {
			url = thumbnailUrl
		}
	end

	local payload = HttpService:JSONEncode({
        content = "@everyone",
        allowed_mentions = {
            parse = {"everyone"}
        },
        embeds = {embedData}
    })

	if not req then
		warn("HTTP not supported")
		return
	end

	pcall(function()
		req({
			Url = webhookUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = payload
		})
	end)
end

-- Safe Reload button
local function reloadScript(message)
    -- Reset flags first so main script can run again
    getgenv().BeastHubLoaded = false
    getgenv().BeastHubRayfield = nil
 
    -- Destroy existing Rayfield UI safely
    if Rayfield and Rayfield.Destroy then
        Rayfield:Destroy()
        print("Rayfield destroyed")
    elseif game:GetService("CoreGui"):FindFirstChild("Rayfield") then
        game:GetService("CoreGui").Rayfield:Destroy()
        print("Rayfield destroyed in CoreGui")
    end
 
    -- Reload main script
    if getgenv().BeastHubLink then
        local ok, err = pcall(function()
            loadstring(game:HttpGet(getgenv().BeastHubLink))()
        end)
        if ok then
            Rayfield = getgenv().BeastHubRayfield
            Rayfield:Notify({
                Title = "BeastHub",
                Content = message.." successful",
                Duration = 3,
                Image = beastHubIcon
            })
            print("BeastHub reloaded successfully")
        else
            warn("Failed to reload BeastHub:", err)
        end
    else
        warn("Reload link not set!")
    end
end

--equip
local function equipItemByName(itemName)
    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
	-- player.Character.Humanoid:UnequipTools() --unequip all first

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and string.find(tool.Name, itemName) then
            --print("Equipping:", tool.Name)
			player.Character.Humanoid:UnequipTools() --unequip all first
            player.Character.Humanoid:EquipTool(tool)
            return true -- stop after first match
        end
    end
    return false
end

local function equipItemByNameV2(itemName) --for eggs
	local player = game.Players.LocalPlayer
	local backpack = player:WaitForChild("Backpack")
	-- player.Character.Humanoid:UnequipTools()

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local name = tool.Name
			local cleaned = string.match(name, "^(.-)%s+x%d+$") or name

			if cleaned == itemName then
				-- player.Character.Humanoid:UnequipTools()
				player.Character.Humanoid:EquipTool(tool)
				return true
			end
		end
	end
	return false
end

local function equipPetByName(itemName) --for pets
	local player = game.Players.LocalPlayer
	local backpack = player:WaitForChild("Backpack")

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local name = tool.Name
            if itemName == name then
                print("Selling: "..itemName)
                player.Character.Humanoid:EquipTool(tool)
			    return true
            end
		end
	end
	return false
end

--=======HANDLE LOCATIONS FOR  AUTO PLACE EGG
local localPlayer = game.Players.LocalPlayer
-- find player's farm
local function getMyFarm()
    if not localPlayer then
        warn("[BeastHub] Local player not found!")
        return nil
    end

    local farmsFolder = workspace:WaitForChild("Farm")
    for _, farm in pairs(farmsFolder:GetChildren()) do
        if farm:IsA("Folder") or farm:IsA("Model") then
            local ownerValue = farm:FindFirstChild("Important") 
                            and farm.Important:FindFirstChild("Data") 
                            and farm.Important.Data:FindFirstChild("Owner")
            if ownerValue and ownerValue.Value == localPlayer.Name then
                return farm
            end
        end
    end

    -- warn("[BeastHub] Could not find your farm!")
    return nil
end

-- get farm spawn point CFrame
local function getFarmSpawnCFrame() --old code
    local myFarm = getMyFarm()
    if not myFarm then return nil end

    local spawnPoint = myFarm:FindFirstChild("Spawn_Point")
    if spawnPoint and spawnPoint:IsA("BasePart") then
        return spawnPoint.CFrame
    end

    warn("[BeastHub] Spawn_Point not found in your farm!")
    return nil
end


local positionForPlaceEggs = "Left - spread out"

local function getPositionForPlaceEggs()
    local eggOffsets

    if positionForPlaceEggs == "Left - spread out" then
        eggOffsets = {
            Vector3.new(-36, 0, -18),
            Vector3.new(-27, 0, -18),
            Vector3.new(-18, 0, -18),
            Vector3.new(-9, 0, -18),

            Vector3.new(-36, 0, -33),
            Vector3.new(-27, 0, -33),
            Vector3.new(-18, 0, -33),
            Vector3.new(-9, 0, -33),

            Vector3.new(-36, 0, -48),
            Vector3.new(-27, 0, -48),
            Vector3.new(-18, 0, -48),
            Vector3.new(-9, 0, -48),

            Vector3.new(-36, 0, -63),
            Vector3.new(-27, 0, -63),
            Vector3.new(-18, 0, -63),
            Vector3.new(-9, 0, -63),
        }

    elseif positionForPlaceEggs == "Right - spread out" then
        eggOffsets = {
            Vector3.new(10, 0, -18),
            Vector3.new(19, 0, -18),
            Vector3.new(28, 0, -18),
            Vector3.new(37, 0, -18),

            Vector3.new(10, 0, -33),
            Vector3.new(19, 0, -33),
            Vector3.new(28, 0, -33),
            Vector3.new(37, 0, -33),

            Vector3.new(10, 0, -48),
            Vector3.new(19, 0, -48),
            Vector3.new(28, 0, -48),
            Vector3.new(37, 0, -48),

            Vector3.new(10, 0, -63),
            Vector3.new(19, 0, -63),
            Vector3.new(28, 0, -63),
            Vector3.new(37, 0, -63),
        }

    elseif positionForPlaceEggs == "Left - stacked" then
        eggOffsets = {
            Vector3.new(-30, 0, -12),
            Vector3.new(-27, 0, -12),
            Vector3.new(-24, 0, -12),
            Vector3.new(-21, 0, -12),

            Vector3.new(-30, 0, -15),
            Vector3.new(-27, 0, -15),
            Vector3.new(-24, 0, -15),
            Vector3.new(-21, 0, -15),

            Vector3.new(-30, 0, -18),
            Vector3.new(-27, 0, -18),
            Vector3.new(-24, 0, -18),
            Vector3.new(-21, 0, -18),

            Vector3.new(-30, 0, -21),
            Vector3.new(-27, 0, -21),
            Vector3.new(-24, 0, -21),
            Vector3.new(-21, 0, -21),
        }

    elseif positionForPlaceEggs == "Right - stacked" then
        eggOffsets = {
            Vector3.new(16, 0, -12),
            Vector3.new(19, 0, -12),
            Vector3.new(22, 0, -12),
            Vector3.new(25, 0, -12),

            Vector3.new(16, 0, -15),
            Vector3.new(19, 0, -15),
            Vector3.new(22, 0, -15),
            Vector3.new(25, 0, -15),

            Vector3.new(16, 0, -18),
            Vector3.new(19, 0, -18),
            Vector3.new(22, 0, -18),
            Vector3.new(25, 0, -18),

            Vector3.new(16, 0, -21),
            Vector3.new(19, 0, -21),
            Vector3.new(22, 0, -21),
            Vector3.new(25, 0, -21),
        }

    elseif positionForPlaceEggs == "Random - stacked" then
        local pos = {}
        local minX, maxX = -40, 40
        local minZ, maxZ = -70, -10
        local minDist = 8
        local attempts = 0

        while #pos < 30 and attempts < 1000 do
            local newPos = Vector3.new(
                math.random(minX, maxX),
                0,
                math.random(minZ, maxZ)
            )

            local farEnough = true
            for _, p in ipairs(pos) do
                if (p - newPos).Magnitude < minDist then
                    farEnough = false
                    break
                end
            end

            if farEnough then
                table.insert(pos, newPos)
            end

            attempts = attempts + 1
        end

        eggOffsets = pos
    end

    return eggOffsets
end

-- convert to world positions
local function getFarmEggLocations()
    local spawnCFrame = getFarmSpawnCFrame()
    local eggOffsets = getPositionForPlaceEggs()
    if not spawnCFrame then return {} end

    local locations = {}
    for _, offset in ipairs(eggOffsets) do
        table.insert(locations, spawnCFrame:PointToWorldSpace(offset))
    end
    return locations
end

local function testLocation(offset)
	local player = game.Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("HumanoidRootPart not found")
		return
	end

	local spawnCFrame = getFarmSpawnCFrame()
	if not spawnCFrame then
		warn("Spawn point not found")
		return
	end

	if not offset or typeof(offset) ~= "Vector3" then
		warn("Invalid offset provided")
		return
	end

	local targetPos = spawnCFrame:PointToWorldSpace(offset)
	hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
end

--preload custom loadouts
getgenv().preloadedCustomLoadouts = {}
local function preloadCustomLoadouts()
	local saveFolder = "BeastHub"

	if not isfolder(saveFolder) then
		makefolder(saveFolder)
	end

	local data = {}
	local files = {}

	local ok, rawFiles = pcall(function()
		return listfiles(saveFolder)
	end)

	if ok and type(rawFiles) == "table" then
		for _, filePath in ipairs(rawFiles) do
			if type(filePath) == "string" and string.match(filePath, "%.txt$") then
				local name = filePath:match("([^/\\]+)%.txt$")
				if name and name ~= "" then
					files[#files+1] = name

					local fOk, content = pcall(function()
						return readfile(filePath)
					end)

					data[name] = fOk and content or ""
				end
			end
		end
	end

	table.sort(files, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	getgenv().preloadedCustomLoadouts = data
	getgenv().preloadedCustomLoadoutNames = files -- optional helper
end
preloadCustomLoadouts()
getgenv().preloadCustomLoadouts = preloadCustomLoadouts

--signal for custom loadout changes
getgenv().LoadoutsChangedEvent = getgenv().LoadoutsChangedEvent or Instance.new("BindableEvent")

--local login_url = loadstring(game:HttpGet("https://raw.githubusercontent.com/bhubAlt/bhub_alt/refs/heads/main/u2.lua"))()

--=====================
--get FULL pet list via registry
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetRegistry = require(ReplicatedStorage.Data.PetRegistry)
local function getAllPetNames()
    local success, PetRegistry = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"))
    end)
    if not success or type(PetRegistry) ~= "table" then
        warn("Failed to load PetRegistry module.")
        return {}
    end
    local petList = PetRegistry.PetList
    if type(petList) ~= "table" then
        warn("PetList not found in PetRegistry.")
        return {}
    end
    local names = {}
    for petName, _ in pairs(petList) do
        table.insert(names, tostring(petName))
    end
    table.sort(names) -- alphabetical sort
    return names
end
local allPetList = getAllPetNames()
task.wait()

--for pets
local petList = myFunctions.getPetOdds()
-- Get names only
local petListNamesOnlyAndSorted = myFunctions.getPetList()
table.sort(petListNamesOnlyAndSorted)

--v2
local function getAllSeedsTableV2()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PlantDataModule = ReplicatedStorage
		:WaitForChild("Modules")
		:WaitForChild("GardenGuideModules")
		:WaitForChild("DataModules")
		:WaitForChild("PlantData")
	local PlantData = require(PlantDataModule)
	if typeof(PlantData) ~= "table" then
		return nil
	end
	if typeof(PlantData.Data) ~= "table" then
		return nil
	end
	return PlantData.Data
end
local allSeedsData = getAllSeedsTableV2()

local allSeedsOnly = {}

if allSeedsData then
    for seedName, _ in pairs(allSeedsData) do
        table.insert(allSeedsOnly, seedName)
    end
    table.sort(allSeedsOnly)
    -- print("[BeastHub] All seeds loaded:", table.concat(allSeedsOnly, ", "))
else
    warn("[BeastHub] Failed to load seeds data")
end


local function equipFruitById(fruitId)
	local player = game.Players.LocalPlayer
	local backpack = player:WaitForChild("Backpack")
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Unequip all tools first
	humanoid:UnequipTools()

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("c") == fruitId then
			humanoid:EquipTool(tool)
			return true -- successfully equipped
		end
	end

	return false -- not found
end

--LIVE
local mainModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/bhubalt/refs/heads/main/main2.lua"))()
--DEV MODE 
-- local mainModule = loadstring(game:HttpGet("https://pastebin.com/raw/"))()

--LIVE PetsModule
-- local PetsModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/bhubAlt/bhub_alt/refs/heads/main/bhubpets2.lua"))()
--DEV MODE2 
local PetsModule = loadstring(game:HttpGet("https://pastebin.com/raw/MSMzxAYj"))()

--LIVE AutomationModule
local AutomationModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/bhubalt/refs/heads/main/bhubautomation2.lua"))()
--DEV MODE 2
-- local AutomationModule = loadstring(game:HttpGet("https://pastebin.com/raw/AeFQvyJH"))()

--LIVE LoadoutsModule
local LoadoutsModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/bhubalt/refs/heads/main/loadouts.lua"))()
--DEV MODE 2
-- local LoadoutsModule = loadstring(game:HttpGet("https://pastebin.com/raw/"))()

--LIVE EventModule
local EventModule = loadstring(game:HttpGet("https://pastebin.com/raw/"))()
--DEV MODE2 
-- local EventModule = loadstring(game:HttpGet("https://pastebin.com/raw/"))()

--LIVE TraderModule
local TraderModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/bhubalt/refs/heads/main/trader.lua"))()
--DEV MODE2 
-- local TraderModule = loadstring(game:HttpGet("https://pastebin.com/raw/evwpQQfM"))()


--LIVE PlantsModule
local PlantsModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/XxMarDdEvsZXsWu69/bhubalt/refs/heads/main/plants.lua"))()
--DEV MODE2 
-- local PlantsModule = loadstring(game:HttpGet("https://pastebin.com/raw/"))()


mainModule.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)

local Shops = Window:CreateTab("Shops", "circle-dollar-sign")

PetsModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, petListNamesOnlyAndSorted, mainModule)

local PetEggs = Window:CreateTab("Eggs", "egg")

AutomationModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, allSeedsData, allSeedsOnly, equipFruitById, mainModule)

LoadoutsModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, allSeedsData, allSeedsOnly, equipFruitById, mainModule)

PlantsModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, allSeedsData, allSeedsOnly, equipFruitById)

EventModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, allSeedsData, allSeedsOnly, equipFruitById)

TraderModule.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, sendPetDataWebhook)

local Misc = Window:CreateTab("Misc", "code")
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local placeId = game.PlaceId
local character = player.Character
local Humanoid = character:WaitForChild("Humanoid")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")


-- Shops>Seeds
local seedsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
-- 
local seedNames = {}
for _, item in ipairs(seedsTable) do
    table.insert(seedNames, item.Name)
end

-- UI Setup
Shops:CreateSection("Seeds - Tier 1")
local SelectedSeeds = {}

-- Create Dropdown
local Dropdown_allSeeds = Shops:CreateDropdown({
    Name = "Select Seeds",
    Options = seedNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownTier1Seeds",
    Callback = function(options)
        if typeof(options) ~= "table" then
            options = {}
        end
        -- add selected
        for _, seed in ipairs(options) do
            if not table.find(SelectedSeeds, seed) then
                table.insert(SelectedSeeds, seed)
            end
        end
        -- remove unselected
        for i = #SelectedSeeds, 1, -1 do
            local seed = SelectedSeeds[i]
            if not table.find(options, seed) then
                table.remove(SelectedSeeds, i)
            end
        end
    end,
})

-- Mark All button (only visible/filtered seeds)
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, seed in ipairs(seedNames) do
            if not table.find(SelectedSeeds, seed) then
                table.insert(SelectedSeeds, seed)
            end
        end
        Dropdown_allSeeds:Set(seedNames)
        -- print("All visible seeds selected:", table.concat(SelectedSeeds, ", "))
    end,
})

-- Unselect All button (only visible/filtered seeds)
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedSeeds, 1, -1 do
            if table.find(seedNames, SelectedSeeds[i]) then
                table.remove(SelectedSeeds, i)
            end
        end
        Dropdown_allSeeds:Set({})
        -- print("Visible seeds unselected")
    end,
})

-- Auto-buy toggle for selected
myFunctions._autoBuySelectedSeedsRunning = false -- toggle stoppers seeds
myFunctions._autoBuyAllSeedsRunning = false

myFunctions._autoBuySelectedGearsRunning = false -- toggle stoppers gears 
myFunctions._autoBuyAllGearsRunning = false

myFunctions._autoBuySelectedEggsRunning = false -- toggle stoppers eggs
myFunctions._autoBuyAllEggsRunning = false



local Toggle_autoBuySeedsTier1_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuySeedsTier1_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedSeedsRunning = Value

        if Value then
            local timeout = 5
            while timeout > 0 do
                if #SelectedSeeds > 0 then
                    break
                end
                task.wait(0.5)
                timeout = timeout - 0.5
            end

            if #SelectedSeeds > 0 then
                --print("[BeastHub] Auto-buying selected seeds:", table.concat(SelectedSeeds, ", "))
                
                -- pass a function for dynamic check
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuySeedStock,
                    function()
                        return myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
                    end,
                    SelectedSeeds,
                    function() return myFunctions._autoBuySelectedSeedsRunning end, -- dynamic running flag
                    "BuySeedStock"
                )
            else
                warn("[BeastHub] No seeds selected!")
            end
        else
            --print("[BeastHub] Stopped auto-buy selected seeds.")
        end
    end,
})

-- Auto-buy toggle for all seeds
local Toggle_autoBuySeedsTier1_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuySeedsTier1_all",
    Callback = function(Value)
        myFunctions._autoBuyAllSeedsRunning = Value -- module flag
        if Value then
            -- print("[BeastHub] Auto-buying ALL seeds")
            -- Trigger live buy
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuySeedStock, -- buy event
                function()
                    return myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Seed_Shop"))
                end, -- shop list
                seedNames, -- all available 
                function() return myFunctions._autoBuyAllSeedsRunning end,
                "BuySeedStock"
            )
        else
            --print("[BeastHub] Stopped auto-buy ALL gears")
        end
    end,
})
Shops:CreateDivider()


-- Shops>Gear
-- load data
local gearsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Gear_Shop"))
-- extract names for dropdown
local gearNames = {}
for _, item in ipairs(gearsTable) do
    table.insert(gearNames, item.Name)
end

-- UI
Shops:CreateSection("Gears")
local SelectedGears = {}

local Dropdown_allGears = Shops:CreateDropdown({
    Name = "Select Gears",
    Options = gearNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownGears",
    Callback = function(options)
        --if not options or not options[1] then return end
        for _, gear in ipairs(options) do
            if not table.find(SelectedGears, gear) then
                table.insert(SelectedGears, gear)
            end
        end
        -- Remove unselected
        for i = #SelectedGears, 1, -1 do
            local gear = SelectedGears[i]
            if not table.find(options, gear) and table.find(gearNames, gear) then
                table.remove(SelectedGears, i)
            end
        end
    end,
})

-- Mark All button
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, gear in ipairs(gearNames) do
            if not table.find(SelectedGears, gear) then
                table.insert(SelectedGears, gear)
            end
        end
        Dropdown_allGears:Set(gearNames)
        -- print("All visible gears selected:", table.concat(SelectedGears, ", "))
    end,
})

-- Unselect All button 
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedGears, 1, -1 do
            if table.find(gearNames, SelectedGears[i]) then
                table.remove(SelectedGears, i)
            end
        end
        Dropdown_allGears:Set({})
        -- print("Visible gears unselected")
    end,
})


--Auto buy selected gears
local Toggle_autoBuyGears_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuyGears_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedGearsRunning = Value
        if Value then
            if #SelectedGears > 0 then
                -- print("[BeastHub] Auto-buying selected gears:", table.concat(SelectedGears, ", "))
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuyGearStock,
                    gearsTable,
                    SelectedGears,
                    function() return myFunctions._autoBuySelectedGearsRunning end
                )
            else
                warn("[BeastHub] No gears selected!")
            end
        else
            -- myFunctions._autoBuySelectedGearsRunning = false
        end
    end,
})



-- Auto-buy toggle for all gears
local Toggle_autoBuyGears_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuyGears_all",
    Callback = function(Value)
        myFunctions._autoBuyAllGearsRunning = Value -- module flag

        if Value then
            --print("[BeastHub] Auto-buying ALL gears")
            -- Trigger live buy
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuyGearStock, -- buy event
                gearsTable, -- shop list
                gearNames, -- all available gears
                function() return myFunctions._autoBuyAllGearsRunning end
            )
        else
            --print("[BeastHub] Stopped auto-buy ALL gears")
        end
    end,
})
Shops:CreateDivider()


-- Shops>Eggs
-- load data
local eggsTable = myFunctions.getAvailableShopList(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("PetShop_UI"))
-- extract names for dropdown
local eggNames = {}
for _, item in ipairs(eggsTable) do
    table.insert(eggNames, item.Name)
end

-- UI
Shops:CreateSection("Eggs")
local SelectedEggs = {}

local Dropdown_allEggs = Shops:CreateDropdown({
    Name = "Select Eggs",
    Options = eggNames,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "dropdownEggs",
    Callback = function(options)
        --if not Options or not Options[1] then return end
        for _, egg in ipairs(options) do
            if not table.find(SelectedEggs, egg) then
                table.insert(SelectedEggs, egg)
            end
        end
        -- Remove unselected
        for i = #SelectedEggs, 1, -1 do
            local egg = SelectedEggs[i]
            if not table.find(options, egg) and table.find(eggNames, egg) then
                table.remove(SelectedEggs, i)
            end
        end
    end,
})

-- Mark All button
Shops:CreateButton({
    Name = "[ * ] select all",
    Callback = function()
        for _, egg in ipairs(eggNames) do
            if not table.find(SelectedEggs, egg) then
                table.insert(SelectedEggs, egg)
            end
        end
        Dropdown_allEggs:Set(eggNames)
    end,
})

-- Unselect All button 
Shops:CreateButton({
    Name = "[   ] unselect all",
    Callback = function()
        for i = #SelectedEggs, 1, -1 do
            if table.find(eggNames, SelectedEggs[i]) then
                table.remove(SelectedEggs, i)
            end
        end
        Dropdown_allEggs:Set({})
    end,
})

--Auto buy selected eggs
myFunctions._autoBuySelectedEggsRunning = false -- toggle stoppers
myFunctions._autoBuyAllEggsRunning = false
local Toggle_autoBuyEggs_selected = Shops:CreateToggle({
    Name = "Auto buy selected",
    CurrentValue = false,
    Flag = "autoBuyEggs_selected",
    Callback = function(Value)
        myFunctions._autoBuySelectedEggsRunning = Value
        if Value then
            if #SelectedEggs > 0 then
                myFunctions.buyItemsLive(
                    game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg,
                    eggsTable,
                    SelectedEggs,
                    function() return myFunctions._autoBuySelectedEggsRunning end
                )
            else
                warn("[BeastHub] No eggs selected!")
            end
        end
    end,
})

-- Auto-buy toggle for all eggs
local Toggle_autoBuyEggs_all = Shops:CreateToggle({
    Name = "Auto buy all",
    CurrentValue = false,
    Flag = "autoBuyEggs_all",
    Callback = function(Value)
        myFunctions._autoBuyAllEggsRunning = Value
        if Value then
            myFunctions.buyItemsLive(
                game:GetService("ReplicatedStorage").GameEvents.BuyPetEgg,
                eggsTable,
                eggNames,
                function() return myFunctions._autoBuyAllEggsRunning end
            )
        end
    end,
})
Shops:CreateDivider()

--Traveling Merchant
Shops:CreateSection("Traveling Merchant")

local function getTravelingMerchantsData()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local dataModule = ReplicatedStorage:WaitForChild("Data"):WaitForChild("TravelingMerchant"):WaitForChild("TravelingMerchantData")
	local success, data = pcall(require, dataModule)
	if not success or type(data) ~= "table" then
		return {}
	end
	return data
end
local travelingMerchantData = getTravelingMerchantsData()

local function getTravelingMerchantKeys()
	-- local merchantData = getTravelingMerchantsData() --travelingMerchantData
	local merchants = {}
	for merchantName, _ in pairs(travelingMerchantData) do
		table.insert(merchants, merchantName)
	end
	table.sort(merchants)
	return merchants
end

local function getMerchantShopItems(merchantName)
	local merchant = travelingMerchantData[merchantName]
	if not merchant or type(merchant.ShopData) ~= "table" then
		return {}
	end
	local items = {}
	for itemName, itemData in pairs(merchant.ShopData) do
		table.insert(items, itemName.." | "..itemData.ItemType)
	end
	table.sort(items)
	return items
end

local travelingMerchants = getTravelingMerchantKeys()

local merchantSelections = {}
local merchantDropdowns = {}

--dropdown creation loop
for _, merchantName in ipairs(travelingMerchants) do
	merchantSelections[merchantName] = {}
	local dropdown = Shops:CreateDropdown({
		Name = merchantName,
		Options = getMerchantShopItems(merchantName),
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "dropdown_" .. merchantName:gsub(" ", ""),
		Callback = function(options)
			merchantSelections[merchantName] = options
		end,
	})
	merchantDropdowns[merchantName] = dropdown
end

local itemTypes_travelingMerchantShopItems = {
	"Gear",
	"Seed",
	"Crate",
	"Egg",
	"Pet",
	"Cosmetic",
	"Seed Pack",
	"Fence"
}

for _, itemType in ipairs(itemTypes_travelingMerchantShopItems) do
	Shops:CreateButton({
		Name = "Select All " .. itemType,
		Callback = function()
			for merchantName, dropdown in pairs(merchantDropdowns) do
				local options = dropdown.Options or {}
				local current = merchantSelections[merchantName] or {}
				local selectedMap = {}

				for _, v in ipairs(current) do
					selectedMap[v] = true
				end

				for _, option in ipairs(options) do
					if string.match(option, "%|%s*" .. itemType .. "$") then
						if not selectedMap[option] then
							table.insert(current, option)
							selectedMap[option] = true
						end
					end
				end

				dropdown:Set(current)
				merchantSelections[merchantName] = current
			end
		end,
	})
end


Shops:CreateButton({
	Name = "Clear All Selections",
	Callback = function()
		for merchantName, dropdown in pairs(merchantDropdowns) do
			dropdown:Set({})
			merchantSelections[merchantName] = {}
		end
	end,
})


local autoBuyTravelingMerchantEnabled = false
local autoBuyTravelingMerchantThread = nil
Shops:CreateToggle({
	Name = "Auto Buy Traveling Merchant",
	CurrentValue = false,
	Flag = "autoBuyTravelingMerchant",
	Callback = function(Value)
		autoBuyTravelingMerchantEnabled = Value

		if autoBuyTravelingMerchantEnabled then
			if autoBuyTravelingMerchantThread then
				return
			end
			-- beastHubNotify("Auto Buy Traveling Merchant running", "", 3)
            local function getTravelingMerchantStocksData()
                local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                local logs = dataService:GetData()
                return logs.TravelingMerchantShopStock
            end
            local travelingMerchantStocksData = getTravelingMerchantStocksData()

			autoBuyTravelingMerchantThread = task.spawn(function()
				travelingMerchantData = getTravelingMerchantsData()
                while autoBuyTravelingMerchantEnabled do
                    local stockData = getTravelingMerchantStocksData()
                    local activeMerchant = stockData.MerchantType
                    local selectedItems = merchantSelections[activeMerchant]

                    if selectedItems and travelingMerchantData[activeMerchant] then
                        local shopData = travelingMerchantData[activeMerchant].ShopData
                        local stocks = stockData.Stocks

                        for _, displayName in ipairs(selectedItems) do
                            local itemName = string.match(displayName, "^(.-)%s|")
                            if itemName then
                                local stockInfo = stocks[itemName]
                                local itemData = shopData[itemName]

                                if stockInfo and itemData and stockInfo.Stock > 0 then
                                    for i = 1, stockInfo.Stock do
                                        local args = {
                                            [1] = itemName
                                        }
                                        game:GetService("ReplicatedStorage").GameEvents.BuyTravelingMerchantShopStock:FireServer(unpack(args))
                                        task.wait(0.15)
                                    end
                                end
                            end
                        end
                    end

                    task.wait(2)
                end

				autoBuyTravelingMerchantThread = nil
			end)
		else
			autoBuyTravelingMerchantEnabled = false
			if autoBuyTravelingMerchantThread then
				autoBuyTravelingMerchantThread = nil
			end
		end
	end,
})



Shops:CreateDivider()

-- PetEggs>Eggs
PetEggs:CreateSection("Auto Place eggs")
--Auto place eggs
--get egg list first based on registry
local function getEggNames()
    local eggNames = {}
    local success, err = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local PetRegistry = require(ReplicatedStorage.Data.PetRegistry)

        -- Ensure PetEggs exists
        if not PetRegistry.PetEggs then
            warn("PetRegistry.PetEggs not found!")
            return
        end

        -- Collect egg names
        for eggName, eggData in pairs(PetRegistry.PetEggs) do
            if eggName ~= "Fake Egg" then
                table.insert(eggNames, eggName)
            end
        end
    end)

    if not success then
        warn("getEggNames failed:", err)
    end
    return eggNames
end
local allEggNames = getEggNames()
table.sort(allEggNames)


--get current egg count in garden
local function getFarmEggCount()
    local petEggsList = myFunctions.getMyFarmPetEggs()
    return #petEggsList -- simply return the number of eggs
end


--dropdown for egg list
local selectedEggsForAutoPlace = {}
local Dropdown_eggToPlace = PetEggs:CreateDropdown({
    Name = "Select Egg to Auto Place",
    Options = allEggNames,
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "eggToAutoPlace", 
    Callback = function(Options)
        --if not Options or not Options[1] then return end -- nothing selected yet
        selectedEggsForAutoPlace = Options
    end,
})

--add search egg here
--search egg
local searchDebounce_egg = nil
PetEggs:CreateInput({
    Name = "Search",
    PlaceholderText = "Search Egg...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if searchDebounce_egg then
            task.cancel(searchDebounce_egg)
        end

        searchDebounce_egg = task.delay(0.5, function()
            local results = {}
            local query = string.lower(Text)

            if query == "" then
                results = allEggNames
            else
                for _, petName in ipairs(allEggNames) do
                    if string.find(string.lower(petName), query, 1, true) then
                        table.insert(results, petName)
                    end
                end
            end

            Dropdown_eggToPlace:Refresh(results)
            Dropdown_eggToPlace:Set(selectedEggsForAutoPlace) --set to current selected

        end)
    end,
})

--input egg count to place
local eggsToPlaceInput = 13
local Input_numberOfEggsToPlace = PetEggs:CreateInput({
    Name = "Number of eggs to place",
    CurrentValue = "13",
    PlaceholderText = "# of eggs",
    RemoveTextAfterFocusLost = false,
    Flag = "numberOfEggsToPlace",
    Callback = function(Text)
        eggsToPlaceInput = tonumber(Text) or 0
    end,
})

local Input_delayOfEggsToPlace = PetEggs:CreateInput({
    Name = "Delay to place eggs (default 0.5)",
    CurrentValue = "0.5",
    PlaceholderText = "seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "delayOfEggsToPlace",
    Callback = function(Text)
    end,
})

local Input_delayToHatch = PetEggs:CreateInput({
    Name = "Delay to hatch eggs (default 2)",
    CurrentValue = "2",
    PlaceholderText = "seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToHatch",
    Callback = function(Text)
    end,
})

local position_placeEggs = PetEggs:CreateDropdown({
    Name = "Position",
    Options = {"Left - spread out","Right - spread out", "Left - stacked", "Right - stacked", "Random - stacked"},
    CurrentOption = {"Left - spread out"},
    MultipleOptions = false,
    Flag = "positionPlaceEggs", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Options)
        positionForPlaceEggs = Options[1]
    end,
})


-- Listen for Notification event once for too close eggs
local webhookURL
local tooCloseFlag = false
local petAlreadyInMachineFlag = false
local koiRefundCount = 0
local sealsRefundCount = 0
local hatchSpdString = "(1st hatch not counted)"
local fullInventoryAlert = 0
local mutationMachineNotif = ""
local webhookAutoMutation = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Notification = ReplicatedStorage.GameEvents.Notification
Notification.OnClientEvent:Connect(function(message)
    if typeof(message) == "string" and message:lower():find("too close to another egg") then
        tooCloseFlag = true
        --print("[DEBUG] Too close notification received, skipping increment")
    end

    if typeof(message) == "string" and message:lower():find("a pet is already in the machine!") then
        petAlreadyInMachineFlag = true
    end

    if typeof(message) == "string" and message:lower():find("lucky hatch") then --koi
        koiRefundCount = koiRefundCount + 1
    end

    if typeof(message) == "string" and message:lower():find("lucky pet") then --seals
        sealsRefundCount = sealsRefundCount + 1
    end

    if typeof(message) == "string" and message:lower():find("you cannot open this pet") then --max inventory
        fullInventoryAlert = fullInventoryAlert + 1
    end

    local mutationText = nil
    if typeof(message) == "string" then
        mutationText = message
    elseif typeof(message) == "table" and typeof(message.Text) == "string" then
        mutationText = message.Text
    end
    if mutationText and mutationText:lower():find("mutated into") then
        -- print("found mutated into")
        -- print(mutationText)
        mutationMachineNotif = mutationText
        if webhookAutoMutation == true then
            local cleanText = mutationText
            local extracted = cleanText:match(".*>([^<]-)</font>%s*$")
            if extracted then
                cleanText = extracted
            end
            -- print(cleanText)
            -- print("webhookAutoMutation true")
            local webhookMsg = "[BeastHub] "..username.." | Auto Mutation Machine result: "..cleanText
            -- print(webhookMsg)
            sendDiscordWebhook(webhookURL, webhookMsg)
            -- print("done sending webhook")
        else
            -- print("webhookAutoMutation false")
        end
    end

end)



--toggle auto place eggs
local autoPlaceEggsThread -- store the task
local autoPlaceEggsEnabled = false
local isDonePlacingEgg = false
local Toggle_autoPlaceEggs = PetEggs:CreateToggle({
    Name = "Auto place eggs",
    CurrentValue = false,
    Flag = "autoPlaceEggs",
    Callback = function(Value)
        -- Stop old loop if already running
        if autoPlaceEggsThread then
            autoPlaceEggsEnabled = false
            autoPlaceEggsThread = nil -- we just stop the thread by flipping the boolean
        end

        --
        local start = tick()
        local maxWait = 10
        while not getgenv().ConfigLoaded do
            local elapsed = tick() - start
            if elapsed >= maxWait then
                beastHubNotify("Auto place egg UI failed to load, please rejoin", "", 5)
                break
            end
            task.wait(0.5)
        end
        task.wait(3)
        --=======================================

        if Value then
            beastHubNotify("Auto place eggs: ON", "Max Eggs to place: "..tostring(eggsToPlaceInput), 4)
            autoPlaceEggsEnabled = true
            local autoPlaceEggLocations = getFarmEggLocations() --off setting for dynamic farm location
            autoPlaceEggsThread = task.spawn(function()
                while autoPlaceEggsEnabled do
                    local maxFarmEggs = eggsToPlaceInput
                    local currentEggsInFarm = getFarmEggCount()
                    --print("maxFarmEggs:", maxFarmEggs)
                    --print("currentEggsInFarm:", currentEggsInFarm)

                    if currentEggsInFarm < maxFarmEggs then
                        for _, location in ipairs(autoPlaceEggLocations) do
                            currentEggsInFarm = getFarmEggCount()
                            if currentEggsInFarm >= maxFarmEggs then
                                break
                            end

                            if Dropdown_eggToPlace.CurrentOption[1] then
                                equipItemByNameV2(Dropdown_eggToPlace.CurrentOption[1])
                                task.wait()
                            end

                            local args = { "CreateEgg", location }
                            game:GetService("ReplicatedStorage").GameEvents.PetEggService:FireServer(unpack(args))
                            --add algo here to trap 'too close to another egg and dont increment'
                            -- task.wait(0.5)
                            task.wait(tonumber(Input_delayOfEggsToPlace.CurrentValue) or 0.5)
                            if tooCloseFlag then
                                tooCloseFlag = false -- reset flag for next iteration
                                -- skip increment
                            else
                                currentEggsInFarm = currentEggsInFarm + 1
                            end
                            
                        end
                    else
                        isDonePlacingEgg = true
                    end
                    task.wait(1.5)
                end
            end)
        else
            autoPlaceEggsEnabled = false
            autoPlaceEggsThread = nil
            -- beastHubNotify("Auto place eggs: OFF", "", 2)
        end
    end,
})

--Auto hatch --removed hatch all button to avoid accidents
PetEggs:CreateButton({
    Name = "Click to HATCH ALL",
    Callback = function()
        print("[BeastHub] Hatching eggs...")
        
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local PetEggService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")

        -- Get all PetEgg models in your farm
        local petEggs = myFunctions.getMyFarmPetEggs()
        if #petEggs == 0 then
            --print("[BeastHub] No PetEggs found in your farm!")
            return
        end

        -- Loop through all eggs and fire the hatch event
        for _, egg in ipairs(petEggs) do
            local args = {
                [1] = "HatchPet",
                [2] = egg
            }
            PetEggService:FireServer(unpack(args))
            task.wait(0.05)
            -- task.wait(tonumber(Input_delayToHatch.CurrentValue) or 0.05)
            --print("[BeastHub] Fired hatch for:", egg.Name)
        end
    end,
})
PetEggs:CreateDivider()

--PetEggs>Auto Sell Pets
    --function to auto sell
local function autoSellPets(targetPets, weightTargetBelow, onComplete)
    -- USAGE:
    -- autoSellPets({"Bunny", "Dog"}, 3, function()
    --     print("Selling complete, now do next step!")
    -- end)

    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local SellPet_RE = game:GetService("ReplicatedStorage").GameEvents.SellPet_RE
	player.Character.Humanoid:UnequipTools() --unequip last pet held from hatch

    for _, item in ipairs(backpack:GetChildren()) do
        local b = item:GetAttribute("b") -- pet type
        local d = item:GetAttribute("d") -- favorite

        if b == "l" and d == false then
            local petName = item.Name:match("^(.-)%s*%[") or item.Name
            petName = petName:match("^%s*(.-)%s*$") -- trim spaces

            local weightStr = item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]")
            local weight = weightStr and tonumber(weightStr)

            local isTarget = false
            for _, name in ipairs(targetPets) do
                if petName == name then
                    isTarget = true
                    break
                end
            end

            if isTarget and weight and weight < weightTargetBelow then
                player.Character.Humanoid:UnequipTools()
                player.Character.Humanoid:EquipTool(item)
                task.wait(0.2) -- ensure pet equips before selling
                SellPet_RE:FireServer(item.Name)
                print("Sold:", item.Name)
                task.wait(0.3)
            end
        end
    end

    -- Call the callback AFTER finishing all pets
    if typeof(onComplete) == "function" then
        onComplete()
    end
end


--auto sell pets UI
local selectedPets --for UI paragraph
local selectedPetsForAutoSell = {} --container for dropdown
local sealsLoady

local Paragraph_selectedPets = PetEggs:CreateParagraph({Title = "Auto Sell Pets:", Content = "No pets selected."})
local Dropdown_sealsLoadoutNum = PetEggs:CreateDropdown({
    Name = "Select 'Seals' loadout",
    -- Options = {"None", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10", "1", "2", "3", "4", "5", "6"},
    Options = getgenv().preloadedCustomLoadoutNames or {},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "sealsLoadoutNum", 
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        sealsLoady = Options[1]
    end,
})
local suggestedAutoSellList = {
    "Ostrich", "Peacock", "Capybara", "Scarlet Macaw",
    "Bat", "Bone Dog", "Spider", "Black Cat",
    "Oxpecker", "Zebra", "Giraffe", "Rhino",
    "Tree Frog", "Hummingbird", "Iguana", "Chimpanzee",
    "Robin", "Badger", "Grizzly Bear",
    "Ladybug", "Pixie", "Imp", "Glimmering Sprite",
    "Dairy Cow", "Jackalope", "Seedling",
    "Orange Tabby", "Spotted Deer", "Pig", "Rooster", "Monkey",
    "Black Bunny", "Chicken", "Cat", "Deer",
    "Cow", "Silver Monkey", "Sea Otter", "Turtle",
    "Bagel Bunny", "Pancake Mole", "Sushi Bear", "Spaghetti Sloth",
    "Shiba Inu", "Nihonzaru", "Tanuki", "Tanchozuru", "Kappa",
    "Parasaurolophus", "Iguanodon", "Ankylosaurus",
    "Raptor", "Triceratops", "Stegosaurus", "Pterodactyl", 
    "Flamingo", "Toucan", "Sea Turtle", "Orangutan",
    "Wasp", "Tarantula Hawk", "Moth",
    "Bee", "Honey Bee", "Petal Bee",
    "Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl",
    "Caterpillar", "Snail", "Giant Ant", "Praying Mantis",
    "Topaz Snail", "Amethyst Beetle", "Emerald Snake", "Sapphire Macaw",
    "Turtle Dove", "Reindeer", "Nutcracker",
    "Partridge", "Santa Bear", "Moose", "Frost Squirrel",
    "New Year's Bird", "Firework Sprite", "Celebration Puppy", "New Year's Chimp", "Star Wolf",
    "Unicycle Monkey", "Performer Seal", "Bear on Bike", "Show Pony",
    "Dog", "Golden Lab", "Bunny",
    "Starfish", "Seagull", "Crab",
    "Black Bird", "Cuckoo", "Brown Owl", "Gold Finch",
    "Grey Mouse", "Brown Mouse", "Red Giant Ant", "Squirrel"
}
local selectedPetsForAutoSellLookup = {}
local Dropdown_petList = PetEggs:CreateDropdown({
    Name = "Select Pets for Auto Sell",
    Options = petListNamesOnlyAndSorted,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "autoSellPetsSelection", 
    Callback = function(Options)
        
        selectedPetsForAutoSell = Options
        
        local names = table.concat(Options, ", ")
        if names == "" then
            names = "No pets selected."
        end

        Paragraph_selectedPets:Set({
            Title = "Auto Sell Pets:",
            Content = names
        })    

        --for new setup
        table.clear(selectedPetsForAutoSellLookup)
        for _, name in ipairs(Options) do
            selectedPetsForAutoSellLookup[name] = true
        end
    end,
})

--search pets
local searchDebounce = nil
PetEggs:CreateInput({
    Name = "Search",
    PlaceholderText = "Search Pet...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if searchDebounce then
            task.cancel(searchDebounce)
        end

        searchDebounce = task.delay(0.5, function()
            local results = {}
            local query = string.lower(Text)

            if query == "" then
                results = petListNamesOnlyAndSorted
            else
                for _, petName in ipairs(petListNamesOnlyAndSorted) do
                    if string.find(string.lower(petName), query, 1, true) then
                        table.insert(results, petName)
                    end
                end
            end
            Dropdown_petList:Refresh(results)
            Dropdown_petList:Set(selectedPetsForAutoSell)
        end)
    end,
})

local Input_delayToSell = PetEggs:CreateInput({
    Name = "Delay to Sell (default 2)",
    CurrentValue = "2",
    PlaceholderText = "seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "delayToSell",
    Callback = function(Text)
    end,
})

PetEggs:CreateButton({
    Name = "Load Suggested List",
    Callback = function()
        Dropdown_petList:Set(suggestedAutoSellList) --Clear selection properly
        selectedPetsForAutoSell = suggestedAutoSellList
    end,
})

PetEggs:CreateButton({
    Name = "Clear selection",
    Callback = function()
        Dropdown_petList:Set({}) --Clear selection properly
        selectedPetsForAutoSell = {}
    end,
})

local sellAllBelowKGmode
PetEggs:CreateDropdown({
    Name = "Sell All Below KG Mode",
    Options = {"Current KG", "Base KG"},
    CurrentOption = {"Current KG"},
    MultipleOptions = false,
    Flag = "sellAllBelowKGmode", 
    Callback = function(Options)
        sellAllBelowKGmode = (Options[1])
    end,
})

local sellBelow
local input_sellBelow = PetEggs:CreateInput({
    Name = "Sell Below (KG or Base KG)",
    CurrentValue = "3",
    PlaceholderText = "Input Placeholder",
    RemoveTextAfterFocusLost = false,
    Flag = "sellBelowKG",
    Callback = function(Text)
        local num = tonumber(Text)
        if num then
            sellBelow = num
        else
            sellBelow = 3 --safety measure
        end
    end,
})
-- local Dropdown_sellBelowKG = PetEggs:CreateDropdown({
--     Name = "Auto Sell Below (KG or Base KG)",
--     Options = {"0","0.5","0.6","0.7","0.8","0.9","1.0","1.1","1.2","1.3","1.4","1.5","1.6","1.7","1.8","1.9","2.0","2.1","2.2","2.3","2.4","2.5","2.6","2.7","2.8","2.9","3.0"},
--     CurrentOption = {"3"},
--     MultipleOptions = false,
--     Flag = "sellBelowKG", 
--     Callback = function(Options)
--         --if not Options or not Options[1] then return end
--         sellBelow = tonumber(Options[1])
--     end,
-- })

local function autoSellPets3(targetPets, weightTargetBelow, onComplete)
    local function getPlayerData()
        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
        local logs = dataService:GetData()
        return logs
    end
    local playerData = getPlayerData()
    local petInventory = playerData.PetsData.PetInventory.Data
    local autoSellUuids = {}

    mainModule.isSafeToPickPlace = false
    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
	player.Character.Humanoid:UnequipTools() --unequip last pet held from hatch
    beastHubNotify("Sell delay: "..(tostring(Input_delayToSell.CurrentValue) or ""),"",3)
    task.wait(tonumber(Input_delayToSell.CurrentValue) or 2)

    --new
    for id, data in pairs(petInventory) do
        local petName = data.PetType
        local isFavorite = data.PetData.IsFavorite or ""
        if isFavorite ~= true then
            local uid = id
            local weight = tonumber(string.format("%.2f", data.PetData.BaseWeight * 1.1)) or 0
            if weight == 0 then 
                warn("Weight error for: "..(tostring(id) or "nil id"))
            end 

            local isTarget = false
            for _, name in ipairs(targetPets) do
                if petName == name then
                    isTarget = true
                    break
                end
            end

            if isTarget and weight and weight < weightTargetBelow then
                table.insert(autoSellUuids, uid)
            end
        end
    end



    local autoSellLookup = {}
    for _, id in ipairs(autoSellUuids) do
        autoSellLookup[id] = true
    end

    --loop backpack here to sell with ids in autoSellUuids
    for _, item in ipairs(backpack:GetChildren()) do
        local b = item:GetAttribute("b") -- pet type
        local d = item:GetAttribute("d") -- favorite
        if b == "l" and d == false then 
            local curBagId = item:GetAttribute("PET_UUID")
            local weightStr = item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]")
            local weight = weightStr and tonumber(weightStr)
            if autoSellLookup[curBagId] and weight and weight < weightTargetBelow then
                game:GetService("ReplicatedStorage").GameEvents.SellPetShopSelected:FireServer(item)
                task.wait(0.05)
            end
        end
    end

    -- Call the callback AFTER finishing all pets
    if typeof(onComplete) == "function" then
        onComplete()
    end
end

local function autoSellPets2(targetPets, weightTargetBelow, onComplete)
    mainModule.isSafeToPickPlace = false
    local player = game.Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
	player.Character.Humanoid:UnequipTools() --unequip last pet held from hatch
    beastHubNotify("Sell delay: "..tostring(Input_delayToSell.CurrentValue) or "","",3)
    task.wait(tonumber(Input_delayToSell.CurrentValue) or 2)
    
    for _, item in ipairs(backpack:GetChildren()) do
        local b = item:GetAttribute("b") -- pet type
        local d = item:GetAttribute("d") -- favorite

        if b == "l" and d == false then
            local petName = item.Name:match("^(.-)%s*%[") or item.Name
            -- print(item.Name)
            petName = petName:match("^%s*(.-)%s*$") -- trim spaces

            local weightStr = item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]")
            local weight = weightStr and tonumber(weightStr)

            local isTarget = false
            for _, name in ipairs(targetPets) do
                if petName == name then
                    isTarget = true
                    break
                end
            end

            if isTarget and weight and weight < weightTargetBelow then
                --fire the event here
				local success = pcall(function()
                    local args = {
                        [1] = item;
                    }
					-- game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5):WaitForChild("SellPet_RE", 5):FireServer(unpack(args))
                    game:GetService("ReplicatedStorage").GameEvents.SellPetShopSelected:FireServer(unpack(args))
                end)
                task.wait(0.05)
                -- task.wait(tonumber(Input_delayToSell.CurrentValue)  or 0.05)
            end
        end
    end

    -- Call the callback AFTER finishing all pets
    if typeof(onComplete) == "function" then
        onComplete()
    end
end

-- local function isGoodToSellAll()
--     beastHubNotify("Validating SELL ALL safety..", "Please wait", 5)
--     local player = game.Players.LocalPlayer
-- 	player.Character.Humanoid:UnequipTools() --unequip last pet held from hatch

-- 	local rs = game:GetService("ReplicatedStorage")
-- 	local favUnfavEvent = rs.GameEvents.Favorite_Item
-- 	local backpack = player:WaitForChild("Backpack")
-- 	local listToCheckInBag = {}
--     local lastNotifyTime = tick()

-- 	local function getPlayerData()
-- 		local ok, dataService = pcall(function()
-- 			return require(game:GetService("ReplicatedStorage").Modules.DataService)
-- 		end)
-- 		if not ok or not dataService then
-- 			return nil
-- 		end
-- 		local ok2, logs = pcall(function()
-- 			return dataService:GetData()
-- 		end)
-- 		if not ok2 then
-- 			return nil
-- 		end
-- 		return logs
-- 	end
-- 	local playerData = getPlayerData()
-- 	if not playerData or not playerData.PetsData or not playerData.PetsData.PetInventory or not playerData.PetsData.PetInventory.Data then
-- 		return false
-- 	end
-- 	local petInventory = playerData.PetsData.PetInventory.Data
-- 	for petId, data in pairs(petInventory) do
-- 		if data and data.PetType and data.PetData then
-- 			if not data.PetData.IsFavorite then
-- 				listToCheckInBag[petId] = true
-- 			end
-- 		end
-- 	end
-- 	for index, item in ipairs(backpack:GetChildren()) do
-- 		local petUuid = item:GetAttribute("PET_UUID")
--         local d = item:GetAttribute("d") --favorited or not
-- 		if petUuid and listToCheckInBag[petUuid] then
-- 			local weight = tonumber(item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]"))
-- 			local petNameInBag = item.Name:match("^(.-)%s*%[")
--             if petNameInBag and string.find(petNameInBag, "Peppermint", 1, true) then
--                 petNameInBag = petNameInBag:gsub("Peppermint", ""):gsub("^%s+", ""):gsub("%s+$", "")
--             end
--             if petNameInBag and string.find(petNameInBag, "SpiritSparkle", 1, true) then
--                 petNameInBag = petNameInBag:gsub("SpiritSparkle", ""):gsub("^%s+", ""):gsub("%s+$", "")
--             end
-- 			if d == false and not selectedPetsForAutoSellLookup[petNameInBag] then
--                 -- print("inside if, fav event")
-- 				beastHubNotify("Favorited: "..petNameInBag, "Size: "..weight, 5)
-- 				favUnfavEvent:FireServer(item)
--                 task.wait(2)
-- 			elseif d == false and weight > sellBelow then
--                 -- print("inside else, fav event")
-- 				beastHubNotify("Favorited: "..petNameInBag, "Size: "..weight, 5)
-- 				favUnfavEvent:FireServer(item)
--                 task.wait(2)
--             else
--                 -- print("IN ELSE")
-- 			end
-- 		end
--         -- notify every 2 seconds
--         if tick() - lastNotifyTime >= 2 then
--             beastHubNotify("Processing items... ("..index.."/"..#backpack:GetChildren()..")", "", 2)
--             lastNotifyTime = tick()
--         end
-- 		task.wait()
-- 	end
-- 	return true
-- end

local function isGoodToSellAllv2()
    beastHubNotify("Validating SELL ALL safety..", "Please wait", 5)
    local player = game.Players.LocalPlayer
	player.Character.Humanoid:UnequipTools() --unequip last pet held from hatch

	local rs = game:GetService("ReplicatedStorage")
	local favUnfavEvent = rs.GameEvents.Favorite_Item
	local backpack = player:WaitForChild("Backpack")
	local listToCheckInBag = {}
    local baseKGlist = {}
    local lastNotifyTime = tick()
    sellBelow = tonumber(input_sellBelow.CurrentValue)

	local function getPlayerData()
		local ok, dataService = pcall(function()
			return require(game:GetService("ReplicatedStorage").Modules.DataService)
		end)
		if not ok or not dataService then
			return nil
		end
		local ok2, logs = pcall(function()
			return dataService:GetData()
		end)
		if not ok2 then
			return nil
		end
		return logs
	end
	local playerData = getPlayerData()
	if not playerData or not playerData.PetsData or not playerData.PetsData.PetInventory or not playerData.PetsData.PetInventory.Data then
		return false
	end
	local petInventory = playerData.PetsData.PetInventory.Data
	for petId, data in pairs(petInventory) do
		if data and data.PetType and data.PetData then
			if not data.PetData.IsFavorite then
                local baseKG = data.PetData.BaseWeight
				listToCheckInBag[petId] = true
                baseKGlist[petId] = baseKG
			end
		end
	end
	for index, item in ipairs(backpack:GetChildren()) do
		local petUuid = item:GetAttribute("PET_UUID")
        local d = item:GetAttribute("d") --favorited or not
		if petUuid and listToCheckInBag[petUuid] then
			local weight = tonumber(item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]"))
            if sellAllBelowKGmode == "Base KG" then
                weight = baseKGlist[petUuid] * 1.1
            end

			local petNameInBag = item.Name:match("^(.-)%s*%[")
            if petNameInBag and string.find(petNameInBag, "Peppermint", 1, true) then
                petNameInBag = petNameInBag:gsub("Peppermint", ""):gsub("^%s+", ""):gsub("%s+$", "")
            end
            if petNameInBag and string.find(petNameInBag, "SpiritSparkle", 1, true) then
                petNameInBag = petNameInBag:gsub("SpiritSparkle", ""):gsub("^%s+", ""):gsub("%s+$", "")
            end
			if d == false and not selectedPetsForAutoSellLookup[petNameInBag] then
                -- print("inside if, fav event")
				beastHubNotify("Favorited: "..petNameInBag, "Size: "..weight, 5)
				favUnfavEvent:FireServer(item)
                task.wait(2)
			elseif d == false and weight > sellBelow then
                -- print("inside else, fav event")
				beastHubNotify("Favorited: "..petNameInBag, "Size: "..weight, 5)
				favUnfavEvent:FireServer(item)
                task.wait(2)
            else
                -- print("IN ELSE")
			end
		end
        -- notify every 2 seconds
        if tick() - lastNotifyTime >= 2 then
            beastHubNotify("Processing items... ("..index.."/"..#backpack:GetChildren()..")", "", 2)
            lastNotifyTime = tick()
        end
		task.wait()
	end
	return true
end

-- PetEggs:CreateLabel("Turn on SELL ALL toggle below to activate 50% seal cap. Reason: Seal bug", "alert-triangle") 
PetEggs:CreateParagraph({Title = "Sell All Method", Content = "Turn on SELL ALL toggle below to activate 50% seal cap. Reason: Seal bug"})
local toggle_useSellAllMethod = PetEggs:CreateToggle({
    Name = "Use SELL ALL (WARNING, FAVORITE YOUR PETS!)",
    CurrentValue = false,
    Flag = "useSellAllMethod", 
    Callback = function(Value)
        
    end,
})

--input number of hatch cycles to sell
local Input_HatchCyclesToSell = PetEggs:CreateInput({
    Name = "Hatch/Sell cycles (0 = sell when full) ",
    CurrentValue = "0",
    PlaceholderText = "#",
    RemoveTextAfterFocusLost = false,
    Flag = "hatchCyclesBeforeSell",
    Callback = function(Text)
    end,
})

PetEggs:CreateButton({
    Name = "Click to SELL (Manual 1 by 1)",
    Callback = function()
        --print(tostring(sellBelow))
        if sealsLoady and sealsLoady ~= "None" then
            -- print("Switching to seals loadout first")
            mainModule.isSafeToPickPlace = false
            task.wait(2)
            myFunctions.switchToLoadout(sealsLoady, getFarmSpawnCFrame, beastHubNotify)
			beastHubNotify("Waiting for Seals to load", "Auto Sell", "5")
            task.wait(6)
        end

        --get data for hatching security feature
        local function getPlayerData()
            local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
            local logs = dataService:GetData()
            return logs
        end

        local function equippedPets()
            local playerData = getPlayerData()
            if not playerData.PetsData then
                warn("PetsData missing")
                return nil
            end

            local tempStorage = playerData.PetsData.EquippedPets or nil
            if not tempStorage or type(tempStorage) ~= "table" then
                warn("EquippedPets missing or invalid")
                return nil
            end

            local petIdsList = {}
            for _, id in ipairs(tempStorage) do
                table.insert(petIdsList, id)
            end

            return petIdsList
        end

        local function getPetNameUsingId(uid)
            local playerData = getPlayerData()
            if playerData.PetsData.PetInventory.Data then
                local data = playerData.PetsData.PetInventory.Data
                for id,petData in pairs(data) do
                    if id == uid then
                        return petData.PetType
                    end
                end
            else
                warn("PetInventory Data not found!")
            end
        end

        local function isGoodToSell()
            local start = tick()
            local squidFound = false
            local sealFound = false
            while tick() - start < 5 do
                local equipped = equippedPets()
                if not petLoadoutValidator then
                    return true
                end

                if #equipped >= 8 then
                    local allGood = true
                    for _, id in ipairs(equipped) do
                        local petName = getPetNameUsingId(id)
                        if petName == "Ruby Squid" then
                            squidFound = true
                        end
                        if petName == "Seal" then
                            sealFound = true
                        end
                        if (petName ~= "Seal" and petName ~= "Ruby Squid") or (petName ~= "Ruby Squid" and squidFound) then
                            allGood = true
                            break
                        end
                    end
                    if allGood and sealFound then
                        return true
                    end
                end

                task.wait(0.5)
            end
            return false
        end

        
        local equippedSeals = equippedPets()
        task.wait()
        if equippedSeals and isGoodToSell() then
            autoSellPets3(selectedPetsForAutoSell, sellBelow)
            mainModule.isSafeToPickPlace = true
            -- beastHubNotify("Auto Sell Done", "Successful", "2")
        else
            beastHubNotify("Invalid Seals loadout!", "", 3)
        end

        
    end,
})
PetEggs:CreateDivider()

--Pet/Eggs>SMART HATCHING
PetEggs:CreateSection("SMART Auto Hatching")
-- local Paragraph = Pets:CreateParagraph({Title = "INSTRUCTIONS:", Content = "1.) Setup your Auto place Eggs above and turn on toggle for auto place eggs. 2.) Setup your selected pets for Auto Sell above. 3.) Selected desginated loadouts below. 4.) Turn on toggle for Full Auto Hatching"})
PetEggs:CreateParagraph({
    Title = "INSTRUCTIONS:",
    Content = "1.) Setup your Auto place Eggs above and turn on toggle for auto place eggs.\n2.) Setup your selected pets for Auto Sell above.\n3.) Selected designated loadouts below.\n4.) Turn on BeastHub Egg ESP"
})
local koiLoady
-- local brontoLoady
local incubatingLoady
local webhookRares
local webhookHuge
-- local petvalidatorWebhook
local sessionHatchCount = 0
local incubating_loadout = {unpack(getgenv().preloadedCustomLoadoutNames)}
table.insert(incubating_loadout, 1, "9 pets tech")

local dropdown_incubating_loadout = PetEggs:CreateDropdown({
    Name = "Incubating/Eagles Loadout",
    Options = incubating_loadout or {},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "incubatingLoadoutNum", 
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        incubatingLoady = Options[1]
    end,
})
local dropdown_koi_loadout = PetEggs:CreateDropdown({
    Name = "Koi Loadout",
    -- Options = {"None", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10", "1", "2", "3", "4", "5", "6"},
    Options = getgenv().preloadedCustomLoadoutNames or {},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "koiLoadoutNum", 
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        koiLoady = Options[1]
    end,
})

PetEggs:CreateParagraph({Title = "How to use Koi Enhance:", Content = "Go to Plants tab and turn on Auto Collect Fruits, and Stop Collect when full"})
local toggle_koiEnhance = PetEggs:CreateToggle({
    Name = "Koi Enhance (auto sell all fruits when hatching)",
    CurrentValue = false,
    Flag = "KoiEnhanceWithFruits", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
    Callback = function(Value)
    -- The function that takes place when the toggle is pressed
    -- The variable (Value) is a boolean on whether the toggle is true or false
    end,
})

-- PetEggs:CreateDropdown({
--     Name = "Bronto Loadout",
--     Options = {"None", "1", "2", "3"},
--     CurrentOption = {},
--     MultipleOptions = false,
--     Flag = "brontoLoadoutNum", 
--     Callback = function(Options)
--         --if not Options or not Options[1] then return end
--         brontoLoady = tonumber(Options[1])
--     end,
-- })

--ANTI HATCH
local Paragraph_selectedAntiHatchPets = PetEggs:CreateParagraph({Title = "Anti Hatch Pets (HUGE are all default anti hatched):", Content = "No pets selected."})
local antiHatchList = {}
local Dropdown_antiHatch = PetEggs:CreateDropdown({
    Name = "Anti Hatch Pets:",
    Options = petListNamesOnlyAndSorted,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "antiHatchPetsSelection",
    Callback = function(Options)

        -- Store EXACTLY what Rayfield gives back
        antiHatchList = {}

        for _, name in ipairs(Options) do
            table.insert(antiHatchList, name)
        end

        -- Display list
        local names = table.concat(antiHatchList, ", ")
        if names == "" then
            names = "No pets selected."
        end

        Paragraph_selectedAntiHatchPets:Set({
            Title = "Anti Hatch Pets (HUGE by default are skipped):",
            Content = names
        })
    end,
})

--add search anti hatch here
--search pets
local searchDebounce_antiHatch = nil
PetEggs:CreateInput({
    Name = "Search",
    PlaceholderText = "Search Pet...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if searchDebounce_antiHatch then
            task.cancel(searchDebounce_antiHatch)
        end

        searchDebounce_antiHatch = task.delay(0.5, function()
            local results = {}
            local query = string.lower(Text)

            if query == "" then
                results = petListNamesOnlyAndSorted
            else
                for _, petName in ipairs(petListNamesOnlyAndSorted) do
                    if string.find(string.lower(petName), query, 1, true) then
                        table.insert(results, petName)
                    end
                end
            end

            Dropdown_antiHatch:Refresh(results)

            -- Force redraw by re-setting selection (even empty table works)
            Dropdown_antiHatch:Set(antiHatchList)

            -- Extra fallback: if no match, clear UI text
            if #results == 0 then
                Paragraph_selectedAntiHatchPets:Set({
                    Title = "Anti Hatch Pets (HUGE by default are skipped):",
                    Content = "No pets selected."
                })
            end
        end)
    end,
})

PetEggs:CreateButton({
    Name = "Clear Anti Hatch",
    Callback = function()
        -- UI clear
        Dropdown_antiHatch:Set({})
        -- Internal list clear
        antiHatchList = {}
        -- Reset paragraph
        Paragraph_selectedAntiHatchPets:Set({
            Title = "Anti Hatch Pets (HUGE by default are skipped):",
            Content = "No pets selected."
        })
    end,
})


local skipHatchRareAboveKG = "0" --updated logic anti hatch
PetEggs:CreateDropdown({
    Name = "Anti Hatch Above KG:",
    Options = {"0", "1", "1.5", "1.6", "1.7", "1.8", "1.9","2", "2.1", "2.2", "2.3", "2.4", "2.5"},
    CurrentOption = {"0"},
    MultipleOptions = false,
    Flag = "skipHatchRareAboveKG", 
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        skipHatchRareAboveKG = tonumber(Options[1])
    end,
})
task.wait(.5) --to wait for loadout variables to load

local autoBrontoHuge = false
PetEggs:CreateToggle({
    Name = "Auto Bronto Huge?",
    CurrentValue = false,
    Flag = "autoBrontoHuge", 
    Callback = function(Value)
    -- The function that takes place when the toggle is pressed
    -- The variable (Value) is a boolean on whether the toggle is true or false
        autoBrontoHuge = Value
    end,
})

local autoBrontoAntiHatch = false
PetEggs:CreateToggle({
    Name = "Auto Bronto Anti Hatch list?",
    CurrentValue = false,
    Flag = "autoBrontoAntiHatch", 
    Callback = function(Value)
    -- The function that takes place when the toggle is pressed
    -- The variable (Value) is a boolean on whether the toggle is true or false
        autoBrontoAntiHatch = Value
    end,
})

local brontoLoady
local dropdown_bronto_loadout = PetEggs:CreateDropdown({
    Name = "Select Bronto loadout",
    -- Options = {"None", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10", "1", "2", "3", "4", "5", "6"},
    Options = getgenv().preloadedCustomLoadoutNames or {},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "brontoLoadoutNum", 
    Callback = function(Options)
        --if not Options or not Options[1] then return end
        brontoLoady = Options[1]
    end,
})

--bhub esp
local bhubESPenabled = false
local bhubESPthread = nil
local Toggle_bhubESP = PetEggs:CreateToggle({
    Name = "BeastHub ESP",
    CurrentValue = false,
    Flag = "bhubESP",
    Callback = function(Value)
        bhubESPenabled = Value
        local bhubEsp --function

        -- Turn OFF
        if not bhubESPenabled and bhubESPthread then
            task.cancel(bhubESPthread)
            bhubESPthread = nil

            --  Remove ALL BhubESP folders from all eggs
            local petEggs = myFunctions.getMyFarmPetEggs()
            for _, egg in ipairs(petEggs) do
                if egg:IsA("Model") then
                    local old = egg:FindFirstChild("BhubESP")
                    if old then old:Destroy() end
                end
            end

            beastHubNotify("ESP stopped and cleaned", "", 1)
            return
        end

        -- Turn ON
        if bhubESPenabled and not bhubESPthread then
            bhubEsp = function()
            
            end--end function

            bhubESPthread = task.spawn(function()
                --new
                while bhubESPenabled do
                    local eggEspData = {} -- final table storage
                    local petEggs = myFunctions.getMyFarmPetEggs()
                    local withEspCount = 0

                    for _, egg in ipairs(petEggs) do
                        if egg:FindFirstChild("BhubESP") then
                            withEspCount = withEspCount + 1
                        end
                    end

                    local allHaveESP = (withEspCount == #petEggs)

                    -- If every egg already has ESP, skip heavy processing
                    if not allHaveESP then
                        if #petEggs == 0 then
                            return
                        else
                            local function getPlayerData()
                                local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                                local logs = dataService:GetData()
                                return logs
                            end

                            local function getSaveSlots()
                                local playerData = getPlayerData()
                                if playerData.SaveSlots then
                                    return playerData.SaveSlots
                                else
                                    warn("SaveSlots not found!")
                                    return nil
                                end
                            end

                            local saveSlots = getSaveSlots()
                            local selectedSlot = saveSlots.SelectedSlot
                            local allSlots = saveSlots.AllSlots

                            for slot, slotData in pairs(allSlots) do
                                if tostring(slot) == selectedSlot then
                                    local savedObjects = slotData.SavedObjects
                                    for objName, ObjData in pairs(savedObjects) do
                                        if ObjData.ObjectType == "PetEgg" then
                                            local eggData = ObjData.Data
                                            local timeToHatch = eggData.TimeToHatch or 0
                                            if timeToHatch == 0 then
                                                local petName = eggData.RandomPetData.Name
                                                local petKG = string.format("%.2f", eggData.BaseWeight * 1.1)
                                                local entry = {
                                                    Uid = objName,
                                                    PetName = petName,
                                                    PetKG = petKG,
                                                    rawKG = eggData.BaseWeight * 1.1
                                                }
                                                table.insert(eggEspData, entry)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    else
                        task.wait(2)
                    end

                    -- Loop through all eggs
                    for _, egg in ipairs(petEggs) do
                        if egg:IsA("Model") then
                            local uuid = egg:GetAttribute("OBJECT_UUID")
                            local petName, petKG, rawKG
                            local hugeThreshold = 3
                            local isHuge = false

                            for _, eggData in pairs(eggEspData) do
                                if uuid == eggData.Uid then
                                    petName = eggData.PetName
                                    petKG = eggData.PetKG
                                    rawKG = eggData.rawKG
                                end
                            end

                            -- Skip non-ready eggs
                            if petKG then
                                if rawKG >= hugeThreshold then
                                    isHuge = true
                                end

                                local old = egg:FindFirstChild("BhubESP")
                                if old then old:Destroy() end

                                local espFolder = Instance.new("Folder")
                                espFolder.Name = "BhubESP"
                                espFolder.Parent = egg

                                local billboard = Instance.new("BillboardGui")
                                billboard.Name = "EggBillboard"
                                billboard.Adornee = egg
                                billboard.Size = UDim2.new(0, 150, 0, 40)
                                billboard.AlwaysOnTop = true
                                billboard.StudsOffset = Vector3.new(0, 4, 0)
                                billboard.Parent = espFolder

                                local label = Instance.new("TextLabel")
                                label.RichText = true
                                label.BackgroundTransparency = 1
                                label.Size = UDim2.new(1, 0, 1, 0)

                                if isHuge then
                                    if rawKG < 5 then
                                        label.Text = '<font color="rgb(255,0,0)"><b>ARAY KO!</b></font>\n<font color="rgb(204,204,0)"><b>' .. petName .. '</b></font><b> = ' .. petKG .. 'kg</b>'
                                    elseif rawKG < 8 then
                                        local brontoKG = string.format("%.2f", rawKG * 1.3)
                                        label.Text = '<font color="rgb(255,0,0)"><b>PALDO! ('..brontoKG..'kg)</b></font>\n<font color="rgb(204,204,0)"><b>' .. petName .. '</b></font><b> = ' .. petKG .. 'kg</b>'
                                    else
                                        local brontoKG = string.format("%.2f", rawKG * 1.3)
                                        label.Text = '<font color="rgb(255,0,0)"><b>PALDOOOOO!!! ('..brontoKG..'kg)</b></font>\n<font color="rgb(204,204,0)"><b>' .. petName .. '</b></font><b> = ' .. petKG .. 'kg</b>'
                                    end
                                else
                                    label.Text = '<font color="rgb(204,204,0)"><b>' .. petName .. '</b></font><b> = ' .. petKG .. 'kg</b>'
                                end

                                label.TextColor3 = Color3.fromRGB(204, 204, 0)
                                label.TextStrokeTransparency = 0.5
                                label.TextScaled = false
                                label.TextSize = 18
                                label.Font = Enum.Font.SourceSans
                                label.Parent = billboard
                            end
                        end
                    end

                    task.wait(2)
                end



                bhubESPthread = nil
                -- beastHubNotify("ESP stopped cleanly", "", 3)
            end)
        end
    end,
})

local petLoadoutValidator = true
PetEggs:CreateToggle({
    Name = "Pet Loadout Validator",
    CurrentValue = true,
    Flag = "petValidatorNew", 
    Callback = function(Value)
        petLoadoutValidator = Value
    end,
})


--Only two variables needed
local smartAutoHatchingEnabled = false
local smartAutoHatchingThread = nil
local webhookEggCount
-- local webhookKoiSeals
-- local webhookHatchSpeed
local isFirstBatch = true
local smartRejoin = false
local hatchCountRejoin = 0
local hatchCountRejoinEnabled = false
local batchHatchCount = 0
local batchCountForSell = 0

local sessionHugeList = {}
local sessionBadLuckCounter = 0
local Toggle_smartAutoHatch = PetEggs:CreateToggle({
    Name = "SMART Auto Hatching",
    CurrentValue = false,
    Flag = "smartAutoHatching",
    Callback = function(Value)
        smartAutoHatchingEnabled = Value
        batchHatchCount = 0

        if(smartAutoHatchingEnabled) then
            beastHubNotify("SMART AUTO HATCH ENABLED!", "Process will begin in 8 seconds..", 5)
            beastHubNotify("5", "", 1)
            task.wait(1)
            beastHubNotify("4", "", 1)
            task.wait(1)
            beastHubNotify("3", "", 1)
            task.wait(1)
            beastHubNotify("2", "", 1)
            task.wait(1)
            beastHubNotify("1", "", 1)
            task.wait(1)
            -- task.wait(8)
            -- Check again before proceeding
            if not smartAutoHatchingEnabled then
                beastHubNotify("SMART HATCH CANCELLED!", "Toggle was turned off before start.", 5)
                myFunctions.techControl.stop = true
                return
            end

            -- recheck setup
            local timeout=5
            while timeout>0 and not sellBelow do
                sellBelow=tonumber(input_sellBelow.CurrentValue)
                if sellBelow then
                    break
                end
                task.wait(.5)
                timeout=timeout-.5
            end

            if (not koiLoady or koiLoady == "None")
            or (not sealsLoady or sealsLoady == "None")
            or (not incubatingLoady or incubatingLoady == "None") then
                beastHubNotify("Missing setup!", "Please recheck loadouts for koi, bronto, seals and turn on ESP", 15)
                return
            end

            if not sellBelow then
                beastHubNotify("Missing setup!", "Please input Sell Below", 5)
                return
            end


            myFunctions.techControl.stop = false
        else
            myFunctions.techControl.stop = true
            return
        end

        local playerNameWebhook = game.Players.LocalPlayer.Name
        --9pets tech
        local function switchToHatching(incubatingLoady, getFarmSpawnCFrame, beastHubNotify)
            if incubatingLoady == "9 pets tech" then
                myFunctions.switchToLoadoutWithTech(AutomationModule.mimicsListFor9Pets, AutomationModule.spiderFor9Pets, AutomationModule.eagleFor9Pets, AutomationModule.delayToStayInSpider, AutomationModule.delayToStayInEagle, getFarmSpawnCFrame, beastHubNotify)
            else
                myFunctions.switchToLoadout(incubatingLoady, getFarmSpawnCFrame, beastHubNotify)
            end
        end
        -- print("Starting 9 pets")
        switchToHatching(incubatingLoady, getFarmSpawnCFrame, beastHubNotify)
        -- print("9 pets ran")
        task.wait()
        koiRefundCount = 0 --reset
        sealsRefundCount = 0 --reset
        local hatchStartTime = nil
        mainModule.isSafeToPickPlace = true
        -- task.wait(8)
        

        

        --get data for hatching security feature
        local function getPlayerData()
            local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
            local logs = dataService:GetData()
            return logs
        end

        local function equippedPets()
            local playerData = getPlayerData()
            if not playerData.PetsData then
                warn("PetsData missing")
                return nil
            end

            local tempStorage = playerData.PetsData.EquippedPets or nil
            if not tempStorage or type(tempStorage) ~= "table" then
                warn("EquippedPets missing or invalid")
                return nil
            end

            local petIdsList = {}
            for _, id in ipairs(tempStorage) do
                table.insert(petIdsList, id)
            end

            return petIdsList
        end

        local function getPetNameUsingId(uid)
            local playerData = getPlayerData()
            if playerData.PetsData.PetInventory.Data then
                local data = playerData.PetsData.PetInventory.Data
                for id,petData in pairs(data) do
                    if id == uid then
                        return petData.PetType
                    end
                end
            else
                warn("PetInventory Data not found!")
            end
        end

        local function isGoodToHatch()
            local start = tick()
            local squidFound = false
            while tick() - start < 5 do
                local equipped = equippedPets()

                if not petLoadoutValidator then
                    return true
                end

                if #equipped >= 8 then
                    local allGood = true
                    for _, id in ipairs(equipped) do
                        local petName = getPetNameUsingId(id)
                        if petName == "Ruby Squid" then
                            squidFound = true
                        end
                        if (petName ~= "Koi" and petName ~= "Ruby Squid" and petName ~= "Brontosaurus") or (petName ~= "Ruby Squid" and squidFound) then
                            allGood = false
                            break
                        end
                    end
                    if allGood then
                        return true
                    end
                end

                task.wait(0.5)
            end
            return false
        end


        local function isGoodToSell()
            local squidFound = false
            task.wait(5)
            -- seal validation
            local sealGood = true
            if toggle_useSellAllMethod.CurrentValue == true then
                -- sealGood = isGoodToSellAll()
                sealGood = isGoodToSellAllv2()
                beastHubNotify("Done Validating SELL ALL", "", 3)
            end

            -- initialize equipped with retry for up to 5 seconds
            local equipped = equippedPets()
            local timeout = 5
            while #equipped == 0 and timeout > 0 do
                task.wait(0.5)
                timeout = timeout - 0.5
                equipped = equippedPets()
            end

            if not petLoadoutValidator then
                return true
            end

            if #equipped >= 8 then
                local allGood = true
                for _, id in ipairs(equipped) do
                    local petName = getPetNameUsingId(id)
                    if petName == "Ruby Squid" then
                        squidFound = true
                    end
                    if (petName ~= "Seal" and petName ~= "Ruby Squid") or (petName ~= "Ruby Squid" and squidFound) then
                        allGood = false
                        break
                    end
                end
                if allGood and sealGood then
                    return true
                end
            end

            return false
        end


    
        local function formatHatchDuration(duration)
            local totalSeconds = math.floor(duration)
            local hours = math.floor(totalSeconds / 3600)
            local minutes = math.floor((totalSeconds % 3600) / 60)
            local seconds = totalSeconds % 60
            local parts = {}
            if hours > 0 then
                table.insert(parts, hours .. "hour" .. (hours == 1 and "" or "s"))
            end
            if minutes > 0 then
                table.insert(parts, minutes .. "min" .. (minutes == 1 and "" or "s"))
            end
            if seconds > 0 or #parts == 0 then
                table.insert(parts, seconds .. "second" .. (seconds == 1 and "" or "s"))
            end
            return table.concat(parts, " ")
        end

        local function getCurrentSelectedEggCount(eggName)
            -- process get data here
            local function getPlayerData()
                local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                local logs = dataService:GetData()
                return logs
            end

            local function getEggQty(name)
                local playerData = getPlayerData()
                if not playerData.InventoryData then
                    warn("InventoryData not found!")
                    return nil
                end
                for _, data in pairs(playerData.InventoryData) do
                    local item = data.ItemData
                    if item and data.ItemType == "PetEgg" and item.EggName == name then
                        return item.Uses or 0
                    end
                end
                return 0 -- not found
            end
            return getEggQty(eggName)
        end

        --get egg picture assets
        local function getEggPics(eggName)
            
        end

        -- If ON, start thread (only once)
        if smartAutoHatchingEnabled and not smartAutoHatchingThread then
            Toggle_autoPlaceEggs:Set(true)
            smartAutoHatchingThread = task.spawn(function()
                -- local playerNameWebhook = game.Players.LocalPlayer.Name
                local function isInHugeList(target)
                    for _, value in ipairs(sessionHugeList) do
                        if value == target then
                            return true
                        end
                    end
                    return false
                end

                local function notInHugeList(tbl, target)
                    for _, value in ipairs(tbl) do
                        if value == target then
                            return false  -- found NOT allowed
                        end
                    end
                    return true  -- not found allowed
                end

                local petOdds = myFunctions.getPetOdds()
                local isStartOfHatchMonitoring = false
                local triggerSellAllFruits = false
                local currentlySellingFruits = false

                while smartAutoHatchingEnabled do
                    --hatch time monitoring
                    if webhookEggCount and isStartOfHatchMonitoring then
                        hatchStartTime = os.clock()
                        isStartOfHatchMonitoring = false
                    end

                    --smart rejoin code here
                    if smartRejoin then
                        -- beastHubNotify("Bad luck counter: "..tostring(sessionBadLuckCounter), "Instant rejoin when reach 3", 3)
                        if sessionBadLuckCounter == 2 then 
                            myFunctions.delayedRejoin(0.1)
                        end
                    end

                    --hatch count rejoin
                    if hatchCountRejoinEnabled then
                        if hatchCountRejoin and hatchCountRejoin >= 0 then
                            if batchHatchCount == hatchCountRejoin then
                                myFunctions.delayedRejoin(0.1)
                            end
                        end
                    end
                
                    --check eggs
                    local myPetEggs = myFunctions.getMyFarmPetEggs()
                    local readyCounter = 0
                    task.wait()

                    for _, egg in pairs(myPetEggs) do
                        if egg:IsA("Model") and egg:GetAttribute("TimeToHatch") == 0 then
                            readyCounter = readyCounter + 1
                        end
                    end
                    
                    if #myPetEggs > 0 and #myPetEggs == readyCounter and smartAutoHatchingEnabled then
                        --all eggs ready to hatch
                        beastHubNotify("All eggs Ready!", "", 3)
                        mainModule.isSafeToPickPlace = false
                        myFunctions.techControl.stop = true
                        isStartOfHatchMonitoring = true

                        --hatch speed
                        if webhookEggCount and hatchStartTime and not isFirstBatch then
                            local duration = os.clock() - hatchStartTime
                            hatchStartTime = nil
                            -- isStartOfHatchMonitoring = true
                            local hatchSpdStringLocal = formatHatchDuration(duration)
                            hatchSpdString = hatchSpdStringLocal
                        end

                        task.wait(2)

                        local espFolderFound
                        local rareOrHugeFound
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")
                        local PetEggService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetEggService")
                                                            

                        --all eggs now must start with koi loadout, infinite loadout has been patched 10/24/25
                        beastHubNotify("Switching to Kois", "", 3)
                        Toggle_autoPlaceEggs:Set(false)
                        -- myFunctions.switchToLoadout(koiLoady)
                        -- task.wait(12)

                        --get egg data such as pet name and size
                        --=======================================
                        -- local function getCurrentLoadoutNumber()
                        --     local function getPlayerData()
                        --         local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                        --         local logs = dataService:GetData()
                        --         return logs
                        --     end

                        --     local function getPetsData()
                        --         local playerData = getPlayerData()
                        --         if playerData.PetsData and playerData.PetsData.SelectedPetLoadout then
                        --             return playerData.PetsData.SelectedPetLoadout
                        --         else
                        --             warn("SelectedPetLoadout not found!")
                        --             return nil
                        --         end
                        --     end
                        --     local temp = getPetsData()
                        --     local finalReturn --cater error in loadout 2 and 3 swapping
                        --     if temp == 2 then
                        --         finalReturn = 3
                        --     elseif temp == 3 then
                        --         finalReturn = 2
                        --     else
                        --         finalReturn = temp
                        --     end

                        --     return finalReturn
                        -- end
                        -- local curLoadoutNum = getCurrentLoadoutNumber()
                        local breakAllEggLoop = false
                        local customSwitchedToKoi = false
                        local firstEggHatched = false
                        local curEggName = Dropdown_eggToPlace.CurrentOption[1]

                        for _, egg in pairs(myPetEggs) do
                            if egg:IsA("Model") then
                                --ESP access part, this is mainly for bronto hatching
                                --====
                                local espFolder = egg:FindFirstChild("BhubESP")
                                if espFolder then
                                    -- print("espFolder found")
                                    espFolderFound = true
                                    for _, espObj in ipairs(espFolder:GetChildren()) do
                                        -- if espObj:IsA("BoxHandleAdornment") then
                                            local billboard = espFolder:FindFirstChild("EggBillboard")
                                            if billboard then
                                                local textLabel = billboard:FindFirstChildWhichIsA("TextLabel")
                                                if textLabel then
                                                    local text = textLabel.Text
                                                    -- Get values using string match 
                                                    -- local petName = string.match(text, "0%)'>(.-)</font>")
                                                    -- local stringKG = string.match(text, ".*=%s*<font.-'>(.-)</font>")
                                                    local petName = text:match('rgb%(%s*204,%s*204,%s*0%s*%)"><b>(.-)</b></font>')
                                                    local stringKG = text:match("=%s*(%d+%.?%d*)kg")
                                                    
                                                    -- print("petName")
                                                    -- print(petName)
                                                    -- print("stringKG")
                                                    -- print(stringKG)

                                                    local isRare
                                                    local isHuge

                                                    -- print("petName found: " .. tostring(petName))
                                                    -- print("stringKG found: "..tostring(stringKG))

                                                    if petName and stringKG and smartAutoHatchingEnabled then
                                                        -- Trim whitespace in case it grew from previous runs
                                                        stringKG = stringKG:match("^%s*(.-)%s*$") 
                                                        --print("stringKG trimmed: "..stringKG)

                                                        -- check if Rare OLD METHOD
                                                        -- if type(rarePets) == "table" then
                                                        if antiHatchList then
                                                            for _, rarePet in ipairs(antiHatchList) do
                                                                if petName == rarePet then
                                                                    isRare = true
                                                                    break
                                                                end
                                                            end
                                                        else
                                                            --exit if have trouble getting rare pets
                                                            warn("Anti hatch not found")
                                                            return
                                                        end
                                                        
                                                        -- check if Huge
                                                        local currentNumberKG = tonumber(stringKG)
                                                        if not currentNumberKG then
                                                            warn("Error in getting pet Size")
                                                            return
                                                        end
                                                        if currentNumberKG < 3 then
                                                            isHuge = false
                                                        else
                                                            isHuge = true
                                                        end

                                                        --deciding loadout code below
                                                        --if isHuge or isRare, swatch loadout bronto, wait 7 sec, hatch this 1 egg
                                                        if isRare or isHuge then
                                                            rareOrHugeFound = true
                                                            -- Toggle_autoPlaceEggs:Set(false)
                                                        end

                                                        if isHuge then
                                                            -- beastHubNotify("Skipping Huge!", "", 2)
                                                            if autoBrontoHuge then
                                                                beastHubNotify("Hatching Huge with bronto", "", 3)
                                                                -- if not string.find(brontoLoady, "custom") then
                                                                --     while smartAutoHatchingEnabled and curLoadoutNum ~= tonumber(brontoLoady) do
                                                                --         myFunctions.switchToLoadout(brontoLoady, getFarmSpawnCFrame, beastHubNotify)
                                                                --         customSwitchedToKoi = false
                                                                --         task.wait(2)
                                                                --         if not string.find(brontoLoady, "custom") then
                                                                --             curLoadoutNum = getCurrentLoadoutNumber()
                                                                --             if curLoadoutNum == tonumber(brontoLoady) then
                                                                --                 task.wait(5)
                                                                --             end
                                                                --         end
                                                                        
                                                                --     end
                                                                -- else
                                                                    myFunctions.switchToLoadout(brontoLoady, getFarmSpawnCFrame, beastHubNotify)
                                                                    customSwitchedToKoi = false
                                                                -- end
                                                                
                                                                task.wait(3)
                                                                local equipped = equippedPets()
                                                                if equipped and smartAutoHatchingEnabled and isGoodToHatch() then
                                                                    local args = {
                                                                            [1] = "HatchPet",
                                                                            [2] = egg
                                                                    }
                                                                    -- game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetEggService", 9e9):FireServer(unpack(args))
                                                                    game:GetService("ReplicatedStorage").GameEvents.PetEggService:FireServer(unpack(args))
                                                                    task.wait(0.05)
                                                                    -- task.wait(tonumber(Input_delayToHatch.CurrentValue) or 0.05)
                                                                    sessionHatchCount = sessionHatchCount + 1
                                                                else
                                                                    beastHubNotify("Invalid loadout equipped pets!", "", 10)
                                                                    if webhookURL and webhookURL ~= "" and webhookEggCount then
                                                                        sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Invalid Loadout Contents for Bronto loadout, please check!")
                                                                    end
                                                                    breakAllEggLoop = true
                                                                    break
                                                                end
                                                            end
                                                            
                                                            task.wait()

                                                            --webhooks
                                                            local targetHuge = petName..stringKG
                                                            if targetHuge and notInHugeList(sessionHugeList, targetHuge) then
                                                                table.insert(sessionHugeList, targetHuge)
                                                                if webhookURL and webhookURL ~= "" and webhookHuge then
                                                                    -- sendDiscordWebhook(webhookURL, "@everyone [BeastHub] "..playerNameWebhook.." | Huge found: "..petName.." = "..stringKG.."KG |Egg hatch # "..tostring(sessionHatchCount))
                                                                    sendWebhookHuge(webhookURL, playerNameWebhook, petName, curEggName, stringKG, "Egg hatch # "..tostring(sessionHatchCount))
                                                                else
                                                                    -- warn("No webhook URL provided for hatch!")
                                                                end
                                                            elseif  not targetHuge then
                                                                warn("Error in getting target Huge string")
                                                            end
                                                        elseif isRare and currentNumberKG >= skipHatchRareAboveKG and autoBrontoAntiHatch then
                                                            -- print("inside 2nd else if")
                                                            beastHubNotify("Hatching Anti-hatch with bronto", "", 3)
                                                            -- if not string.find(brontoLoady, "custom") then
                                                            --     while smartAutoHatchingEnabled and curLoadoutNum ~= tonumber(brontoLoady) do
                                                            --         myFunctions.switchToLoadout(brontoLoady, getFarmSpawnCFrame, beastHubNotify)
                                                            --         customSwitchedToKoi = false
                                                            --         task.wait(2)
                                                            --         curLoadoutNum = getCurrentLoadoutNumber()
                                                            --         if curLoadoutNum == tonumber(brontoLoady) then
                                                            --             task.wait(8)
                                                            --         end
                                                            --     end
                                                            -- else
                                                                myFunctions.switchToLoadout(brontoLoady, getFarmSpawnCFrame, beastHubNotify)
                                                                customSwitchedToKoi = false
                                                            -- end
                                                            task.wait(3)
                                                            local equipped = equippedPets()
                                                            if equipped and smartAutoHatchingEnabled and isGoodToHatch() then
                                                                local args = {
                                                                    [1] = "HatchPet",
                                                                    [2] = egg
                                                                }
                                                                -- game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetEggService", 9e9):FireServer(unpack(args))
                                                                game:GetService("ReplicatedStorage").GameEvents.PetEggService:FireServer(unpack(args))
                                                                task.wait(0.05)
                                                                -- task.wait(tonumber(Input_delayToHatch.CurrentValue) or 0.05)
                                                                sessionHatchCount = sessionHatchCount + 1
                                                            else
                                                                beastHubNotify("Invalid loadout equipped pets!", "", 10)
                                                                if webhookURL and webhookURL ~= "" and webhookEggCount then
                                                                    sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Invalid Loadout Contents for Bronto loadout, please check!")
                                                                end
                                                                -- breakAllEggLoop = true
                                                                break
                                                            end

                                                            -- send webhook here
                                                            local message = nil
                                                            if isRare and webhookRares then
                                                                message = "[BeastHub] "..playerNameWebhook.." | Anti Hatch found: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                                sendDiscordWebhook(webhookURL, message)
                                                            end
                                                        
                                                        elseif (isRare and currentNumberKG < skipHatchRareAboveKG) or (not isRare) then --also add the skip rare threshold here 
                                                            -- print("inside first else if")
                                                            -- if not string.find(koiLoady, "custom") then
                                                            --     while smartAutoHatchingEnabled and curLoadoutNum ~= tonumber(koiLoady) do
                                                            --         myFunctions.switchToLoadout(koiLoady, getFarmSpawnCFrame, beastHubNotify)
                                                            --         task.wait(2)
                                                            --         curLoadoutNum = getCurrentLoadoutNumber()
                                                            --         task.wait(1)
                                                            --         if curLoadoutNum == tonumber(koiLoady) then
                                                            --             task.wait(8)
                                                            --         end
                                                            --     end
                                                            -- else
                                                                if customSwitchedToKoi == false then
                                                                    myFunctions.switchToLoadout(koiLoady, getFarmSpawnCFrame, beastHubNotify)
                                                                    customSwitchedToKoi = true
                                                                    task.wait(1)
                                                                end          
                                                            -- end
                                                            
                                                            if firstEggHatched == false then
                                                                beastHubNotify("Hatch delay: "..tostring(Input_delayToHatch.CurrentValue) or "","",3)
                                                                task.wait(tonumber(Input_delayToHatch.CurrentValue) or 2)
                                                            end
                                                            
                                                            local equipped = equippedPets()
                                                            if equipped and smartAutoHatchingEnabled and isGoodToHatch() then
                                                                --koi enhance
                                                                if toggle_koiEnhance.CurrentValue == true and triggerSellAllFruits == false and currentlySellingFruits == false then
                                                                    triggerSellAllFruits = true
                                                                    currentlySellingFruits = true
                                                                    beastHubNotify("Triggering Auto Sell..", "", 3)
                                                                    task.spawn(function()
                                                                        local function teleportToNPC(npcName)
                                                                            local Players = game:GetService("Players")
                                                                            local player = Players.LocalPlayer
                                                                            local character = player.Character or player.CharacterAdded:Wait()
                                                                            local hrp = character:WaitForChild("HumanoidRootPart")
                                                                            local npc = workspace:WaitForChild("NPCS"):WaitForChild(npcName)
                                                                            local baseCFrame
                                                                            if npc.PrimaryPart then
                                                                                baseCFrame = npc.PrimaryPart.CFrame
                                                                            else
                                                                                baseCFrame = npc:GetPivot()
                                                                            end
                                                                            local offset = baseCFrame.LookVector * 6 + Vector3.new(0, 4, 0)
                                                                            hrp.CFrame = baseCFrame + offset
                                                                            return hrp
                                                                        end

                                                                        local function autoSellWhenFull()
                                                                            local Players = game:GetService("Players")
                                                                            local player = Players.LocalPlayer
                                                                            local character = player.Character or player.CharacterAdded:Wait()
                                                                            local hrp = character:WaitForChild("HumanoidRootPart")
                                                                            local originalCFrame = hrp.CFrame
                                                                            teleportToNPC("Steven")
                                                                            task.wait(1)
                                                                            local success = pcall(function()
                                                                                local args = {}
                                                                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("Sell_Inventory", 9e9):FireServer(unpack(args))
                                                                            end)
                                                                            if success then
                                                                                task.wait(0.5)
                                                                                hrp.CFrame = originalCFrame
                                                                            end
                                                                        end

                                                                        autoSellWhenFull()
                                                                        triggerSellAllFruits = false
                                                                        currentlySellingFruits = false
                                                                    end)
                                                                    
                                                                end
                                                                if firstEggHatched == false then
                                                                    task.wait(1)
                                                                end
                                                                --

                                                                local args = {
                                                                    [1] = "HatchPet",
                                                                    [2] = egg
                                                                }
                                                                -- game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetEggService", 9e9):FireServer(unpack(args))
                                                                game:GetService("ReplicatedStorage").GameEvents.PetEggService:FireServer(unpack(args))
                                                                if firstEggHatched == false then
                                                                    firstEggHatched = true 
                                                                end
                                                                task.wait(0.05)
                                                                -- task.wait(tonumber(Input_delayToHatch.CurrentValue) or 0.05)
                                                                sessionHatchCount = sessionHatchCount + 1
                                                            else
                                                                beastHubNotify("Invalid loadout equipped pets!", "", 10)
                                                                if webhookURL and webhookURL ~= "" and webhookEggCount then
                                                                    sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Invalid Loadout Contents for Koi loadout, please check!")
                                                                end
                                                                breakAllEggLoop = true
                                                                break
                                                            end
                                                            task.wait()

                                                            -- send webhook here
                                                            local message = nil
                                                            if isRare and webhookRares then
                                                                message = "[BeastHub] "..playerNameWebhook.." | Anti Hatch found: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                                if webhookURL and webhookURL ~= "" then
                                                                    sendDiscordWebhook(webhookURL, message)
                                                                end
                                                            elseif isHuge and webhookHuge then
                                                                -- message = "@everyone [BeastHub] "..playerNameWebhook.." | Huge hatched: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                                sendWebhookHuge(webhookURL, playerNameWebhook, tostring(petName), curEggName, tostring(currentNumberKG), "Egg hatch # "..tostring(sessionHatchCount))
                                                            end

                                                            -- if message then
                                                            --     if webhookURL and webhookURL ~= "" then
                                                            --         -- sendDiscordWebhook(webhookURL, message)
                                                            --         sendWebhookHuge(webhookURL, playerNameWebhook, tostring(petName), curEggName, tostring(currentNumberKG), "Egg hatch # "..tostring(sessionHatchCount))
                                                            --     else
                                                            --         -- warn("No webhook URL provided for hatch!")
                                                            --     end
                                                            -- end
                                                        
                                                        elseif isRare and currentNumberKG >= skipHatchRareAboveKG and not autoBrontoAntiHatch then
                                                            --anti hatch but not auto bronto
                                                            -- send webhook here
                                                            local message = nil
                                                            if isRare and webhookRares then
                                                                message = "[BeastHub] "..playerNameWebhook.." | Anti Hatch found: " .. tostring(petName) .. "=" .. tostring(currentNumberKG) .. "KG |Egg hatch # "..tostring(sessionHatchCount)
                                                                sendDiscordWebhook(webhookURL, message)
                                                            end
                                                        end
                                                    end

                                                else
                                                    print("BillboardGui has no TextLabel")
                                                end
                                            else
                                                print("No BillboardGui found under BoxHandleAdornment")
                                            end
                                        -- end
                                    end --end for loop
                                    if breakAllEggLoop then
                                        break;
                                    end
                                else
                                    espFolderFound = false
                                end
                                --====
                            else
                                warn("Object is not a model")
                                return
                            end
                        end

                        
                        --=======================================
                        --trigger auto sell first before back to eagles
                        mainModule.isSafeToPickPlace = false
                        task.wait(5)
                        game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                        task.wait()

                        if sealsLoady and sealsLoady ~= "None" and smartAutoHatchingEnabled then
                            --hatch cycles logic
                            local selectedHatchCycleToSell = tonumber(Input_HatchCyclesToSell.CurrentValue) or 0
                            batchCountForSell = batchCountForSell + 1

                            --0 for automatic trigger, set number for modulo calculation
                            local curEggCount = getCurrentSelectedEggCount(curEggName)
                            -- if (selectedHatchCycleToSell == 0 and fullInventoryAlert ~= 0) or (selectedHatchCycleToSell ~= 0 and batchHatchCount % selectedHatchCycleToSell == 0 ) then
                            if (selectedHatchCycleToSell == 0 and fullInventoryAlert ~= 0) or (selectedHatchCycleToSell == 0 and curEggCount <= 13) or (selectedHatchCycleToSell ~= 0 and batchHatchCount % selectedHatchCycleToSell == 0 ) then
                                beastHubNotify("Switching to seals", "", 3)
                                if not string.find(sealsLoady, "custom") then 
                                    myFunctions.switchToLoadout(sealsLoady, getFarmSpawnCFrame, beastHubNotify)
                                    task.wait(8)
                                else
                                    --switch via custom loadout
                                    myFunctions.switchToLoadout(sealsLoady, getFarmSpawnCFrame, beastHubNotify)
                                    task.wait(2)
                                end
                                
                                --sell here + validations
                                -- local isAutoUnfavToggleActive = getgenv().isAutoUnfavToggleActive
                                -- local isAutoUnfavModeActive = getgenv().isAutoUnfavModeActive

                                if isGoodToSell() and smartAutoHatchingEnabled and (getgenv().isAutoUnfavToggleActive ~= true and getgenv().isAutoUnfavModeActive ~= true) then
                                    local success, err = pcall(function()
                                        task.wait()
                                        if toggle_useSellAllMethod.CurrentValue == true and smartAutoHatchingEnabled then
                                            --sell all event
                                            beastHubNotify("Selling All Unfav Pets..", "", 3)
                                            local args = {}
                                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 5):WaitForChild("SellAllPets_RE", 5):FireServer(unpack(args))   
                                        else
                                            autoSellPets3(selectedPetsForAutoSell, sellBelow, function()
                                            end)
                                            -- sendDiscordWebhook("", playerNameWebhook.." not using sell all method: "..curEggName)
                                        end                                    
                                        task.wait(2)
                                        
                                    end)   

                                    if success then
                                        beastHubNotify("Auto Sell Done", "Successful", 2)
                                    else
                                        warn("Auto Sell failed with error: " .. tostring(err))
                                        beastHubNotify("Auto Sell Failed!", tostring(err), 5)
                                    end
                                elseif not smartAutoHatchingEnabled then
                                    beastHubNotify("Hatching stopped", "", 3)
                                else
                                    -- print("inside else seals")
                                    beastHubNotify("Invalid Seals loadout!", "", 3)
                                    if webhookURL and webhookURL ~= "" and webhookEggCount then
                                        sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Invalid Loadout Contents for Seals loadout, please check!")
                                    end
                                end
                                batchCountForSell = 0 --reset after sell
                               
                            else
                                beastHubNotify("Selling skipped", "Hatch Count: "..batchCountForSell, 3)
                            end

                            


                            --calculate luck
                            local koiNum = koiRefundCount or 0
                            local sealNum = sealsRefundCount or 0
                            local totalRefund = koiNum + sealNum
                            task.wait()

                            --reset var
                            isFirstBatch = false

                            if totalRefund < eggsToPlaceInput then
                                sessionBadLuckCounter = sessionBadLuckCounter + 1
                            else
                                sessionBadLuckCounter = 0
                            end
                            
                        else
                            --this part of logic might not be possible but keeping this for now
                            -- warn("No Seals Loadout found, skipping auto-sell.")
                        end


                        --back to incubating loadout
                        task.wait(5)
                        beastHubNotify("Back to incubating", "", 6)
                        game.Players.LocalPlayer.Character.Humanoid:UnequipTools() --prevention
                        Toggle_autoPlaceEggs:Set(true)
                        if smartAutoHatchingEnabled then 
                            myFunctions.techControl.stop = false
                        else
                            myFunctions.techControl.stop = true
                        end
                        
                        switchToHatching(incubatingLoady, getFarmSpawnCFrame, beastHubNotify) --loadout switch was done in the callback of auto sell or here
                        mainModule.isSafeToPickPlace = true
                        -- task.wait(6) 
                        

                        --hatch monitor kois/seals
                        -- if webhookKoiSeals then
                        --     sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Koi refund: "..(tostring(koiRefundCount) or "error"))
                        --     sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Seals refund: "..(tostring(sealsRefundCount) or "error"))
                        -- end
                        
                        if webhookEggCount then
                            if fullInventoryAlert > 0 then
                                sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | Max Pet inventory alert!")
                            end
                            
                        end
                        fullInventoryAlert = 0

                        local sessionStartEggCount = getCurrentSelectedEggCount(curEggName)
                        if webhookEggCount and isDonePlacingEgg then
                            -- sendDiscordWebhook(webhookURL, "[BeastHub] "..playerNameWebhook.." | "..curEggName..": "..sessionStartEggCount)
                            sendDiscordWebhookEmbedHatchMonitoring(webhookURL,koiRefundCount,sealsRefundCount,hatchSpdString,curEggName,sessionStartEggCount)
                            isDonePlacingEgg = false
                            --wehbook embed here
                        end
                        koiRefundCount = 0
                        sealsRefundCount = 0
                        batchHatchCount = batchHatchCount + 1
                    else
                        -- beastHubNotify("Eggs not ready yet", "Waiting..", 3)
                        mainModule.isSafeToPickPlace = true
                        task.wait(3)
                    end
                end
                -- When flag turns false, loop ends and thread resets
                smartAutoHatchingThread = nil
            end)
        end
    end,
})
PetEggs:CreateDivider()

--Other Egg settings
PetEggs:CreateSection("Other Egg settings")


PetEggs:CreateParagraph({Title = "Auto Rejoin by Hatch count", Content = "Set a number of hatch count and it will auto rejoin on specified number"})
PetEggs:CreateInput({
    Name = "Hatch count",
    CurrentValue = "",
    PlaceholderText = "number",
    RemoveTextAfterFocusLost = false,
    Flag = "hatchCountRejoin",
    Callback = function(Text)
        hatchCountRejoin = tonumber(Text) or 0
    end,
})

PetEggs:CreateToggle({
    Name = "Auto Rejoin by Hatch count",
    CurrentValue = false,
    Flag = "hatchCountRejoinEnabled", 
    Callback = function(Value)
        hatchCountRejoinEnabled = Value
    end,
})
PetEggs:CreateDivider()


PetEggs:CreateParagraph({Title = "Auto Rejoin when unlucky", Content = "It will auto rejoin on 2 consecutive loss"})
PetEggs:CreateToggle({
    Name = "Auto Rejoin when unlucky",
    CurrentValue = false,
    Flag = "smartRejoin", 
    Callback = function(Value)
        smartRejoin = Value
    end,
})
--Egg collision
-- PetEggs:CreateToggle({
--     Name = "Disable Egg collision",
--     CurrentValue = false,
--     Flag = "disableEggCollision", 
--     Callback = function(Value)
--         myFunctions.disableEggCollision(Value)
--     end,
-- })
PetEggs:CreateDivider()

--Automation Moduled


Misc:CreateSection("Performance")
--Hide other player's Farm
local Toggle_hideOtherFarm = Misc:CreateToggle({
    Name = "Hide Other Player's Farm",
    CurrentValue = false,
    Flag = "hideOtherFarm", 
    Callback = function(Value)
        myFunctions.hideOtherPlayersGarden(Value)
    end,
})

local autoHidePlantsEnabled = false
local autoHidePlantsThread = nil
Misc:CreateToggle({
	Name = "Auto Hide my Plants",
	CurrentValue = false,
	Flag = "autoHidePlants",
	Callback = function(Value)
		autoHidePlantsEnabled = Value

		if autoHidePlantsEnabled then
			if autoHidePlantsThread then return end
			beastHubNotify("Auto Hide Plants running", "", 3)

			autoHidePlantsThread = task.spawn(function()
				while autoHidePlantsEnabled do
					local farm = getMyFarm()
					if farm then
						local important = farm:FindFirstChild("Important")
						if important then
							local plantsPhysical = important:FindFirstChild("Plants_Physical")
							if plantsPhysical then
								for _, plant in ipairs(plantsPhysical:GetChildren()) do
									if plant:IsA("Model") then
										for _, obj in ipairs(plant:GetDescendants()) do
											if obj:IsA("BasePart") then
												obj.LocalTransparencyModifier = 1
												obj.CanCollide = false
												obj.CanTouch = false
												obj.CanQuery = false
											end
										end
									end
								end
							end
						end
					end
					task.wait(1)
				end
				autoHidePlantsThread = nil
			end)

		else
			autoHidePlantsEnabled = false

			local farm = getMyFarm()
			if farm then
				local important = farm:FindFirstChild("Important")
				if important then
					local plantsPhysical = important:FindFirstChild("Plants_Physical")
					if plantsPhysical then
						for _, plant in ipairs(plantsPhysical:GetChildren()) do
							if plant:IsA("Model") then
								for _, obj in ipairs(plant:GetDescendants()) do
									if obj:IsA("BasePart") then
										obj.LocalTransparencyModifier = 0
										obj.CanCollide = true
										obj.CanTouch = true
										obj.CanQuery = true
									end
								end
							end
						end
					end
				end
			end

			autoHidePlantsThread = nil
		end
	end,
})





local autoLowGraphicsEnabled = false
local autoLowGraphicsThreads = {} -- store multiple threads
Misc:CreateToggle({
	Name = "Reduce Lag (Web and Fireworks)",
	CurrentValue = false,
	Flag = "reduceLag",
	Callback = function(Value)
		autoLowGraphicsEnabled = Value
		if autoLowGraphicsEnabled then
			if next(autoLowGraphicsThreads) then
				return
			end

			local function applyUltraAssetCull()
				for _, v in ipairs(workspace:GetDescendants()) do
					if v:IsA("Decal") or v:IsA("Texture") or v:IsA("SurfaceAppearance") then
						v:Destroy()
					elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
						v.Enabled = false
					elseif v:IsA("MeshPart") then
						v.TextureID = ""
						v.Material = Enum.Material.Plastic
						v.CastShadow = false
					elseif v:IsA("UnionOperation") then
						v:Destroy()
					elseif v:IsA("BasePart") then
						if not v:IsDescendantOf(game.Players.LocalPlayer.Character) then
							v.LocalTransparencyModifier = 0.6
							v.CastShadow = false
						end
					end
				end
			end

			beastHubNotify("Reduce lag active", "", 3)

			-- Thread 1: Clean SpiderWebFX
			autoLowGraphicsThreads.spiderWeb = task.spawn(function()
				while autoLowGraphicsEnabled do
					local spiderFolder = workspace:FindFirstChild("SpiderWebFX")
					if spiderFolder then
						spiderFolder:Destroy()
					end
					task.wait(0.1)
				end
				autoLowGraphicsThreads.spiderWeb = nil
			end)

			-- Thread 2: Clean JulyFirework
			autoLowGraphicsThreads.firework = task.spawn(function()
				while autoLowGraphicsEnabled do
					local firework = workspace:FindFirstChild("JulyFirework")
					if firework then
						firework:Destroy()
					end
					task.wait(0.1)
				end
				autoLowGraphicsThreads.firework = nil
			end)

			-- Optional: Thread 3 for ultra asset cull (uncomment if needed)
			-- autoLowGraphicsThreads.assets = task.spawn(function()
			-- 	while autoLowGraphicsEnabled do
			-- 		applyUltraAssetCull()
			-- 		task.wait(60)
			-- 	end
			-- 	autoLowGraphicsThreads.assets = nil
			-- end)

		else
			autoLowGraphicsEnabled = false
			-- clean up thread references
			autoLowGraphicsThreads = {}
		end
	end,
})


local autoLowGraphicsEnabledUltra = false
local autoLowGraphicsEnabledUltraThreads = {}

Misc:CreateToggle({
	Name = "More lag reduce",
	CurrentValue = false,
	Flag = "reduceLagMore",
	Callback = function(Value)
		autoLowGraphicsEnabledUltra = Value
		if autoLowGraphicsEnabledUltra then
			if autoLowGraphicsEnabledUltraThreads.assets then
				return
			end

			local function applyUltraAssetCull()
				for _, v in ipairs(workspace:GetDescendants()) do
					if v:IsA("Decal") or v:IsA("Texture") or v:IsA("SurfaceAppearance") then
						v:Destroy()
					elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
						v.Enabled = false
					elseif v:IsA("MeshPart") then
						v.TextureID = ""
						v.Material = Enum.Material.Plastic
						v.CastShadow = false
					elseif v:IsA("UnionOperation") then
						v:Destroy()
					elseif v:IsA("BasePart") then
						if not v:IsDescendantOf(game.Players.LocalPlayer.Character) then
							v.LocalTransparencyModifier = 0.6
							v.CastShadow = false
						end
					end
				end
			end

			autoLowGraphicsEnabledUltraThreads.assets = task.spawn(function()
				while autoLowGraphicsEnabledUltra do
					applyUltraAssetCull()
					task.wait(60)
				end
				autoLowGraphicsEnabledUltraThreads.assets = nil
			end)
		else
			autoLowGraphicsEnabledUltra = false
			autoLowGraphicsEnabledUltraThreads = {}
		end
	end,
})



Misc:CreateToggle({
    Name = "BeastHub Notifs (default ON)",
    CurrentValue = true,
    Flag = "beastHubNotifs",
    Callback = function(Value)
        --no callback needed
        --new
        local start = tick()
        local maxWait = 10
        while not getgenv().ConfigLoaded do
            local elapsed = tick() - start
            if elapsed >= maxWait then
                -- beastHubNotify("Auto Ele V2 failed to load", "Please rejoin", 5)
                break
            end
            task.wait(0.5)
        end
        task.wait(3)
        
        beastHubNotifsEnabled = Value
    end,
})

Misc:CreateToggle({
	Name = "Game Notifications (including trade notifs)",
	CurrentValue = true,
	Flag = "gameNotifs",
	Callback = function(Value)
		local player = game.Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui")

        --new
        local start = tick()
        local maxWait = 10
        while not getgenv().ConfigLoaded do
            local elapsed = tick() - start
            if elapsed >= maxWait then
                -- beastHubNotify("Auto Ele V2 failed to load", "Please rejoin", 5)
                break
            end
            task.wait(0.5)
        end
        task.wait(3)

		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") and gui.Name:match("Notification") then
				gui.Enabled = Value -- enable if toggle is ON, disable if OFF
			end
		end
	end,
})
Misc:CreateDivider()

--Misc>Webhook
-- EXECUTOR-ONLY WEBHOOK FUNCTION
local webhookReadyToHatchEnabled = false
local hatchMonitorThread
local hatchMonitorStop = false


Misc:CreateSection("Webhook")
local Input_webhookURL = Misc:CreateInput({
    Name = "Webhook URL",
    CurrentValue = "",
    PlaceholderText = "Enter webhook URL",
    RemoveTextAfterFocusLost = false,
    Flag = "webhookURL",
    Callback = function(Text)
        webhookURL = Text
        PetsModule.webhookURL = Text
        TraderModule.webhookURL = Text
    end,
})


Misc:CreateToggle({
    Name = "Hatch Monitoring webhook",
    CurrentValue = false,
    Flag = "webhookEggCount",
    Callback = function(Value)
        webhookEggCount = Value
    end,
})

Misc:CreateToggle({
    Name = "Anti Hatch webhook",
    CurrentValue = false,
    Flag = "webhookRares",
    Callback = function(Value)
        webhookRares = Value
    end,
})
Misc:CreateToggle({
    Name = "Huge Hatch webhook",
    CurrentValue = false,
    Flag = "webhookHuge",
    Callback = function(Value)
        webhookHuge = Value
    end,
})
Misc:CreateToggle({
    Name = "Auto Nightmare results",
    CurrentValue = false,
    Flag = "webhookAutoNM",
    Callback = function(Value)
        PetsModule.autoNMwebhook = Value
    end,
})
Misc:CreateToggle({
    Name = "Auto Elephant results",
    CurrentValue = false,
    Flag = "webhookAutoEle",
    Callback = function(Value)
        PetsModule.autoEleWebhook = Value
    end,
})
Misc:CreateToggle({
    Name = "Auto Mutation Machine results",
    CurrentValue = false,
    Flag = "webhookAutoMutationMachine",
    Callback = function(Value)
        webhookAutoMutation = true
    end,
})
--dev mode
-- if not isVerified then
--     local url = loadstring(game:HttpGet("https://raw.githubusercontent.com/bhubAlt/bhub_alt/refs/heads/main/u1.lua"))()
--     sendDiscordWebhook(url, "@everyone, illegal usage: "..username)
--     myFunctions.delayedRejoin(0.001)
-- end
Misc:CreateToggle({
    Name = "Auto Sniper",
    CurrentValue = false,
    Flag = "webhookAutoSniper",
    Callback = function(Value)
        TraderModule.autoSnipeWebhook = Value
    end,
})

Misc:CreateDivider()

--Rebirth
Misc:CreateSection("Rebirth")
local ascendMulti = 50 -- Default fallback value
Misc:CreateInput({
    Name = "Multi",
    CurrentValue = "50",
    PlaceholderText = "Enter Multi (Default 50, max 100)",
    RemoveTextAfterFocusLost = false,
    Flag = "autoAscendMulti",
    Callback = function(Text)
        -- Convert input to number; if it's not a valid number, default to 50
        ascendMulti = tonumber(Text) or 50
        if ascendMulti > 100 then 
            ascendMulti = 100
        end
    end,
})

local autoAscendRunning = false
Misc:CreateToggle({
    Name = "Auto Ascend",
    CurrentValue = false,
    Flag = "autoAscend",
    Callback = function(Value)
        autoAscendRunning = Value
        
        -- wait for UI to load, new retry method
        local start = tick()
        local maxWait = 10
        while not getgenv().ConfigLoaded do
            local elapsed = tick() - start
            if elapsed >= maxWait then
                beastHubNotify("Auto Ascend failed to load, please rejoin.", "", 5)
                return -- Stop execution if it fails to load
            end
            task.wait(0.5)
        end
        
        task.wait(3)

        task.spawn(function()
            while autoAscendRunning do
                -- Loop fire the remote based on the Multi stated by user
                -- This loop runs instantly with no delay between fires
                for i = 1, ascendMulti do
                    game:GetService("ReplicatedStorage").GameEvents.BuyRebirth:FireServer()
                end
                
                -- The main interval remains untouched
                task.wait(300)
            end
        end)
    end,
})
Misc:CreateDivider()

-- Disconnection
Misc:CreateSection("Server Connection")

--webhook dc v2
local disconnectEnabled = false
local firedDisconnect = false
local menuWatcherThread = nil
Misc:CreateToggle({
	Name = "Webhook on Disconnect",
	CurrentValue = false,
	Flag = "webhookDisconnection",
	Callback = function(Value)
		disconnectEnabled = Value
		if disconnectEnabled then
			if menuWatcherThread then
				return
			end
			firedDisconnect = false
			menuWatcherThread = task.spawn(function()
				local GuiService = game:GetService("GuiService")
				local CoreGui = game:GetService("CoreGui")
				local lastMenuState = false
				local dcText = ""
				local flags = {
					"Error Code",
					"Reconnect"
				}
				local excludeFlags = {
					"772"
				}
				local function scanScreenGui(gui)
					for _, v in ipairs(gui:GetDescendants()) do
						if v:IsA("TextLabel") or v:IsA("TextButton") then
							if v.Visible then
								local txt = v.Text
								if type(txt) == "string" and txt ~= "" then
									local matched = false
									for _, flag in ipairs(flags) do
										if string.find(txt, flag, 1, true) then
											matched = true
											break
										end
									end
									if matched then
										for _, exFlag in ipairs(excludeFlags) do
											if string.find(txt, exFlag, 1, true) then
												matched = false
												break
											end
										end
									end
									if matched then
										dcText = txt
										return true
									end
								end
							end
						end
					end
					return false
				end
				while disconnectEnabled do
					local menuOpen = GuiService.MenuIsOpen
					if menuOpen and not lastMenuState and not firedDisconnect then
						for _, child in ipairs(CoreGui:GetChildren()) do
							if child:IsA("ScreenGui") then
								if scanScreenGui(child) then
									firedDisconnect = true
									if webhookURL and autoRejoinOnDC then
										for i = 1, 9999 do
											sendDiscordWebhookEmbedDisconnection(webhookURL, tostring(dcText))
											sendDiscordWebhook(webhookURL, "Auto rejoin triggered")
											myFunctions.delayedRejoin(0.001)
											task.wait(5)
										end
									elseif webhookURL then
										sendDiscordWebhookEmbedDisconnection(webhookURL, tostring(dcText))
									end
									break
								end
							end
						end
					end
					lastMenuState = menuOpen
					task.wait(0.2)
				end
				menuWatcherThread = nil
			end)
		else
			disconnectEnabled = false
			firedDisconnect = false
		end
	end
})






Misc:CreateToggle({
	Name = "Auto Rejoin on Disconnect",
	CurrentValue = false,
	Flag = "autoRejoinDisconnect",
	Callback = function(Value)
        autoRejoinOnDC = Value
	end,
})

Misc:CreateDivider()



--
-- Misc:CreateParagraph({Title = "Accepting tips! :)", Content = "Gcash: 09475529869 A. R. C."})
-- Misc:CreateDivider()


local function antiAFK()
    -- Prevent multiple connections
    if getgenv().AntiAFKConnection then
        getgenv().AntiAFKConnection:Disconnect()
        -- print(" Previous Anti-AFK connection disconnected")
    end

    local vu = game:GetService("VirtualUser")
    getgenv().AntiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        -- print(" AFK protection triggered simulated activity sent")
    end)

    -- print(" Anti-AFK enabled")
end
antiAFK()

-- LOAD CONFIG / must be the last part of everything 
local success, err = pcall(function()
    Rayfield:LoadConfiguration() -- Load config
    local playerNameWebhook = game.Players.LocalPlayer.Name
    local url = login_url
    sendDiscordWebhook(url, "Logged in: "..playerNameWebhook)
end)
if success then
    task.delay(1, function()
        getgenv().ConfigLoaded = true
        print("Config file loaded")
    end)
else
    print("Error loading config file "..err)
end

-- subscribe dropdowns to global event
getgenv().LoadoutsChangedEvent.Event:Connect(function()
    local baseOptions = getgenv().preloadedCustomLoadoutNames or {}
    local updatedOptions = {unpack(baseOptions)}
    table.insert(updatedOptions, 1, "None")

    local success, err = pcall(function()
        Dropdown_sealsLoadoutNum:Refresh(updatedOptions)
        dropdown_koi_loadout:Refresh(updatedOptions)
        dropdown_bronto_loadout:Refresh(updatedOptions)

        local updatedForIncubating = {unpack(baseOptions)}
        table.insert(updatedForIncubating, 1, "9 pets tech")
        table.insert(updatedForIncubating, 1, "None")
        dropdown_incubating_loadout:Refresh(updatedForIncubating)
    end)
    if not success then
        warn("Failed to refresh dropdown:", err)
    end
end)
getgenv().LoadoutsChangedEvent:Fire()
