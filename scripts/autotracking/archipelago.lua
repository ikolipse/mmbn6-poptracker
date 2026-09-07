require("scripts.autotracking.item_mapping")
require("scripts.autotracking.location_mapping")
require("scripts.autotracking.room_id_to_tab_mapping")

CUR_INDEX = -1
--SLOT_DATA = nil

ALL_LOCATIONS = {}
SLOT_DATA = {}

MANUAL_CHECKED = true
ROOM_SEED = "default"
TROLL_PLAYER = false

if Highlight then
    HIGHLIGHT_LEVEL= {
        [0] = Highlight.Unspecified,
        [10] = Highlight.NoPriority,
        [20] = Highlight.Avoid,
        [30] = Highlight.Priority,
        [40] = Highlight.None,
        [100] = Highlight.Unspecified, --Filler
        [101] = Highlight.Priority, --Progression
        [102] = Highlight.NoPriority, --Useful
        [103] = Highlight.Priority, -- Prog + Useful
        [104] = Highlight.Avoid, --Trap
        [105] = Highlight.Priority, -- Prog + Trap
        [106] = Highlight.NoPriority, -- Useful + Trap
        [107] = Highlight.Priority, -- Prog + Useful + Trap
    }
end

Troll_Lookup = {
    ["solarcell"] = true,
    ["earthor"] = true,
}

---function to build a pretty-printable representation of a provided table
---@param o table
---@param depth? integer
---@return string
function DumpTable(o, depth)
    if depth == nil then
        depth = 0
    end
    if type(o) == 'table' then
        local tabs = ('\t'):rep(depth)
        local tabs2 = ('\t'):rep(depth + 1)
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. tabs2 .. '[' .. k .. '] = ' .. DumpTable(v, depth + 1) .. ',\n'
        end
        return s .. tabs .. '}'
    else
        return tostring(o)
    end
end

---helper function that gets called when a LocationSection has changed state.
---checks if the interaction was from the server or manual.
---if manual, puts it into a cache for keeping that LocationSection toggled when reconnecting
---@param location LocationSection
function LocationHandler(location)
    if MANUAL_CHECKED then
        local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
        if not custom_storage_item then
            return
        end
        if Archipelago.PlayerNumber == -1 then -- not connected
            if ROOM_SEED ~= "default" then -- seed is from previous connection
                ROOM_SEED = "default"
                custom_storage_item.MANUAL_LOCATIONS["default"] = {}
            else -- seed is default
            end
        end
        local full_path = location.FullID
        if not custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] then
            custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] = {}
        end
        if location.AvailableChestCount < location.ChestCount then --add to list
            -- print("add to list")
            custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][full_path] = location.AvailableChestCount
        else --remove from list of set back to max chestcount
            -- print("remove from list")
            custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][full_path] = nil
        end
    end
    -- local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
    -- print(DumpTable(storage_item.ItemState.MANUAL_LOCATIONS))
    ForceUpdate() --
end

--function to force an update even if the interaction within poptracker noramlly would not call for a state update
function ForceUpdate()
    local update = Tracker:FindObjectForCode("update")
    if update == nil then
        return
    end
    update.Active = not update.Active
end


---resets or updates a given item back to default or what's saved for the given seed in the pseudo-cache LuaItems
---@param item_code JsonItem|string Tracker:FindObjectForCode(item) return object
---@param item_type string|nil table of the ItemCode and extra parameters from the Item_Mapping.lau
---@param consumable_multiplier integer|nil table of the ItemCode and extra parameters from the Item_Mapping.lua
---@param item_id integer AP-ID of the item from ITEM_MAPPING
---@param reset boolean|nil flag to update or reset the item false=update, true=reset, nil=update
local function ItemUpdate(item_code, item_type, consumable_multiplier, item_id, reset)
    local item_obj = nil

    if type(item_code) == "string" then
        item_obj = Tracker:FindObjectForCode(item_code)
    else
        item_obj = item_code
    end
    if item_obj == nil then
        print(string.format("ItemUpdate: could not find item_object for code %s", item_code))
        return
    end

    if item_type == nil then
        item_type = item_obj.Type
    end

    if item_type == "toggle" then
        item_obj.Active = not reset --reset and false or true
    elseif item_type == "progressive" then
        item_obj.CurrentStage = reset and 0 or (item_obj.CurrentStage + 1)
    elseif item_type == "consumable" then
        item_obj.AcquiredCount = reset and (item_obj.MinCount or 0) or
        (item_obj.AcquiredCount + item_obj.Increment * (consumable_multiplier or 1))
    elseif item_type == "progressive_toggle" then
        item_obj.CurrentStage = reset and 0 or (item_obj.CurrentStage + 1)
        item_obj.Active = not reset -- reset and false or true
    end
end


---resets or updates a given location back to default or whats saved for the gives seed in the pseudo-cache LuaItems
---@param location_obj LocationSection Tracker:FindObjectForCode(location) return object
---@param custom_storage_item table Reference for the custom LuaItem CachesItems
---@param location_id integer AP-ID of the location from LOCATION_MAPPING
---@param reset boolean flag to update or reset the item false=update, true=reset, nil=update
local function LocationUpdate(location_obj, custom_storage_item, location_id, reset)
    ---@cast location_obj LocationSection

    if reset then --reset
        if custom_storage_item and custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][location_obj.FullID] then
            location_obj.AvailableChestCount = custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED][location_obj.FullID]
        else
            location_obj.AvailableChestCount = location_obj.ChestCount
        end
        location_obj.Highlight = HIGHLIGHT_LEVEL[40]
    else --update
        (location_obj --[[@as LocationSection]]).AvailableChestCount = location_obj.AvailableChestCount - 1
    end
