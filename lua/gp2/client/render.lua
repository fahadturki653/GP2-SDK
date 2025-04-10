-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Render related hooks
-- ----------------------------------------------------------------------------

include "gp2/client/render/env_portal_laser.lua"

ProjectedWallEntity = ProjectedWallEntity or {}
ProjectedWallEntity.Walls = ProjectedWallEntity.Walls or {}

ProjectedTractorBeamEntity = ProjectedTractorBeamEntity or {}
ProjectedTractorBeamEntity.Beams = ProjectedTractorBeamEntity.Beams or {}

PropTractorBeam = PropTractorBeam or {}
PropTractorBeam.Beams = PropTractorBeam.Beams or {}

NpcPortalTurretFloor = NpcPortalTurretFloor or {}
NpcPortalTurretFloor.Turrets = NpcPortalTurretFloor.Turrets or {}

PropPortal = PropPortal or {}
PropPortal.Portals = PropPortal.Portals or {}

local MAX_RAY_LENGTH = 8192

local TURRET_BEAM_COLOR = Color(255,32,32,255)
local TURRET_BEAM_MATERIAL = Material("effects/redlaser1_scripted.vmt")
local TURRET_EYE_GLOW = Material("sprites/glow1_scripted.vmt")

local PROJECTED_WALL_MATERIAL = Material("effects/projected_wall")

local PROJECTED_BEAM_MATERIAL = Material("effects/tractor_beam_blue")
local PROJECTED_BEAM_MATERIAL_INVERSE = Material("effects/tractor_beam_orange")

local PROJECTED_BEAM_COLOR_NORMAL = Color(12,28,80)
local PROJECTED_BEAM_COLOR_INVERTED = Color(255,60,0)

local PROJECTED_BEAM_COLOR_NORMAL_END = Color(0,64,128)
local PROJECTED_BEAM_COLOR_INVERTED_END = Color(128,64,0)

local PROP_TRACTOR_BEAM_END = Material("sprites/beam_smoke_01")
local PROP_TRACTOR_BEAM = Material("sprites/beam_generic_2")
local PROP_TRACTOR_GLOW = Material("particle/particle_glow_05")

local END_POINT_PULSE_SCALE = 16

local HALF_VECTOR = Vector(0.5,0.5,0.5)
local HALF2_VECTOR = Vector(0.25,0.25,0.25)

local gp2_projected_wall_dlight = CreateClientConVar("gp2_r_projected_wall_dlight", "0", true, false, "Should Hard Light Bridge emit light? Can be expensive if bridge is long!", 0, 1)

TURRET_EYE_GLOW:SetVector("$color", HALF_VECTOR)
TURRET_BEAM_MATERIAL:SetVector("$color", HALF2_VECTOR)

function ProjectedWallEntity.AddToRenderList(ent, wall)
    ProjectedWallEntity.Walls[ent] = wall
end

function ProjectedWallEntity.IsAdded(ent)
    return ProjectedWallEntity.Walls[ent] ~= nil and ProjectedWallEntity.Walls[ent]:IsValid()
end

function ProjectedWallEntity.Render()
    for entity, wall in pairs(ProjectedWallEntity.Walls) do
        if not IsValid(entity)  then
            ProjectedWallEntity.Walls[entity] = nil
            return
        end

        if wall and wall:IsValid() then
            render.SetMaterial(PROJECTED_WALL_MATERIAL)
            wall:Draw()

            if gp2_projected_wall_dlight:GetBool() then
                for i = 64, entity:GetDistanceToHit() - 32, 32 do
                    local dlight = DynamicLight( i )
                    local point = entity:GetParent():GetPos() + entity:GetAngles():Forward() * i

                    if dlight then
                        dlight.pos = point
                        dlight.r = 0
                        dlight.g = 25
                        dlight.b = 75
                        dlight.brightness = 1
                        dlight.decay = 1000 * FrameTime()
                        dlight.size = 192
                        dlight.dietime = CurTime() + 1
                    end
                end
            end
        end
    end
end

function ProjectedTractorBeamEntity.AddToRenderList(ent, wall)
    ProjectedTractorBeamEntity.Beams[ent] = wall
end

function ProjectedTractorBeamEntity.IsAdded(ent)
    return ProjectedTractorBeamEntity.Beams[ent] ~= nil and ProjectedTractorBeamEntity.Beams[ent]:IsValid()
