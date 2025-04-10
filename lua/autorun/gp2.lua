-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Start point for whole framework
-- ----------------------------------------------------------------------------



local developer = GetConVar("developer")

local fmt = string.format

GP2_PROJECT_COLOR_THEME = Color(180, 155, 255)
if SERVER then
    GP2_PROJECT_COLOR_THEME_LIGHT = Color(238, 232, 255)
else
    GP2_PROJECT_COLOR_THEME_LIGHT = Color(255, 254, 197)
end

GP2_PROJECT_COLOR_THEME_ERROR = Color(255, 90, 90)
GP2_PROJECT_COLOR_THEME_ERROR_LIGHT = Color(255, 155, 155)
GP2_PROJECT_NAME = '[GP2] '

GP2 = GP2 or {
    --- Print message to console
    --- @param msg string Message
    --- @vararg any Optional params from format string
    Print = function(msg, ...)
        MsgC(GP2_PROJECT_COLOR_THEME, GP2_PROJECT_NAME)
        MsgC(GP2_PROJECT_COLOR_THEME_LIGHT, fmt(msg, ...))
        print()
    end,

    --- Print error message to console (color differs depending on realm)
    --- @param msg string Message
    --- @vararg any Optional params from format string
    Error = function(msg, ...)
        MsgC(GP2_PROJECT_COLOR_THEME, GP2_PROJECT_NAME)
        MsgC(GP2_PROJECT_COLOR_THEME_ERROR_LIGHT, fmt(msg, ...))
        print()
    end,
}

-- Blue (first) portal
PORTAL_TYPE_FIRST = 0
-- Orange (second) portal
PORTAL_TYPE_SECOND = 1

--- Default open duration (size)
PORTAL_OPEN_DURATION = 0.5
--- Default static duration (fill effect)
PORTAL_STATIC_DURATION = 1

--- Default color for first portal
--- @return number, number, number: red, green, blue
PORTAL1_DEFAULT_COLOR = {0, 115, 210}

--- Default color for second portal
--- @return number, number, number: red, green, blue
PORTAL2_DEFAULT_COLOR = {210, 115, 0}

--- Default width for portal
PORTAL_WIDTH = 64

--- Default height for portal
PORTAL_HEIGHT = 112

-- Use unfinished implementation for better portal movement
-- internally tries to build local copy of world mesh for physics
-- with hole
--
-- currently unfinished
-- has noticable lag
PORTAL_USE_NEW_ENVIRONMENT_SYSTEM = false

if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
    require("niknaks")
end

include("gp2/globals.lua")
include("gp2/utils.lua")
include("gp2/netmessages.lua")
include("gp2/soundmanager.lua")
include("gp2/particles.lua")
include("gp2/entityextensions.lua")
include("gp2/portalmanager.lua")
include("gp2/portaldetours.lua")
include("gp2/portalmovement" .. (PORTAL_USE_NEW_ENVIRONMENT_SYSTEM and "_new" or "_old") .. ".lua")
AddCSLuaFile("gp2/portalmovement" .. (PORTAL_USE_NEW_ENVIRONMENT_SYSTEM and "_new" or "_old") .. ".lua")
AddCSLuaFile("gp2/globals.lua")
AddCSLuaFile("gp2/utils.lua")
AddCSLuaFile("gp2/netmessages.lua")
AddCSLuaFile("gp2/soundmanager.lua")
AddCSLuaFile("gp2/particles.lua")
AddCSLuaFile("gp2/entityextensions.lua")
AddCSLuaFile("gp2/portalmanager.lua")
AddCSLuaFile("gp2/portaldetours.lua")
AddCSLuaFile("gp2/paint.lua")
AddCSLuaFile("gp2/client/hud.lua")
GP2_VERSION = include("gp2/version.lua")

list.Set("ContentCategoryIcons", "Portal 2", "games/16/portal2.png")

-- Cubes
list.Set("SpawnableEntities", "prop_weighted_cube_clean", {
    PrintName = "Cube",
    ClassName = "prop_weighted_cube",
    Category = "Portal 2"
})

list.Set("SpawnableEntities", "prop_weighted_cube_companion", {
    PrintName = "Cube (Companion)",
    ClassName = "prop_weighted_cube",
    Category = "Portal 2",
    KeyValues = { NewSkins = 1, CubeType = 1 }
})

