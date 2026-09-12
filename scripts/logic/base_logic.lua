-- this is the file to put all your custom logic functions into.
-- if you dont want to use the json based logic you can switch to a graph-based logic method.
-- the needed functions for that are in `/scripts/logic/graph_logic/logic_main.lua`.



-- function <name> (<parameters if needed>)
--     <actual code>
--     <indentations are just for readability>
-- end
--

function hasCentral3Access()
  	if ANY(
        "keydata", --access through central 2
        ALL("fish", "toolprgm"), --access through seaside
        ALL("authdata", "cybbrdax"), --access through green
        ALL("umbrella", "vacdata"), --access through sky
        ALL("acdckydt", "areapass") --access through acdc
    ) == ACCESS_NORMAL then
  		return ACCESS_NORMAL
  	elseif ALL("vacdata", ANY("erasecross", "groundcross", ALL("chargecross", "fish"), ALL("dustcross", "fish"))) == ACCESS_NORMAL then
		-- Accessible by using Link Navis, which is not consider by AP logic
		return ACCESS_SEQUENCEBREAK
	end

	return ACCCESS_NONE
end

function hasSeasideNetAccess()
  return ANY(
    "fish",
    ALL("toolprgm", hasCentral3Access)
  )
end

function hasGreenNetAccess()
  return ANY(
    "authdata",
    ALL("cybbrdax", hasCentral3Access)
  )
end

function hasSkyNetAccess()
	if ANY("umbrella", ALL("vacdata", hasCentral3Access)) == ACCESS_NORMAL then
	  	return ACCESS_NORMAL
	elseif ANY("erasecross", "groundcross", ALL("chargecross", "fish"), ALL("dustcross", "fish")) == ACCESS_NORMAL then
		-- Can access using Link Navis, which is out of logic
		return ACCESS_SEQUENCEBREAK
	end

	return ACCCESS_NONE
end

function hasACDCNetAccess()
  return ANY(
    "acdckydt",
    ALL("areapass", hasCentral3Access)
  )
end

-- requires sky access, but logically also requires explore score of 6
function hasUndernetAccess()
  	if hasSkyNetAccess() == ACCESS_NORMAL then
		if exploreScoreIs6() == ACCESS_NORMAL then
	  		return ACCESS_NORMAL
	  	end

	  	return ACCESS_SEQUENCEBREAK
	elseif ANY("erasecross", "groundcross", ALL("chargecross", "fish"), ALL("dustcross", "fish")) == ACCESS_NORMAL then
		return ACCESS_SEQUENCEBREAK
  	end

	return ACCESS_NONE
end

-- requires sky access, but logically also requires explore score of 9
function hasGraveyardAccess()
  	if hasSkyNetAccess() == ACCESS_NORMAL then
		if exploreScoreIs9() == ACCESS_NORMAL then
	  		return ACCESS_NORMAL
	  	end

	  	return ACCESS_SEQUENCEBREAK
  	end

	return ACCESS_NONE
end

-- same thing as sky overworld access but separate for readability + in case it gets locked behind money or a new check
function canBuyRushFood()
  return HAS("umbrella")
end

-- functions to check whether or not you have the right link navis to clear obstacles
function canClearFire()
  return ANY(
    "heatcross",
    ALL("chargecross", "fish"),
    "spoutcross",
    ALL("tengucross", "authdata")
  )
end

function canClearTree()
  return ANY(
    "heatcross",
    ALL("slashcross", "authdata"),
    ALL("tomahawkcross", "umbrella"),
    "groundcross"
  )
end

function canClearGeyser()
  return ANY(
    ALL("eleccross", "umbrella"),
    "erasecross",
    "spoutcross",
    "groundcross"
  )
end

function canClearCloud()
  return ANY(
    ALL("eleccross", "umbrella"),
    "erasecross",
    ALL("tomahawkcross", "umbrella"),
    ALL("dustcross", "fish")
  )
end

function canClearCyclone()
  return ANY(
    ALL("slashcross", "authdata"),
    ALL("chargecross", "fish"),
    ALL("tengucross", "authdata"),
    ALL("dustcross", "fish")
  )
end

function canAccessUnderground2BMD2()
	if HAS("game_version_gregar") then
		return ANY(HAS("heatcross"), ALL("chargecross", "fish", ANY("umbrella", "vacdata")))
	elseif HAS("game_version_falzar") then
		return ANY(HAS("spoutcross"), ALL("tengucross", "authdata"))
	end
end

function canAccessSeaside1BMD3()
	-- EraseMan requires player to be able to get SkyBanner, or VacData and ToolPrgm
	if HAS("game_version_gregar") then
		return ANY(ALL("eleccross", "umbrella"), ALL("erasecross", ANY("umbrella", ALL("vacdata", "keydata"), ALL("vacdata", "toolprgm"), ALL("vacdata", "cybbrdax"))))
	elseif HAS("game_version_falzar") then
		return ANY("spoutcross", ALL("groundcross", ANY("umbrella", ALL("vacdata", "keydata"), ALL("vacdata", "toolprgm"), ALL("vacdata", "cybbrdax"))))
	end
end

