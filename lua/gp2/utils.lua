-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Various utils
-- ----------------------------------------------------------------------------

GP2.Utils = {}

local clamp = math.Clamp
local tan = math.tan
local table_insert = table.insert
local sound_Play = sound.Play


function GP2.Utils.CalcClosestPointOnLineSegment(point, lineStart, lineEnd)
    local toPoint = point - lineStart
    local lineDirection = (lineEnd - lineStart):GetNormalized()
    local dotProduct = clamp(lineDirection:Dot(toPoint), 0, (lineEnd - lineStart):Length())

    return lineStart + lineDirection * dotProduct
end

local CalcClosestPointOnLineSegment = GP2.Utils.CalcClosestPointOnLineSegment

function GP2.Utils.EmitSoundAtClosestPoint(player, sourcePos, targetPos, soundPath)
    -- Ensure the player is valid
    if not IsValid(player) or not player:IsPlayer() or not player:Alive() then
        return
    end

    -- Calculate the nearest point on the line segment to the player
    local playerPos = player:GetPos()
    local nearestPoint = CalcClosestPointOnLineSegment(playerPos, sourcePos, targetPos)

    -- Emit the sound at the nearest point
    sound_Play(soundPath, nearestPoint)
end

if SERVER then
    
else
    local render_GetViewSetup = render.GetViewSetup

    function GP2.Utils.AddFace(resultTable, v1, v2, v3, v4, uv1, uv2, uv3, uv4)
        table_insert(resultTable, { pos = v1, u = uv1[1], v = uv1[2] })
        table_insert(resultTable, { pos = v2, u = uv2[1], v = uv2[2] })
        table_insert(resultTable, { pos = v3, u = uv3[1], v = uv3[2] })
    
        table_insert(resultTable, { pos = v3, u = uv3[1], v = uv3[2] })
        table_insert(resultTable, { pos = v4, u = uv4[1], v = uv4[2] })
        table_insert(resultTable, { pos = v1, u = uv1[1], v = uv1[2] })
    end

    function GP2.Utils.ToViewModelPosition(vOrigin)
        local view = render_GetViewSetup()
        local vEyePos = view.origin
        local aEyesRot = view.angles
        local vOffset = vOrigin - vEyePos
        local vForward = aEyesRot:Forward()
    
        local nViewX = tan(view.fovviewmodel_unscaled * math.pi / 360)
        local nWorldX = tan(view.fov_unscaled * math.pi / 360)
    
        if (nViewX == 0 or nWorldX == 0) then
            return vEyePos + vForward * vForward:Dot(vOffset)
        end
    
        local nFactor = nViewX / nWorldX
    
        return vEyePos
            + aEyesRot:Right() * (aEyesRot:Right():Dot(vOffset) * nFactor)
            + aEyesRot:Up() * (aEyesRot:Up():Dot(vOffset) * nFactor)
            + vForward * vForward:Dot(vOffset)
    end
    
end