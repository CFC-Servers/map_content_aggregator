--- @class MCA_Utils
local Utils = {}
MCA.Utils = Utils

local isstring = isstring
local string_lower = string.lower
local string_Right = string.Right
local string_byte = string.byte
local string_Split = string.Split
local string_Replace = string.Replace

do
    -- FIXME: Simplify and reduce the string.lower calls

    --- Returns whether the given character falls between "a" and "z"
    --- @param char string
    local function isChar( char )
        local byte = string_byte( char )
        return byte >= 97 and byte <= 122
    end

    --- Returns a version of the key that is case-insensitive and without the prefix character
    --- @param key string
    --- @return string
    local function plainKey( key )
        if not isstring( key ) then return key end

        key = isChar( key[1] ) and key or string_Right( key, -2 )
        return string_lower( key )
    end

    --- Returns an agnostic-access version of the given table.
    --- (Access the keys without the prefix character, and case-insensitive)
    --- @param tbl table
    --- @return table
    local function agnostic( tbl )
        --- @type table<string plainKey, string realKey>
        local plainKeys = {}

        for k, v in pairs( tbl ) do
            -- If the key is a string and it starts with a not-letter
            if isstring( k ) and ( not isChar( k[1] ) ) then
                plainKeys[plainKey( k )] = k
            end
        end

        return setmetatable( tbl, {
            __index = function( self, key )
                local actual = rawget( self, key )
                if actual ~= nil then return actual end

                key = string_lower( key )

                return rawget( self, plainKeys[key] )
            end,

            __newindex = function( self, key, value )
                local plain = plainKeys[string_lower( key )]
                if not plain then
                    rawset( self, key, value )
                    return
                end

                rawset( self, plain, value )
            end
        } )
    end

    Utils.VMT_TextureFields = {
        "basetexture",
        "basetexture2",

        "detail",
        "detail2",

        "bumpmap",
        "bumpmap2",

        "bumpmask",
        "decaltexture",
        -- "crackmaterial", -- idk this seems to break windows if we include it
        "tintmasktexture",
        "blendmodulatetexture",

        "envmap",
        "envmapmask",
        "envmapmask2",

        "lightwarptexture",
        "phongwarptexture",
        "phongexponenttexture",
        "fresnelrangestexture",

        "parallaxmap",
    }

    local textureFieldsLookup = {}
    for _, field in ipairs( Utils.VMT_TextureFields ) do
        textureFieldsLookup[field] = true
    end

    --- An agnostic-access lookup table for VMT texture fields
    --- @type table<string, boolean>
    Utils.VMT_TextureFieldsLookup = setmetatable( textureFieldsLookup, {
        __index = function( self, key )
            local actual = rawget( self, key )
            if actual ~= nil then return actual end

            return rawget( self, plainKey( key ) )
        end
    } )

    local function parseVmtValue( value )
        if istable( value ) then
            for k, v in pairs( value ) do
                value[k] = parseVmtValue( v )
            end

            return agnostic( value )
        end

        if isnumber( value ) then
            return value
        end

        -- Vector
        if value[1] == "[" then
            value = string.sub( value, 2, -2 )
            value = string.Split( value, " " )

            return Vector(
                tonumber( value[1] ) or 0,
                tonumber( value[2] ) or 0,
                tonumber( value[3] ) or 0
            )
        end

        return value
    end

    local function parseValueToVmt( value )
        if istable( value ) then
            for k, v in pairs( value ) do
                value[k] = parseValueToVmt( v )
            end

            return value
        end

        if isvector( value ) then
            return "[" .. value.x .. " " .. value.y .. " " .. value.z .. "]"
        end

        return tostring( value )
    end

    --- Loops through all fields that contain textures and returns whether or not we have them all locally
    --- @param vmtFields table<string, string>
    --- @return boolean
    local function hasAllTextures( vmtFields )
        local value
        for _, field in ipairs( Utils.VMT_TextureFields ) do
            value = vmtFields[field]

            if value then
                value = string_lower( value )

                -- If the value is env_cubemap, it means to use the nearest env_cubemap
                -- Meaning we don't have a specific texture to look for, so we skip it
                if value ~= "env_cubemap" then
                    local path = "materials/" .. value .. ".vtf"

                    if not file.Exists( path, "GAME" ) then
                        print( "Missing texture for field: ", field, value )
                        return false
                    end
                end
            end
        end

        return true
    end

    --- Turns a VMT file into a table, allows easy getting/setting of fields
    --- Also Compiles the VMT back into a string, ready to save to a file
    --- @param vmtData string The raw VMT file data
    --- @return VMTStruct
    function Utils.VMT( vmtData )

        -- Get rid of commented lines
        vmtData = string.gsub( vmtData, "//.-\r\n", "" )

        local lines = string_Split( vmtData, "\r\n" )
        local shaderType = string_lower( string_Replace( lines[1], "\"", "" ) )

        --- @type table<string, string|Vector>
        local fields = util.KeyValuesToTable( vmtData, false, false )
        for k, v in pairs( fields ) do
            fields[k] = parseVmtValue( v )
        end

        --- @class VMTStruct
        local struct = {
            --- All of the key/values stored in the VMT file
            fields = agnostic( fields ),

            --- @type string
            shaderType = shaderType,

            --- Compiles the VMT back into a string
            --- @return string
            Compile = function()
                local saveFields = {}
                for k, v in pairs( fields ) do
                    saveFields[k] = parseValueToVmt( v )
                end

                local kv = util.TableToKeyValues( saveFields, shaderType )

                return string.Replace( kv, "\n", "\r\n" )
            end
        }

        return struct
    end

    local hasMaterialCache = {}

    --- (Uncached) Returns whether or not the caller has the given material and all linked textures
    --- @param name string The name (not path) of the material
    --- @return boolean
    function Utils._HasMaterialFull( name )
        local path = "materials/" .. name

        local hasVmt = file.Exists( path .. ".vmt", "GAME" )
        local hasVtf = file.Exists( path .. ".vtf", "GAME" )

        -- If we don't have a VMT, then we either:
        --   - Have the VTF, meaning its just a texture and we do have it
        --   - Don't have the VTF, meaning we don't have it at all
        if not hasVmt then return hasVtf end

        -- We have the VMT, we'll look through all of its textures and make sure we have them
        local vmt = Utils.VMT( file.Read( path .. ".vmt", "GAME" ) )
        local fields = vmt.fields

        -- In a patch material, we need to make sure we have the base material its based on, and all of its textures
        -- We'll do this by recursively calling this function
        if vmt.shaderType == "patch" then
            local include = fields.include
            include = string_lower( include )
            include = string_Replace( include, "materials/", "" )
            include = string_Replace( include, ".vmt", "" )

            local hasBase = Utils.HasMaterialFull( include )
            if not hasBase then return false end

            local hasBaseTextures = hasAllTextures( fields.replace )
            if not hasBaseTextures then return false end
        end

        return hasAllTextures( fields )
    end

    --- (Cached) Returns whether or not the caller has the given material and all linked textures
    --- @param name string The name (not path) of the material
    --- @return boolean
    function Utils.HasMaterialFull( name )
        name = string_lower( name )

        local cached = hasMaterialCache[name]
        if cached ~= nil then return cached end

        cached = Utils._HasMaterialFull( name )
        hasMaterialCache[name] = cached

        return cached
    end

end

do
    local baseAssets = include( "mca/base_assets.lua" )

    function Utils.IsBaseAsset( path )
        return baseAssets[path] ~= nil
    end
end