function canAccessSeaside2BMD3()
	-- ChargeMan requires player to be able to get SkyBanner, or VacData and ToolPrgm
	if HAS("game_version_gregar") then
		return ANY(ALL("slashcross", "authdata"), ALL("chargecross", "fish", ANY("umbrella", ALL("vacdata", "keydata"), ALL("vacdata", "toolprgm"), ALL("vacdata", "cybbrdax"))))
	elseif HAS("game_version_falzar") then
		return ANY(ALL("tengucross", "authdata"), ALL("dustcross", "fish", ANY("umbrella", ALL("vacdata", "keydata"), ALL("vacdata", "toolprgm"), ALL("vacdata", "cybbrdax"))))
	end
end

function exploreScore()
    score = 0
    -- Fish grants Seaside Overworld access
    if Tracker:ProviderCountForCode("fish") > 0 then
        score = score + 2
    end

    if hasSeasideNetAccess() == ACCESS_NORMAL then
        score = score + 1
    end

    -- AuthData grants Green Overworld access
    if Tracker:ProviderCountForCode("authdata") > 0 then
        score = score + 1
    end

    if hasGreenNetAccess() == ACCESS_NORMAL then
        score = score + 1
    end

    -- Umbrella grants Sky Overworld access
    if Tracker:ProviderCountForCode("umbrella") > 0 then
        score = score + 2
    end

    if hasSkyNetAccess() == ACCESS_NORMAL then
        score = score + 1
    end

    -- ACDCKyDt grants ACDC Overworld access
    if Tracker:ProviderCountForCode("acdckydt") > 0 then
        score = score + 1
    end

    if hasACDCNetAccess() == ACCESS_NORMAL then
        score = score + 1
    end

    -- If player has StmpCard, then they can access Expo
    if Tracker:ProviderCountForCode("stmpcard") > 0 then
        score = score + 1
    end

    -- If player has a score of 6 and Sky Cyberworld access, Undernet is accessible
    if hasSkyNetAccess() == ACCESS_NORMAL and score > 6 then
        score = score + 1
    end

    -- If player has a score of 9 and Sky Cyberworld access, Graveyard is accessible
    if hasSkyNetAccess() == ACCESS_NORMAL and score > 9 then
        score = score + 1
    end

    return score
end

function exploreScoreIs1()
    if exploreScore() > 1 then
        return ACCESS_NORMAL
	end

    return ACCESS_NONE
end

function exploreScoreIs2()
    if exploreScore() > 2 then
        return ACCESS_NORMAL
	end

    return ACCESS_NONE
end

function exploreScoreIs3()
    if exploreScore() > 3 then
        return ACCESS_NORMAL
	end

    return ACCESS_NONE
end

function exploreScoreIs4()
    if exploreScore() > 4 then
        return ACCESS_NORMAL
	end

    return ACCESS_NONE
end

function exploreScoreIs6()
    if exploreScore() > 6 then
        return ACCESS_NORMAL
	end

    return ACCESS_NONE
end

function exploreScoreIs8()
    if exploreScore() > 8 then
        return ACCESS_NORMAL
	end

    return ACCESS_NONE
end

function exploreScoreIs9()
    if exploreScore() > 9 then
        return ACCESS_NORMAL
	end

    return ACCESS_NONE
end

function canDoNotEnoughMembers()
	-- Need 2 Discord S chips before the job is in logic.
	if ALL("fanfarez", "timpanit") == ACCESS_NORMAL and Tracker:ProviderCountForCode("discords") > 1 then
		return ACCESS_NORMAL
	end

	return ACCESS_NONE
end

function canDoSupportChipPls()
	-- Need 2 Discord S chips before the job is in logic.
	if ALL("bblwrapq", "atk30", "recov80h", "geddona") == ACCESS_NORMAL and Tracker:ProviderCountForCode("discords") > 1 then
		return ACCESS_NORMAL
	end

	return ACCESS_NONE
end

function requestRankB()
	if requestPointsPossible(true) >= 10 then
		return ACCESS_NORMAL
	end

	if requestPointsPossible(false) >= 10 then
		return ACCESS_SEQUENCEBREAK
	end

	return ACCESS_NONE
end

function requestRankA()
	if requestPointsPossible(true) >= 25 then
		return ACCESS_NORMAL
	end

	if requestPointsPossible(false) >= 25 then
		return ACCESS_SEQUENCEBREAK
	end

	return ACCESS_NONE
end

function requestRankS()
	if requestPointsPossible(true) >= 35 then
		return ACCESS_NORMAL
	end

	if requestPointsPossible(false) >= 35 then
		return ACCESS_SEQUENCEBREAK
	end

	return ACCESS_NONE
end

function requestRankMaster()
	print("Request Points possible: "..requestPointsPossible(true))
	print("Request Points possible out of logic: "..requestPointsPossible(false))
	if requestPointsPossible(true) >= 75 then
		return ACCESS_NORMAL
	end

	if requestPointsPossible(false) >= 75 then
		return ACCESS_SEQUENCEBREAK
	end

	return ACCESS_NONE
end