list.Set("SpawnableEntities", "prop_weighted_cube_reflective", {
    PrintName = "Cube (Reflective)",
    ClassName = "prop_weighted_cube",
    Category = "Portal 2",
    KeyValues = { NewSkins = 1, CubeType = 2 }
})

list.Set("SpawnableEntities", "prop_weighted_cube_sphere", {
    PrintName = "Cube (Sphere)",
    ClassName = "prop_weighted_cube",
    Category = "Portal 2",
    KeyValues = { NewSkins = 1, CubeType = 3 }
})

list.Set("SpawnableEntities", "prop_weighted_cube_antique", {
    PrintName = "Cube (Antique)",
    ClassName = "prop_weighted_cube",
    Category = "Portal 2",
    KeyValues = { NewSkins = 1, CubeType = 4 }
})


if SERVER then
    -- AcceptInput hooks
    include("gp2/inputsmanager.lua")
    -- EntityKeyValue hooks
    include("gp2/keyvalues.lua")
    -- Vscripts (serverside only)
    include("gp2/vscriptmanager.lua")
    include("gp2/vgui.lua")
    include("gp2/mouthmanager.lua")
    include("gp2/gamemovement.lua")
    include("gp2/portalpvs.lua")
    include("gp2/portalpropteleport.lua")
    include("gp2/paint.lua")
    include("gp2/client/hud.lua")

    hook.Add("Initialize", "GP2::Initialize", function()
        SoundManager.Initialize()
        MouthManager.Initialize()
    end)

    hook.Add("PlayerSpawn", "GP2::PlayerSpawn", function(ply, transition)
        -- Try to call OnPostPlayerSpawn on all Vscripted entities
        -- and siltently fail if there's no OnPostPlayerSpawn function in script
        -- pass player to scripts to handle logic per player

        GP2.VScriptMgr.CallHookFunction("OnPostPlayerSpawn", true, ply)
    end)

    hook.Add("PlayerInitialSpawn", "GP2::PlayerInitialSpawn", function(ply, transition)
    end)

    local function fixTonemaps()
        timer.Simple(0, function()
            local tonemapCtrls = ents.FindByClass("env_tonemap_controller")

            if #tonemapCtrls == 0 then
                local ctrl = ents.Create("env_tonemap_controller")
                ctrl:Spawn()
                ctrl:Activate()
                table.insert(tonemapCtrls, ctrl)
            end

            for _, ent in ipairs(tonemapCtrls) do
                -- Set to 1, triggers reroute in inputsmanager.lua
                ent:Input("setbloomscale", NULL, NULL, 1)
            end
        end)
    end

    function fixPortalColors()
        timer.Simple(2, function()
            for _, portal in ipairs(ents.FindByClass("prop_portal")) do
                if portal:GetPlacedByMap() then
                    local firstPlayer = Entity(1)				
                    if IsValid(firstPlayer) then
                        local info = firstPlayer:GetInfo("gp2_portal_color" .. portal:GetType() + 1)
                        local r, g, b = unpack((info or "255 255 255"):Split(" "))
        
                        portal:SetPortalColor(r, g, b)
                    end
                end
            end
        end)
    end

    hook.Add("PostCleanupMap", "GP2::PostCleanupMap", function()
        GP2.VScriptMgr.InitializeScriptForEntity(game.GetWorld(), "mapspawn")
        GP2.VScriptMgr.CallHookFunction("OnPostSpawn", true)

        PaintManager.Initialize()

        fixTonemaps()
        fixPortalColors()
    end)

    hook.Add("InitPostEntity", "GP2::InitPostEntity", function()
        GP2.VScriptMgr.InitializeScriptForEntity(game.GetWorld(), "mapspawn")
        GP2.VScriptMgr.CallHookFunction("OnPostSpawn", true)

        PaintManager.Initialize()

        fixTonemaps()
        fixPortalColors()
    end)

    hook.Add("Think", "GP2::Think", function()
        GP2.VScriptMgr.Think()
        -- SoundManager.Think()
        MouthManager.Think()
    end)

    hook.Add("PlayerTick", "GP2::PlayerTick", function(ply, mv)
        if not ply:Alive() then return end

        if IsValid(ply:GetViewEntity()) and ply:GetViewEntity():GetClass() == "point_viewcontrol" then
            ply:SetMoveType(MOVETYPE_NONE)
            ply:AddEffects(EF_NODRAW)
            ply.FrozenByCamera = true
        elseif ply.FrozenByCamera then
            ply:SetMoveType(MOVETYPE_WALK)
            ply:RemoveEffects(EF_NODRAW)
            ply.FrozenByCamera = nil
        end
    end)

    hook.Add("OnPlayerJump", "GP2::OnPlayerJump", function(ply, speed)
        for _, proxy in ipairs(ents.FindByClass("logic_playerproxy")) do
            proxy:TriggerOutput("OnJump", ply)
        end
    end)

    hook.Add("PhysgunPickup", "GP2::PhysgunPickup", function(ply, ent)
        if ent.OnPhysgunPickup and isfunction(ent.OnPhysgunPickup) then
            return ent:OnPhysgunPickup(ply)
        end
    end)

    hook.Add("PhysgunDrop", "GP2::PhysgunDrop", function(ply, ent)
        if ent.OnPhysgunDrop and isfunction(ent.OnPhysGunDrop) then
            ent:OnPhysGunDrop(ply)
        end
    end)

    hook.Add("OnPlayerPhysicsPickup", "GP2::OnPlayerPhysicsPickup", function(ply, ent)
        if ent.OnPlayerPickup and isfunction(ent.OnPlayerPickup) then
            ent:OnPlayerPickup(ply)
        end
    end)

    hook.Add("OnPlayerPhysicsDrop", "GP2::OnPlayerPhysicsDrop", function(ply, ent, thrown)
        if ent.OnPlayerDrop and isfunction(ent.OnPlayerDrop) then
            ent:OnPlayerDrop(ply, thrown)
        end
    end)

    hook.Add("GravGunOnPickedUp", "GP2::GravGunOnPickedUp", function(ply, ent)
        if ent.OnGravGunPickup and isfunction(ent.OnGravGunPickup) then
            ent:OnGravGunPickup(ply)
        end
    end)

    hook.Add("GravGunOnDropped", "GP2::GravGunOnDropped", function(ply, ent)
        if ent.OnGravGunDrop and isfunction(ent.OnGravGunDrop) then
            ent:OnGravGunDrop(ply)
        end
    end)

    hook.Add("GravGunPunt", "GP2::GravGunPunt", function(ply, ent)
        if ent.OnGravGunPunt and isfunction(ent.OnGravGunPunt) then
            return ent:OnGravGunPunt(ply)
        end
    end)

    hook.Add("PlayerFootstep", "GP2::PlayerFootsteps", function(ply, pos, foot, sound, volume, rf)
        if ply:GetGroundEntity() ~= NULL then
            ply._PreviousGroundEnt = ply:GetGroundEntity()
        end

        if ply._PreviousGroundEnt and IsValid(ply._PreviousGroundEnt) and ply._PreviousGroundEnt:GetClass() == "projected_wall_entity" then
            ply:EmitSound("Lightbridge.Step" .. (foot and "Right" or "Left"))
            return true
        end
    end)

    hook.Add("EntityEmitSound", "GP2::EntityEmitSound", function(data)
        local name = data.OriginalSoundName
        local file_path = data.SoundName
        local level = data.SoundLevel
        local ent = data.Entity
        local pos = data.Pos
        local duration = SoundDuration(data.SoundName)

        SoundManager.EntityEmitSound(name, ent, level, pos, duration)
        MouthManager.EmitSound(ent, file_path)
    end)

    net.Receive(GP2.Net.SendLoadedToServer, function(len, ply)
        local whom = net.ReadEntity()
        --GP2.Print("Player " .. tostring(whom) .. " loaded on server!")

        if whom == Entity(1) then
            GP2.VScriptMgr.CallHookFunction("OnPostSpawn", true)
        end
    end)
else
    hook.Add("Initialize", "GP2::Initialize", function()
        SoundManager.Initialize()
    end)

    include("gp2/paint.lua")
    include("gp2/client/vgui.lua")
    AddCSLuaFile("gp2/client/vgui.lua")
    include("gp2/client/hud.lua")
    include("gp2/client/render.lua")
    include("gp2/client/portalrendering.lua")
    include("gp2/client/render.lua")
    include("gp2/gamemovement.lua")
    AddCSLuaFile("gp2/client/portalrendering.lua")
    AddCSLuaFile("gp2/gamemovement.lua")

    hook.Add("Think", "GP2::Think", function()
        SoundManager.Think()
    end)
end