end

function ProjectedTractorBeamEntity.Render()
    for entity, beam in pairs(ProjectedTractorBeamEntity.Beams) do
        if not IsValid(entity) then
            ProjectedTractorBeamEntity.Beams[entity] = nil
            return
        end

        if beam and beam:IsValid() then
            local basetexturetransform = PROJECTED_BEAM_MATERIAL:GetMatrix("$basetexturetransform")

            entity.baseTransformPosition = entity.baseTransformPosition or 0

            basetexturetransform:SetField(1, 4, entity.baseTransformPosition)
            PROJECTED_BEAM_MATERIAL:SetMatrix("$basetexturetransform", basetexturetransform)
            PROJECTED_BEAM_MATERIAL:SetMatrix("$detail1texturetransform", basetexturetransform)
            PROJECTED_BEAM_MATERIAL:SetMatrix("$detail2texturetransform", basetexturetransform)
            
            PROJECTED_BEAM_MATERIAL_INVERSE:SetMatrix("$basetexturetransform", basetexturetransform)
            PROJECTED_BEAM_MATERIAL_INVERSE:SetMatrix("$detail1texturetransform", basetexturetransform)
            PROJECTED_BEAM_MATERIAL_INVERSE:SetMatrix("$detail2texturetransform", basetexturetransform)

            local rate = entity:Get_LinearForce() / 1000

            -- for now i'll do rate same for every tractor beam
            rate = entity:Get_LinearForce() < 0 and -0.25 or 0.25

            if entity:Get_LinearForce() < 0 then
                render.SetMaterial(PROJECTED_BEAM_MATERIAL_INVERSE)
            else
                render.SetMaterial(PROJECTED_BEAM_MATERIAL)
            end

            entity.baseTransformPosition = (entity.baseTransformPosition + rate * FrameTime()) % 1
            
            beam:Draw()

            local hitData = entity.HitData
            
            if hitData then
                local hitPos = hitData.HitPos
                local angles = hitData.Angles
                local radius = hitData.Radius
                local sides = hitData.Sides
            
                local up = angles:Up()
                local right = angles:Right()
                local forward = angles:Forward()

                hitPos = hitPos - forward * 3

                render.SetMaterial(PROP_TRACTOR_BEAM_END)
            
                render.StartBeam(sides + 1)
            
                for i = 0, sides do
                    local angle = ((i / sides) + (CurTime() * 0.3) % 1) * math.pi * 2
                    local offset = right * math.cos(angle) * radius + up * math.sin(angle) * radius
                    local point = hitPos + offset
                    render.AddBeam(point, 14, i / sides, entity:Get_LinearForce() < 0 and PROJECTED_BEAM_COLOR_INVERTED_END or PROJECTED_BEAM_COLOR_NORMAL_END)
                end
            
                render.EndBeam()
            end
        end
    end
end

function PropTractorBeam.AddToRenderList(beam)
    PropTractorBeam.Beams[beam] = true
end

function PropTractorBeam.IsAdded(beam)
    return PropTractorBeam.Beams[beam] ~= nil
end

