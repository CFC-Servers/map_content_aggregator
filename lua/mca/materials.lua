local istable = istable
local string_lower = string.lower

--- @class MCA_Materials
MCA.Materials = {}
--- @class MCA_Materials
local Materials = MCA.Materials
local Models = MCA.Models
local IsBaseAsset = MCA.Utils.IsBaseAsset

local failedToLoad = {}

--- Finds all vtf paths in the VMT fields
--- @param materialPaths string[]
--- @param vmtFields table<string, string> The fields from the VMT struct
--- @param _i number? The indentation level for debug prints
local function processVmtTextures( materialPaths, vmtFields, _i )
    local indent = string.rep( " ", _i or 1 )
    local log = function( msg, ... )
        print( indent .. msg, ... )
    end

    local function saveTexture( value )
        if not value then return end
        if value == "env_cubemap" then return end

        local vtf = string_lower( "materials/" .. value .. ".vtf" )
        if IsBaseAsset( vtf ) then
            log( "(Skipping base VTF asset: " .. vtf .. ")" )
            return
        end

        log( "MCA: Found texture: " .. vtf )
        table.insert( materialPaths, vtf )
    end

    local isTextureField = MCA.Utils.VMT_TextureFieldsLookup

    local function processFields( fields )
        for fieldName, value in pairs( fields ) do
            if isTextureField[fieldName] then
                saveTexture( value )
            end

            if istable( value ) then
                processFields( value )
            end
        end
    end

    processFields( vmtFields )
end

--- The VMT contains paths to other materials we may care about
--- It also always includes the $baseTexture, which tells us where the VTF is
--- @param materialPaths string[]
--- @param matName string
--- @param _i number? The indentation level for debug prints
function Materials.processVmt( materialPaths, matName, _i )
    _i = _i or 1

    local indent = string.rep( " ", _i )
    local log = function( msg, ... )
        print( indent .. msg, ... )
    end

    local vmt = matName
    if not string.StartsWith( vmt, "materials/" ) then
        vmt = "materials/" .. vmt .. ".vmt"
    end
    vmt = string_lower( vmt )

    if IsBaseAsset( vmt ) then
        log( "(Skipping base VMT asset: " .. vmt .. ")" )
        return
    end

    log( "MCA: Processing VMT: " .. vmt )

    local vmtData = file.Read( vmt, "GAME" )
    if not vmtData then
        log( "MCA: Failed to load material details for: " .. matName, vmt )
        failedToLoad[vmt] = true
        return nil
    end

    local vmtStruct = MCA.Utils.VMT( vmtData )

    local isPatch = vmtStruct.shaderType == "patch"
    if isPatch then
        -- .include is a full VMT path, including the .vmt extension
        local includePath = vmtStruct.fields.include
        log( "- Include path: " .. includePath )

        -- Get the name from the path
        local plainIncludeName = string_lower( includePath )

        -- Only process it if it's not a base asset
        if not IsBaseAsset( plainIncludeName ) then
            -- Recursively call this function with the include name
            Materials.processVmt( materialPaths, plainIncludeName, _i + 2 )
        end
    end

    -- Add the VMT's textures to the content paths
    processVmtTextures( materialPaths, vmtStruct.fields, _i )
    table.insert( materialPaths, vmt )
end

do
    local rawget = rawget
    local isstring = isstring

    --- Reads and processes the material data for all map materials
    function Materials:LoadMaterials( holder )
        local worldMats = NikNaks.CurrentMap:GetMaterials()

        local Decals = MCA.Decals --[[@as MCA_DecalsModule]]
        table.Add( worldMats, Decals:GetMapDecalTextures() )

        local count = #worldMats

        local materialPaths = {}
        local processVmt = Materials.processVmt
        for i = 1, count do
            local mat = rawget( worldMats, i ) -- NikNaks returns have a metatable that we want to skip
            local name = isstring( mat ) and mat or mat:GetName()

            print( "MCA: Material: ", name )
            processVmt( materialPaths, name )
        end

        print( "MCA: Loaded " .. table.Count( materialPaths ) .. " materials" )

        print( "MCA: Failed to load " .. table.Count( failedToLoad ) .. " materials" )
        for vmt in pairs( failedToLoad ) do
            print( "MCA: File Not Found: " .. vmt )
        end

        for i = 1, #materialPaths do
            local path = materialPaths[i]
            holder[path] = true
        end

        -- Load materials for all models
        for modelPath in pairs( Models.allModels ) do
            for _, mat in ipairs( Models.GetModelMaterials( modelPath ) ) do
                print( "MCA: Getting Model Materials: ", mat )

                if (not holder[mat]) and (not IsBaseAsset( mat )) then
                    mat = "materials/" .. mat .. ".vmt"
                    print( "  MCA: Model Material: ", mat )
                    holder[mat] = true
                end
            end
        end
    end
end