function requestPointsPossible(in_logic)
	-- 1 star jobs
	-- Virus Deletion and Find Keepsake always reachable
	requestPoints = 2

	-- If Got a Problem. beatable
	if Tracker:ProviderCountForCode("fish") > 0 then
		requestPoints = requestPoints + 1
	end

	-- If Errand Request, Loan Collection, and Get The Chip! beatable
	if hasSeasideNetAccess() == ACCESS_NORMAL then
		-- Get The Chip! requires DolThdr1 A
		if Tracker:ProviderCountForCode("dolthdr1a") > 0 then
			requestPoints = requestPoints + 1
		end

		-- Loan Collection starts in Green HP
		if hasGreenNetAccess() == ACCESS_NORMAL then
			requestPoints = requestPoints + 1
		end

		requestPoints = requestPoints + 1
	end

	-- For Somebody Help!, we force the 10,000z option. To prevent heavy grinding, require Millions or
	-- a 100,000z drop. This can be gotten out of logic.
	if ANY("100000z", "millions") == ACCESS_NORMAL or not in_logic then
		requestPoints = requestPoints + 1
	end

	-- If Daughter Worry, Stop Him!, and Diet Goods Money beatable
	if Tracker:ProviderCountForCode("authdata") > 0 then
		-- Daughter Worry and Diet Goods Money require Seaside Cyberworld access
		if hasSeasideNetAccess() == ACCESS_NORMAL then
			requestPoints = requestPoints + 2
		end

		requestPoints = requestPoints + 1
	end

	-- If Songwriter beatable
	if hasSkyNetAccess() == ACCESS_NORMAL then
		requestPoints = requestPoints + 1
	end

	-- If not Rank B, then can't do more requests
	if requestPoints < 10 then
		return requestPoints
	end

	-- 2 star jobs
	-- Juvenile Division always beatable. We also cannot get this far without Green Overworld and Seaside Cyberworld
	-- access, so Stand In Recruit and Lumber Merchant are always beatable too
	requestPoints = requestPoints + 6

	-- If For Victory! beatable. This can be done out of logic by buyign GunDelS1 C from Tab's Shop.
	if Tracker:ProviderCountForCode("gundels1c") > 0 or not in_logic then
		requestPoints = requestPoints + 2
	end

	-- If Stock Up!, Penguins Ran Away, Update Help, and Do Something! beatable
	-- Note: Do Something! requires fire damage, but for simplicity, we just assume you can get those in Robo Control
	if Tracker:ProviderCountForCode("fish") > 0 then
		requestPoints = requestPoints + 8
	end

	-- If Buy Which Stock? and Want to Meet Daughter beatable
	if hasSkyNetAccess() == ACCESS_NORMAL then
		requestPoints = requestPoints + 4
	end

	-- If Not Enough Member beatable.
	-- Note: Two requests require Discord S, so it is only in logic once you have both.
	if ALL("fanfarez", "discords", "timpanit") == ACCESS_NORMAL and Tracker:ProviderCountForCode("discords") > 1 then
		requestPoints = requestPoints + 2
	end

	-- If Self Research beatable. Assumed you get PoisSeed P, and have OrderSys to buy second one.
	-- Note: This can always be done due to the base patch giving full library completion.
	if ALL("poisseedp", "anubisp", "ordersys") == ACCESS_NORMAL or not in_logic then
		requestPoints = requestPoints + 2
	end

	--If not Rank A, then can't do more requests
	if requestPoints < 25 then
		return requestPoints
	end

	-- 3 star jobs
	-- We cannot get this far without Green Overworld and Seaside Cyberworld access, so Time Capsule and
	-- Road to Soul Battler always beatable
	requestPoints = requestPoints + 6

	-- If Find the Virus!, Can't Open Safe, Track the Criminal, and An Experiment! are beatable
	if Tracker:ProviderCountForCode("fish") > 0 then
		requestPoints = requestPoints + 12
	end

	-- If Get the Bad Guy is beatable
	if hasCentral3Access() == ACCESS_NORMAL then
		requestPoints = requestPoints + 3
	end

	-- If Official Request beatable
	if Tracker:ProviderCountForCode("umbrella") > 0 then
		requestPoints = requestPoints + 3
	end

	-- If not Rank S, then can't do more requests
	if requestPoints < 35 then
		return requestPoints
	end

	-- If Where's My Navi beatable
	if ALL(exploreScoreIs6(), hasSkyNetAccess()) == ACCESS_NORMAL then
		requestPoints = requestPoints + 4
	end

	-- If One More Time. beatable
	if ALL("authdata", "acdckydt") == ACCESS_NORMAL then
		requestPoints = requestPoints + 4
	end

	-- If SupportChip Pls beatable
	-- Note: Two requests require Discord S, so it is only in logic once you have both.
	if ALL("umbrella", "atk30", "bblwrapq", "geddona", "recov80h", "discords") == ACCESS_NORMAL and Tracker:ProviderCountForCode("discords") > 1 then
		requestPoints = requestPoints + 4
	end

	-- If Negotiate! beatable
	if ALL("umbrella", "authdata", hasUndernetAccess()) then
		requestPoints = requestPoints + 4
	end

	-- Max number of points: 75
	return requestPoints
end