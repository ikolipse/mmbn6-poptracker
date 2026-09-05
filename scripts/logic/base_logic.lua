-- this is the file to put all your custom logic functions into.
-- if you dont want to use the json based logic you can switch to a graph-based logic method.
-- the needed functions for that are in `/scripts/logic/graph_logic/logic_main.lua`.



-- function <name> (<parameters if needed>)
--     <actual code>
--     <indentations are just for readability>
-- end
--

function hasCentral3Access()
  return ANY(
        "keydata", --access through central 2
        ALL("fish", "toolprgm"), --access through seaside
        ALL("authdata", "cybbrdax"), --access through green
        ALL("umbrella", "vacdata"), --access through sky
        ALL("acdckydt", "areapass") --access through acdc
    )
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
  return ANY(
    "umbrella",
    ALL("vacdata", hasCentral3Access)
  )
end

function hasACDCNetAccess()
  return ANY(
    "acdckydt",
    ALL("areapass", hasCentral3Access)
  )
end

-- same thing as sky net access but separate in case undernet gets locked behind exploration points
function hasUndernetAccess()
  return hasSkyNetAccess()
end

-- same thing as sky overworld access but separate for readability + in case it gets locked behind money or a new check
function canBuyRushFood()
  return HAS("umbrella")
end

-- functions to check whether or not you have the right link navis to clear obstacles
function canClearFire()
  return ANY(
    "heatcross",
    "chargecross",
    "sproutcross",
    "tengucross"
  )
end

function canClearTree()
  return ANY(
    "heatcross",
    "slashcross",
    "tomahawkcross",
    "groundcross"
  )
end

function canClearGeyser()
  return ANY(
    "eleccross",
    "erasecross",
    "spoutcross",
    "groundcross"
  )
end

function canClearCloud()
  return ANY(
    "eleccross",
    "erasecross",
    "tomahawkcross",
    "dustcross"
  )
end

function canClearCyclone()
  return ANY(
    "slashcross",
    "chargecross",
    "tengucross",
    "dustcross"
  )
end