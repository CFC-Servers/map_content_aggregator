--- @class MCA_DecalsModule
MCA.Decals = {}
--- @class MCA_DecalsModule
local Decals = MCA.Decals

local rawget = rawget

local whitelist = {
    infodecal = true,
    infooverlay = true,
    ["info_overlay"] = true,
}

--- Reads the map decals from the BSP and stores them in mapDecals
--- @return string[] The map decal textures
function Decals:GetMapDecalTextures()
    local ents = NikNaks.CurrentMap:GetEntities()
    local entsCount = #ents

    local ent
    local textureNames = {}

    for i = 1, entsCount do
        ent = rawget( ents, i )
        local classname = rawget( ent, "classname" )

        if whitelist[classname] then
            table.insert( textureNames, rawget( ent, "texture" ) )
        end
    end

    return textureNames
end