function PropTractorBeam.Render()
    for beam in pairs(PropTractorBeam.Beams) do
        if not IsValid(beam) then
            PropTractorBeam.Beams[beam] = nil
            continue 
        end

        beam.CachedAttachments = beam.CachedAttachments or {}
        beam.AttachmentTrails = beam.AttachmentTrails or {{}, {}, {}}
        beam.NextParticleCoreTime = beam.NextParticleCoreTime or CurTime() + 0.05

        if beam:GetEnabled() and CurTime() > beam.NextParticleCoreTime then
            local effectdata = EffectData()
            effectdata:SetEntity(beam)
            effectdata:SetMagnitude(2.5)
            effectdata:SetRadius(40)
            effectdata:SetColor(reverse and 1 or 0)
            util.Effect("tractor_beam_effect", effectdata)

            beam.NextParticleCoreTime = CurTime() + 0.05
        end

        for i = 1, 3 do
            beam.CachedAttachments[i] = beam.CachedAttachments[i] or beam:LookupAttachment("emitter" .. i)
            local attach = beam:GetAttachment(beam.CachedAttachments[i])

            if attach then
                if beam:GetEnabled() then
                    render.SetMaterial(PROP_TRACTOR_GLOW)
                    render.DrawSprite(attach.Pos, 96, 96, beam:Get_LinearForce() < 0 and PROJECTED_BEAM_COLOR_INVERTED or PROJECTED_BEAM_COLOR_NORMAL)
                    table.insert(beam.AttachmentTrails[i], {Pos = attach.Pos, LifeTime = 2, MaxLifeTime = 2})
                end

                render.SetMaterial(PROP_TRACTOR_BEAM)
                render.StartBeam(#beam.AttachmentTrails[i])
                for b = 1, #beam.AttachmentTrails[i] do
                    local trailPoint = beam.AttachmentTrails[i][b]

                    local width = 8 * (trailPoint.LifeTime / trailPoint.MaxLifeTime)
                    render.AddBeam(trailPoint.Pos, width, 0, beam:Get_LinearForce() < 0 and PROJECTED_BEAM_COLOR_INVERTED or PROJECTED_BEAM_COLOR_NORMAL)

                    trailPoint.LifeTime = trailPoint.LifeTime - FrameTime()
                end
                render.EndBeam()

                for b = #beam.AttachmentTrails[i], 1, -1 do
                    if beam.AttachmentTrails[i][b].LifeTime <= 0 then
                        table.remove(beam.AttachmentTrails[i], b)
                    end
                end
            end
        end
    end
end

function NpcPortalTurretFloor.AddToRenderList(turret)
    NpcPortalTurretFloor.Turrets[turret] = true
end

function NpcPortalTurretFloor.Render()
    for turret in pairs(NpcPortalTurretFloor.Turrets) do
        if not IsValid(turret) then 
            NpcPortalTurretFloor.Turrets[turret] = nil
            continue
        end

        if turret:GetEyeState() == 3 then continue end

        turret.attachNum = turret.attachNum or turret:LookupAttachment("light")
        local attach = turret:GetAttachment(turret.attachNum)

        local start = attach.Pos
        local fwd = turret:GetAngles():Forward()

        local prmn, prmx = turret:GetPoseParameterRange("aim_pitch")
        local yrmn, yrmx = turret:GetPoseParameterRange("aim_yaw")

        local pitch = math.Remap(turret:GetPoseParameter("aim_pitch"), 0, 1, prmn, prmx)
        local yaw = math.Remap(turret:GetPoseParameter("aim_yaw"), 0, 1, yrmn, yrmx)

        turret.LaserAngles = turret.LaserAngles or Angle(0,0,0)
        turret.LaserAngles.x = turret:GetAngles().x + pitch
        turret.LaserAngles.y = turret:GetAngles().y + yaw

        local tr = util.TraceLine({
            start = start,
            endpos = start + turret.LaserAngles:Forward() * MAX_RAY_LENGTH,
            filter = turret,
            mask = MASK_SOLID,
        })

        turret.FlickerTime = turret.FlickerTime or 0
        turret.Flicked = turret.Flicked or false

        turret.PixVis = turret.PixVis or util.GetPixelVisibleHandle()
        turret.PixVis2 = turret.PixVis2 or util.GetPixelVisibleHandle()
        local pixelVisibility = util.PixelVisible(start, 16, turret.PixVis)
        local pixelVisibility2 = util.PixelVisible(tr.HitPos, 1, turret.PixVis2)

        if not turret:GetHasAmmo() and CurTime() > turret.FlickerTime then
            turret.Flicked = not turret.Flicked
            turret.FlickerTime = CurTime() + math.Rand(0.05, 0.3)
        end

        turret.EyeGlowColor = turret.EyeGlowColor or Color(255,0,0)
        turret.BeamGlowColor = turret.BeamGlowColor or Color(255,0,0)

        turret.BeamGlowColor.r = 255 * pixelVisibility2

        turret.BeamPulseOffset = turret.BeamPulseOffset or math.Rand(0, 2 * math.pi)
        turret.BeamGlowSize = turret.BeamGlowSize or 0
        turret.BeamGlowSize = ((math.max(0.0, math.sin(CurTime() * math.pi + turret.BeamPulseOffset))) * END_POINT_PULSE_SCALE + 3.0)
        
        if turret:GetEyeState() < 3 and not turret.Flicked then
            render.SetBlend(0.2)
            render.SetMaterial(TURRET_BEAM_MATERIAL)
            TURRET_BEAM_MATERIAL:SetVector("$color", HALF_VECTOR)
            render.DrawBeam(start, tr.HitPos, 2, 0, 1, TURRET_BEAM_COLOR)

            render.OverrideBlend( true, BLEND_SRC_COLOR, BLEND_SRC_ALPHA, BLENDFUNC_ADD )
            render.SetMaterial(TURRET_EYE_GLOW)
            render.DrawSprite(tr.HitPos, turret.BeamGlowSize, turret.BeamGlowSize, turret.BeamGlowColor)
            render.OverrideBlend( false )
        end

        turret.EyeGlowSize = turret.EyeGlowSize or 32
        turret.EyeGlowColor = turret.EyeGlowColor or Color(255,0,0)

        if not turret:GetIsAsActor() then
            if turret:GetEyeState() == 1 then
                turret.EyeGlowColor.r = Lerp(FrameTime() * 15, turret.EyeGlowColor.r, 128)
                turret.EyeGlowSize = Lerp(FrameTime() * 5, turret.EyeGlowSize, 32)
            elseif turret:GetEyeState() == 2 then
                turret.EyeGlowColor.r = Lerp(FrameTime() * 15, turret.EyeGlowColor.r, 192)
                turret.EyeGlowSize = Lerp(FrameTime() * 5, turret.EyeGlowSize, 48)
            elseif turret:GetEyeState() == 3 then
                turret.EyeGlowColor.r = Lerp(FrameTime() * 15, turret.EyeGlowColor.r, 0)
                turret.EyeGlowSize = Lerp(FrameTime() * 0.5, turret.EyeGlowSize, 64)
            end
        else
            turret.EyeGlowColor.r = Lerp(FrameTime() * 15, turret.EyeGlowColor.r, 0)
            turret.EyeGlowSize = Lerp(FrameTime() * 5, turret.EyeGlowSize, 32)
        end

        local lp = LocalPlayer()
        local plyPos = lp:GetPos()
        local directionToPlayer = (plyPos - turret:GetPos()):GetNormalized()
        local fwd = turret:GetAngles():Forward()
        local dot = fwd:Dot(directionToPlayer)
        local opacity = math.Clamp((dot + 1) / 2, 0, 1)

        turret.EyeGlowColor.r = 255 * opacity

        render.OverrideBlend( true, BLEND_SRC_COLOR, BLEND_SRC_ALPHA, BLENDFUNC_ADD )
        render.SetMaterial(TURRET_EYE_GLOW)
        render.DrawSprite(start, turret.EyeGlowSize, turret.EyeGlowSize, turret.EyeGlowColor)
        render.OverrideBlend( false )
    end
end

function PropPortal.AddToRenderList(portal)
    PropPortal.Portals[portal] = true
end

function PropPortal.IsAddedToRenderList(portal)
    return PropPortal.Portals[portal] ~= nil
end

function PropPortal.Render()
    for portal in pairs(PropPortal.Portals) do
        if not IsValid(portal) then PropPortal.Portals[portal] = nil ; continue end
        if not portal:GetActivated() then continue end

        portal:DrawGhost()
    end
end

hook.Add("PreDrawTranslucentRenderables", "GP2::PreDrawTranslucentRenderables", function(depth, sky, skybox3d)
    if depth or sky then return end

    PropIndicatorPanel.Render()
    VguiMovieDisplay.Render()
    VguiSPProgressSign.Render()
    VguiNeurotoxinCountdown.Render()
    PropPortal.Render()

    if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM and PortalRendering.Rendering then
        return true
    end
end)

hook.Add("PreDrawOpaqueRenderables", "GP2::PreDrawOpaqueRenderables", function(depth, sky, skybox3d)
    if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM and PortalRendering.Rendering then
        return true
    end
end)

hook.Add("PostDrawTranslucentRenderables", "GP2::PostDrawTranslucentRenderables", function(depth, sky, skybox3d)
    if depth or sky then return end

    EnvPortalLaser.Render()
    ProjectedWallEntity.Render()
    ProjectedTractorBeamEntity.Render()
    NpcPortalTurretFloor.Render()
    PropTractorBeam.Render()
end)

hook.Add("PostDrawOpaqueRenderables", "GP2::PostDrawOpaqueRenderables", function(depth, sky, skybox3d)
end)