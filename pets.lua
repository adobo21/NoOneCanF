local M = {}

M.autoEleWebhook = false
M.autoNMwebhook = false
M.webhookURL = ""
function M.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon, equipItemByName, equipItemByNameV2, getMyFarm, getFarmSpawnCFrame, getAllPetNames, sendDiscordWebhook, petListNamesOnlyAndSorted, mainModule)

    local Pets = Window:CreateTab("Pets", "cat")
    
    --auto fav unfav pet
    local selectedPetsForAutoFav = {}
    local selectedPetLookup = {}
    local autoFavEnabled
    local autoFavThread
    local autoFavToggle

    Pets:CreateSection("Auto Favorite/Unfavorite Pet")

    getgenv().isAutoUnfavModeActive = nil
    local dropdown_favMode = Pets:CreateDropdown({
        Name = "Select Mode",
        Options = {"Auto Favorite", "Auto Unfavorite"},
        CurrentOption = {"Auto Favorite"},
        MultipleOptions = false,
        Flag = "autoFavMode",
        Callback = function(Options)
            if typeof(Options) == "table" and Options[1] == "Auto Unfavorite" then
                getgenv().isAutoUnfavModeActive = true
            else
                getgenv().isAutoUnfavModeActive = false
            end
        end,
    })
    local dropdown_petToAutoFav = Pets:CreateDropdown({
        Name = "Select Pet",
        Options = petListNamesOnlyAndSorted,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "petListForAutoFav", 
        Callback = function(Options)
            selectedPetsForAutoFav = Options  
            table.clear(selectedPetLookup)
            for _, name in ipairs(Options) do
                selectedPetLookup[name] = true
            end
        end,
    })
    -- search pets
    local PetssearchDebounce_autoFav = nil
    Pets:CreateInput({
        Name = "Search",
        PlaceholderText = "Search Pet...",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if PetssearchDebounce_autoFav then
                task.cancel(PetssearchDebounce_autoFav)
            end

            PetssearchDebounce_autoFav = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = petListNamesOnlyAndSorted
                else
                    for _, petName in ipairs(petListNamesOnlyAndSorted) do
                        if type(petName) == "string" then
                            if string.find(string.lower(petName), query, 1, true) then
                                table.insert(results, petName)
                            end
                        end
                    end
                end
                dropdown_petToAutoFav:Refresh(results)
                dropdown_petToAutoFav:Set(selectedPetsForAutoFav)
            end)
        end,
    })
    Pets:CreateButton({
        Name = "Select All",
        Callback = function()
            local allOptions = petListNamesOnlyAndSorted
            if #allOptions == 0 then
                return
            end
            dropdown_petToAutoFav:Set(allOptions)
            selectedPetsForAutoFav = allOptions
            table.clear(selectedPetLookup)
            for _, v in ipairs(allOptions) do
                selectedPetsForAutoFav[v] = true
                selectedPetLookup[v] = true
            end
        end,
    })
    Pets:CreateButton({
        Name = "Clear list",
        Callback = function()
            dropdown_petToAutoFav:Set({})
            selectedPetsForAutoFav = {}
            selectedPetLookup = {}
        end,
    })

    local dropdown_kgType
    Pets:CreateDropdown({
        Name = "KG mode",
        Options = {"Current KG", "Base KG"},
        CurrentOption = {"Current KG"},
        MultipleOptions = false,
        Flag = "selectedKGTypeforAutoFav", 
        Callback = function(Options)
            dropdown_kgType = Options[1]
        end,
    })

    local dropdown_selectedKgModeforAutoFav = Pets:CreateDropdown({
        Name = "Below or Above",
        Options = {"Below", "Above"},
        CurrentOption = {"Above"},
        MultipleOptions = false,
        Flag = "selectedKGforAutoFav", 
        Callback = function(Options)
        end,
    })

    local input_kgForAutoFavPet = Pets:CreateInput({
        Name = "KG",
        CurrentValue = "3",
        PlaceholderText = "number",
        RemoveTextAfterFocusLost = false,
        Flag = "kgForAutoFavPet",
        Callback = function(Text)
        -- The function that takes place when the input is changed
        -- The variable (Text) is a string for the value in the text box
        end,
    })

    getgenv().isAutoUnfavToggleActive = nil
    autoFavToggle = Pets:CreateToggle({
        Name = "Auto Favorite or Unfavorite Pet",
        CurrentValue = false,
        Flag = "autoFavPet",
        Callback = function(Value)
            autoFavEnabled = Value
            getgenv().isAutoUnfavToggleActive = Value
            -- 
            if not Value then
                autoFavEnabled = false
                autoFavThread = nil
                return
            end

            if autoFavEnabled then
                local timeout=5
                while timeout>0 and (
                    not selectedPetsForAutoFav or #selectedPetsForAutoFav==0
                    or not dropdown_kgType or dropdown_kgType == nil
                ) do
                    task.wait(.5)
                    timeout=timeout-.5
                end

                -- Checker for empty dropdown
                if not selectedPetsForAutoFav or #selectedPetsForAutoFav == 0 then
                    autoFavEnabled = false
                    return
                end
                local player = game:GetService("Players").LocalPlayer
                local rs = game:GetService("ReplicatedStorage")
                local favUnfavEvent = rs.GameEvents.Favorite_Item
                local backpack = player:WaitForChild("Backpack")

                if autoFavThread then
                    return
                end

                autoFavThread = task.spawn(function()
                    local function getPlayerData()
                        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                        local logs = dataService:GetData()
                        return logs
                    end
                    while autoFavEnabled do
                        if selectedPetsForAutoFav and backpack then
                            -- collect all matching items
                            local toFlip = {}
                            local baseKGlist = {}
                            --
                            local petInventory = getPlayerData().PetsData.PetInventory.Data
                            if petInventory then
                                for petId, data in pairs(petInventory) do 
                                    local petName = data.PetType
                                    -- local petLevel = data.PetData.Level
                                    local baseKG = tonumber(string.format("%.2f", data.PetData.BaseWeight * 1.1))
                                    if selectedPetLookup[petName] then
                                        toFlip[petId] = true
                                        baseKGlist[petId] = baseKG
                                    end 
                                end
                            else
                                warn("petInventory not found")
                            end
                            
                            -- flip all to desired state
                            for _, item in ipairs(backpack:GetChildren()) do
                                if autoFavEnabled then
                                    local curPetId = item:GetAttribute("PET_UUID") or nil
                                    if curPetId and toFlip[curPetId] then
                                        local d = item:GetAttribute("d")
                                        local favMode = dropdown_favMode.CurrentOption[1]
                                        local curWeight = tonumber(item.Name:match("%[(%d+%.?%d*)%s*[Kk][Gg]%]"))

                                        local selectedKgMode = dropdown_selectedKgModeforAutoFav.CurrentOption[1]
                                        local selectedKG = tonumber(input_kgForAutoFavPet.CurrentValue) or 3

                                        if dropdown_kgType == "Base KG" then
                                            -- print("base KG mode")
                                            curWeight = baseKGlist[curPetId]
                                            -- print("curWeight", curWeight)
                                        -- else
                                            -- print("else", dropdown_kgType.CurrentValue)
                                        end

                                        
                                        if autoFavEnabled and favMode and selectedKgMode and favMode == "Auto Favorite" and selectedKgMode == "Above" and curWeight > selectedKG and d == false then
                                            favUnfavEvent:FireServer(item) -- flip to favorite
                                        elseif autoFavEnabled and favMode and selectedKgMode and favMode == "Auto Favorite" and selectedKgMode == "Below" and curWeight < selectedKG and d == false then
                                            favUnfavEvent:FireServer(item)
                                        elseif autoFavEnabled and favMode and selectedKgMode and favMode == "Auto Unfavorite" and selectedKgMode == "Above" and curWeight > selectedKG and d == true then
                                            favUnfavEvent:FireServer(item) -- flip to unfavorite
                                        elseif autoFavEnabled and favMode and selectedKgMode and favMode == "Auto Unfavorite" and selectedKgMode == "Below" and curWeight < selectedKG and d == true then
                                            favUnfavEvent:FireServer(item) -- flip to unfavorite
                                        end
                                        task.wait()
                                    end   
                                end
                            end
                        end

                        task.wait(2)
                        if not autoFavEnabled then
                            break
                        end
                    end

                    autoFavThread = nil
                end)
            end
        end,
    })

    --Mutation machine
    --get pet mutations list
    local function safeGetPetNames(fn)
        local list = fn()
        local attempts = 0

        while (#list == 0 and attempts < 20) do
            task.wait(0.25)
            list = fn()
            attempts = attempts + 1
        end

        return list
    end
    local allPetList = safeGetPetNames(getAllPetNames)

    task.wait()
    
    local player = game.Players.LocalPlayer
    local function getMachineMutationTypes()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local success, PetMutationRegistry = pcall(function()
            return require(
                ReplicatedStorage:WaitForChild("Data")
                    :WaitForChild("PetRegistry")
                    :WaitForChild("PetMutationRegistry")
            )
        end)
        if not success or type(PetMutationRegistry) ~= "table" then
            warn("Failed to load PetMutationRegistry module.")
            return {}
        end
        local machineMutations = PetMutationRegistry.MachineMutationTypes
        if type(machineMutations) ~= "table" then
            warn("MachineMutationTypes not found in PetMutationRegistry.")
            return {}
        end
        local names = {}
        for mutationName, _ in pairs(machineMutations) do
            table.insert(names, tostring(mutationName))
        end
        table.insert(names, "GiantGolem")
        table.sort(names)
        return names
    end

    -- get place pet location (safe)
    local function getPetEquipLocation()
        local success, result = pcall(function()
            local spawnCFrame = getFarmSpawnCFrame()
            if typeof(spawnCFrame) ~= "CFrame" then
                return nil
            end
            -- offset forward 5 studs
            return spawnCFrame * CFrame.new(0, 0, -5)
        end)
        if success then
            return result
        else
            warn("[getPetEquipLocation] Error: " .. tostring(result))
            return nil
        end
    end


    local autoStartMachineEnabled = false
    local connectionAutoStartMachine -- store the connection so we can disconnect it later
    local function startMachine()
        local args = {
            [1] = "StartMachine"
        }
        game:GetService("ReplicatedStorage").GameEvents.PetMutationMachineService_RE:FireServer(unpack(args))
    end

    Pets:CreateSection("Mutation Machine")
    Pets:CreateButton({
        Name = "Submit Held Pet",
        Callback = function()
            local args = {
                [1] = "SubmitHeldPet"
            }
            game:GetService("ReplicatedStorage").GameEvents.PetMutationMachineService_RE:FireServer(unpack(args))
        end,
    })
    local Toggle = Pets:CreateToggle({
        Name = "Auto Start Machine (VULN)",
        CurrentValue = false,
        Flag = "autoStartMutationMachine",
        Callback = function(Value)
            autoStartMachineEnabled = Value
            -- cleanup previous connection if exists
            if connectionAutoStartMachine then
                connectionAutoStartMachine:Disconnect()
                connectionAutoStartMachine = nil
            end
            if autoStartMachineEnabled then
                local prompt
                local success, err = pcall(function()
                    prompt = workspace.NPCS.PetMutationMachine.Model.ProxPromptPart.PetMutationMachineProximityPrompt
                end)
                if not success or not prompt then
                    warn("[BeastHub] Cannot find mutation machine prompt", err or "")
                    return
                end

                -- Do an initial check right away
                if prompt.ActionText ~= "Skip" then
                    startMachine()
                    --print("Mutation Machine is available, starting machine now..")
                else
                    --print("Mutation Machine is already running")
                end

                --  Connect to listen for changes after the initial check
                connectionAutoStartMachine = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
                    if prompt.ActionText ~= "Skip" then
                    startMachine()
                        --print("Mutation Machine is available, starting machine now..")
                    else
                        --print("Mutation Machine is already running")
                    end
                end)
            end
        end,
    })
    Pets:CreateSection("Auto Pet Mutation")
    local phoenixLoady
    local dropdown_claimMachinePet = Pets:CreateDropdown({
        Name = "Loadout for Claim pet",
        -- Options = {"None", "1", "2", "3", "4", "5", "6", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "phoenixLoadoutNum", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            phoenixLoady = Options[1]
        end,
    })
    local levelingLoady
    local dropdown_mutation_leveling_A = Pets:CreateDropdown({
        Name = "Leveling Loadout A",
        -- Options = {"None", "1", "2", "3", "4", "5", "6", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoadoutNum_A", 
        Callback = function(Options)
            levelingLoady = Options[1]
        end,
    })

    local autoMutationTargetLevel_A
    Pets:CreateInput({
		Name = "Target level A",
		CurrentValue = "",
		PlaceholderText = "Enter level",
		RemoveTextAfterFocusLost = false,
		Flag = "autoMutationTargetLevel_A",
		Callback = function(Text) 
            local num = tonumber(Text)
            if num then
                autoMutationTargetLevel_A = num
            else
                autoMutationTargetLevel_A = 50
            end
        end,
	})

    local levelingLoady_B
    local dropdown_mutation_leveling_B = Pets:CreateDropdown({
        Name = "Leveling Loadout B",
        -- Options = {"None", "1", "2", "3", "4", "5", "6", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoadoutNum_B", 
        Callback = function(Options)
            levelingLoady_B = Options[1]
        end,
    })
    local autoMutationTargetLevel_B
    Pets:CreateInput({
		Name = "Target level B",
		CurrentValue = "",
		PlaceholderText = "Enter level",
		RemoveTextAfterFocusLost = false,
		Flag = "autoMutationTargetLevel_B",
		Callback = function(Text) 
            local num = tonumber(Text)
            if num then
                autoMutationTargetLevel_B = num
            else
                autoMutationTargetLevel_B = 50
            end
        end,
	})
    local golemLoady
    local dropdown_mutation_golem = Pets:CreateDropdown({
        Name = "Loadout for Machine Cooldown reduction",
        -- Options = {"None", "1", "2", "3", "4", "5", "6", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "golemLoadoutNum", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            golemLoady = Options[1]
        end,
    })

    local levelingMethod = ""
    Pets:CreateDropdown({
        Name = "Leveling Method",
        Options = {"Loadout only", "Loadout+Levelup Lollipop"},
        CurrentOption = {"Loadout+Levelup Lollipop"},
        MultipleOptions = false,
        Flag = "levelingMethod", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            levelingMethod = Options[1]
        end,
    })

    local selectedPetsForAutoMutation = {}
    local selectedMutationsForAutoMutation
    local Dropdown_petListForMutation = Pets:CreateDropdown({
        Name = "Select Pet/s (excluded favorites)",
        Options = allPetList,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "autoMutationPets", 
        Callback = function(Options)
            selectedPetsForAutoMutation = Options
        end,
    })

    --add search pet for auto mutation here
    --search pet
    local searchDebounce_petForAutoMutation = nil
    Pets:CreateInput({
        Name = "Search",
        PlaceholderText = "Search Pet...",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_petForAutoMutation then
                task.cancel(searchDebounce_petForAutoMutation)
            end

            searchDebounce_petForAutoMutation = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = allPetList
                else
                    for _, petName in ipairs(allPetList) do
                        if string.find(string.lower(petName), query, 1, true) then
                            table.insert(results, petName)
                        end
                    end
                end

                Dropdown_petListForMutation:Refresh(results)
                Dropdown_petListForMutation:Set(selectedPetsForAutoMutation) --set to current selected

            end)
        end,
    })

    Pets:CreateButton({
        Name = "Clear selection",
        Callback = function()
            Dropdown_petListForMutation:Set({}) --  
            selectedPetsForAutoMutation = {}
        end,
    })
    
    --auto mutation flags moved top for the function to recognize them
    local autoPetMutationEnabled = false
    local autoPetMutationThread = nil

    local mutationList = getMachineMutationTypes()
    local dropdown_selectedMutations = Pets:CreateDropdown({
        Name = "Select Mutation/s",
        Options = mutationList,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "selectedMutationsForAutoMutation",
        Callback = function(Options)
            selectedMutationsForAutoMutation = Options
        end,
    })
    Pets:CreateButton({
        Name = "Clear mutations",
        Callback = function()
            if dropdown_selectedMutations then
                dropdown_selectedMutations:Set({})
                selectedMutationsForAutoMutation = {}
            end
        end,
    })


    -- local Toggle_autoHatchAfterAutoMutation = Pets:CreateToggle({
    --     Name = "Auto Hatch after Auto mutation",
    --     CurrentValue = false,
    --     Flag = "autoHatchAfterAutoMutation", 
    --     Callback = function(Value)
    --     end,
    -- })

    local autoLevelAfterAutoEleMutationMachine = false
    Pets:CreateToggle({
        Name = "Auto Level after Auto Mutation",
        CurrentValue = false,
        Flag = "autoLevelAfterAutoMutationMachine", 
        Callback = function(Value)
            autoLevelAfterAutoEleMutationMachine = Value
        end,
    })
    local Toggle_autoLevel

    local Toggle_autoMutation = Pets:CreateToggle({
        Name = "Auto Mutation",
        CurrentValue = false,
        Flag = "autoMutation", 
        Callback = function(Value)
            autoPetMutationEnabled = Value
            local autoMutatePetsV2 --new function using getData
            
            if autoPetMutationEnabled then --declare function code only when condition is right
                --turn off auto smart hatching instantly
                -- Toggle_smartAutoHatch:Set(false)
                -- Check for missing setup
                -- Wait until Rayfield sets up the values (or timeout after 10s)
                
                local timeout = 4
                while timeout > 0 and (
                    (
                        (not phoenixLoady or phoenixLoady == "None")
                        and not (phoenixLoady and string.find(phoenixLoady, "custom", 1, true))
                    )
                    or (
                        (not levelingLoady or levelingLoady == "None")
                        and not (levelingLoady and string.find(levelingLoady, "custom", 1, true))
                    )
                    or not levelingLoady_B
                    or (
                        (not golemLoady or golemLoady == "None")
                        and not (golemLoady and string.find(golemLoady, "custom", 1, true))
                    )
                    or not autoMutationTargetLevel_A
                    or not autoMutationTargetLevel_B
                    or not selectedPetsForAutoMutation
                    or not selectedMutationsForAutoMutation or #selectedMutationsForAutoMutation == 0
                ) do
                    task.wait(1)
                    timeout = timeout - 1
                end

                --final validation
                if
                    (
                        (not phoenixLoady or phoenixLoady == "None")
                        and not (phoenixLoady and string.find(phoenixLoady, "custom", 1, true))
                    )
                    or (
                        (not levelingLoady or levelingLoady == "None")
                        and not (levelingLoady and string.find(levelingLoady, "custom", 1, true))
                    )
                    or (
                        (not golemLoady or golemLoady == "None")
                        and not (golemLoady and string.find(golemLoady, "custom", 1, true))
                    )
                    or not selectedPetsForAutoMutation
                    or not autoMutationTargetLevel_A
                    or not selectedMutationsForAutoMutation or #selectedMutationsForAutoMutation == 0
                then
                    beastHubNotify("Missing setup!", "Please recheck loadouts", 10)
                    return
                end

                -- print(autoMutationTargetLevel_A)
                -- print(autoMutationTargetLevel_B)
                autoMutatePetsV2 = function(selectedPetForAutoMutation, mutations, onComplete)
                    --local functions
                    local HttpService = game:GetService("HttpService")
                    
                    local function getPlayerData()
                        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                        local logs = dataService:GetData()
                        return logs
                    end

                    local function getPetInventory()
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            return playerData.PetsData.PetInventory.Data
                        else
                            warn("PetsData not found!")
                            return nil
                        end
                    end

                    local function getCurrentPetLevelByUid(uid)
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            for id, data in pairs(playerData.PetsData.PetInventory.Data) do
                                if tostring(id) == uid then
                                    return data.PetData.Level
                                end
                            end
                            return nil
                        else
                            warn("PetsData not found!")
                            return nil
                        end
                    end

                    local function getMutationMachineData() 
                        local playerData = getPlayerData()
                        if playerData.PetMutationMachine then
                            return playerData.PetMutationMachine
                        else
                            warn("PetMutationMachine not found!")
                            return nil
                        end
                    end
                    -- Function you can call anytime to refresh pets data
                    local function refreshPets()
                        -- USAGE: local favs, unfavs = refreshPets()
                        local pets = getPetInventory()
                        local favoritePets, unfavoritePets = {}, {}
                        if pets then
                            for uid, pet in pairs(pets) do
                                local entry = {
                                    Uid = uid,
                                    PetType = pet.PetType,
                                    Uuid = pet.UUID, 
                                    PetData = pet.PetData
                                }
                                if pet.PetData.IsFavorite then
                                    table.insert(favoritePets, entry)
                                else
                                    table.insert(unfavoritePets, entry)
                                end
                            end
                        end
                        --
                        return favoritePets, unfavoritePets
                    end

                    local function getMachineMutationsData() --all mutation data including enums
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")
                        local success, PetMutationRegistry = pcall(function()
                            return require(
                                ReplicatedStorage:WaitForChild("Data")
                                    :WaitForChild("PetRegistry")
                                    :WaitForChild("PetMutationRegistry")
                            )
                        end)
                        if not success or type(PetMutationRegistry) ~= "table" then
                            warn("Failed to load PetMutationRegistry module.")
                            return {}
                        end
                        local machineMutations = PetMutationRegistry.MachineMutationTypes
                        if type(machineMutations) ~= "table" then
                            warn("MachineMutationTypes not found in PetMutationRegistry.")
                            return {}
                        end
                        -- table.sort(machineMutations)
                        return machineMutations
                    end

                    local function equipItemByName(itemName)
                        local player = game.Players.LocalPlayer
                        local backpack = player:WaitForChild("Backpack")
                        player.Character.Humanoid:UnequipTools() --unequip all first

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

                    local function equipPetByUuid(uuid)
                        local player = game.Players.LocalPlayer
                        local backpack = player:WaitForChild("Backpack")
                        for _, tool in ipairs(backpack:GetChildren()) do
                            if tool:GetAttribute("PET_UUID") == uuid then
                                player.Character.Humanoid:EquipTool(tool)
                            end
                        end
                    end

                    -- get place pet location (safe)
                    local function getPetEquipLocation()
                        local success, result = pcall(function()
                            local spawnCFrame = getFarmSpawnCFrame()
                            if typeof(spawnCFrame) ~= "CFrame" then
                                return nil
                            end
                            -- offset forward 5 studs
                            return spawnCFrame * CFrame.new(0, 0, -5)
                        end)
                        if success then
                            return result
                        else
                            warn("[getPetEquipLocation] Error: " .. tostring(result))
                            return nil
                        end
                    end

                    --main function code
                    --vars
                    local favs, unfavs = refreshPets()
                    local selectedMutationsString = string.lower(table.concat(selectedMutationsForAutoMutation, " ")) --combined into 1 string for easy search
                    local selectedMutationFound --if true then no need to mutate
                    local petFoundV2 = false--set to true if candidate is found
                    local message = "Auto mutation stopped"
                    --loop unfavs to find the selected pet to mutate
                    --initial check for rejoin, copied the machine monitoring below
                    local mutationMachineData = getMutationMachineData()
                    if mutationMachineData.SubmittedPet then
                        if mutationMachineData.PetReady == true then
                            beastHubNotify("A Pet is ready to claim!", "Switching to phoenix loadout..", 3)
                            --claim with phoenix
                            mainModule.isSafeToPickPlace = false
                            task.wait(1)
                            myFunctions.switchToLoadout(phoenixLoady, getFarmSpawnCFrame, beastHubNotify)
                            task.wait(6)
                            local args = {
                                [1] = "ClaimMutatedPet";
                            }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetMutationMachineService_RE", 9e9):FireServer(unpack(args))
                            task.wait()
                            mainModule.isSafeToPickPlace = true
                            --Auto Start machine toggle VULN is advised
                        else
                            beastHubNotify("A Pet is already in machine", "Switching to golems loadout..", 3)
                            --switch to golems and wait till pet is ready
                            mainModule.isSafeToPickPlace = false
                            task.wait(1)
                            myFunctions.switchToLoadout(golemLoady, getFarmSpawnCFrame, beastHubNotify)
                            task.wait(6)
                            mainModule.isSafeToPickPlace = true
                            --monitoring code here
                            local machineCurrentStatus = getMutationMachineData().PetReady
                            while autoPetMutationEnabled and machineCurrentStatus == false do
                                beastHubNotify("Waiting for Machine to be ready", "", 3)
                                task.wait(15)
                                machineCurrentStatus = getMutationMachineData().PetReady
                            end 
                            --claim once while loop is broken, it means pet is ready
                            if autoPetMutationEnabled and machineCurrentStatus == true then
                                beastHubNotify("A Pet is ready to claim!", "Switching to phoenix loadout..", 3)
                                mainModule.isSafeToPickPlace = false
                                task.wait(1)
                                myFunctions.switchToLoadout(phoenixLoady, getFarmSpawnCFrame, beastHubNotify)
                                task.wait(6)
                                local args = {
                                    [1] = "ClaimMutatedPet";
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetMutationMachineService_RE", 9e9):FireServer(unpack(args))
                                task.wait()
                                mainModule.isSafeToPickPlace = true
                            end
                        end
                    end
                    
                    for _, pet in pairs(unfavs) do 
                        local curPet = pet.PetType
                        -- local uid = pet.Uuid
                        local uid = tostring(pet.Uid)
                        local curLevel = pet.PetData.Level
                        local curMutationEnum = pet.PetData.MutationType
                        local curMutation -- fetch later after enums fetch
                        local machineMutationEnums = {} --pet mutation enums container
                        local mutations = getMachineMutationsData() --all mutation data
                        for mutation, data in pairs(mutations) do --extract only enums
                            table.insert(machineMutationEnums, {mutation, data.EnumId})
                        end
                        --insert added mutation enums here (example: Giant Golem)
                        table.insert(machineMutationEnums, {"GiantGolem", "V"})

                        --get current pet mutation via enum
                        for _, entry in ipairs(machineMutationEnums) do
                            local mutation = entry[1]
                            local enumId = entry[2]
                            if enumId == curMutationEnum then
                                curMutation = mutation
                                break
                            end
                        end
                        
                        if curMutation == nil then
                            --beastHubNotify("Pet found has no mutation yet", "", 3)
                        end
                        --check curPet if good for auto mutation
                        if autoPetMutationEnabled and curPet == selectedPetForAutoMutation then 
                            --match current enum if found in selectedMutationsForAutoMutation
                            if curMutation and string.find(selectedMutationsString, string.lower(curMutation)) then
                                --already mutated
                                print("Already mutated "..curPet.." with desired mutation", "", 3)
                            else
                                if curMutation == nil then
                                    -- beastHubNotify("Found target!", curPet.." | ".."No mutation".." | "..curLevel.." | "..uid, 3)    
                                    beastHubNotify("Found target with no mutation yet", "", 3)
                                else
                                    -- beastHubNotify("Found target!", curPet.." | "..curMutation.." | "..curLevel.." | "..uid ,3)
                                    beastHubNotify("Found target", "", 3)
                                end
                                petFoundV2 = true
                                --DO MAIN ACTIONS HERE TO MUTATION
                                mutationMachineData = getMutationMachineData()
                                    --start machine if not started
                                if mutationMachineData.IsRunning == false then
                                    beastHubNotify("Machine started","",3)
                                    startMachine()
                                else
                                    beastHubNotify("Machine is already running","",3)
                                end

                                --process current pet for leveling here
                                mainModule.isSafeToPickPlace = false
                                task.wait(1)
                                myFunctions.switchToLoadout(levelingLoady, getFarmSpawnCFrame, beastHubNotify)
                                task.wait(6)
                                equipPetByUuid(uid)
                                task.wait()
                                --place pet to garden for leveling                                    
                                local petEquipLocation = getPetEquipLocation()
                                local args = {
                                    [1] = "EquipPet",
                                    [2] = uid,
                                    [3] = petEquipLocation, 
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                task.wait(1)
                                mainModule.isSafeToPickPlace = true

                                while autoPetMutationEnabled and curLevel < 50 do
                                    local haveLollipop = false
                                    if levelingMethod == "Loadout+Levelup Lollipop" then
                                        if equipItemByName("Levelup Lollipop") == false then 
                                            beastHubNotify("No more lollipops!", "Leveling now", 4)    
                                        else
                                            haveLollipop = true
                                            beastHubNotify("Equipping Lollipop", "Leveling now", 4) 
                                        end 
                                        task.wait(1)

                                        while autoPetMutationEnabled and haveLollipop and curLevel < 50 do
                                            task.wait(.5)
                                            local args = {
                                                [1] = "ApplyBoost";
                                                [2] = uid;
                                            }
                                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetBoostService", 9e9):FireServer(unpack(args))
                                            curLevel = curLevel + 1
                                        end
                                        --refresh pet data
                                        task.wait(2)
                                        curLevel = getCurrentPetLevelByUid(uid)
                                        beastHubNotify("Rechecked pet level: "..curLevel, "",3)
                                        if curLevel < 50 then --if still below 50 after lollipop
                                            beastHubNotify("Still below 50 after lollipop", "",3)
                                        end
                                        --monitor level every 5 sec
                                        --A
                                        while autoPetMutationEnabled and curLevel < autoMutationTargetLevel_A do 
                                            beastHubNotify("Current Pet age: "..curLevel, "waiting to hit age "..tostring(autoMutationTargetLevel_A), 3)
                                            task.wait(5)
                                            curLevel = getCurrentPetLevelByUid(uid)
                                        end

                                        --B
                                        --unequip, change loadout, equip
                                        mainModule.isSafeToPickPlace = false
                                        task.wait(1)
                                        myFunctions.switchToLoadout(levelingLoady_B, getFarmSpawnCFrame, beastHubNotify)
                                        task.wait(6)
                                        equipPetByUuid(uid)
                                        task.wait()                                  
                                        local petEquipLocation = getPetEquipLocation()
                                        local args = {
                                            [1] = "EquipPet",
                                            [2] = uid,
                                            [3] = petEquipLocation, 
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                        task.wait(1)
                                        mainModule.isSafeToPickPlace = true

                                        while autoPetMutationEnabled and curLevel < autoMutationTargetLevel_B do 
                                            beastHubNotify("Current Pet age: "..curLevel, "waiting to hit age "..tostring(autoMutationTargetLevel_B), 3)
                                            task.wait(5)
                                            curLevel = getCurrentPetLevelByUid(uid)
                                        end

                                        --unequip once ready
                                        local args = {
                                            [1] = "UnequipPet";
                                            [2] = uid;
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                        task.wait(1) 

                                    else --loadout method only
                                        --A
                                        while autoPetMutationEnabled and curLevel < autoMutationTargetLevel_A do 
                                            beastHubNotify("Current Pet age: "..curLevel, "waiting to hit age "..tostring(autoMutationTargetLevel_A), 3)
                                            task.wait(5)
                                            curLevel = getCurrentPetLevelByUid(uid)
                                        end

                                        --B
                                        mainModule.isSafeToPickPlace = false
                                        task.wait(1)
                                        myFunctions.switchToLoadout(levelingLoady_B, getFarmSpawnCFrame, beastHubNotify)
                                        task.wait(6)
                                        equipPetByUuid(uid)
                                        task.wait()                                  
                                        local petEquipLocation = getPetEquipLocation()
                                        local args = {
                                            [1] = "EquipPet",
                                            [2] = uid,
                                            [3] = petEquipLocation, 
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                        task.wait(1)
                                        mainModule.isSafeToPickPlace = true

                                        while autoPetMutationEnabled and curLevel < autoMutationTargetLevel_B do 
                                            beastHubNotify("Current Pet age: "..curLevel, "waiting to hit age "..tostring(autoMutationTargetLevel_B), 3)
                                            task.wait(5)
                                            curLevel = getCurrentPetLevelByUid(uid)
                                        end

                                        --unequip once ready
                                        local args = {
                                            [1] = "UnequipPet";
                                            [2] = uid;
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                        task.wait(1) 
                                    end
                                end


                                --check if pet is already inside machine
                                if mutationMachineData.SubmittedPet then
                                    if mutationMachineData.PetReady == true then
                                        beastHubNotify("A Pet is ready to claim!", "Switching to phoenix loadout..", 3)
                                        --claim with phoenix
                                        mainModule.isSafeToPickPlace = false
                                        task.wait(1)
                                        myFunctions.switchToLoadout(phoenixLoady, getFarmSpawnCFrame, beastHubNotify)
                                        task.wait(6)
                                        local args = {
                                            [1] = "ClaimMutatedPet";
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetMutationMachineService_RE", 9e9):FireServer(unpack(args))
                                        task.wait()
                                        mainModule.isSafeToPickPlace = true
                                        --Auto Start machine toggle VULN is advised
                                    else
                                        beastHubNotify("A Pet is already in machine", "Switching to golems loadout..", 3)
                                        --switch to golems and wait till pet is ready
                                        mainModule.isSafeToPickPlace = false
                                        task.wait(1)
                                        myFunctions.switchToLoadout(golemLoady, getFarmSpawnCFrame, beastHubNotify)
                                        task.wait(6)
                                        mainModule.isSafeToPickPlace = true
                                        --monitoring code here
                                        local machineCurrentStatus = getMutationMachineData().PetReady
                                        while autoPetMutationEnabled and machineCurrentStatus == false do
                                            beastHubNotify("Waiting for Machine to be ready", "", 3)
                                            task.wait(5)
                                            machineCurrentStatus = getMutationMachineData().PetReady
                                        end 
                                        --claim once while loop is broken, it means pet is ready
                                        if autoPetMutationEnabled and machineCurrentStatus == true then
                                            beastHubNotify("A Pet is ready to claim!", "Switching to phoenix loadout..", 3)
                                            mainModule.isSafeToPickPlace = false
                                            task.wait(1)
                                            myFunctions.switchToLoadout(phoenixLoady, getFarmSpawnCFrame, beastHubNotify)
                                            task.wait(6)
                                            local args = {
                                                [1] = "ClaimMutatedPet";
                                            }
                                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetMutationMachineService_RE", 9e9):FireServer(unpack(args))
                                            task.wait()
                                            mainModule.isSafeToPickPlace = true
                                        end
                                    end
                                end
                                --process current pet here for machine
                                if autoPetMutationEnabled and curLevel > 49 then
                                    beastHubNotify("Current Pet is good to submit", "", 3)
                                    mainModule.isSafeToPickPlace = false
                                    task.wait(1)
                                    myFunctions.switchToLoadout(golemLoady, getFarmSpawnCFrame, beastHubNotify)
                                    task.wait(6)
                                    --hold pet then submit      
                                    equipPetByUuid(uid)
                                    task.wait()

                                    local args = {
                                        [1] = "SubmitHeldPet"
                                    }
                                    game:GetService("ReplicatedStorage").GameEvents.PetMutationMachineService_RE:FireServer(unpack(args))
                                    beastHubNotify("Current Pet submitted", "", 3)
                                    task.wait(1)
                                    mainModule.isSafeToPickPlace = true
                                    -- myFunctions.switchToLoadout(golemLoady, getFarmSpawnCFrame, beastHubNotify)
                                    -- task.wait(6)
                                    --monitoring code here
                                    local machineCurrentStatus = getMutationMachineData().PetReady
                                    while autoPetMutationEnabled and machineCurrentStatus == false do
                                        beastHubNotify("Waiting for Machine to be ready", "", 3)
                                        task.wait(5)
                                        machineCurrentStatus = getMutationMachineData().PetReady
                                    end 
                                    --claim once while loop is broken, it means pet is ready
                                    if autoPetMutationEnabled and machineCurrentStatus == true then
                                        beastHubNotify("A Pet is ready to claim!", "Switching to phoenix loadout..", 3)
                                        mainModule.isSafeToPickPlace = false
                                        task.wait(1)
                                        myFunctions.switchToLoadout(phoenixLoady, getFarmSpawnCFrame, beastHubNotify)
                                        task.wait(6)
                                        local args = {
                                            [1] = "ClaimMutatedPet";
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetMutationMachineService_RE", 9e9):FireServer(unpack(args))
                                        task.wait()
                                        mainModule.isSafeToPickPlace = true
                                        message = "Mutation Cycle done"
                                    end
                                end
                                -- break --break for loop for Unfavs
                            end
                        end
                    end

                    --Call the callback AFTER finishing
                    if petFoundV2 == false then 
                        message = "No eligible pet"                     
                    end
                    if typeof(onComplete) == "function" then
                        onComplete(message)
                    end
                end

                
                --main logic
                if autoPetMutationEnabled and not autoPetMutationThread then
                    autoPetMutationThread = task.spawn(function()
                        while autoPetMutationEnabled do
                            beastHubNotify("Auto Pet mutation running..", "", 3)
                            player.Character.Humanoid:UnequipTools()
                            if selectedPetsForAutoMutation then --
                                local success, err = pcall(function()
                                    --add loop for multi select    
                                    local failCounter = 0            
                                    for i, petName in ipairs(selectedPetsForAutoMutation) do                                
                                        autoMutatePetsV2(petName, selectedMutationsForAutoMutation, function(msg)
                                            if msg == "No eligible pet" then
                                                beastHubNotify("Not Found: "..petName, "Make sure to select the correct pet/s", 5)
                                                failCounter = failCounter + 1
                                                if failCounter == #selectedPetsForAutoMutation then
                                                    autoPetMutationEnabled = false
                                                    autoPetMutationThread = nil

                                                    if autoLevelAfterAutoEleMutationMachine then
                                                        beastHubNotify("Auto Leveling triggered", "", 3)
                                                        Toggle_autoLevel:Set(true)
                                                    end
                                                    return
                                                end
                                            else
                                                beastHubNotify(msg, "", 5)
                                            end 
                                        end)
                                    end
                                end)

                                if success then
                                else
                                    warn("Auto Mutation Cycle failed with error: " .. tostring(err))
                                    beastHubNotify("Auto Mutation Cycle failed with error: ", tostring(err), 5)
                                end
                            end
                            task.wait(5) --cycle delay
                        end
                        -- When flag turns false, loop ends and thread resets
                        autoPetMutationThread = nil
                    end)
                end
            end
        end,
    })
    Pets:CreateDivider()

    Pets:CreateSection("Auto Leveling")
    -- Pets:CreateParagraph({
    --     Title = "INSTRUCTIONS:",
    --     Content = "1.) Setup the leveling loadout from 'Auto Pet Mutation'.\n2.) Make sure there 1 pet slot available in your leveling loadout. \n3.) Select desired level target and start Auto Level"
    -- })

    local selectedPetsForAutoLevel = {}
    local Dropdown_petListForAutoLevel = Pets:CreateDropdown({
        Name = "Select Pet/s",
        Options = allPetList,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "autoLevelPets", 
        Callback = function(Options)
            selectedPetsForAutoLevel = Options
        end,
    })

    --add search pet for auto leveling here
    --search pet
    local searchDebounce_petForAutoLeveling = nil
    Pets:CreateInput({
        Name = "Search",
        PlaceholderText = "Search Pet...",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_petForAutoLeveling then
                task.cancel(searchDebounce_petForAutoLeveling)
            end

            searchDebounce_petForAutoLeveling = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = allPetList
                else
                    for _, petName in ipairs(allPetList) do
                        if string.find(string.lower(petName), query, 1, true) then
                            table.insert(results, petName)
                        end
                    end
                end

                Dropdown_petListForAutoLevel:Refresh(results)
                Dropdown_petListForAutoLevel:Set(selectedPetsForAutoLevel) --set to current selected

            end)
        end,
    })

    Pets:CreateButton({
        Name = "Clear selection",
        Callback = function()
            Dropdown_petListForAutoLevel:Set({}) --  
        end,
    })

    local levelingLoadoutA
    local dropdown_autolevel_A = Pets:CreateDropdown({
        Name = "Leveling Loadout A",
        -- Options = {"None", "1", "2", "3", "4", "5", "6", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoadoutA", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            levelingLoadoutA = Options[1] or "None"
        end,
    })

    local targetLevelForAutoLevel = Pets:CreateInput({
        Name = "Target Level (A)",
        CurrentValue = "",
        PlaceholderText = "input number..",
        RemoveTextAfterFocusLost = false,
        Flag = "autoLeveltargetLevel",
        Callback = function(Text)
        -- The function that takes place when the input is changed
        -- The variable (Text) is a string for the value in the text box
        end,
    })

    local levelingLoadoutB
    local dropdown_autolevel_B = Pets:CreateDropdown({
        Name = "Leveling Loadout B",
        -- Options = {"None", "1", "2", "3", "4", "5", "6", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoadoutB", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            levelingLoadoutB = Options[1] or "None"
        end,
    })

    local targetLevelForAutoLevelB = Pets:CreateInput({
        Name = "Target Level (B)",
        CurrentValue = "",
        PlaceholderText = "input number..",
        RemoveTextAfterFocusLost = false,
        Flag = "autoLeveltargetLevelB",
        Callback = function(Text)
        -- The function that takes place when the input is changed
        -- The variable (Text) is a string for the value in the text box
        end,
    })


    local autoLevelEnabled = false
    local autoLevelThread = nil
    --early declare togggles to access Set:(false)
    local toggle_autoEle
    local toggle_autoNM
    local toggle_autoEleV2 -- for later

    Toggle_autoLevel = Pets:CreateToggle({
        Name = "Auto level",
        CurrentValue = false,
        Flag = "autoLevel",
        Callback = function(Value)
            autoLevelEnabled = Value

            --  Stop thread if turned off
            if not autoLevelEnabled then
                if autoLevelThread then
                    task.cancel(autoLevelThread)
                    autoLevelThread = nil
                    beastHubNotify("Auto Level stopped", "", 3)
                end
                return
            else
                --turn off auto hatching of auto level is on
                -- Toggle_smartAutoHatch:Set(false)
                toggle_autoEle:Set(false)
                toggle_autoNM:Set(false)
                toggle_autoEleV2:Set(false)
            end

            beastHubNotify("Auto level running", "",3)
            --
            local targetLevel = tonumber(targetLevelForAutoLevel.CurrentValue) or 0
            local targetLevelB = tonumber(targetLevelForAutoLevelB.CurrentValue) or 0
            local isNum = targetLevel
            local isNumB = targetLevelB
            local targetPetsForAutoLevel = Dropdown_petListForAutoLevel.CurrentOption or nil 
            
            -- Wait until Rayfield sets up the values (or timeout after 10s)
            local timeout = 3
            while timeout > 0 and (
                (not levelingLoadoutA or levelingLoadoutA == "None") and not (levelingLoadoutA and string.find(levelingLoadoutA, "custom", 1, true))
                or (not levelingLoadoutB or levelingLoadoutB == "None") and not (levelingLoadoutB and string.find(levelingLoadoutB, "custom", 1, true))
                or targetPetsForAutoLevel == nil or targetPetsForAutoLevel == "None"
                or not isNum
                or not isNumB
            ) do
                task.wait(.5)
                timeout = timeout - .5
                targetLevel = tonumber(targetLevelForAutoLevel.CurrentValue) or 0
                targetLevelB = tonumber(targetLevelForAutoLevelB.CurrentValue) or 0
                isNum = targetLevel or 0
                isNumB = targetLevelB or 0
                targetPetsForAutoLevel = Dropdown_petListForAutoLevel.CurrentOption or nil 
            end
            
            --actual checker
            local validA = levelingLoadoutA ~= "None" and targetLevel
	        local validB = levelingLoadoutB ~= "None" and targetLevelB

            if (not validA and not validB) 
            or Dropdown_petListForAutoLevel.CurrentOption == nil or Dropdown_petListForAutoLevel.CurrentOption[1] == "None" 
            or (not isNum and levelingLoadoutA ~= "None")
            or (not isNumB and levelingLoadoutB ~= "None") then
                beastHubNotify("Setup missing", "Please also make sure you select Leveling Loadout", 3)
                return
            end 

            -- beastHubNotify("Auto level running", "",3)

            -- Start auto-level thread
            autoLevelThread = task.spawn(function()
                local function getPlayerData()
                    local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                    local logs = dataService:GetData()
                    return logs
                end

                local function getPetInventory()
                    local playerData = getPlayerData()
                    if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                        return playerData.PetsData.PetInventory.Data
                    else
                        warn("PetsData not found!")
                        return nil
                    end
                end

                --OLD, all fav and unfav for leveling
                -- local function refreshPets()
                --     local pets = getPetInventory()
                --     local myPets = {}
                --     if pets then
                --         for uid, pet in pairs(pets) do
                --             table.insert(myPets, {
                --                 Uid = uid,
                --                 PetType = pet.PetType,
                --                 Uuid = pet.UUID,
                --                 PetData = pet.PetData
                --             })
                --         end
                --     end
                --     return myPets
                -- end

                --NEW, use unfavs only
                local function refreshPets()
                    local pets = getPetInventory()
                    local unfavoritePets = {}
                    if pets then
                        for uid, pet in pairs(pets) do
                            local entry = {
                                Uid = uid,
                                PetType = pet.PetType,
                                Uuid = pet.UUID, 
                                PetData = pet.PetData
                            }
                            if pet.PetData.IsFavorite then
                                --for favorites
                            else
                                table.insert(unfavoritePets, entry)
                            end
                        end
                    end
                    --
                    return unfavoritePets
                end

                local function equipPetByUuid(uuid)
                    local player = game.Players.LocalPlayer
                    local backpack = player:WaitForChild("Backpack")
                    for _, tool in ipairs(backpack:GetChildren()) do
                        if tool:GetAttribute("PET_UUID") == uuid then
                            player.Character.Humanoid:EquipTool(tool)
                        end
                    end
                end

                local function getPetEquipLocation()
                    local success, result = pcall(function()
                        local spawnCFrame = getFarmSpawnCFrame()
                        if typeof(spawnCFrame) ~= "CFrame" then
                            return nil
                        end
                        return spawnCFrame * CFrame.new(0, 0, -5)
                    end)
                    return success and result or nil
                end

                local function getCurrentPetLevelByUid(uid)
                    local playerData = getPlayerData()
                    if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                        for id, data in pairs(playerData.PetsData.PetInventory.Data) do
                            if tostring(id) == uid then
                                return data.PetData.Level
                            end
                        end
                    end
                    return nil
                end

                -- Main Logic
                --add loop for multi pets
                for i, petName in ipairs(targetPetsForAutoLevel) do
                    --print("Selected pet:", petName)

                    local allMyPets = refreshPets()
                    -- local selectedPet = Dropdown_petListForAutoLevel.CurrentOption[1]
                    local selectedPet = petName --changed to multi select
                    local petFound = false

                    --NEW leveling method
                    for _, pet in pairs(allMyPets) do 
                        if not autoLevelEnabled then break end

                        local curPet = pet.PetType
                        -- local uid = pet.Uuid
                        local uid = tostring(pet.Uid)
                        local curLevel = pet.PetData.Level

                        --A
                        if curPet == selectedPet and curLevel < targetLevel then
                            petFound = true
                            beastHubNotify("Found: " .. curPet, "with level: " .. curLevel, "3")
                            mainModule.isSafeToPickPlace = false
                            task.wait(1)
                            myFunctions.switchToLoadout(levelingLoadoutA, getFarmSpawnCFrame, beastHubNotify)
                            task.wait(6)

                            local petEquipLocation = getPetEquipLocation()
                            equipPetByUuid(uid)
                            task.wait()
                            mainModule.isSafeToPickPlace = true

                            local args = { "EquipPet", uid, petEquipLocation }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9)
                                :WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                            task.wait(1)

                            while autoLevelEnabled and curLevel < targetLevel do
                                beastHubNotify("Current Pet age: " .. curLevel, "Waiting to hit age " .. targetLevel, 3)
                                task.wait(5)
                                curLevel = getCurrentPetLevelByUid(uid)
                                if autoLevelEnabled and curLevel >= targetLevel then
                                    beastHubNotify("Target level reached for: " .. curPet .. "!", "Done for this pet", 3)
                                    task.wait(.5)
                                    local args = { "UnequipPet", uid }
                                    game:GetService("ReplicatedStorage")
                                        :WaitForChild("GameEvents", 9e9)
                                        :WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                    task.wait(1)
                                    break
                                end
                            end
                        end

                        --B
                        if curPet == selectedPet and curLevel < targetLevelB then
                            petFound = true
                            beastHubNotify("Found: " .. curPet, "with level: " .. curLevel, "3")
                            mainModule.isSafeToPickPlace = false
                            task.wait(1)
                            myFunctions.switchToLoadout(levelingLoadoutB, getFarmSpawnCFrame, beastHubNotify)
                            task.wait(6)

                            local petEquipLocation = getPetEquipLocation()
                            equipPetByUuid(uid)
                            task.wait()
                            mainModule.isSafeToPickPlace = true

                            local args = { "EquipPet", uid, petEquipLocation }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9)
                                :WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                            task.wait(1)

                            while autoLevelEnabled and curLevel < targetLevelB do
                                beastHubNotify("Current Pet age: " .. curLevel, "Waiting to hit age " .. targetLevelB, 3)
                                task.wait(5)
                                curLevel = getCurrentPetLevelByUid(uid)
                                if autoLevelEnabled and curLevel >= targetLevelB then
                                    beastHubNotify("Target level reached for: " .. curPet .. "!", "Done for this pet", 3)
                                    task.wait(.5)
                                    local args = { "UnequipPet", uid }
                                    game:GetService("ReplicatedStorage")
                                        :WaitForChild("GameEvents", 9e9)
                                        :WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                    task.wait(1)
                                    break
                                end
                            end
                        end
                    end

                    if not autoLevelEnabled then
                        return
                    elseif not petFound then
                        beastHubNotify(selectedPet.." not found", "", 3)
                        task.wait(1)
                    else
                        beastHubNotify("Auto Level cycle done!", "", 3)  
                    end
                end

                --  Cleanup
                autoLevelEnabled = false
                autoLevelThread = nil

            end)
        end,
    })
    Pets:CreateDivider()

    --Auto NM
    Pets:CreateSection("Auto Nightmare")
    -- Pets:CreateParagraph({
    --     Title = "INSTRUCTIONS:",
    --     Content = "1.) Setup the leveling loadout from 'Auto Pet Mutation'.\n2.) Input target level for Nightmare requirement below."
    -- })

    local selectedPetsForAutoNM
    local Dropdown_petListForAutoNM = Pets:CreateDropdown({
        Name = "Select Pet (excluded favorites)",
        Options = allPetList,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "autoNMPets", 
        Callback = function(Options)
            selectedPetsForAutoNM = Options
        end,
    })

    --add search pet for auto NM here
    --search pet
    local searchDebounce_petForAutoNM = nil
    Pets:CreateInput({
        Name = "Search",
        PlaceholderText = "Search Pet...",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_petForAutoNM then
                task.cancel(searchDebounce_petForAutoNM)
            end

            searchDebounce_petForAutoNM = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = allPetList
                else
                    for _, petName in ipairs(allPetList) do
                        if string.find(string.lower(petName), query, 1, true) then
                            table.insert(results, petName)
                        end
                    end
                end

                Dropdown_petListForAutoNM:Refresh(results)
                Dropdown_petListForAutoNM:Set(selectedPetsForAutoNM or {}) --set to current selected

            end)
        end,
    })
    Pets:CreateButton({
        Name = "Clear selection",
        Callback = function()
            Dropdown_petListForAutoNM:Set({}) --  
        end,
    })
    
    local levelingLoady_NM_A
    local dropdown_NM_loadout_A = Pets:CreateDropdown({
        Name = "Leveling Loadout A (required)",
        -- Options = {"None","custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoady_NM_A", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            levelingLoady_NM_A = Options[1]
        end,
    })
    
    local targetLevelForNM_A
    Pets:CreateInput({
        Name = "Target Level A (required)",
        CurrentValue = "",
        PlaceholderText = "Level",
        RemoveTextAfterFocusLost = false,
        Flag = "autoNMtargetLevel_A",
        Callback = function(Text)
            local num = tonumber(Text)
            if num then
                targetLevelForNM_A = num
            else
                targetLevelForNM_A = 30
            end
        end,
    })

    local levelingLoady_NM
    local dropdown_NM_loadout_B = Pets:CreateDropdown({
        Name = "Leveling Loadout B (optional)",
        -- Options = {"None","custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoady_NM", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            levelingLoady_NM = Options[1]
        end,
    })
    
    local targetLevelForNM
    Pets:CreateInput({
        Name = "Target Level B (optional)",
        CurrentValue = "",
        PlaceholderText = "Level",
        RemoveTextAfterFocusLost = false,
        Flag = "autoNMtargetLevel",
        Callback = function(Text)
            local num = tonumber(Text)
            if num then
                targetLevelForNM = num
            else
                targetLevelForNM = 30
            end
        end,
    })

    local delayToDropTarget 
    Pets:CreateInput({
        Name = "Delay to drop target pet (17)",
        CurrentValue = "",
        PlaceholderText = "seconds",
        RemoveTextAfterFocusLost = false,
        Flag = "delayToDropTargetInAutoNM",
        Callback = function(Text)
        local num = tonumber(Text)
            if num then
                delayToDropTarget = num
            else
                delayToDropTarget = 17
            end
        end,
    })
    local delayToDropHHteam 
    Pets:CreateInput({
        Name = "HH team drop interval (default 1.5)",
        CurrentValue = "",
        PlaceholderText = "seconds",
        RemoveTextAfterFocusLost = false,
        Flag = "delayToDropHHteam",
        Callback = function(Text)
        local num = tonumber(Text)
            if num then
                delayToDropHHteam = num
            else
                delayToDropHHteam = 1.5
            end
        end,
    })

    local horsemanLoady
    local dropdown_horseman_loadout = Pets:CreateDropdown({
        Name = "Horseman Loadout",
        -- Options = {"None", "custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "horsemanLoadoutNum", 
        Callback = function(Options)
            --if not Options or not Options[1] then return end
            horsemanLoady = Options[1]
        end,
    })

    local autoPickNM = false
    Pets:CreateToggle({
        Name = "Auto rejoin if NM",
        CurrentValue = false,
        Flag = "autoPickNM", 
        Callback = function(Value)
            autoPickNM = Value
        end,
    })

    local autoEleAfterAutoNMenabled
    local autoEleV2AfterAutoNMenabled

    --for single toggle only
    local toggle_autoEleAfterAutoNM
    local toggle_autoEleV2AfterAutoNM
    toggle_autoEleAfterAutoNM = Pets:CreateToggle({
        Name = "Auto Elephant after Auto NM",
        CurrentValue = false,
        Flag = "autoEleAfterAutoNM",
        Callback = function(Value)
            autoEleAfterAutoNMenabled = Value
            if Value then
                autoEleV2AfterAutoNMenabled = false
                toggle_autoEleV2AfterAutoNM:Set(false)
            end
        end,
    })

    toggle_autoEleV2AfterAutoNM = Pets:CreateToggle({
        Name = "Auto Elephant V2 after Auto NM",
        CurrentValue = false,
        Flag = "autoEleV2AfterAutoNM",
        Callback = function(Value)
            autoEleV2AfterAutoNMenabled = Value
            if Value then
                autoEleAfterAutoNMenabled = false
                toggle_autoEleAfterAutoNM:Set(false)
            end
        end,
    })

    local autoLevelAfterAutoNM = false
    Pets:CreateToggle({
        Name = "Auto Level after Auto NM",
        CurrentValue = false,
        Flag = "autoLevelAfterAutoNM", 
        Callback = function(Value)
            autoLevelAfterAutoNM = Value
        end,
    })


    local autoNMenabled
    local autoNMthread = nil
    local autoNMpickupNotif --for auto pickup if NM, mimic method
    
    toggle_autoNM = Pets:CreateToggle({
        Name = "Auto Nightmare",
        CurrentValue = false,
        Flag = "autoNightmare", 
        Callback = function(Value)
            autoNMenabled = Value
            
            local autoNM
            if autoNMenabled then
                beastHubNotify("Auto NM running", "", 3)
                Toggle_autoMutation:Set(false)
                Toggle_autoLevel:Set(false)

                -- Check for missing setup
                -- Wait until Rayfield sets up the values (or timeout after 10s)
                local timeout = 5
                -- while timeout > 0 and (
                --     (not levelingLoady_NM) and not (levelingLoady_NM and string.find(levelingLoady_NM, "custom", 1, true))
                --     or (not levelingLoady_NM_A or levelingLoady_NM_A == "None") and not (levelingLoady_NM_A and string.find(levelingLoady_NM_A, "custom", 1, true))
                --     or (not horsemanLoady or horsemanLoady == "None") and not (horsemanLoady and string.find(horsemanLoady, "custom", 1, true))
                --     or not selectedPetsForAutoNM
                --     or targetLevelForNM_A == nil
                --     or targetLevelForNM == nil                
                --     or autoEleAfterAutoNMenabled == nil 
                --     or autoEleV2AfterAutoNMenabled == nil
                --     or autoPickNM == nil
                --     or delayToDropTarget == nil
                --     or delayToDropHHteam == nil
                -- ) do
                --     task.wait(0.5)
                --     timeout = timeout - 0.5
                -- end
                --new
                while timeout > 0 and (
                    (
                        (not levelingLoady_NM or not string.find(levelingLoady_NM, "custom", 1, true))
                        and
                        (not levelingLoady_NM_A or not string.find(levelingLoady_NM_A, "custom", 1, true))
                    )
                    or (levelingLoady_NM_A and not string.find(levelingLoady_NM_A, "custom", 1, true))
                    or (levelingLoady_NM and not string.find(levelingLoady_NM, "custom", 1, true))
                    or (levelingLoady_NM_A and targetLevelForNM_A == nil)
                    or (levelingLoady_NM and targetLevelForNM == nil)
                    or not horsemanLoady or not string.find(horsemanLoady, "custom", 1, true)
                    or not selectedPetsForAutoNM
                    or autoEleAfterAutoNMenabled == nil
                    or autoEleV2AfterAutoNMenabled == nil
                    or autoPickNM == nil
                    or delayToDropTarget == nil
                    or delayToDropHHteam == nil
                ) do
                    task.wait(0.5)
                    timeout = timeout - 0.5
                end
                --checkers here, final check, works for sudden reconnection
                if delayToDropTarget == nil then
                    delayToDropTarget = 0
                end
                if delayToDropHHteam == nil then
                    delayToDropHHteam = 1.5
                end
                if (not levelingLoady_NM_A or levelingLoady_NM_A == "None") and not (levelingLoady_NM_A and string.find(levelingLoady_NM_A, "custom", 1, true))
                or not selectedPetsForAutoNM 
                or (not horsemanLoady or horsemanLoady == "None") and not (horsemanLoady and string.find(horsemanLoady, "custom", 1, true))
                or not targetLevelForNM_A then
                    beastHubNotify("Missing setup!", "", 10)
                    return
                end

                autoNM = function(selectedPetForAutoNM, onComplete)
                    local petFound = false
                    local HttpService = game:GetService("HttpService")
                
                    local function getPlayerData()
                        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                        local logs = dataService:GetData()
                        return logs
                    end
                
                    local function getPetInventory()
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            return playerData.PetsData.PetInventory.Data
                        else
                            warn("PetsData not found!")
                            return nil
                        end
                    end

                    local function getCurrentPetLevelByUid(uid)
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            for id, data in pairs(playerData.PetsData.PetInventory.Data) do
                                if(tostring(id) == uid) then
                                    return data.PetData.Level
                                end
                            end
                            return nil
                        else
                            warn("PetsData not found!")
                            return nil
                        end
                    end

                    local function getPetMutationEnumByUid(uid)
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            for id, data in pairs(playerData.PetsData.PetInventory.Data) do
                                if tostring(id) == uid then
                                    return data.PetData.MutationType
                                end
                            end
                            return nil
                        else
                            warn("Pet Mutation not found!")
                            return nil
                        end
                    end

                    -- Function you can call anytime to refresh pets data
                    local function refreshPets()
                        -- USAGE: local favs, unfavs = refreshPets()
                        local pets = getPetInventory()
                        local favoritePets, unfavoritePets = {}, {}
                        if pets then
                            for uid, pet in pairs(pets) do
                                local entry = {
                                    Uid = uid,
                                    PetType = pet.PetType,
                                    Uuid = pet.UUID, 
                                    PetData = pet.PetData
                                }
                                if pet.PetData.IsFavorite then
                                    table.insert(favoritePets, entry)
                                else
                                    table.insert(unfavoritePets, entry)
                                end
                            end
                        end
                        --
                        return favoritePets, unfavoritePets
                    end

                    local function equipItemByName(itemName)
                        local player = game.Players.LocalPlayer
                        local backpack = player:WaitForChild("Backpack")
                        player.Character.Humanoid:UnequipTools() --unequip all first

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

                    local function equipPetByUuid(uuid)
                        local player = game.Players.LocalPlayer
                        local backpack = player:WaitForChild("Backpack")
                        for _, tool in ipairs(backpack:GetChildren()) do
                            if tool:GetAttribute("PET_UUID") == uuid then
                                player.Character.Humanoid:EquipTool(tool)
                            end
                        end
                    end

                    local function getPetEquipLocation()
                        local success, result = pcall(function()
                            local spawnCFrame = getFarmSpawnCFrame()
                            if typeof(spawnCFrame) ~= "CFrame" then
                                return nil
                            end
                            -- offset forward 5 studs
                            return spawnCFrame * CFrame.new(0, 0, -5)
                        end)
                        if success then
                            return result
                        else
                            warn("[getPetEquipLocation] Error: " .. tostring(result))
                            return nil
                        end
                    end

                    local function getMachineMutationsData() --all mutation data including enums
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")
                        local success, PetMutationRegistry = pcall(function()
                            return require(
                                ReplicatedStorage:WaitForChild("Data")
                                    :WaitForChild("PetRegistry")
                                    :WaitForChild("PetMutationRegistry")
                            )
                        end)
                        if not success or type(PetMutationRegistry) ~= "table" then
                            warn("Failed to load PetMutationRegistry module.")
                            return {}
                        end
                        local machineMutations = PetMutationRegistry.MachineMutationTypes
                        if type(machineMutations) ~= "table" then
                            warn("MachineMutationTypes not found in PetMutationRegistry.")
                            return {}
                        end
                        -- table.sort(machineMutations)
                        return machineMutations
                    end

                    local function getMachineMutationsDataWithPrint() -- all mutation data including enums
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")

                        local success, PetMutationRegistry = pcall(function()
                            return require(
                                ReplicatedStorage:WaitForChild("Data")
                                    :WaitForChild("PetRegistry")
                                    :WaitForChild("PetMutationRegistry")
                            )
                        end)

                        if not success or type(PetMutationRegistry) ~= "table" then
                            warn("Failed to load PetMutationRegistry module.")
                            return {}
                        end

                        local machineMutations = PetMutationRegistry.EnumToPetMutation
                        if type(machineMutations) ~= "table" then
                            warn("MachineMutationTypes not found in PetMutationRegistry.")
                            return {}
                        end

                        return machineMutations
                    end

                    function loadCustomTeamWithDelay(customName, delay)
                        local function getPetEquipLocation()
                            local ok, result = pcall(function()
                                local spawnCFrame = getFarmSpawnCFrame()
                                if typeof(spawnCFrame) ~= "CFrame" then
                                    return nil
                                end
                                return spawnCFrame * CFrame.new(0, 0, -5)
                            end)
                            if ok then
                                return result
                            else
                                warn("EquipLocationError " .. tostring(result))
                                return nil
                            end
                        end

                        local function parseFromFile()
                            local ids = {}
                            local ok, content = pcall(function()
                                return readfile("BeastHub/"..customName..".txt")
                            end)
                            if not ok then
                                warn("Failed to read "..customName..".txt")
                                return ids
                            end
                            for line in string.gmatch(content, "([^\n]+)") do
                                local id = string.match(line, "({[%w%-]+})") -- keep the {} with the ID
                                if id then
                                    -- print("id loaded")
                                    -- print(id or "")
                                    table.insert(ids, id)
                                end
                            end
                            return ids
                        end

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

                            local tempStorage = playerData.PetsData.EquippedPets
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
                        local equipped = equippedPets()
                        if equipped and #equipped > 0 then
                            for _,id in ipairs(equipped) do
                                local args = {
                                    [1] = "UnequipPet";
                                    [2] = id;
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                task.wait()
                            end
                        end

                        local location = getPetEquipLocation()
                        local petIds = parseFromFile()

                        if #petIds == 0 then
                            beastHubNotify(customName.." is empty", "", 3)
                            return
                        end

                        for _, id in ipairs(petIds) do
                            local args = {
                                [1] = "EquipPet";
                                [2] = id;
                                [3] = location;
                            }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                            task.wait(delay)
                        end
                        -- beastHubNotify("Loaded "..customName, "", 3)
                    end

                    local function equippedPets()
                        local playerData = getPlayerData()
                        if not playerData.PetsData then
                            return nil
                        end
                        local tempStorage = playerData.PetsData.EquippedPets
                        if not tempStorage or type(tempStorage) ~= "table" then
                            return nil
                        end
                        local petIdsList = {}
                        for _, id in ipairs(tempStorage) do
                            table.insert(petIdsList, id)
                        end
                        return petIdsList
                    end


                    --main function code
                    --vars
                    local favs, unfavs = refreshPets()
                    task.wait(1)
                    local message = "Auto Nightmare stopped"

                    --main loop for unfavs
                    for _, pet in pairs(unfavs) do 
                        local curPet = pet.PetType
                        -- local uid = pet.Uuid --bug, not all pet inventory has UUID
                        local uid = tostring(pet.Uid)
                        local curLevel = pet.PetData.Level
                        local curMutationEnum = pet.PetData.MutationType
                        local curMutation -- fetch later after enums fetch
                        local machineMutationEnums = {} --pet mutation enums container
                        -- local mutations = getMachineMutationsData() --all mutation data
                        local mutations = getMachineMutationsDataWithPrint()
                        for enum, value in pairs(mutations) do --extract only enums
                            table.insert(machineMutationEnums, {enum, value})
                        end
                        --get current pet mutation via enum
                        for _, entry in ipairs(machineMutationEnums) do
                            local mutation = entry[2]
                            local enumId = entry[1]
                            if enumId == curMutationEnum then
                                curMutation = mutation
                                break
                            end
                        end

                        
                        
                        if autoNMenabled and curPet == selectedPetForAutoNM then
                            if curMutation ~= "Nightmare" then
                                beastHubNotify("Pet found: "..curPet, curMutation or "", 5)
                                --conditions
                                if curMutation == nil then
                                    beastHubNotify("Pet found has no mutation yet", "", 3) 
                                end
                                petFound = true
                                --switch to leveling
                                mainModule.isSafeToPickPlace = false
                                task.wait(1)
                                myFunctions.switchToLoadout(levelingLoady_NM_A, getFarmSpawnCFrame, beastHubNotify)
                                task.wait(3)
                                equipPetByUuid(uid)
                                task.wait()
                                --place pet to garden for leveling                                    
                                local petEquipLocation = getPetEquipLocation()
                                local args = {
                                    [1] = "EquipPet",
                                    [2] = uid,
                                    [3] = petEquipLocation, 
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                task.wait(3)
                                -- mainModule.isSafeToPickPlace = true

                                --equip cleanse and fire
                                -- mainModule.isSafeToPickPlace = false
                                if equipItemByName("Cleansing Pet Shard") == false then 
                                    -- beastHubNotify("No more cleansing shards!", "", 4)
                                    -- return    
                                else
                                    -- beastHubNotify("Cleansing now..", "", 3) 
                                end 
                                task.wait(.5)
                                --cleanse event
                                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                                local PetShardService_RE = ReplicatedStorage.GameEvents.PetShardService_RE -- RemoteEvent
                                -- Find pet model anywhere inside PetsPhysical
                                local petPhysical = workspace:WaitForChild("PetsPhysical")
                                local targetPet = petPhysical:FindFirstChild(tostring(uid), true) -- 'true' enables recursive search
                                if targetPet then
                                    PetShardService_RE:FireServer("ApplyShard", targetPet)
                                    -- print(" Fired ApplyShard for pet UID:", uid, "found at", targetPet:GetFullName())
                                else
                                    beastHubNotify("Cannot apply shard", "Pet not in garden", 3)
                                    local playerName = game.Players.LocalPlayer.Name
                                    local webhookMsg = "[BeastHub] "..playerName.." | Auto Nightmare: "..curPet.."= Failed to cleanse!"
                                    sendDiscordWebhook(M.webhookURL, webhookMsg)
                                    break
                                end
                                mainModule.isSafeToPickPlace = true
                                task.wait(2)
                                --unequip shard
                                -- game.Players.LocalPlayer.Character.Humanoid:UnequipTools()

                                --monitor level
                                --if provided A only
                                if levelingLoady_NM == "None" or levelingLoady_NM == nil then
                                    targetLevelForNM = targetLevelForNM_A
                                end

                                --A
                                while autoNMenabled and curLevel < targetLevelForNM_A and targetLevelForNM_A ~= 0 do
                                    beastHubNotify("Current Pet age: "..curLevel, "waiting to hit age "..targetLevelForNM_A.."..",3)
                                    task.wait(5)
                                    curLevel = getCurrentPetLevelByUid(uid)
                                end

                                --B

                                if levelingLoady_NM ~= "None" then
                                    mainModule.isSafeToPickPlace = false
                                    task.wait(1)
                                    myFunctions.switchToLoadout(levelingLoady_NM, getFarmSpawnCFrame, beastHubNotify)
                                    task.wait(3)
                                    equipPetByUuid(uid)
                                    task.wait()
                                    --place pet to garden for leveling                                    
                                    local petEquipLocation = getPetEquipLocation()
                                    local args = {
                                        [1] = "EquipPet",
                                        [2] = uid,
                                        [3] = petEquipLocation, 
                                    }
                                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                    task.wait(1)
                                    mainModule.isSafeToPickPlace = true  
                                    
                                    while autoNMenabled and curLevel < targetLevelForNM do
                                        beastHubNotify("Current Pet age: "..curLevel, "waiting to hit age "..targetLevelForNM.."..",3)
                                        task.wait(5)
                                        curLevel = getCurrentPetLevelByUid(uid)
                                    end
                                end
                                
                                --unequip once ready
                                local args = {
                                    [1] = "UnequipPet";
                                    [2] = uid;
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                task.wait(1) 

                                --switch to NM loady
                                if autoNMenabled then 
                                    mainModule.isSafeToPickPlace = false
                                    task.wait(1)

                                    --pickup all here, to avoid dilo spitting to horseman loadout pets
                                    local equipped = equippedPets()
                                    for _,id in ipairs(equipped) do
                                        local args = {
                                            [1] = "UnequipPet";
                                            [2] = id;
                                        }
                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                        task.wait()
                                    end
                                    task.wait(5) --wait for dilo spits to clear

                                    --switch to HH
                                    local dropAt = os.clock() + delayToDropTarget
                                    task.spawn(function()
                                        loadCustomTeamWithDelay(horsemanLoady, delayToDropHHteam)
                                    end)
                                    beastHubNotify("Delay to drop: "..tostring(delayToDropTarget), "", delayToDropTarget)
                                    while os.clock() < dropAt do
                                        task.wait(0.05)
                                    end
                                    local args = {
                                        [1] = "EquipPet",
                                        [2] = uid,
                                        [3] = petEquipLocation,
                                    }
                                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetsService",9e9):FireServer(unpack(args))
                                    task.wait(2)
                                    mainModule.isSafeToPickPlace = true


                                    --monitor if curLevel dropped
                                    -- while autoNMenabled and curLevel >= targetLevel do
                                    --     beastHubNotify("Ready for Nightmare!", "Waiting for NM skill..",3)
                                    --     task.wait(5)
                                    --     curLevel = getCurrentPetLevelByUid(uid)
                                    -- end

                                    --test new monitoring, mimic method
                                    if autoPickNM == true then
                                        local lastLevelCheck = 0
                                        while autoNMenabled and curLevel >= targetLevelForNM do
                                            task.wait(0.001)
                                            local updatedEnum = getPetMutationEnumByUid(uid)
                                            if updatedEnum == "A" then
                                                myFunctions.delayedRejoin(0)
                                                -- local args = {
                                                --     [1] = "UnequipPet";
                                                --     [2] = uid;
                                                -- }
                                                -- game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                                task.wait()
                                                -- beastHubNotify("NM detected", "", 3)
                                            end
                                            if os.clock() - lastLevelCheck >= 20 then
                                                curLevel = getCurrentPetLevelByUid(uid)
                                                lastLevelCheck = os.clock()
                                            end
                                        end
                                    else --default method
                                        while autoNMenabled and curLevel >= targetLevelForNM do
                                            beastHubNotify("Ready for Nightmare!", "Waiting for NM skill..",3)
                                            task.wait(5)
                                            curLevel = getCurrentPetLevelByUid(uid)
                                        end
                                    end


                                    task.wait(.5)

                                    --unequip upon exit
                                    local args = {
                                        [1] = "UnequipPet";
                                        [2] = uid;
                                    }
                                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                    task.wait(1) 

                                    --get updated mutation for webhook if enabled
                                    if autoNMenabled and M.autoNMwebhook and curLevel < targetLevelForNM  then
                                        --get updated enuma
                                        beastHubNotify("Sending webhook","",3)
                                        -- print("Sending webhook..")
                                        -- print(curPet)
                                        -- print(uid)
                                        -- print(curLevel)
                                        task.wait(1)
                                        local updatedEnum = getPetMutationEnumByUid(uid)
                                        -- print("updatedEnum:")
                                        -- print(updatedEnum)
                                        local updatedMutation = "default_empty"
                                        --get updated pet mutation via enum
                                        for _, entry in ipairs(machineMutationEnums) do
                                            local mutation = entry[2]
                                            local enumId = entry[1]
                                            if enumId == updatedEnum then
                                                updatedMutation = mutation
                                                -- print("updatedMutation: "..updatedMutation)
                                                break
                                            end
                                        end
                                        --
                                        local playerName = game.Players.LocalPlayer.Name
                                        local webhookMsg = "[BeastHub] "..playerName.." | Auto Nightmare result: "..curPet.."="..updatedMutation
                                        sendDiscordWebhook(M.webhookURL, webhookMsg)
                                        -- beastHubNotify("Webhook sent", "", 2)
                                        task.wait(1)
                                    end

                                    

                                end
                                return
                            end
                        end --end if curpet is match
                        -- task.wait(10)

                    end -- end main for loop

                    --  Call the callback AFTER finishing
                    if petFound == false then 
                        message = "No eligible pet"                     
                    end
                    if typeof(onComplete) == "function" then
                        onComplete(message)
                    end

                end --autoNM function end

                --MAIN logic
                autoNMthread = nil
                if autoNMenabled and not autoNMthread then
                    autoNMthread = task.spawn(function()
                        while autoNMenabled do
                            local notFoundCount = 0
                            for _,selectedPetForAutoNM in ipairs(selectedPetsForAutoNM) do
                                if not autoNMenabled then
                                    break
                                end
                                autoNM(selectedPetForAutoNM, function(msg)
                                    if msg == "No eligible pet" then
                                        beastHubNotify("Not found: "..selectedPetForAutoNM, "Make sure to select the correct pet", 3)
                                        notFoundCount = notFoundCount + 1
                                        task.wait(1)
                                    else
                                        beastHubNotify(msg, "", 5)
                                        return
                                    end
                                end) --end function call
                                task.wait(2)    
                            end

                            --add auto ele condition
                            if autoNMenabled and autoEleAfterAutoNMenabled == true and notFoundCount == #selectedPetsForAutoNM then
                                beastHubNotify("Auto Elephant triggered", "", 3)
                                toggle_autoEle:Set(true)
                                return
                            end
                            --add auto ele condition v2
                            if autoNMenabled and autoEleV2AfterAutoNMenabled == true and notFoundCount == #selectedPetsForAutoNM then
                                beastHubNotify("Auto Elephant V2 triggered", "", 3)
                                toggle_autoEleV2:Set(true)
                                return
                            end
                            --auto level
                            if autoNMenabled and autoLevelAfterAutoNM == true and notFoundCount == #selectedPetsForAutoNM then
                                beastHubNotify("Auto Leveling triggered", "", 3)
                                Toggle_autoLevel:Set(true)
                                return
                            end

                            if notFoundCount == #selectedPetsForAutoNM then
                                autoNMenabled = false
                                if autoNMthread then
                                    autoNMthread = nil
                                end
                            end

                            
                        end --end while
                    end) --end thread spawn
                end
            else
                autoNMenabled = false
                if autoNMthread then
                    autoNMthread = nil
                end
            end      
        end,
    })
    Pets:CreateDivider()

    --Auto Elephant
    Pets:CreateSection("Auto Elephant")
    -- Pets:CreateParagraph({
    --     Title = "INSTRUCTIONS:",
    --     Content = "1.) Setup the leveling loadout from 'Auto Pet Mutation'.\n2.) Fill up the rest below."
    -- })

    local selectedPetsForAutoEle = {}
    local Dropdown_petListForAutoEle = Pets:CreateDropdown({
        Name = "Select Pet (excluded favorites)",
        Options = allPetList,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "autoElePets", 
        Callback = function(Options)
            selectedPetsForAutoEle = Options
        end,
    })

    local searchDebounce_petForAutoEle = nil
    Pets:CreateInput({
        Name = "Search",
        PlaceholderText = "Search Pet...",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if searchDebounce_petForAutoEle then
                task.cancel(searchDebounce_petForAutoEle)
            end

            searchDebounce_petForAutoEle = task.delay(0.5, function()
                local results = {}
                local query = string.lower(Text)

                if query == "" then
                    results = allPetList
                else
                    for _, petName in ipairs(allPetList) do
                        if string.find(string.lower(petName), query, 1, true) then
                            table.insert(results, petName)
                        end
                    end
                end

                Dropdown_petListForAutoEle:Refresh(results)
                Dropdown_petListForAutoEle:Set(selectedPetsForAutoEle or {}) --set to current selected

            end)
        end,
    })

    local elephantUsed = Pets:CreateDropdown({
        Name = "Elephant Used",
        Options = {"Normal Elephant", "RBH Elephant"},
        CurrentOption = {"Normal Elephant"},
        MultipleOptions = false,
        Flag = "elephantUsed", 
        Callback = function(Options)
        end,
    })

    local targetKGForEle = Pets:CreateInput({
        Name = "Target Base KG",
        CurrentValue = "3.85",
        PlaceholderText = "input KG",
        RemoveTextAfterFocusLost = false,
        Flag = "autoEletargetKG",
        Callback = function(Text)

        end,
    })

    local levelingLoadyV1
    local dropdown_eleV1_leveling_A = Pets:CreateDropdown({
        Name = "Leveling Loadout",
        -- Options = {"custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoadyV1", 
        Callback = function(Options)
            levelingLoadyV1 = Options[1]
        end,
    })

    local elephantLoady
    local dropdown_eleV1_loadout = Pets:CreateDropdown({
        Name = "Elephant Loadout",
        -- Options = {"custom_1", "custom_2", "custom_3", "custom_4", "custom_5", "custom_6", "custom_7", "custom_8", "custom_9", "custom_10"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "elephantLoadoutNum", 
        Callback = function(Options)
            elephantLoady = Options[1]
        end,
    })

    
    local autoLevelAfterAutoEleEnabled = false
    local toggle_autoLevelAfterAutoEle = Pets:CreateToggle({
        Name = "Auto Level after Auto Elephant",
        CurrentValue = false,
        Flag = "autoLevelAfterAutoEle", 
        Callback = function(Value)
            autoLevelAfterAutoEleEnabled = Value
        end,
    })

    local autoEleEnabled
    local autoEleThread = nil
    toggle_autoEle = Pets:CreateToggle({
        Name = "Auto Elephant",
        CurrentValue = false,
        Flag = "autoElephant", 
        Callback = function(Value)
            autoEleEnabled = Value
            local autoEle --function declaration

            if autoEleEnabled then
                Toggle_autoMutation:Set(false)
                toggle_autoNM:Set(false)
                Toggle_autoLevel:Set(false)

                local timeout = 10
                while timeout > 0 and (
                    (not levelingLoadyV1 or levelingLoadyV1 == "None") and not (levelingLoadyV1 and string.find(levelingLoadyV1, "custom", 1, true))
                    or (not elephantLoady or elephantLoady == "None") and not (elephantLoady and string.find(elephantLoady, "custom", 1, true))
                    or next(selectedPetsForAutoEle) == nil
                    or elephantUsed.CurrentOption[1] == nil
                    or not tonumber(targetKGForEle.CurrentValue)
                    or autoLevelAfterAutoEleEnabled == nil 
                ) do
                    task.wait(.5)
                    timeout = timeout - .5
                end
                --checkers here, final check, works for sudden reconnection
                local targetKG = tonumber(targetKGForEle.CurrentValue)
                local eleUsed = elephantUsed.CurrentOption[1]
                local isNumKG = targetKG

                if (not levelingLoadyV1 or levelingLoadyV1 == "None")  and not (levelingLoadyV1 and string.find(levelingLoadyV1, "custom", 1, true))
                or next(selectedPetsForAutoEle) == nil
                or (not elephantLoady or elephantLoady == "None")  and not (elephantLoady and string.find(elephantLoady, "custom", 1, true))
                or not isNumKG 
                or not eleUsed or eleUsed == "" then
                    beastHubNotify("Missing setup!", "", 10)
                    return
                end

                --main function declaration
                autoEle = function(selectedPetForAutoEle, onComplete)
                    local HttpService = game:GetService("HttpService")

                    local function getPlayerData()
                        local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                        local logs = dataService:GetData()
                        return logs
                    end

                    local function getPetInventory()
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            return playerData.PetsData.PetInventory.Data
                        else
                            warn("PetsData not found!")
                            return nil
                        end
                    end

                    local function getCurrentPetLevelByUid(uid)
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            for id, data in pairs(playerData.PetsData.PetInventory.Data) do
                                if(tostring(id) == uid) then
                                    return data.PetData.Level
                                end
                            end
                            return nil
                        else
                            warn("PetsData not found!")
                            return nil
                        end
                    end

                    local function getCurrentPetKGByUid(uid)
                        local playerData = getPlayerData()
                        if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                            for id, data in pairs(playerData.PetsData.PetInventory.Data) do
                                if(tostring(id) == uid) then
                                    return data.PetData.BaseWeight
                                end
                            end
                            return nil
                        else
                            warn("PetsData not found!")
                            return nil
                        end
                    end

                    local function refreshPets()
                        -- USAGE: local favs, unfavs = refreshPets()
                        local pets = getPetInventory()
                        local favoritePets, unfavoritePets = {}, {}
                        if pets then
                            for uid, pet in pairs(pets) do
                                local entry = {
                                    Uid = uid,
                                    PetType = pet.PetType,
                                    Uuid = pet.UUID, 
                                    PetData = pet.PetData
                                }
                                if pet.PetData.IsFavorite then
                                    table.insert(favoritePets, entry)
                                else
                                    table.insert(unfavoritePets, entry)
                                end
                            end
                        end
                        --
                        return favoritePets, unfavoritePets
                    end

                    local function equipPetByUuid(uuid)
                        local player = game.Players.LocalPlayer
                        local backpack = player:WaitForChild("Backpack")
                        for _, tool in ipairs(backpack:GetChildren()) do
                            if tool:GetAttribute("PET_UUID") == uuid then
                                player.Character.Humanoid:EquipTool(tool)
                            end
                        end
                    end

                    local function getPetEquipLocation()
                        local success, result = pcall(function()
                            local spawnCFrame = getFarmSpawnCFrame()
                            if typeof(spawnCFrame) ~= "CFrame" then
                                return nil
                            end
                            -- offset forward 5 studs
                            return spawnCFrame * CFrame.new(0, 0, -5)
                        end)
                        if success then
                            return result
                        else
                            warn("[getPetEquipLocation] Error: " .. tostring(result))
                            return nil
                        end
                    end

                    --main function code
                    local favs, unfavs = refreshPets()
                    task.wait(1)
                    local petFound = false
                    local message = "Auto Elephant stopped"
                    local targetLevel
                    if eleUsed == "Normal Elephant" then
                        -- targetKG = 3.85
                        targetLevel = 50
                    else
                        -- targetKG = 6.05
                        targetLevel = 40
                    end

                    --main loop for unfavs
                    for _, pet in pairs(unfavs) do 
                        local curPet = pet.PetType
                        local uid = tostring(pet.Uid)
                        local curLevel = pet.PetData.Level
                        local curBaseKG = tonumber(pet.PetData.BaseWeight) * 1.1

                        if autoEleEnabled and curPet == selectedPetForAutoEle and targetKG > curBaseKG then
                            beastHubNotify("Target found", "Auto Elephant", 3)
                            beastHubNotify(curPet, "Base KG: "..curBaseKG, 3)
                            petFound = true

                            --switch to leveling
                            mainModule.isSafeToPickPlace = false
                            task.wait(1)
                            myFunctions.switchToLoadout(levelingLoadyV1, getFarmSpawnCFrame, beastHubNotify)
                            task.wait(6)
                            equipPetByUuid(uid)
                            task.wait()
                            --place pet to garden for leveling                                    
                            local petEquipLocation = getPetEquipLocation()
                            local args = {
                                [1] = "EquipPet",
                                [2] = uid,
                                [3] = petEquipLocation, 
                            }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                            task.wait(1)
                            mainModule.isSafeToPickPlace = true
                            
                            --monitor level
                            while autoEleEnabled and curLevel < targetLevel do
                                beastHubNotify("Current Pet age: "..curLevel, "waiting to hit age "..targetLevel.."..",3)
                                task.wait(5)
                                curLevel = getCurrentPetLevelByUid(uid)
                            end

                            --unequip once ready
                            local args = {
                                [1] = "UnequipPet";
                                [2] = uid;
                            }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                            task.wait(1) 

                            --swtich to Ele loady
                            if autoEleEnabled then 
                                mainModule.isSafeToPickPlace = false
                                task.wait(1)
                                myFunctions.switchToLoadout(elephantLoady, getFarmSpawnCFrame, beastHubNotify)
                                task.wait(6)
                                --equip to garden
                                local args = {
                                    [1] = "EquipPet",
                                    [2] = uid,
                                    [3] = petEquipLocation, 
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                task.wait(2)
                                mainModule.isSafeToPickPlace = true

                                --monitor if curLevel dropped
                                while autoEleEnabled and curLevel >= targetLevel do
                                    -- local delayInSecs = (delayInMins * 60) or nil
                                    beastHubNotify("Ready for Elephant!", "Waiting for Elephant skill..",2)
                                    task.wait(5)
                                    curLevel = getCurrentPetLevelByUid(uid)
                                end
                                task.wait(.3)

                                --unequip upon exit
                                local args = {
                                    [1] = "UnequipPet";
                                    [2] = uid;
                                }
                                game:GetService("ReplicatedStorage"):WaitForChild("GameEvents", 9e9):WaitForChild("PetsService", 9e9):FireServer(unpack(args))
                                task.wait(.2) 

                                --webhook if enabled
                                if autoEleEnabled and M.autoEleWebhook and curLevel < targetLevel  then
                                    -- local updatedKG = tostring(curBaseKG + 0.1) --static adding of KG instead of get base KG
                                    curBaseKG = getCurrentPetKGByUid(uid)
                                    local updatedKG = string.format("%.2f", curBaseKG * 1.1)
                                    
                                    beastHubNotify("Sending webhook","",3)
                                    local playerName = game.Players.LocalPlayer.Name
                                    local webhookMsg = "[BeastHub] "..playerName.." | Auto Elephant result: "..curPet.."="..updatedKG.."KG"
                                    sendDiscordWebhook(M.webhookURL, webhookMsg)
                                    task.wait(1)
                                end
                            end
                            return
                        end
                        
                    end --end for loop

                    if petFound == false then 
                        message = "No eligible pet"                     
                    end
                    if typeof(onComplete) == "function" then
                        onComplete(message)
                    end
                end --autoEle end

                --MAIN logic
                autoEleThread = nil
                if autoEleEnabled and not autoEleThread then
                    autoEleThread = task.spawn(function()
                        -- while autoEleEnabled do
                        --     beastHubNotify("Auto Elephant running", "", 3)
                        --     for _,selectedPetForAutoEle in ipairs(selectedPetsForAutoEle) do
                        --         autoEle(selectedPetForAutoEle, function(msg)
                        --             if msg == "No eligible pet" then
                        --                 beastHubNotify("Not found..", "Make sure to select the correct pet", 3)
                        --                 -- autoEleEnabled = false
                        --                 task.wait(1)
                        --             else
                        --                 beastHubNotify(msg, "", 5)
                        --             end
                        --         end) --end function call
                        --         task.wait(.1)    
                        --     end
                        --     --add auto level condition
                        --     if autoLevelAfterAutoEleEnabled == true and autoEleEnabled then
                        --         beastHubNotify("Auto Leveling triggered", "", 3)
                        --         Toggle_autoLevel:Set(true)
                        --     end
                            
                        -- end --end while
                        -- beastHubNotify("Auto Elephant Stopped", "", 3)
                        --new
                        while autoEleEnabled do
                            local notFoundCount = 0
                            beastHubNotify("Auto Elephant running", "", 3)
                            for _,selectedPetForAutoEle in ipairs(selectedPetsForAutoEle) do
                                if not autoEleEnabled then
                                    break
                                end
                                autoEle(selectedPetForAutoEle, function(msg)
                                    if msg == "No eligible pet" then
                                        beastHubNotify("Not found: "..selectedPetForAutoEle, "Make sure to select the correct pet", 3)
                                        notFoundCount = notFoundCount + 1
                                        task.wait(1)
                                    else
                                        beastHubNotify(msg, "", 5)
                                        return
                                    end
                                end)
                                task.wait(.1)
                            end
                            if autoEleEnabled and autoLevelAfterAutoEleEnabled == true and notFoundCount == #selectedPetsForAutoEle then
                                beastHubNotify("Auto Leveling triggered", "", 3)
                                Toggle_autoLevel:Set(true)
                            end
                            if notFoundCount == #selectedPetsForAutoEle then
                                autoEleEnabled = false
                                if autoEleThread then
                                    autoEleThread = nil
                                end
                            end
                        end
                        beastHubNotify("Auto Elephant Stopped", "", 3)
                    end) -- end thread spawn
                end 
            else
                autoEleEnabled = false
                if autoEleThread then
                    autoEleThread = nil
                end
                
            end
        end,
    })
    Pets:CreateDivider()


    --Auto Elephant V2
	Pets:CreateSection("Auto Elephant V2")
	local v2_selectedPets
	local v2_petDropdown = Pets:CreateDropdown({
		Name = "Choose Pet/s (non-favorite)",
		Options = allPetList,
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "v2_autoElePet",
		Callback = function(Options)
			v2_selectedPets = Options
		end,
	})
	local v2_searchTask = nil
	Pets:CreateInput({
		Name = "Pet Search",
		PlaceholderText = "Type pet name",
		RemoveTextAfterFocusLost = false,
		Callback = function(Text)
			if v2_searchTask then
				task.cancel(v2_searchTask)
			end
			v2_searchTask = task.delay(0.5, function()
				local filtered = {}
				local query = string.lower(Text)
				if query == "" then
					filtered = allPetList
				else
					for _, name in ipairs(allPetList) do
						if string.find(string.lower(name), query, 1, true) then
							table.insert(filtered, name)
						end
					end
				end
				v2_petDropdown:Refresh(filtered)
				v2_petDropdown:Set(v2_selectedPets)
			end)
		end,
	})

    Pets:CreateButton({
        Name = "Clear selection",
        Callback = function()
            v2_petDropdown:Set({}) --  
        end,
    })

	-- local v2_targetLevel = Pets:CreateInput({
	-- 	Name = "Target Level",
	-- 	CurrentValue = "50",
	-- 	PlaceholderText = "Enter level",
	-- 	RemoveTextAfterFocusLost = false,
	-- 	Flag = "v2_eleTargetLevel",
	-- 	Callback = function() end,
	-- })

    local v2_targetKG = Pets:CreateInput({
		Name = "Target KG",
		CurrentValue = "3.85",
		PlaceholderText = "Enter KG",
		RemoveTextAfterFocusLost = false,
		Flag = "v2_eleTargetKG",
		Callback = function() end,
	})

    local levelingLoadoutForAutoEleV2_A
    local dropdown_eleV2_leveling_A = Pets:CreateDropdown({
        Name = "Leveling loadout A",
        -- Options = {"None","custom_1","custom_2","custom_3","custom_4","custom_5","custom_6","custom_7","custom_8","custom_9","custom_10","1","2","3","4","5","6"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoadoutForAutoEleV2_A",
        Callback = function(Options)
            levelingLoadoutForAutoEleV2_A = Options[1]
        end,
    })
    local v2_levelTarget_A
    Pets:CreateInput({
		Name = "Target level A",
		CurrentValue = "",
		PlaceholderText = "Enter level",
		RemoveTextAfterFocusLost = false,
		Flag = "v2_eleTargetLevelA",
		Callback = function(Text)
            local num = tonumber(Text)
            if num then
                v2_levelTarget_A = num
            else
                v2_levelTarget_A = 50
            end
        end,
	})

    local levelingLoadoutForAutoEleV2_B
    local dropdown_eleV2_leveling_B = Pets:CreateDropdown({
        Name = "Leveling loadout B",
        -- Options = {"None","custom_1","custom_2","custom_3","custom_4","custom_5","custom_6","custom_7","custom_8","custom_9","custom_10","1","2","3","4","5","6"},
        Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "levelingLoadoutForAutoEleV2_B",
        Callback = function(Options)
            levelingLoadoutForAutoEleV2_B = Options[1]
        end,
    })
    local v2_levelTarget_B
    Pets:CreateInput({
		Name = "Target level B",
		CurrentValue = "",
		PlaceholderText = "Enter level",
		RemoveTextAfterFocusLost = false,
		Flag = "v2_eleTargetLevelB",
		Callback = function(Text)
            local num = tonumber(Text)
            if num then
                v2_levelTarget_B = num
            else
                v2_levelTarget_B = 0
            end
        end,
	})

	local v2_eleLoadout
	local dropdown_eleV2_loadout = Pets:CreateDropdown({
		Name = "Elephant Loadout",
		-- Options = {"None","custom_1","custom_2","custom_3","custom_4","custom_5","custom_6","custom_7","custom_8","custom_9","custom_10"},
		Options = getgenv().preloadedCustomLoadoutNames or {},
        CurrentOption = {},
		MultipleOptions = false,
		Flag = "v2_eleLoadout",
		Callback = function(Options)
			v2_eleLoadout = Options[1]
		end,
	})
    -- --select toy
    local dropdown_selectedToyForAutoEleV2 = Pets:CreateDropdown({
        Name = "Select Toy",
        Options = {"None", "Small Pet Toy", "Medium Pet Toy"},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "selectToysForAutoEleV2", 
        Callback = function(Options)
        end,
    })
    local input_delayToBoostEle = Pets:CreateInput({
        Name = "Delay to boost (default 1.75)",
        CurrentValue = "1.75",
        PlaceholderText = "seconds",
        RemoveTextAfterFocusLost = false,
        Flag = "delayToBoostEle_3",
        Callback = function(Text)
        end,
    })
    local input_removeOtherPetsAtEleV2 
    Pets:CreateInput({
        Name = "Remove other pets at Ele CD",
        CurrentValue = "",
        PlaceholderText = "seconds",
        RemoveTextAfterFocusLost = false,
        Flag = "removeOtherPetsAtEleV2",
        Callback = function(Text)
        local num = tonumber(Text)
            if num then
                input_removeOtherPetsAtEleV2 = num
            else
                input_removeOtherPetsAtEleV2 = 300
            end
        end,
    })
    local v2_autoRemoveBoosts = nil
	Pets:CreateToggle({
		Name = "Auto remove toy boosts",
		CurrentValue = false,
		Flag = "v2_autoRemoveToyBoosts",
		Callback = function(Value)
			v2_autoRemoveBoosts = Value
		end,
	})
	local v2_autoLevelAfter = nil
	Pets:CreateToggle({
		Name = "Auto Level After Elephant",
		CurrentValue = false,
		Flag = "v2_autoLevelAfter",
		Callback = function(Value)
			v2_autoLevelAfter = Value
		end,
	})
	local v2_enabled
	local v2_thread = nil
	toggle_autoEleV2 = Pets:CreateToggle({
		Name = "Auto Elephant V2",
		CurrentValue = false,
		Flag = "v2_autoEle",
		Callback = function(Value)
			v2_enabled = Value
			local runAutoEle
			if v2_enabled then
				Toggle_autoMutation:Set(false)
				toggle_autoNM:Set(false)
                Toggle_autoLevel:Set(false)
                beastHubNotify("Auto Elephant V2 running","",6)

				-- local waitTime = 5
				-- while waitTime > 0 and (
				-- 	(not levelingLoadoutForAutoEleV2_A or levelingLoadoutForAutoEleV2_A == "None") and not (levelingLoadoutForAutoEleV2_A and string.find(levelingLoadoutForAutoEleV2_A,"custom",1,true))
                --     or (not levelingLoadoutForAutoEleV2_B or levelingLoadoutForAutoEleV2_B == "None") and not (levelingLoadoutForAutoEleV2_B and string.find(levelingLoadoutForAutoEleV2_B,"custom",1,true))
				-- 	or (not v2_eleLoadout or v2_eleLoadout == "None") and not (v2_eleLoadout and string.find(v2_eleLoadout,"custom",1,true))
				-- 	or not v2_selectedPets
                --     -- or not tonumber(v2_targetLevel.CurrentValue)
                --     or not tonumber(v2_targetKG.CurrentValue)
                --     or v2_levelTarget_A == nil
                --     or v2_levelTarget_B == nil
                --     or not dropdown_selectedToyForAutoEleV2.CurrentOption[1]
                --     or not tonumber(input_delayToBoostEle.CurrentValue)
                --     or input_removeOtherPetsAtEleV2 == nil
                --     or v2_autoRemoveBoosts == nil
				-- 	or v2_autoLevelAfter == nil
				-- ) do
				-- 	task.wait(0.5)
				-- 	waitTime = waitTime - 0.5
				-- end

                --new
                local start = tick()
                local maxWait = 10
                while not getgenv().ConfigLoaded do
                    local elapsed = tick() - start
                    if elapsed >= maxWait then
                        beastHubNotify("Auto Ele V2 failed to load", "Please rejoin", 5)
                        break
                    end
                    task.wait(0.5)
                end
                task.wait(3)

                -- local desiredLevel = tonumber(v2_targetLevel.CurrentValue)
				if not v2_selectedPets or not v2_eleLoadout or not levelingLoadoutForAutoEleV2_A or not tonumber(input_delayToBoostEle.CurrentValue) or not tonumber(v2_targetKG.CurrentValue) or not dropdown_selectedToyForAutoEleV2.CurrentOption[1] or v2_autoRemoveBoosts == nil or not v2_levelTarget_A then
                    beastHubNotify("Missing setup","",10)
					return
				end

                local toyToUse = dropdown_selectedToyForAutoEleV2.CurrentOption[1]
                local targetKG = tonumber(v2_targetKG.CurrentValue)
                --ele cd listener
                local cooldownListenerAutoEle = nil
                local petCooldownsAutoEle = {}
                local savedEleIds = {}
                -- local target_A = tonumber(v2_levelTarget_A.CurrentValue)
                -- local target_B = tonumber(v2_levelTarget_B.CurrentValue)

				runAutoEle = function(petName,onFinish)
                    local location = getPetEquipLocation()

					local function fetchData()
						return require(game:GetService("ReplicatedStorage").Modules.DataService):GetData()
					end
					local function getInventory()
						local d = fetchData()
						return d and d.PetsData and d.PetsData.PetInventory and d.PetsData.PetInventory.Data
					end
					local function getLevel(uid)
						for id,data in pairs(getInventory()) do
							if tostring(id) == uid then
								return data.PetData.Level
							end
						end
					end
					local function getWeight(uid)
						for id,data in pairs(getInventory()) do
							if tostring(id) == uid then
								return data.PetData.BaseWeight
							end
						end
					end
					local favs, unfavs = {}, {}
					for uid,pet in pairs(getInventory()) do
						local entry = {Uid=uid,PetType=pet.PetType,Uuid=pet.UUID,PetData=pet.PetData}
						if pet.PetData.IsFavorite then
							table.insert(favs,entry)
						else
							table.insert(unfavs,entry)
						end
					end

                    --v2 helper functions
                    local function getPlayerData()
                            local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                            local logs = dataService:GetData()
                            return logs
                        end

                    local function equippedPets()
                        local playerData = getPlayerData()
                        if not playerData.PetsData then
                            return nil
                        end
                        local tempStorage = playerData.PetsData.EquippedPets
                        if not tempStorage or type(tempStorage) ~= "table" then
                            return nil
                        end
                        local petIdsList = {}
                        for _, id in ipairs(tempStorage) do
                            table.insert(petIdsList, id)
                        end
                        return petIdsList
                    end

                    local function getPetTypeUsingId(uid)
                        local playerData = getPlayerData()
                        if playerData.PetsData.PetInventory.Data then
                            local data = playerData.PetsData.PetInventory.Data
                            for id, petData in pairs(data) do
                                if id == uid then
                                    return petData.PetType
                                end
                            end
                        end
                    end

                    local function delayedBoost(uid, delay)
                        -- equip boost
                        if equipItemByName(toyToUse) then
                            -- beastHubNotify("Equipped toy: ", toyToUse, 3)
                            local ReplicatedStorage = game:GetService("ReplicatedStorage")
                            local PetBoostService = ReplicatedStorage.GameEvents.PetBoostService
                            -- local now = os.clock()
		                    -- print("ApplyBoost fired at:", now, "uid:", uid)
                            PetBoostService:FireServer("ApplyBoost", uid)
                            -- beastHubNotify("Toy boost executed", "", 4)
                            --unequip after fire to avoid error on equip function
                            task.wait(0.01)
                            game.Players.LocalPlayer.Character.Humanoid:UnequipTools()
                            if delay > 0 then
                                task.wait(delay-0.01)
                            else
                                task.wait(0.01)
                            end
                        else
                            print("Equip toy for Auto Ele v2 failed")
                        end
                    end

                    local function checkBoostTimeLeft(toyName, petId) 
                        local toyToBoostAmount = {
                            ["Small Pet Toy"] = 0.1,
                            ["Medium Pet Toy"] = 0.2,
                            ["Large Pet Toy"] = 0.3
                        }

                        local function getPlayerData()
                            local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                            local logs = dataService:GetData()
                            return logs
                        end
                        
                        local playerData = getPlayerData()
                        local petData = playerData.PetsData.PetInventory.Data
                        for id, data in pairs(petData) do
                            if tostring(id) == tostring(petId) then
                                if data.PetData and data.PetData.Boosts then
                                --have boost, check if matching
                                    local boosts = data.PetData.Boosts
                                    for _,boost in ipairs(boosts) do
                                        local boostType = boost.BoostType
                                        local boostAmount = boost.BoostAmount
                                        local boostTime = boost.Time

                                        if boostType == "PASSIVE_BOOST" then
                                            if toyToBoostAmount[toyName] == boostAmount then
                                                return boostTime
                                            end
                                        end
                                    end
                                    return 0
                                else
                                    return 0
                                end
                            end
                        end
                    end 

                    local function equipPetByUuid(uuid)
                        local player = game.Players.LocalPlayer
                        local backpack = player:WaitForChild("Backpack")
                        for _, tool in ipairs(backpack:GetChildren()) do
                            if tool:GetAttribute("PET_UUID") == uuid then
                                player.Character.Humanoid:EquipTool(tool)
                            end
                        end
                    end

                    --for pets in garden
                    local function removePetBoost(id)
                        local function equipPetByUuidWithChecker(uuid)
                            local player = game.Players.LocalPlayer
                            local backpack = player:WaitForChild("Backpack")
                            for _,tool in ipairs(backpack:GetChildren()) do
                                if tool:GetAttribute("PET_UUID") == uuid and tool:GetAttribute("d") == false then
                                    player.Character.Humanoid:EquipTool(tool)
                                    return true
                                elseif tool:GetAttribute("PET_UUID") == uuid and tool:GetAttribute("d") == true then
                                    return false
                                end
                            end
                            return false
                        end
                        local ok,result = pcall(function()
                            local args = {
                                [1] = "UnequipPet";
                                [2] = id;
                            }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetsService",9e9):FireServer(unpack(args))
                            task.wait(1)
                            local equipWithFavChecker = equipPetByUuidWithChecker(id)
                            if not equipWithFavChecker then
                                return false
                            end
                            task.wait(0.01)
                            game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_SubmitHeld:FireServer()
                            task.wait(1)
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetAgeLimitBreak_Cancel",9e9):FireServer(unpack({}))
                            task.wait(1)
                            local args2 = {
                                [1] = "EquipPet";
                                [2] = id;
                                [3] = location;
                            }
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetsService",9e9):FireServer(unpack(args2))
                            task.wait(0.01)
                            return true
                        end)
                        if not ok then
                            print("removePetBoost failed:",result)
                            return false
                        end
                        return result == true
                    end

                    --for in pets in bag
                    local function clearPetBoost(id)
                        local function equipPetByUuidWithChecker(uuid)
                            local player = game.Players.LocalPlayer
                            local backpack = player:WaitForChild("Backpack")
                            for _,tool in ipairs(backpack:GetChildren()) do
                                if tool:GetAttribute("PET_UUID") == uuid and tool:GetAttribute("d") == false then
                                    player.Character.Humanoid:EquipTool(tool)
                                    return true
                                elseif tool:GetAttribute("PET_UUID") == uuid and tool:GetAttribute("d") == true then
                                    return false
                                end
                            end
                            return false
                        end
                        local ok,result = pcall(function()
                            local equipWithFavChecker = equipPetByUuidWithChecker(id)
                            if not equipWithFavChecker then
                                return false
                            end
                            task.wait(0.01)
                            game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_SubmitHeld:FireServer()
                            task.wait(1)
                            game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetAgeLimitBreak_Cancel",9e9):FireServer(unpack({}))
                            task.wait(1)
                            return true
                        end)
                        if not ok then
                            print("removePetBoost failed:",result)
                            return false
                        end
                        return result == true
                    end

                    



                    local targetFound = false
                    

					for _,pet in pairs(unfavs) do
                        targetFound = false
						local uid = tostring(pet.Uid)
						local curLvl = pet.PetData.Level
						local curKG = tonumber(pet.PetData.BaseWeight) * 1.1
                        local maxKG = 3.85
                        local curPetName = pet.PetType
                        local otherPetsRemoved = false
                        
						if v2_enabled and curPetName == petName and tonumber(curKG) < tonumber(targetKG) then
                            targetFound = true
                            local boostRemoved = false

                            --A
							mainModule.isSafeToPickPlace = false
							task.wait(1)
							myFunctions.switchToLoadout(levelingLoadoutForAutoEleV2_A,getFarmSpawnCFrame,beastHubNotify)
							task.wait(3)
							game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet",uid,getFarmSpawnCFrame()*CFrame.new(0,0,-5))
							mainModule.isSafeToPickPlace = true

                            --insert boost removal for eles here
                            if v2_autoRemoveBoosts and #savedEleIds > 0 then
                                -- print("removing boosts..")
                                for _,id in ipairs(savedEleIds) do 
                                    local boostTimeLeft = checkBoostTimeLeft(toyToUse, id)
                                    if boostTimeLeft > 0 then
                                        local removed = clearPetBoost(id)
                                        if removed then
                                            beastHubNotify("Boost cleared for ", id, 3)
                                        elseif not removed then
                                            beastHubNotify("Please unfavorite your Elephant", "", 5)
                                            return 
                                        end
                                        
                                    end
                                end
                                boostRemoved = true
                            end

                            while v2_enabled and curLvl < v2_levelTarget_A do
                                beastHubNotify("Waiting to hit level: "..tostring(v2_levelTarget_A), "", 3)
								task.wait(5)
								curLvl = getLevel(uid)
							end

                            --B
                            if levelingLoadoutForAutoEleV2_B and levelingLoadoutForAutoEleV2_B ~= "None" then 
                                mainModule.isSafeToPickPlace = false
                                task.wait(1)
                                myFunctions.switchToLoadout(levelingLoadoutForAutoEleV2_B,getFarmSpawnCFrame,beastHubNotify)
                                task.wait(3)
                                game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet",uid,getFarmSpawnCFrame()*CFrame.new(0,0,-5))
                                mainModule.isSafeToPickPlace = true
                                while v2_enabled and curLvl < v2_levelTarget_B do
                                    beastHubNotify("Waiting to hit level: "..tostring(v2_levelTarget_B), "", 3)
                                    task.wait(5)
                                    curLvl = getLevel(uid)
                                end
                            end
                            

							game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("UnequipPet",uid)
							if v2_enabled then
								mainModule.isSafeToPickPlace = false
								task.wait(1)
								myFunctions.switchToLoadout(v2_eleLoadout,getFarmSpawnCFrame,beastHubNotify)
								task.wait(6)
								game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet",uid,getFarmSpawnCFrame()*CFrame.new(0,0,-5))
								mainModule.isSafeToPickPlace = true
                                task.wait(1)

                                --get equipped pets
                                local equipped = equippedPets()
                                local petsIdToName = {}
                                if equipped then
                                    for _, id in ipairs(equipped) do
                                        local petName = getPetTypeUsingId(id)
                                        petsIdToName[id] = petName
                                    end
                                end

                                --check if elephants found 
                                local eleIds = {}
                                local otherPets = {} --should use custom loaodout
                                local doneBoost = {}
                                local boostingStarted = false

                                if equipped and #equipped > 0 then
                                    for id,petType in pairs(petsIdToName) do
                                        -- if string.find(petType, "Elephant", 1, true) then
                                        if petType == "Elephant" or petType == "Rainbow Elephant" then
                                            table.insert(eleIds, id)
                                            if petType == "Rainbow Elephant" then
                                                maxKG = 6.05
                                            end
                                        elseif id ~= uid then
                                            table.insert(otherPets, id)
                                        end
                                    end

                                    --save ele ids to clear on next leveling
                                    if not savedEleIds or #savedEleIds == 0 then
                                        savedEleIds = table.clone(eleIds)
                                    end

                                    
                                end

                                --check boost time if need to remove boost
                                if v2_autoRemoveBoosts and not boostRemoved then
                                    -- print("removing boosts..")
                                    for _,id in ipairs(eleIds) do 
                                        local boostTimeLeft = checkBoostTimeLeft(toyToUse, id)
                                        -- print("boostTimeLeft "..id.." "..boostTimeLeft)
                                        if boostTimeLeft > 0 then
                                            -- print("boostTimeLeft: "..boostTimeLeft)
                                            --function to remove pet boosts here
                                            local removed = removePetBoost(id)
                                            if removed then
                                                beastHubNotify("Boost removed for ", id, 3)
                                            elseif not removed then
                                                beastHubNotify("Please unfavorite your Elephant", "", 5)
                                                return 
                                            end
                                            
                                        end
                                    end
                                    boostRemoved = true
                                end

                                --monitor cd after removing boosts
                                if cooldownListenerAutoEle then
                                    cooldownListenerAutoEle:Disconnect()
                                    cooldownListenerAutoEle = nil
                                end
                                cooldownListenerAutoEle = game:GetService("ReplicatedStorage").GameEvents.PetCooldownsUpdated.OnClientEvent:Connect(function(petId,data)
                                    if typeof(data) == "table" and data[1] and data[1].Time then
                                        petCooldownsAutoEle[petId] = data[1].Time
                                    else
                                        -- petCooldownsAutoEle[petId] = 0
                                        petCooldownsAutoEle[petId] = 99999 --set anything not number as high cd in this case
                                    end
                                end)

                                --new
                                while v2_enabled do
                                    local eleForFirstBoost = ""
                                    local timeCDToBoostInMins = 0
                                    local timeCDToBoostInSecForOtherEle
                                    if toyToUse == "Small Pet Toy" then
                                        timeCDToBoostInMins = 1
                                        timeCDToBoostInSecForOtherEle = 240
                                    elseif toyToUse == "Medium Pet Toy" then
                                        timeCDToBoostInMins = 2
                                        timeCDToBoostInSecForOtherEle = 240
                                    else
                                        timeCDToBoostInMins = 0
                                    end
                                    local timeCDToBoostInSec = timeCDToBoostInMins * 60
                                    local delayPerBoost = tonumber(input_delayToBoostEle.CurrentValue)

                                    --force remove all pets at last burst KG
                                    -- if otherPetsRemoved == false and (curKG+.11) >= maxKG and #otherPets > 0 then
                                    --     beastHubNotify("Removing other pets for last KG..", "To ensure stacking", 3)
                                    --     mainModule.isSafeToPickPlace = false
                                    --     for _,otherId in ipairs(otherPets) do
                                    --         local args = {
                                    --             [1] = "UnequipPet";
                                    --             [2] = otherId;
                                    --         }
                                    --         game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetsService",9e9):FireServer(unpack(args))
                                    --         task.wait()
                                    --     end
                                    --     otherPetsRemoved = true
                                    -- end

                                    if timeCDToBoostInMins ~= 0 and #eleIds > 0 then
                                        for _,eleId in ipairs(eleIds) do
                                            local curEleCd = petCooldownsAutoEle[eleId]

                                            --remove other pets if ele cd is below 5mins
                                            if curEleCd and curEleCd <= input_removeOtherPetsAtEleV2 then
                                                if otherPets and #otherPets > 0 then
                                                    mainModule.isSafeToPickPlace = false
                                                    for _,otherId in ipairs(otherPets) do
                                                        local args = {
                                                            [1] = "UnequipPet";
                                                            [2] = otherId;
                                                        }
                                                        game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetsService",9e9):FireServer(unpack(args))
                                                        task.wait()
                                                    end
                                                    mainModule.isSafeToPickPlace = true
                                                end
                                            end

                                            --first ele good for boost
                                            if curEleCd and curEleCd <= timeCDToBoostInSec then
                                                eleForFirstBoost = eleId
                                                break
                                            end
                                        end
                                    end

                                    local idsToDelayBoost = {}
                                    if timeCDToBoostInMins ~= 0 and eleForFirstBoost ~= "" then
                                        table.insert(idsToDelayBoost,eleForFirstBoost)
                                        boostingStarted = true

                                        for _,eleId in ipairs(eleIds) do
                                            if (curKG+.11) >= maxKG then
                                                if eleId ~= eleForFirstBoost then
                                                    table.insert(idsToDelayBoost,eleId)
                                                end
                                            elseif (curKG+.11) < maxKG then
                                                local nextKG = curKG + .11
                                                if eleId ~= eleForFirstBoost and (nextKG+.11 < maxKG) then
                                                    table.insert(idsToDelayBoost,eleId)
                                                end
                                                if eleId ~= eleForFirstBoost and (nextKG+.11 >= maxKG) then
                                                    local args = {
                                                        [1] = "UnequipPet";
                                                        [2] = eleId;
                                                    }
                                                    game:GetService("ReplicatedStorage"):WaitForChild("GameEvents",9e9):WaitForChild("PetsService",9e9):FireServer(unpack(args))
                                                    task.wait()
                                                end
                                            end
                                        end

                                        task.wait(1)
                                        for _,id in ipairs(idsToDelayBoost) do
                                            delayedBoost(id,delayPerBoost)
                                        end
                                        mainModule.isSafeToPickPlace = true
                                    end

                                    task.wait(1)
                                    curLvl = getLevel(uid)
                                    task.wait(1)
                                    if boostingStarted then
                                        task.wait(10)
                                        boostingStarted = false
                                    end

                                    local targetLevelForEleV2
                                    if levelingLoadoutForAutoEleV2_B == nil or levelingLoadoutForAutoEleV2_B == "None" then
                                        targetLevelForEleV2 = v2_levelTarget_A
                                    else
                                        targetLevelForEleV2 = v2_levelTarget_B
                                    end
                                    if curLvl < tonumber(targetLevelForEleV2) then
                                        break
                                    end
                                end



								game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("UnequipPet",uid)
								if v2_enabled and M.autoEleWebhook then
									local newKG = string.format("%.2f",getWeight(uid)*1.1)
									sendDiscordWebhook(M.webhookURL,"[BeastHub] "..game.Players.LocalPlayer.Name.." | Auto Elephant V2: "..pet.PetType.."="..newKG.."KG")
								end
                                task.wait(5)
							end
							return                            
						end
					end

                    if not targetFound then
                        beastHubNotify("No pet found", petName, 6)
                    end


					if typeof(onFinish) == "function" then
						onFinish("No eligible pet")
					end
				end
				v2_thread = task.spawn(function()
					while v2_enabled do
                        task.wait(2)
                        local notFoundCounter = 0
                        for _,v2_selectedPet in ipairs(v2_selectedPets) do
                            runAutoEle(v2_selectedPet,function(msg)
                                if msg == "No eligible pet" then
                                    notFoundCounter = notFoundCounter + 1
                                    if notFoundCounter == #v2_selectedPets then
                                        v2_enabled = false
                                        if v2_autoLevelAfter then
                                            Toggle_autoLevel:Set(true)
                                        end
                                    end
                                end
                            end)    
                        end
						
                        -- -- Disable ele cd listeners
                        -- if cooldownListenerAutoEle then
                        --     cooldownListenerAutoEle:Disconnect()
                        --     cooldownListenerAutoEle = nil
                        -- end
						-- task.wait(0.1)
					end
				end)
            else
                -- Disable ele cd listeners
                if cooldownListenerAutoEle then
                    cooldownListenerAutoEle:Disconnect()
                    cooldownListenerAutoEle = nil
                end

                v2_enabled = false
                if v2_thread then
                    v2_thread = nil
                end
			end
		end,
	})
	Pets:CreateDivider()



    --Auto Pet Age Break
    local idsOnly --storage for ids for target pet breaker dropdown
    local targetPetAgeBreakerLevel = 125
    local selectedTargetCurrentAge = 0

    Pets:CreateSection("Auto Pet Age Break")
    Pets:CreateParagraph({
        Title = "INSTRUCTIONS:",
        Content = "1.) Select Pet\n2.) Refresh list if pet not found\n3.) Ignore Target ID, it will auto populate"
    })
    local selectedPetForAgeBreaker = ""
    -- local paragraph_currentId = Pets:CreateParagraph({
    --     Title = "CURRENT ID:",
    --     Content = "None"
    -- })

    Pets:CreateInput({
        Name = "Target Pet level:",
        CurrentValue = "125",
        PlaceholderText = "max is 125",
        RemoveTextAfterFocusLost = false,
        Flag = "petAgeLevelTarget",
        Callback = function(Text)
            targetPetAgeBreakerLevel = tonumber(Text) or 125
        end,
    })

    local allPetsInInventory = function()
        idsOnly = {}
        local function getPlayerData()
            local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
            local logs = dataService:GetData()
            -- print("got player data")
            return logs
        end

        local function getPetInventory()
            local playerData = getPlayerData()
            if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                -- print("got pets data")
                return playerData.PetsData.PetInventory.Data
            else
                warn("PetsData not found!")
                return nil
            end
        end

        local function getMachineMutationsDataWithPrint() -- all mutation data including enums
            local ReplicatedStorage = game:GetService("ReplicatedStorage")

            local success, PetMutationRegistry = pcall(function()
                return require(
                    ReplicatedStorage:WaitForChild("Data")
                        :WaitForChild("PetRegistry")
                        :WaitForChild("PetMutationRegistry")
                )
            end)

            if not success or type(PetMutationRegistry) ~= "table" then
                warn("Failed to load PetMutationRegistry module.")
                return {}
            end

            local machineMutations = PetMutationRegistry.EnumToPetMutation
            if type(machineMutations) ~= "table" then
                warn("MachineMutationTypes not found in PetMutationRegistry.")
                return {}
            end
            return machineMutations
        end

        -- Function you can call anytime to refresh pets data
        local function refreshPets()
            -- USAGE: local favs, unfavs = refreshPets()
            local pets = getPetInventory()
            local unfavoritePets = {}
            local machineMutationEnums = {} --pet mutation enums container
            local mutations = getMachineMutationsDataWithPrint()
            for enum, value in pairs(mutations) do --extract only enums
                table.insert(machineMutationEnums, {enum, value})
            end        

            if pets then
                for uid, pet in pairs(pets) do
                    local curMutation
                    local curMutationEnum = pet.PetData.MutationType or nil
                    --get current pet mutation via enum
                    for _, entry in ipairs(machineMutationEnums) do
                        local mutation = entry[2]
                        local enumId = entry[1]
                        if enumId == curMutationEnum then
                            curMutation = mutation
                            break
                        end
                    end
                    local entry = {
                        nameToId = pet.PetType.." | "..(curMutation or "Normal").." | Base KG: "..(string.format("%.2f", pet.PetData.BaseWeight * 1.1)).." | Age: "..tostring(pet.PetData.Level),
                        Uid = uid
                    }
                    if not pet.PetData.IsFavorite and pet.PetData.Level >= 100 and pet.PetData.Level < targetPetAgeBreakerLevel then --filter only allowed age for breaker
                        table.insert(unfavoritePets, entry)
                    end
                    
                end
            end
            --
            return unfavoritePets
        end

        --process here
        local unfavs = refreshPets()

        -- Sort unfavs by nameToId BEFORE extracting namesOnly and idsOnly
        table.sort(unfavs, function(a,b)
            return a.nameToId < b.nameToId
        end)

        local namesOnly = {}
        idsOnly = {}

        for _, pet in ipairs(unfavs) do
            table.insert(namesOnly, pet.nameToId)
            table.insert(idsOnly, pet.Uid)
        end

        return namesOnly

    end

    -- local petBreakerTargetIDstored = Pets:CreateDropdown({
    --     Name = "Target ID (do not change)",
    --     Options = {""},
    --     CurrentOption = {""},
    --     MultipleOptions = false,
    --     Flag = "petBreakerTargetStored",
    --     Callback = function() end,
    -- })

    local petBreakerTargetIDstoredFinal
    local petBreakerTargetIDstored = Pets:CreateDropdown({
        Name = "Target ID (do not change)",
        Options = {},
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "petBreakerTargetStored", -- A flag is the identifier for the configuration file; make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Options)
            if Options[1] ~= nil then
                petBreakerTargetIDstoredFinal = Options[1]
            end
        end,
    })

    local autoPetAgeBreakEnabled = false
    local autoPetAgeBreakThread = nil
    local selectedIndex = nil --to know which option is selected in order to get the Uid
    local selectTargetPetForBreaker = allPetsInInventory()

    local selectedPetForAgeBreak = Pets:CreateDropdown({
        Name = "Select Target (Unfavorite and 100+)",
        Options = selectTargetPetForBreaker,
        CurrentOption = {"None"},
        MultipleOptions = false,
        Flag = "AutPetAgeBreakTarget", 
        Callback = function(Options)
            local chosen = Options[1]
            for i, v in ipairs(selectTargetPetForBreaker) do
                if v == chosen then
                    selectedIndex = i
                    break
                end
            end
            
            selectedPetForAgeBreaker = idsOnly[selectedIndex]
            if selectedPetForAgeBreaker then
                print("Dropdown fired")
                print("selectedPetForAgeBreaker")
                print(selectedPetForAgeBreaker)
                petBreakerTargetIDstored:Refresh({ selectedPetForAgeBreaker }) 
                task.wait()
                petBreakerTargetIDstored:Set({ selectedPetForAgeBreaker })
                -- print("stored selectedPetForAgeBreaker to stored input")
                selectedTargetCurrentAge = tonumber(chosen:match("Age:%s*(%d+)"))
            end
            if selectedPetForAgeBreaker == nil then
                -- print("getting value from stored dropdown")
                selectedPetForAgeBreaker = petBreakerTargetIDstored.CurrentOption[1] --stored value in rayfield
                selectedTargetCurrentAge = tonumber(chosen:match("Age:%s*(%d+)"))
                -- print("used pet id from stored input")
                -- print(selectedPetForAgeBreaker)
            end
        end,
    })

    Pets:CreateButton({
        Name = "Refresh List",
        Callback = function()
            --refresh code
            local newList = allPetsInInventory()
            selectTargetPetForBreaker = newList  -- update names
            selectedPetForAgeBreak:Refresh(newList)
            selectedPetForAgeBreak:Set({"None"})
            selectedIndex = nil
            selectedPetForAgeBreaker = nil
            --refresh code end
        end,
    })

    local petAgeKGsacrifice = Pets:CreateDropdown({
        Name = "Sacrifice Below Base KG:",
        Options = {"1", "2", "3"},
        CurrentOption = {"3"},
        MultipleOptions = false,
        Flag = "petAgeKGsacrifice", 
        Callback = function(Options)
        
        end,
    })

    local petAgeLevelSacrifice = Pets:CreateInput({
        Name = "Sacrifice Below Level:",
        CurrentValue = "",
        PlaceholderText = "input number..",
        RemoveTextAfterFocusLost = false,
        Flag = "petAgeLevelSacrifice",
        Callback = function(Text)
        -- The function that takes place when the input is changed
        -- The variable (Text) is a string for the value in the text box
        end,
    })
    
    local toggle_autoSkipViaToken = Pets:CreateToggle({
        Name = "Auto Skip via Token (49 per skip)",
        CurrentValue = false,
        Flag = "autoSkipPetAgeWithToken", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
        Callback = function(Value)
        -- The function that takes place when the toggle is pressed
        -- The variable (Value) is a boolean on whether the toggle is true or false
        end,
    })

    
   
    --with print logs
    -- Pets:CreateToggle({
    --     Name = "Auto Pet Age Break",
    --     CurrentValue = false,
    --     Flag = "autoPetAgeBreak", 
    --     Callback = function(Value)
    --         print("[DEBUG] Toggle changed:", Value)
    --         autoPetAgeBreakEnabled = Value
    --         local autoBreaker

    --         if not autoPetAgeBreakEnabled then
    --             print("[DEBUG] Disabling Auto Pet Age Break")
    --             if autoPetAgeBreakThread then
    --                 task.cancel(autoPetAgeBreakThread)
    --                 autoPetAgeBreakThread = nil
    --                 print("[DEBUG] Thread cancelled")
    --                 beastHubNotify("Auto Pet Age Break stopped", "", 3)
    --             end
    --             return
    --         else
    --             print("[DEBUG] Enabling Auto Pet Age Break")
    --             beastHubNotify("Auto breaker running", "", 3)
    --         end
            
    --         -- wait for config
    --         local start = tick()
    --         local maxWait = 10
    --         print("[DEBUG] Waiting for ConfigLoaded...")
    --         while not getgenv().ConfigLoaded do
    --             local elapsed = tick() - start
    --             if elapsed >= maxWait then
    --                 print("[DEBUG] Config load timeout")
    --                 beastHubNotify("Pet Age break failed to load", "Please rejoin", 5)
    --                 break
    --             end
    --             task.wait(0.5)
    --         end
    --         print("[DEBUG] ConfigLoaded:", getgenv().ConfigLoaded)
    --         task.wait(3)

    --         local sacrificePetName = (selectedPetForAgeBreak.CurrentOption[1]:match("^(.-)%s*|") or ""):match("^%s*(.-)%s*$")
    --         print("petBreakerTargetIDstored.CurrentOption[1]")
    --         print(petBreakerTargetIDstored.CurrentOption[1])
    --         local selectedId = selectedPetForAgeBreaker or petBreakerTargetIDstored.CurrentOption[1]

    --         if petBreakerTargetIDstoredFinal ~= nil then
    --             selectedId = petBreakerTargetIDstoredFinal
    --         end

    --         print("[DEBUG] Selected Pet Name:", sacrificePetName)
    --         print("[DEBUG] Selected Pet ID:", selectedId)

    --         autoBreaker = function(sacrificePetNameParam, selectedIdParam)
    --             print("[DEBUG] Running autoBreaker cycle")

    --             local function getPlayerData()
    --                 local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
    --                 local logs = dataService:GetData()
    --                 return logs
    --             end

    --             local function getPetIdByNameAndFilterKg(name, basekg, belowLevel, exceptId)
    --                 local finalBelowLevel = (belowLevel == 1) and 2 or belowLevel
    --                 local playerData = getPlayerData()

    --                 if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
    --                     for id, data in pairs(playerData.PetsData.PetInventory.Data) do
    --                         local curBaseKG = tonumber(string.format("%.2f", data.PetData.BaseWeight * 1.1))
    --                         if not data.PetData.IsFavorite and data.PetType == name and curBaseKG < basekg and id ~= exceptId and data.PetData.Level < finalBelowLevel then
    --                             print("[DEBUG] Found sacrifice pet:", id)
    --                             return id
    --                         end
    --                     end
    --                     print("[DEBUG] No matching sacrifice pet found")
    --                     return nil
    --                 else
    --                     warn("[DEBUG] PetsData not found!")
    --                     return nil
    --                 end
    --             end

    --             local petIdToSacrifice = getPetIdByNameAndFilterKg(
    --                 sacrificePetNameParam,
    --                 tonumber(petAgeKGsacrifice.CurrentOption[1]),
    --                 tonumber(petAgeLevelSacrifice.CurrentValue),
    --                 selectedIdParam
    --             )

    --             print("[DEBUG] petIdToSacrifice:", petIdToSacrifice)
    --             print("[DEBUG] selectedTargetCurrentAge:", selectedTargetCurrentAge)
    --             print("[DEBUG] targetPetAgeBreakerLevel:", targetPetAgeBreakerLevel)

    --             if petIdToSacrifice and autoPetAgeBreakEnabled and selectedTargetCurrentAge < targetPetAgeBreakerLevel then
    --                 print("[DEBUG] Valid sacrifice found, proceeding")
    --                 beastHubNotify("Worthy sacrifice found!","",3)

    --                 local playerData = getPlayerData()
    --                 task.wait(1)

    --                 if playerData.PetAgeBreakMachine then
    --                     print("[DEBUG] Machine found")

    --                     if playerData.PetAgeBreakMachine.IsRunning then
    --                         print("[DEBUG] Machine already running")

    --                         local runningId = playerData.PetAgeBreakMachine.SubmittedPet.UUID or ""
    --                         print("[DEBUG] Running pet ID:", runningId)

    --                         if runningId == selectedIdParam then
    --                             print("[DEBUG] Same pet already running")
    --                             beastHubNotify("the selected pet is already running in breaker machine", "", 3)
    --                         else
    --                             print("[DEBUG] Different pet running")
    --                             beastHubNotify("A different pet is already running", "waiting for breaker to be done", "3")
    --                         end

    --                         while autoPetAgeBreakEnabled do 
    --                             print("[DEBUG] Monitoring running machine...")
    --                             task.wait(5)

    --                             if toggle_autoSkipViaToken.CurrentValue and playerData.PetAgeBreakMachine.IsRunning then
    --                                 print("[DEBUG] Attempting skip via token")
    --                                 local ok,err = pcall(function()
    --                                     game:GetService("ReplicatedStorage").GameEvents.TradeEvents.TradeTokens.Purchase:InvokeServer(3453278902)
    --                                 end)
    --                                 if not ok then warn("[DEBUG] Skip error:", err) end
    --                             end

    --                             task.wait(5)
    --                             playerData = getPlayerData()

    --                             if not playerData.PetAgeBreakMachine.IsRunning then
    --                                 print("[DEBUG] Machine finished")
    --                                 break
    --                             end
    --                         end

    --                         print("[DEBUG] Claiming finished pet")
    --                         task.wait(1)
    --                         game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Claim:FireServer()
    --                         beastHubNotify("Pet claimed", "", 3)
    --                         return

    --                     else
    --                         print("[DEBUG] Machine ready (not running)")

    --                         local function equipPetByUuid(uuid)
    --                             print("[DEBUG] Equipping pet:", uuid)
    --                             local player = game.Players.LocalPlayer
    --                             local backpack = player:WaitForChild("Backpack")
    --                             for _, tool in ipairs(backpack:GetChildren()) do
    --                                 if tool:GetAttribute("PET_UUID") == uuid then
    --                                     player.Character.Humanoid:EquipTool(tool)
    --                                 end
    --                             end
    --                         end

    --                         if playerData.PetAgeBreakMachine.PetReady then
    --                             print("[DEBUG] Claiming leftover pet")
    --                             game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Claim:FireServer()
    --                             beastHubNotify("Claimed any pet that is ready", "", 3)
    --                         else
    --                             print("[DEBUG] Cancelling stale pet")
    --                             game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Cancel:FireServer()
    --                             beastHubNotify("Removing unstarted pet, if any", "", 3)
    --                         end

    --                         if autoPetAgeBreakEnabled then
    --                             equipPetByUuid(selectedId)
    --                             task.wait()
    --                             print("[DEBUG] Submitting target pet")
    --                             game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_SubmitHeld:FireServer()
    --                             beastHubNotify("Target Pet submitted to breaker", "",3)
    --                             task.wait(2)
    --                         end

    --                         if autoPetAgeBreakEnabled then
    --                             print("[DEBUG] Submitting sacrifice pet:", petIdToSacrifice)
    --                             local args = {
    --                                 [1] = {
    --                                     [1] = petIdToSacrifice
    --                                 }
    --                             }
    --                             game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Submit:FireServer(unpack(args))
    --                             beastHubNotify("Breaker machine started!", "", 3)
    --                             task.wait(1)
    --                         end

    --                         while autoPetAgeBreakEnabled do 
    --                             print("[DEBUG] Monitoring new run...")
    --                             task.wait(5)

    --                             if toggle_autoSkipViaToken.CurrentValue and playerData.PetAgeBreakMachine.IsRunning then
    --                                 print("[DEBUG] Attempting skip via token")
    --                                 local ok,err = pcall(function()
    --                                     game:GetService("ReplicatedStorage").GameEvents.TradeEvents.TradeTokens.Purchase:InvokeServer(3453278902)
    --                                 end)
    --                                 if not ok then warn("[DEBUG] Skip error:", err) end
    --                             end

    --                             task.wait(5)
    --                             playerData = getPlayerData()

    --                             if not playerData.PetAgeBreakMachine.IsRunning then
    --                                 print("[DEBUG] New run finished")
    --                                 break
    --                             end
    --                         end

    --                         if autoPetAgeBreakEnabled then
    --                             print("[DEBUG] Claiming newly processed pet")
    --                             game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Claim:FireServer()
    --                             beastHubNotify("Claimed ready pet in breaker", "", 3)
    --                             task.wait(5)
    --                         end
    --                     end
    --                 end
    --             else
    --                 print("[DEBUG] No valid sacrifice or conditions failed")
    --                 beastHubNotify("No worthy sacrifice.", "", 3)
    --                 autoPetAgeBreakEnabled = false
    --                 autoPetAgeBreakThread = nil
    --             end

    --             print("[DEBUG] Cycle complete")
    --             beastHubNotify("Auto Pet Age Break cycle done", "", 3)
    --         end

    --         if autoPetAgeBreakEnabled and not autoPetAgeBreakThread then
    --             print("[DEBUG] Starting thread loop")
    --             autoPetAgeBreakThread = task.spawn(function()
    --                 while autoPetAgeBreakEnabled do
    --                     autoBreaker(sacrificePetName, selectedId)
    --                     selectedTargetCurrentAge = selectedTargetCurrentAge + 1
    --                     print("[DEBUG] Incremented target age:", selectedTargetCurrentAge)
    --                 end
    --                 print("[DEBUG] Thread exited")
    --             end)
    --         end 
    --     end,
    -- })
    Pets:CreateToggle({
        Name = "Auto Pet Age Break",
        CurrentValue = false,
        Flag = "autoPetAgeBreak", 
        Callback = function(Value)
            autoPetAgeBreakEnabled = Value
            local autoBreaker

            if not autoPetAgeBreakEnabled then
                if autoPetAgeBreakThread then
                    task.cancel(autoPetAgeBreakThread)
                    autoPetAgeBreakThread = nil
                    beastHubNotify("Auto Pet Age Break stopped", "", 3)
                end
                return
            else
                beastHubNotify("Auto breaker running", "", 3)
            end
            
            local start = tick()
            local maxWait = 10
            while not getgenv().ConfigLoaded do
                local elapsed = tick() - start
                if elapsed >= maxWait then
                    beastHubNotify("Pet Age break failed to load", "Please rejoin", 5)
                    break
                end
                task.wait(0.5)
            end
            task.wait(3)

            local sacrificePetName = (selectedPetForAgeBreak.CurrentOption[1]:match("^(.-)%s*|") or ""):match("^%s*(.-)%s*$")
            local selectedId = selectedPetForAgeBreaker or petBreakerTargetIDstored.CurrentOption[1]

            if petBreakerTargetIDstoredFinal ~= nil then
                selectedId = petBreakerTargetIDstoredFinal
            end

            autoBreaker = function(sacrificePetNameParam, selectedIdParam)
                local function getPlayerData()
                    local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                    local logs = dataService:GetData()
                    return logs
                end

                local function getPetIdByNameAndFilterKg(name, basekg, belowLevel, exceptId)
                    local finalBelowLevel = (belowLevel == 1) and 2 or belowLevel
                    local playerData = getPlayerData()

                    if playerData.PetsData and playerData.PetsData.PetInventory and playerData.PetsData.PetInventory.Data then
                        for id, data in pairs(playerData.PetsData.PetInventory.Data) do
                            local curBaseKG = tonumber(string.format("%.2f", data.PetData.BaseWeight * 1.1))
                            if not data.PetData.IsFavorite and data.PetType == name and curBaseKG < basekg and id ~= exceptId and data.PetData.Level < finalBelowLevel then
                                return id
                            end
                        end
                        return nil
                    else
                        warn("PetsData not found!")
                        return nil
                    end
                end

                local petIdToSacrifice = getPetIdByNameAndFilterKg(
                    sacrificePetNameParam,
                    tonumber(petAgeKGsacrifice.CurrentOption[1]),
                    tonumber(petAgeLevelSacrifice.CurrentValue),
                    selectedIdParam
                )

                if petIdToSacrifice and autoPetAgeBreakEnabled and selectedTargetCurrentAge < targetPetAgeBreakerLevel then
                    beastHubNotify("Worthy sacrifice found!","",3)

                    local playerData = getPlayerData()
                    task.wait(1)

                    if playerData.PetAgeBreakMachine then
                        if playerData.PetAgeBreakMachine.IsRunning then
                            local runningId = playerData.PetAgeBreakMachine.SubmittedPet.UUID or ""

                            if runningId == selectedIdParam then
                                beastHubNotify("the selected pet is already running in breaker machine", "", 3)
                            else
                                beastHubNotify("A different pet is already running", "waiting for breaker to be done", "3")
                            end

                            while autoPetAgeBreakEnabled do 
                                task.wait(5)

                                if toggle_autoSkipViaToken.CurrentValue and playerData.PetAgeBreakMachine.IsRunning then
                                    local ok,err = pcall(function()
                                        game:GetService("ReplicatedStorage").GameEvents.TradeEvents.TradeTokens.Purchase:InvokeServer(3453278902)
                                    end)
                                    if not ok then warn(err) end
                                end

                                task.wait(5)
                                playerData = getPlayerData()

                                if not playerData.PetAgeBreakMachine.IsRunning then
                                    break
                                end
                            end

                            task.wait(1)
                            game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Claim:FireServer()
                            beastHubNotify("Pet claimed", "", 3)
                            return

                        else
                            local function equipPetByUuid(uuid)
                                local player = game.Players.LocalPlayer
                                local backpack = player:WaitForChild("Backpack")
                                for _, tool in ipairs(backpack:GetChildren()) do
                                    if tool:GetAttribute("PET_UUID") == uuid then
                                        player.Character.Humanoid:EquipTool(tool)
                                    end
                                end
                            end

                            if playerData.PetAgeBreakMachine.PetReady then
                                game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Claim:FireServer()
                                beastHubNotify("Claimed any pet that is ready", "", 3)
                            else
                                game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Cancel:FireServer()
                                beastHubNotify("Removing unstarted pet, if any", "", 3)
                            end

                            if autoPetAgeBreakEnabled then
                                equipPetByUuid(selectedId)
                                task.wait()
                                game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_SubmitHeld:FireServer()
                                beastHubNotify("Target Pet submitted to breaker", "",3)
                                task.wait(2)
                            end

                            if autoPetAgeBreakEnabled then
                                local args = {
                                    [1] = {
                                        [1] = petIdToSacrifice
                                    }
                                }
                                game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Submit:FireServer(unpack(args))
                                beastHubNotify("Breaker machine started!", "", 3)
                                task.wait(1)
                            end

                            while autoPetAgeBreakEnabled do 
                                task.wait(5)

                                if toggle_autoSkipViaToken.CurrentValue and playerData.PetAgeBreakMachine.IsRunning then
                                    local ok,err = pcall(function()
                                        game:GetService("ReplicatedStorage").GameEvents.TradeEvents.TradeTokens.Purchase:InvokeServer(3453278902)
                                    end)
                                    if not ok then warn(err) end
                                end

                                task.wait(5)
                                playerData = getPlayerData()

                                if not playerData.PetAgeBreakMachine.IsRunning then
                                    break
                                end
                            end

                            if autoPetAgeBreakEnabled then
                                game:GetService("ReplicatedStorage").GameEvents.PetAgeLimitBreak_Claim:FireServer()
                                beastHubNotify("Claimed ready pet in breaker", "", 3)
                                task.wait(5)
                            end
                        end
                    end
                else
                    beastHubNotify("[Auto Breaker] No worthy sacrifice.", "", 3)
                    -- autoPetAgeBreakEnabled = false
                    -- autoPetAgeBreakThread = nil
                end

                -- beastHubNotify("Auto Pet Age Break cycle done", "", 3)
            end

            if autoPetAgeBreakEnabled and not autoPetAgeBreakThread then
                autoPetAgeBreakThread = task.spawn(function()
                    while autoPetAgeBreakEnabled do
                        autoBreaker(sacrificePetName, selectedId)
                        selectedTargetCurrentAge = selectedTargetCurrentAge + 1
                        task.wait(10)
                    end
                end)
            end 
        end,
    })

    Pets:CreateDivider()


    Pets:CreateSection("Other Pet settings")
    Pets:CreateButton({
        Name = "Boost All Pets using Held item",
        Callback = function()
            local function getPlayerData()
                local dataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
                local HttpService = game:GetService("HttpService")
                local logs = dataService:GetData()
                local playerData = HttpService:JSONEncode(logs)
                -- print(logs.PetsData.EquippedPets)
                --setclipboard(playerData)
                return logs.PetsData.EquippedPets
            end

            local data = getPlayerData()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local PetBoostService = ReplicatedStorage.GameEvents.PetBoostService -- RemoteEvent 
                
            for _, id in ipairs(data) do
                -- print(id)
                PetBoostService:FireServer(
                    "ApplyBoost",
                    id
                )
                -- print("boosted!")
            end
        end,
    })
    Pets:CreateDivider()


    -- subscribe dropdowns to global event
    getgenv().LoadoutsChangedEvent.Event:Connect(function()
        local baseOptions = getgenv().preloadedCustomLoadoutNames or {}
        local updatedOptions = {unpack(baseOptions)}
        table.insert(updatedOptions, 1, "None")

        local success, err = pcall(function()
            dropdown_claimMachinePet:Refresh(updatedOptions)
            task.wait()
            dropdown_mutation_leveling_A:Refresh(updatedOptions)
            task.wait()
            dropdown_mutation_leveling_B:Refresh(updatedOptions)
            task.wait()
            dropdown_mutation_golem:Refresh(updatedOptions)
            task.wait()
            dropdown_autolevel_A:Refresh(updatedOptions)
            task.wait()
            dropdown_autolevel_B:Refresh(updatedOptions)
            task.wait()
            dropdown_NM_loadout_A:Refresh(updatedOptions)
            task.wait()
            dropdown_NM_loadout_B:Refresh(updatedOptions)
            task.wait()
            dropdown_horseman_loadout:Refresh(updatedOptions)
            task.wait()
            dropdown_eleV1_leveling_A:Refresh(updatedOptions)
            task.wait()
            dropdown_eleV1_loadout:Refresh(updatedOptions)
            task.wait()
            dropdown_eleV2_leveling_A:Refresh(updatedOptions)
            task.wait()
            dropdown_eleV2_leveling_B:Refresh(updatedOptions)
            task.wait()
            dropdown_eleV2_loadout:Refresh(updatedOptions)
        end)
        if not success then
            warn("Failed to refresh dropdown:", err)
        end
    end)
    getgenv().LoadoutsChangedEvent:Fire()
end

    
return M
