require( "niknaks" )

--- @class MCA
MCA = {}

include( "utils.lua" )
include( "decals.lua" )
include( "materials.lua" )
include( "models.lua" )

local timestamp = os.time()
local mapname = game.GetMap()
local function finalPath( path )
    return "mca/" .. mapname .. "/" .. timestamp .. "/" .. path
end

local function makeDirs( path )
    local parent = string.GetPathFromFilename( path )
    if file.Exists( parent, "DATA" ) then return end

    print( "MCA: Creating directory:", parent )
    file.CreateDir( parent )
end

local function copyFile( path )
    local final = finalPath( path )
    makeDirs( final )

    local contents = file.Read( path, "GAME" )
    if not contents then
        ErrorNoHaltWithStack( "MCA: File not found?:" .. path )
        return
    end

    print( "MCA: Copying file:", path, "to", final )
    file.Write( final, contents )
end

hook.Add( "Think", "MCA_Init", function()
    hook.Remove( "Think", "MCA_Init" )

    local holder = {}

    timer.Simple( 5, function()
        print( "MCA: Initializing..." )
        MCA.Materials:LoadMaterials( holder )
        MCA.Models:LoadModels( holder )

        print( "MCA: Initialization complete!", "Found", table.Count( holder ), "content paths." )
        local allContentPaths = {}

        for path in pairs( holder ) do
            path = string.Replace( path, "\\", "/" )

            table.insert( allContentPaths, path )
            copyFile( path )
        end

        for i, path in ipairs( allContentPaths ) do
            print( i, ":", path )
        end
    end )

end )
