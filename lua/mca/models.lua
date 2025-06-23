--- @class MCA_ModelsModule
MCA.Models = MCA.Models or {}
--- @class MCA_ModelsModule
local Models = MCA.Models

Models.testEnt = Models.testEnt or nil
Models.allModels = {}
local allModels = Models.allModels

do
    local function createTestEnt()
        if Models.testEnt then return end

        local testEnt = ents.Create( "prop_dynamic" )
        testEnt:SetModel( "models/props_junk/watermelon01.mdl" )
        testEnt:SetPos( Vector( 0, 0, -123456 ) )
        testEnt:Spawn()

        Models.testEnt = testEnt
    end

    hook.Add( "Think", "MCA_Models_Init", function()
        hook.Remove( "Think", "MCA_Models_Init" )
        createTestEnt()
    end )

    --- Gets all materials for the given model path
    --- @param modelPath string
    --- @return string[]
    function Models.GetModelMaterials( modelPath )
        if not Models.testEnt then createTestEnt() end

        local testEnt = Models.testEnt
        testEnt:SetModel( modelPath )

        return testEnt:GetMaterials()
    end
end

do
    local file_Find = file.Find
    local string_sub = string.sub
    local string_find = string.find
    local string_StartsWith = string.StartsWith
    local string_GetPathFromFilename = string.GetPathFromFilename

    --- Gets all model-related file paths for the given model path and puts them in the given lookup table
    --- @param modelPath string
    --- @param holder table<string, boolean>
    function Models.GetModelFiles( modelPath, holder )
        local firstDot = string_find( modelPath, ".", 1, true )
        local noExtension = string_sub( modelPath, 1, firstDot - 1 )

        local dir = string_GetPathFromFilename( modelPath )

        local files = file_Find( noExtension, "GAME" )
        local fileCount = #files

        for i = 1, fileCount do
            local fileName = files[i]
            local filePath = dir .. fileName

            if string_StartsWith( filePath, noExtension .. "." ) then
                print( "  MCA: Model File: ", filePath )
                holder[filePath] = true
            end
        end
    end
end

do
    local IsBaseAsset = MCA.Utils.IsBaseAsset
    local util_IsValidModel = util.IsValidModel

    local function isValidModel( modelName )
        if not modelName then return end

        local validModel = util_IsValidModel( modelName )
        validModel = validModel and #modelName > 0
        validModel = validModel and modelName[1] ~= "*"
        validModel = validModel and modelName ~= "models/error.mdl"
        validModel = validModel and file.Exists( modelName, "GAME" )
        validModel = validModel and not IsBaseAsset( modelName )

        return validModel
    end

    --- Gets all model paths for the current map and puts them in mapModels
    --- @param holder table<string, boolean>
    --- @return nil
    function Models:LoadModels( holder )
        do
            local staticModels = NikNaks.CurrentMap:GetStaticPropModels()
            local staticModelCount = #staticModels

            -- Get models for static map props
            for i = 1, staticModelCount do
                local modelName = rawget( staticModels, i )

                if isValidModel( modelName ) then
                    print( "MCA: Static Model: ", modelName )
                    holder[modelName] = true
                    allModels[modelName] = true
                end
            end
        end

        -- Get models from map entities
        do
            -- Which entities to ignore the model of
            local classBlacklist = {
                worldspawn = true
            }

            local entities = NikNaks.CurrentMap:GetEntities()
            local entityCount = #entities

            for i = 1, entityCount do
                local ent = rawget( entities, i )
                local model = rawget( ent, "model" )
                local classname = rawget( ent, "classname" )

                if (not classBlacklist[classname]) and isValidModel( model ) and (not holder[model]) then
                    print( "MCA: Entity Model: ", classname, model )
                    holder[model] = true
                    allModels[model] = true
                end
            end
        end

        local cache = {}
        for modelPath in pairs( allModels ) do
            if not cache[modelPath] then
                Models.GetModelFiles( modelPath, holder )
                cache[modelPath] = true
            end
        end
    end
end