end


--- Function to prepare custom LuaItems for caching, check for mischieve/traps, subscribe to datastorage
local function PreOnClear()
    PLAYER_ID = Archipelago.PlayerNumber or -1
	TEAM_NUMBER = Archipelago.TeamNumber or 0
    if PLAYER_ID > -1 then
        for key, _ in pairs(Troll_Lookup) do
            if string.find(string.lower(Archipelago:GetPlayerAlias(PLAYER_ID)), key, 1, true) ~= nil then
                TROLL_PLAYER = true
                break
            end
        end

        --- example for how to build a date object and how to check current user's date against it
        --local start_day_range = BuildTimeObj(nil, 3 , 31)
        --local end_day_range = BuildTimeObj(nil, 4 , 5)
        --DATE_CHECK_PASSED = CheckDateRange(start_day_range, end_day_range, os.time())
        --if TROLL_PLAYER == false and DATE_CHECK_PASSED then
        --    TROLL_PLAYER = true
        --end

        if #ALL_LOCATIONS > 0 then
            ALL_LOCATIONS = {}
        end
        for _, value in pairs(Archipelago.MissingLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end

        for _, value in pairs(Archipelago.CheckedLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end
        ---add more of those for other datastorage keys
        HINTS_ID = "_read_hints_"..TEAM_NUMBER.."_"..PLAYER_ID
        Archipelago:SetNotify({HINTS_ID}) --{HINTS_ID, other vars, ...}
        Archipelago:Get({HINTS_ID}) --{HINTS_ID, other vars, ...}
    end


    -- print(Archipelago.Seed)
    local seed_base = (Archipelago.Seed or tostring(#ALL_LOCATIONS)).."_"..Archipelago.TeamNumber.."_"..Archipelago.PlayerNumber
    if ROOM_SEED == "default" or ROOM_SEED ~= seed_base then -- seed is default or from previous connection

        ROOM_SEED = seed_base --something like 2345_0_12
        for _, custom_item_code in pairs({"manual_location_storage"}) do -- add more to the table if you created more storage cache items
            local custom_storage_item = Tracker:FindObjectForCode(custom_item_code).ItemState
            if custom_storage_item then
                if #custom_storage_item.MANUAL_LOCATIONS > 10 then
                    custom_storage_item.MANUAL_LOCATIONS[custom_storage_item.MANUAL_LOCATIONS_ORDER[1]] = nil
                    table.remove(custom_storage_item.MANUAL_LOCATIONS_ORDER, 1)
                end
                if custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] == nil then
                    custom_storage_item.MANUAL_LOCATIONS[ROOM_SEED] = {}
                    table.insert(custom_storage_item.MANUAL_LOCATIONS_ORDER, ROOM_SEED)
                end
            end
        end
    else -- seed is from previous connection
        -- do nothing
    end
end

---function that gets called when the pack connects to an AP server
---@param slot_data? table Slotdata send from AP server for the specific user/slot
function OnClear(slot_data)
    MANUAL_CHECKED = false
    local custom_storage_item = Tracker:FindObjectForCode("manual_location_storage")
    if custom_storage_item == nil then
        CreateLuaManualStorageItem("manual_location_storage")
        custom_storage_item = Tracker:FindObjectForCode("manual_location_storage").ItemState
	else
		custom_storage_item = custom_storage_item.ItemState
    end
    -- repeat that here for every cache-storage item you create just to be safe

    PreOnClear()

    ScriptHost:RemoveWatchForCode("StateChanged")
    ScriptHost:RemoveOnLocationSectionHandler("location_section_change_handler")
    --SLOT_DATA = slot_data
    CUR_INDEX = -1
    -- reset locations
    for location_ID, location_array in pairs(LOCATION_MAPPING) do
        for _, location in pairs(location_array) do
            if location then
                if type(location) == "table" then
                    local item_code, item_type, consumable_multiplies = table.unpack(location)
                    ItemUpdate(item_code, item_type, consumable_multiplies, location_ID, true)
                else
                    if location:sub(1, 1) == "@" then
                        ---@type LocationSection
                        local location_obj = Tracker:FindObjectForCode(location) --[[@as LocationSection]]
                        local custom_storage_item = (Tracker:FindObjectForCode("manual_location_storage") --[[@as LuaItem]])
                        .ItemState

                        if location_obj then
                            LocationUpdate(location_obj, custom_storage_item, location_ID, true)
                        end
                    else
                        ---@cast location JsonItem
                        ItemUpdate(location, nil, nil, location_ID, true)
                    end
                end
            end
        end
    end
    -- reset items
    for item_ID, item_array in pairs(ITEM_MAPPING) do
        for _, item_pair in pairs(item_array) do
            local item_code = item_pair[1]
            local item_type = item_pair[2]
            local consumable_multiplier = tonumber(item_pair[3]) or 1
            -- print("on clear", item_code, item_type)
			---@type JsonItem
            local item_obj = Tracker:FindObjectForCode(item_code) --[[@as JsonItem]]
            if item_obj then
                ItemUpdate(item_obj, item_type, consumable_multiplier, item_ID, true)
            end
        end
    end
    PLAYER_ID = Archipelago.PlayerNumber or -1
    TEAM_NUMBER = Archipelago.TeamNumber or 0
    SLOT_DATA = slot_data

    if Tracker:FindObjectForCode("autofill_settings").Active == true then
        --print("should be able to autofill")
        AutoFill(slot_data)
    end
    -- print(PLAYER_ID, TEAM_NUMBER)
    if Archipelago.PlayerNumber > -1 then
        if #ALL_LOCATIONS > 0 then
            ALL_LOCATIONS = {}
        end
        for _, value in pairs(Archipelago.MissingLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end

        for _, value in pairs(Archipelago.CheckedLocations) do
            table.insert(ALL_LOCATIONS, #ALL_LOCATIONS + 1, value)
        end

        HINTS_ID = "_read_hints_"..TEAM_NUMBER.."_"..PLAYER_ID
		ROOM_ID = "mmbn6_room_"..TEAM_NUMBER.."_"..PLAYER_ID
        Archipelago:SetNotify({HINTS_ID, ROOM_ID})
        Archipelago:Get({HINTS_ID, ROOM_ID})
    end
    ScriptHost:AddOnFrameHandler("load handler", OnFrameHandler)
    MANUAL_CHECKED = true
end

---Run every time an Item gets sent to the connected slot
---@param index integer running index for the items the connected slot has received so far
---@param item_id integer ID of the received item, matching the game's datapackage ID
---@param item_name string name of the item from the datapackage for the given itemID
---@param player_number integer slotnumber of the player who picked up the item
function OnItem(index, item_id, item_name, player_number)
    if index <= CUR_INDEX then
        return
    end
    local is_local = player_number == Archipelago.PlayerNumber
    CUR_INDEX = index;
    local item = ITEM_MAPPING[item_id]
    if not item or not item[1] then
        --print(string.format("OnItem: could not find item mapping for id %s", item_id))
        return
    end
    for _, item_pair in pairs(item) do
        local item_code = item_pair[1]
        local item_type = item_pair[2]
        local consumable_multiplier = tonumber(item_pair[3]) or 1

        local item_obj = Tracker:FindObjectForCode(item_code)
        if item_obj then
            ItemUpdate(item_code, item_type, consumable_multiplier, item_id, false)
        else
            print(string.format("OnItem: could not find object for code %s", item_code))
        end
    end
end

LOCATION_NAMES = {
	"@RobotControlComp/RobotControl1/Robot Control Comp 1 BMD 1/",
	"@RobotControlComp/RobotControl1/Robot Control Comp 1 BMD 2/",
	"@RobotControlComp/RobotControl2/Robot Control Comp 2 BMD 1/",
	"@RobotControlComp/RobotControl2/Robot Control Comp 2 BMD 2/",
	"@AquariumComp/Aquarium1/Aquarium Comp 1 BMD 1/",
	"@AquariumComp/Aquarium1/Aquarium Comp 1 BMD 2/",
	"@AquariumComp/Aquarium2/Aquarium Comp 2 BMD 1/",
	"@AquariumComp/Aquarium2/Aquarium Comp 2 BMD 2/",
	"@AquariumComp/Aquarium3/Aquarium Comp 3 BMD 1/",
	"@AquariumComp/Aquarium3/Aquarium Comp 3 BMD 2/",
	"@JudgeTreeComp/JudgeTree1/JudgeTree Comp 1 BMD 1/",
	"@JudgeTreeComp/JudgeTree1/JudgeTree Comp 1 BMD 2/",
	"@JudgeTreeComp/JudgeTree2/JudgeTree Comp 2 BMD 1/",
	"@JudgeTreeComp/JudgeTree2/JudgeTree Comp 2 BMD 2/",
	"@JudgeTreeComp/JudgeTree3/JudgeTree Comp 3 BMD 1/",
	"@JudgeTreeComp/JudgeTree3/JudgeTree Comp 3 BMD 2/",
	"@WeatherComp/Weather1/Mr. Weather Comp 1 BMD 1/",
	"@WeatherComp/Weather1/Mr. Weather Comp 1 BMD 2/",
	"@WeatherComp/Weather2/Mr. Weather Comp 2 BMD 1/",
	"@WeatherComp/Weather2/Mr. Weather Comp 2 BMD 2/",
	"@WeatherComp/Weather3/Mr. Weather Comp 3 BMD 1/",
	"@WeatherComp/Weather3/Mr. Weather Comp 3 BMD 2/",
	"@PavilionComp/Pavilion1/Pavilion Comp 1 BMD 1/",
	"@PavilionComp/Pavilion1/Pavilion Comp 1 BMD 2/",
	"@PavilionComp/Pavilion2/Pavilion Comp 2 BMD 1/",
	"@PavilionComp/Pavilion2/Pavilion Comp 2 BMD 2/",
	"@PavilionComp/Pavilion3/Pavilion Comp 3 BMD 1/",
	"@PavilionComp/Pavilion3/Pavilion Comp 3 BMD 2/",
	"@PavilionComp/Pavilion4/Pavilion Comp 4 BMD 1/",
	"@PavilionComp/Pavilion4/Pavilion Comp 4 BMD 2/",
	"@ACDCNET/ACDC HP/ACDC HP BMD",
	"@SeasideNET/Seaside2/Aquarium HP/Aquarium HP BMD",
	"@GreenNET/Green1/Green HP/Green HP BMD",
	"@SkyNET/Sky1/Sky HP/Sky HP BMD",
	"@CentralTown/CyberCity/RoboDog Comp/RoboDog Comp BMD",
	"@CentralNET/Central1/Labs Comp 1/Labs Comp 1 BMD 1",
	"@CentralNET/Central1/Labs Comp 1/Labs Comp 1 BMD 2",
	"@CentralTown/AcademyClasses/Class 6-1 Comp/Class 6-1 Comp BMD 1",
	"@CentralTown/AcademyClasses/Class 6-1 Comp/Class 6-1 Comp BMD 2",
	"@CentralTown/AcademyClasses/Class 6-2 Comp/Class 6-2 Comp BMD",
	"@CentralTown/AcademyClasses/Class 1-1 Comp/Class 1-1 Comp BMD 1",
	"@CentralTown/AcademyClasses/Class 1-1 Comp/Class 1-1 Comp BMD 2",
	"@CentralTown/AcademyClasses/Class 1-2 Comp/Class 1-2 Comp BMD 1",
	"@CentralTown/AcademyClasses/Class 1-2 Comp/Class 1-2 Comp BMD 2",
	"@CentralTown/CyberCity/Lans House/Bathroom Comp BMD",
	"@SkyTown/SkyExterior/Elevator Comp BMD/",
	"@SeasideAquarium/Exterior/Fish Stick Shop Comp/Fish Stick Shop Comp BMD 1",
	"@SeasideAquarium/Exterior/Fish Stick Shop Comp/Fish Stick Shop Comp BMD 2",
	"@CentralTown/AcademyClasses/Security Camera Comp/Security Camera Comp BMD 1",
	"@CentralTown/AcademyClasses/Security Camera Comp/Security Camera Comp BMD 2",
	"@GreenNET/Green1/Book Comp/Book Comp BMD 1",
	"@GreenNET/Green1/Book Comp/Book Comp BMD 2",
	"@SkyTown/SkyExterior/Fan Comp/Fan Comp BMD 1",
	"@SkyTown/SkyExterior/Fan Comp/Fan Comp BMD 2",
	"@SkyTown/SkyExterior/Air Conditioner Comp/Air Conditioner Comp BMD 1",
	"@SkyTown/SkyExterior/Air Conditioner Comp/Air Conditioner Comp BMD 2",
	"@SkyTown/SkyExterior/Heater Comp/Heater Comp BMD 1",
	"@SkyTown/SkyExterior/Heater Comp/Heater Comp BMD 2",
	"@SkyTown/SkyExterior/Shower Comp/Shower Comp BMD 1",
	"@SkyTown/SkyExterior/Shower Comp/Shower Comp BMD 2",
	"@SkyNET/Sky2/Heliport Comp/Heliport Comp BMD 1",
	"@SkyNET/Sky2/Heliport Comp/Heliport Comp BMD 2",
	"@Undernet/Undernet1/Labs Comp 2/Labs Comp 2 BMD",
	"@Undernet/Undernet2/Vending Machine Comp/Vending Machine Comp BMD 1",
	"@Undernet/Undernet2/Vending Machine Comp/Vending Machine Comp BMD 2",
	"@GreenTown/Courthouse/Punish Chair Comp/Punish Chair Comp BMD",
	"@SeasideAquarium/Exterior/Water Machine Comp/Water Machine Comp BMD",
	"@GreenTown/GreenExterior/Symbol Comp/Symbol Comp BMD 1",
	"@GreenTown/GreenExterior/Symbol Comp/Symbol Comp BMD 2",
	"@CentralTown/AcademyOffices/Monitor Comp BMD/",
	"@SeasideAquarium/Interior/Popcorn Shop Comp BMD/",
	"@CentralTown/AcademyOffices/Teachers Room Comp/Teachers Room Comp BMD 1",
	"@CentralTown/AcademyOffices/Teachers Room Comp/Teachers Room Comp BMD 2",
	"@SeasideAquarium/Interior/Pipe Comp BMD/",
	"@SkyTown/Control/Observation Comp/Observation Comp BMD 1",
	"@SkyTown/Control/Observation Comp/Observation Comp BMD 2",
	"@SkyTown/Control/Oxygen Tank Comp/Oxygen Tank Comp BMD",
	"@CentralTown/AcademyOffices/Principals Office Comp/Principals Office Comp BMD 1",
	"@CentralTown/AcademyOffices/Principals Office Comp/Principals Office Comp BMD 2",
	"@CentralTown/Expo/Mascot Comp/Mascot Comp BMD 1",
	"@CentralTown/Expo/Mascot Comp/Mascot Comp BMD 2",
	"@SeasideNET/Seaside1/Stuffed Toy Shop Comp/Stuffed Toy Shop Comp BMD 1",
	"@SeasideNET/Seaside1/Stuffed Toy Shop Comp/Stuffed Toy Shop Comp BMD 2",
	"@ACDCTown/Dog House Comp/Dog House Comp BMD 1",
	"@ACDCTown/Dog House Comp/Dog House Comp BMD 2",
	"@CentralTown/Expo/Guide Panel Comp BMD/",
	"@CentralNET/Central1/Central Area 1 BMD 1/",
	"@CentralNET/Central1/Central Area 1 BMD 2/",
	"@CentralNET/Central2/Central Area 2 BMD 1/",
	"@CentralNET/Central2/Central Area 2 BMD 2/",
	"@CentralNET/Central3/Central Area 3 BMD/",
	"@SeasideNET/Seaside1/Seaside Area 1 BMD 1/",
	"@SeasideNET/Seaside1/Seaside Area 1 BMD 2/",
	"@SeasideNET/Seaside1/Seaside Area 1 BMD 3/",
	"@SeasideNET/Seaside2/Seaside Area 2 BMD 1/",
	"@SeasideNET/Seaside2/Seaside Area 2 BMD 2/",
	"@SeasideNET/Seaside2/Seaside Area 2 BMD 3/",
	"@SeasideNET/Seaside3/Seaside Area 3 BMD/",
	"@GreenNET/Green1/Green Area 1 BMD 1/",
	"@GreenNET/Green1/Green Area 1 BMD 2/",
	"@GreenNET/Green2/Green Area 2 BMD 1/",
	"@GreenNET/Green2/Green Area 2 BMD 2/",
	"@GreenNET/Green2/Green Area 2 BMD 3/",
	"@Underground/Underground2/Underground 2 BMD 1/",
	"@Underground/Underground2/Underground 2 BMD 2/",
	"@SkyNET/Sky1/Sky Area 1 BMD 1/",
	"@SkyNET/Sky1/Sky Area 1 BMD 2/",
	"@SkyNET/Sky2/Sky Area 2 BMD 1/",
	"@SkyNET/Sky2/Sky Area 2 BMD 2/",
	"@SkyNET/Sky2/Sky Area 2 BMD 3/",
	"@ACDCNET/ACDC Area BMD 1/",
	"@ACDCNET/ACDC Area BMD 2/",
	"@Undernet/Undernet1/Undernet 1 BMD/",
	"@Undernet/Undernet0/Undernet Zero BMD 1/",
	"@Undernet/Undernet0/Undernet Zero BMD 2/",
	"@Undernet/Undernet0/Undernet Zero BMD 3/",
	"@Undernet/Undernet2/Undernet 2 BMD/",
	"@Undernet/Graveyard/Graveyard BMD 1/",
	"@Undernet/Graveyard/Graveyard BMD 2/",
	"@Undernet/Graveyard/Graveyard BMD 3/",
	"@Undernet/Graveyard/Graveyard BMD 4/",
	"@Undernet/Graveyard/Graveyard BMD 5/",
	"@ACDCNET/ACDC HP/ACDC HP PMD",
	"@SeasideNET/Seaside2/Aquarium HP/Aquarium HP PMD",
	"@GreenNET/Green1/Green HP/Green HP PMD",
	"@SkyNET/Sky1/Sky HP/Sky HP PMD",
	"@CentralTown/AcademyClasses/Class 6-2 Comp/Class 6-2 Comp PMD",
	"@Undernet/Undernet1/Labs Comp 2/Labs Comp 2 PMD",
	"@GreenTown/Courthouse/Punish Chair Comp/Punish Chair Comp PMD",
	"@SkyTown/Control/Oxygen Tank Comp/Oxygen Tank Comp PMD",
	"@CentralNET/Central3/Central Area 3 PMD/",
	"@SeasideNET/Seaside3/Seaside Area 3 PMD/",
	"@GreenNET/Green1/Green Area 1 PMD/",
	"@Underground/Underground1/Underground 1 PMD 1/",
	"@Underground/Underground1/Underground 1 PMD 2/",
	"@SkyNET/Sky1/Sky Area 1 PMD/",
	"@ACDCNET/ACDC Area PMD/",
	"@Undernet/Undernet1/Undernet 1 PMD/",
	"@Undernet/Undernet2/Undernet 2 PMD/",
	"@Undernet/Graveyard/Graveyard PMD 1/",
	"@Undernet/Graveyard/Graveyard PMD 2/",
	"@CentralTown/AcademyClasses/School Mr Quiz/",
	"@SeasideAquarium/Interior/Aquarium Quiz Master/",
	"@GreenTown/Courthouse/Green Quiz King/",
	"@CentralTown/CyberCity/Central Barr100 H Trade/",
	"@SeasideNET/Seaside2/Aquarium HP/Aquarium PnlRetrn Trade",
	"@GreenTown/Courthouse/Green HolyPnl S Trade/",
	"@SkyTown/SkyExterior/Air Conditioner Comp/AirCon AuraHed1 B Trade",
	"@CentralTown/AcademyClasses/Class 1-2 EnergBom K Trade/",
	"@SeasideAquarium/Interior/Aquarium DublShot C Trade/",
	"@SeasideAquarium/Exterior/Water Machine Comp/WatrMchn HiBoomer V Trade",
	"@SkyTown/Control/Sky GrabRvng I Trade/",
	"@ACDCNET/ACDC HP/ACDC BigBomb O Trade",
	"@CentralTown/AcademyClasses/Class 6-1 Grid/",
	"@SeasideAquarium/Interior/Seaside Auditorium Trash Can/",
	"@SeasideAquarium/Interior/Seaside Control Room Ladder/",
	"@GreenTown/Courthouse/Green Foyer Flowers/",
	"@SkyTown/Control/Sky Air Tank/",
	"@ACDCTown/ACDC Dexs Door/",
	"@CentralTown/AcademyOffices/Principals Coffee Table/",
	"@CentralTown/Expo/Seaside Pavilion Waterfall/",
	"@CentralNET/Central1/Central 1 Net Cafe/",
	"@GreenNET/Green2/Green 2 Net Cafe/",
	"@SkyNET/Sky1/Sky 1 Net Cafe/",
	"@CentralNET/Central2/Central 2 Heel Navi/",
	"@CentralTown/AcademyClasses/Class 1-2 Comp/Class 1-2 Heel Navi",
	"@SeasideAquarium/Interior/Seaside Auditorium Man/",
	"@AquariumComp/Aquarium1/Aquarium Comp 1 Navi/",
	"@GreenNET/Green1/Green 1 Heel Navi/",
	"@Undernet/Undernet0/Undernet Zero Heel Navi/",
	"@GreenTown/Courthouse/Green Punishment Room Prog/",
	"@SkyNET/Sky1/Sky 1 Brown Navi/",
	"@Undernet/Undernet0/Bass/",
	"@Undernet/Graveyard/Bass SP/",
	"@Underground/Underground2/Bass BX/",
	"@CentralTown/CyberCity/Lans House/Talk To Mayl",
	"@SkyTown/SkyExterior/Heliport Link Navi/ElecMan Class",
	"@GreenTown/GreenExterior/Book Link Navi/SlashMan Class",
	"@CentralTown/AcademyOffices/Labs 2 Link Navi/EraseMan Class",
	"@SeasideAquarium/Interior/Vending Machine Link Navi/ChargeMan Class",
	"@SkyTown/SkyExterior/Heliport Link Navi/TomahawkMan Class",
	"@GreenTown/GreenExterior/Book Link Navi/TenguMan Class",
	"@CentralTown/AcademyOffices/Labs 2 Link Navi/GroundMan Class",
	"@SeasideAquarium/Interior/Vending Machine Link Navi/DustMan Class",
	"@CentralTown/CyberCity/RoboDog Comp/RoboDog Comp Virus Battler",
	"@SeasideAquarium/Exterior/Water Machine Comp/WatrMchn Comp Virus Battler",
	"@GreenTown/Courthouse/Punish Chair Comp/Punish Chair Comp Virus Battler",
	"@SkyTown/Control/Oxygen Tank Comp/Oxygen Tank Comp Virus Battler",
	"@CentralNET/Central1/Central 1 Virus Battler/",
	"@AsterLand/Request/1 Star Requests/Virus Deletion",
	"@AsterLand/Request/1 Star Requests/Find Keepsake",
	"@AsterLand/Request/1 Star Requests/Errand Request",
	"@AsterLand/Request/2 Stars Requests/For Victory!",
	"@AsterLand/Request/2 Stars Requests/JuvenileDiv",
	"@AsterLand/Request/1 Star Requests/Somebody Help!",
	"@AsterLand/Request/1 Star Requests/Get The Chip!",
	"@AsterLand/Request/2 Stars Requests/Stock Up!",
	"@AsterLand/Request/2 Stars Requests/StandIn Recruit",
	"@AsterLand/Request/2 Stars Requests/PenguinsRanAway",
	"@AsterLand/Request/1 Star Requests/Daughter Worry",
	"@AsterLand/Request/1 Star Requests/Stop Him!",
	"@AsterLand/Request/1 Star Requests/Loan Collection",
	"@AsterLand/Request/2 Stars Requests/Lumber Merchant",
	"@AsterLand/Request/3 Stars Requests/TimeCpsl",
	"@AsterLand/Request/1 Star Requests/DietGood Money",
	"@AsterLand/Request/3 Stars Requests/Find The Virus!",
	"@AsterLand/Request/1 Star Requests/Got A Problem.",
	"@AsterLand/Request/1 Star Requests/Songwriter",
	"@AsterLand/Request/2 Stars Requests/Buy Whch Stock",
	"@AsterLand/Request/3 Stars Requests/Cant Open Safe",
	"@AsterLand/Request/3 Stars Requests/Get The Bad Guy",
	"@AsterLand/Request/2 Stars Requests/Update Help",
	"@AsterLand/Request/2 Stars Requests/Do Something!",
	"@AsterLand/Request/2 Stars Requests/Want Meet Dghtr",
	"@AsterLand/Request/2 Stars Requests/Not Engh Member",
	"@AsterLand/Request/3 Stars Requests/Track The Crmnl",
	"@AsterLand/Request/2 Stars Requests/Self Research",
	"@AsterLand/Request/3 Stars Requests/OfficialRequest",
	"@AsterLand/Request/4 Stars Requests/Wheres My Navi",
	"@AsterLand/Request/4 Stars Requests/One More Time.",
	"@AsterLand/Request/4 Stars Requests/SupportChip Pls",
	"@AsterLand/Request/4 Stars Requests/Negotiate!",
	"@AsterLand/Request/3 Stars Requests/An Experiment!",
	"@AsterLand/Request/3 Stars Requests/RoadToSoulBtlr!",
	"@AsterLand/Gacha/Lotto Codes 01-05",
	"@AsterLand/Gacha/Lotto Codes 06-10",
	"@AsterLand/Gacha/Lotto Codes 11-15",
	"@AsterLand/Gacha/Lotto Codes 16-58",
	"@CentralNET/Central2/BlastMan/BlastMan EX",
	"@SeasideNET/Seaside1/DiveMan/DiveMan EX",
	"@CentralNET/Central3/CircusMan/CircusMan EX",
	"@GreenNET/Green2/JudgeMan/JudgeMan EX",
	"@SkyNET/Sky1/ElementMan/ElementMan EX",
	"@Underground/Underground2/Colonel/Colonel EX",
	"@CentralNET/Central2/BlastMan/BlastMan SP - Random encounter",
	"@SeasideNET/Seaside1/DiveMan/DiveMan SP - Random encounter",
	"@CentralNET/Central3/CircusMan/CircusMan SP - Random encounter",
	"@GreenNET/Green2/JudgeMan/JudgeMan SP - Random encounter",
	"@SkyNET/Sky1/ElementMan/ElementMan SP - Random encounter",
	"@Underground/Underground2/Colonel/Colonel SP - Random encounter",
	"@CentralTown/AcademyClasses/ProtoMan FZ/"
}

function checkInLogic()
	local countInLogic = 0
	local countOutOfLogic = 0
	local countCleared = 0
	local countHintable = 0
	local countUnavailable = 0

	for _, loc in pairs(LOCATION_NAMES) do
		local obj = Tracker:FindObjectForCode(loc)

		if obj then
			local level = obj.AccessibilityLevel
			local availableChecks = obj.AvailableChestCount
			local totalChecks = obj.ChestCount

			-- ChestCount - AvailableChestCount = Cleared Checks
			countCleared = countCleared + (totalChecks - availableChecks)

			if availableChecks > 0 then
				if level == ACCESS_NORMAL then
					countInLogic = countInLogic + availableChecks
				elseif level == ACCESS_SEQUENCEBREAK then
					countOutOfLogic = countOutOfLogic + availableChecks
				elseif level == ACCESS_INSPECT then
					countHintable = countHintable + availableChecks
				elseif level == ACCESS_NONE then
					countUnavailable = countUnavailable + availableChecks
				end
			end
		end
	end

	print("Checks in logic: "..countInLogic)
	print("Checks out of logic: "..countOutOfLogic)
	print("Checks hintable: "..countHintable)
	print("Checks cleared: "..countCleared)
	print("Checks cleared: "..countUnavailable)
	print("Total count: "..(countInLogic + countCleared).." out of "..(countInLogic + countOutOfLogic + countHintable + countCleared + countUnavailable))
end

---called when a location gets cleared
---@param location_id integer ID of the location cleared from the datapackage
---@param location_name string name of the location cleared from the datapackage
function OnLocation(location_id, location_name)
    MANUAL_CHECKED = false
    local location_array = LOCATION_MAPPING[location_id]
    if not location_array or not location_array[1] then
        print(string.format("OnLocation: could not find location mapping for id %s", location_id))
        return
    end

    for _, location in pairs(location_array) do
        if location then
            if type(location) == "table" then
                local item_code, item_type, consumable_multiplier = table.unpack(location)
                ItemUpdate(item_code, item_type, consumable_multiplier, location_id, false)
            else

                if location:sub(1, 1) == "@" then
                    ---@type LocationSection
                    local location_obj = Tracker:FindObjectForCode(location) --[[@as LocationSection]]
                    if location_obj then
                        LocationUpdate(location_obj, custom_storage_item, location_id, false)
                    else
                        print(string.format("OnLocation: could not find location_object for code %s", location))
                    end
                else
                    ItemUpdate(location, nil, nil, location_id, false)
                end
            end
        end
    end
    MANUAL_CHECKED = true
	checkInLogic()
end

-- this Autofill function is meant as an example on how to do the reading from slot_data
-- and mapping the values to your own settings
---@param slot_data table
function AutoFill(slot_data)
    print(DumpTable(slot_data))

    mapping={[0]=0,[1]=1,[2]=2}
--    mapToggleReverse={[0]=1,[1]=0,[2]=0,[3]=0,[4]=0}
--    mapTripleReverse={[0]=2,[1]=1,[2]=0}

    slotCodes = {
        game_version = {code="game_version", mapping=mapping},
        include_jobs = {code="include_jobs", mapping=mapping},
        include_graveyard = {code="include_graveyard", mapping=mapping},
        include_ex_bosses = {code="include_ex_bosses", mapping=mapping},
        include_sp_bosses = {code="include_sp_bosses", mapping=mapping},
        include_virus_battler = {code="include_virus_battler", mapping=mapping},
        include_bass_bx = {code="include_bass_bx", mapping=mapping},
        include_protoman_fz = {code="include_protoman_fz", mapping=mapping},
        trade_quest_hinting = {code="trade_quest_hinting", mapping=mapping},
    }
    print(Tracker:FindObjectForCode("autofill_settings").Active)
    if Tracker:FindObjectForCode("autofill_settings").Active == true then
        for settings_name, settings_value in pairs(slot_data) do
            print(settings_name, settings_value)
            if slotCodes[settings_name] then
                item = Tracker:FindObjectForCode(slotCodes[settings_name].code)
                if item.Type == "toggle" then
                    item.Active = slotCodes[settings_name].mapping[settings_value]
                else
                    -- print(k,v,Tracker:FindObjectForCode(slotCodes[k].code).CurrentStage, slotCodes[k].mapping[v])
                    item.CurrentStage = slotCodes[settings_name].mapping[settings_value]
                end
            end
        end
    end
end

---@class APHintMessage
---@field receiving_player integer
---@field finding_player integer
---@field location integer
---@field item integer
---@field found boolean
---@field entrance string
---@field item_flags 0|1|2|3|4|5|6|7
---@field status 0|10|20|30|40

---function to update the Highlight of a LocationSection to represent the status of the hint that is present
---for that LocationSection
---@param locationID integer ID of the locations the hint is being given for
---@param status 0|10|20|30|40|100|101|102|103|104|105|106|107 status to determine the color of the hint glow
local function UpdateHints(locationID, status) -->
    if Highlight then
        -- print(locationID, status)
        local location_table = LOCATION_MAPPING[locationID]
        
        -- Safetly stop if the location ID returns nil in location_mapping.lua
        if not location_table then
            print(string.format("UpdateHints: Location ID %s not found in LOCATION_MAPPING. Skipping highlight.", locationID))
            return
        end

        for _, location in ipairs(location_table) do
            if location:sub(1, 1) == "@" then
				---@type LocationSection
                local obj = Tracker:FindObjectForCode(location)

                if obj then
                    if TROLL_PLAYER and HIGHLIGHT_LEVEL[status] == Highlight.Avoid then
                        obj.Highlight = HIGHLIGHT_LEVEL[30]
                    else
                        obj.Highlight = HIGHLIGHT_LEVEL[status]
                    end
                else
                    print(string.format("No object found for code: %s", location))
                end
            end
        end
    end
end

---triggers as AP sends live updates from the server using a given key we subscribed to in Archipelago:SetNotify
---@param key string Name of the key that was used to send the message
---@param value table<integer, APHintMessage>
---@param old_value table<integer, APHintMessage>
function OnNotify(key, value, old_value)
    print("OnNotify", key, value, old_value)
    if value ~= old_value and key == HINTS_ID then
        Tracker.BulkUpdate = true
        for _, hint in ipairs(value) do
            if hint.finding_player == Archipelago.PlayerNumber then
                if hint.status == 0 then
                    UpdateHints(hint.location, 100+hint.item_flags)
                else
                    UpdateHints(hint.location, hint.status)
                end
            end
        end
        Tracker.BulkUpdate = false
    end

	if key == ROOM_ID then
		onMap(value)
	end
end

---triggers on connecting to AP when we receive this message from the server after providing a given key to Archipelago:Get
---@param key string Name of the key that was used to send the message
---@param value table<integer, APHintMessage>
function OnNotifyLaunch(key, value)
    if key == HINTS_ID then
        Tracker.BulkUpdate = true
        for _, hint in ipairs(value) do
            if hint.finding_player == Archipelago.PlayerNumber then
                if hint.status == 0 then
                    UpdateHints(hint.location, 100+hint.item_flags)
                else
                    UpdateHints(hint.location, hint.status)
                end
            end
        end
        Tracker.BulkUpdate = false
    end
end

-------------------
---this section is only for special things that are time of day or day of year dependant if you really want to do stuff
---stuff like this

---@param start_date number BuildTimeObj() return aka unix timestamp
---@param end_date number BuildTimeObj() return aka unix timestamp
---@param target_date number BuildTimeObj() return aka unix timestamp
function CheckDateRange(start_date, end_date, target_date)
    local one_day = 86400
    local check_result = false
    for day_obj = start_date, end_date, one_day do
        check_result = CheckDate(day_obj, target_date)
        if check_result then
            return true
        end
    end
end

---@param target_date number BuildTimeObj() return aka unix timestamp
---@param reference_time number? BuildTimeObj() return aka unix timestamp
function CheckDate(reference_time, target_date)
    local today = os.date("*t")
    local reference_day =  os.date("*t", target_date)
    if reference_time then
        today = os.date("*t", reference_time)
    end
    return today.year == reference_day.year and
    today.month == reference_day.month and
    today.day == reference_day.day
end

---helper function to return a date object for the provided day
---@param year number?
---@param month number?
---@param day number?
---@param hour number?
---@param minute number?
---@param second number?
---@return integer
function BuildTimeObj(year, month, day, hour, minute, second)
    local today = os.date("*t", os.time())
    return os.time(
        {
            year = year or today.year,
            month = month or today.month,
            day = day or today.day,
            hour = hour or 0,
            min = minute or 0,
            sec = second or 0
        }
    )
end

_last_activated_tab = ""
function onMap(stage_id)
    if not stage_id then
        return
    end

	local map_switch_setting = Tracker:FindObjectForCode("setting_map_tracking")
	if map_switch_setting and map_switch_setting.Active then
		local tab_name = ROOM_ID_TO_TAB_NAME[stage_id][1].."-"..ROOM_ID_TO_TAB_NAME[stage_id][2].."-"..ROOM_ID_TO_TAB_NAME[stage_id][3]
		print("Attempting to swap to tab: "..tab_name)

		if tab_name and tab_name ~= _last_activated_tab then
			Tracker:UiHint("ActivateTab", ROOM_ID_TO_TAB_NAME[stage_id][1])
			Tracker:UiHint("ActivateTab", ROOM_ID_TO_TAB_NAME[stage_id][2])
			Tracker:UiHint("ActivateTab", ROOM_ID_TO_TAB_NAME[stage_id][3])

			_last_activated_tab = tab_name
		end
	end
end
