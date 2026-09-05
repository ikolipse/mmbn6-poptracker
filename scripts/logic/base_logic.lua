-- this is the file to put all your custom logic functions into.
-- if you dont want to use the json based logic you can switch to a graph-based logic method.
-- the needed functions for that are in `/scripts/logic/graph_logic/logic_main.lua`.



-- function <name> (<parameters if needed>)
--     <actual code>
--     <indentations are just for readability>
-- end
--

function hasCentral3Access()
  return (
    (HAS("keydata")) or
    (HAS("fish") and HAS("toolpgrm")) or
    (HAS("authdata") and HAS("cyberbrdax")) or
    (HAS("umbrella") and HAS("vacdata")) or
    (HAS("acdckydt") and HAS("areapass"))
  )
end

function hasSeasideNetAccess()
  return(
    (HAS("fish")) or
    (hasCentral3Access() and HAS("toolpgrm"))
  )
end

function hasGreenNetAccess()
  return(
    (HAS("authdata")) or
    (hasCentral3Access() and HAS("cyberbrdax"))
  )
end

function hasSkyNetAccess()
  return(
    (HAS("umbrella")) or
    (hasCentral3Access() and HAS("vacdata"))
  )
end

function hasACDCNetAccess()
  return(
    (HAS("acdckydt")) or
    (hasCentral3Access() and HAS("areapass"))
  )
end

function hasUndernetAccess()
  return(hasSkyNetAccess())
end

function canBuyRushFood()
  return (HAS("umbrella"))
end

-- functions to check whether or not you have the right link navis to clear obstacles
function canClearFire()
  return (
    HAS("heatcross") or
    HAS("chargecross") or
    HAS("spoutcross") or
    HAS("tengucross")
  )
end

function canClearTree()
  return (
    HAS("heatcross") or
    HAS("slashcross") or
    HAS("tomahawkcross") or
    HAS("groundcross")
  )
end

function canClearGeyser()
  return (
    HAS("eleccross") or
    HAS("erasecross") or
    HAS("spoutcross") or
    HAS("groundcross")
  )
end

function canClearCloud()
  return (
    HAS("eleccross") or
    HAS("erasecross") or
    HAS("tomahawkcross") or
    HAS("dustcross")
  )
end

function canClearTornado()
  return (
    HAS("slashcross") or
    HAS("chargecross") or
    HAS("tengucross") or
    HAS("dustcross")
  )
end