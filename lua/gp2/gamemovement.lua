-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Player's movement
-- ----------------------------------------------------------------------------

AddCSLuaFile()

GP2.GameMovement = {}
local playersInTB = {}

function GP2.GameMovement.PlayerEnteredToTractorBeam(ply, beam)
    playersInTB[ply] = beam
end

function GP2.GameMovement.PlayerExitedFromTractorBeam(ply, beam)
    playersInTB[ply] = nil
end

local function TractorBeamMovement(ply, mv)
    local beam = playersInTB[ply]

    if IsValid(beam) then
        ply:SetGroundEntity(NULL)

        local plyPos = ply:WorldSpaceCenter()
        local plyAng = ply:GetAngles()
        local centerPos = beam:WorldSpaceCenter()
        local angles = beam:GetAngles()

        local toCenter = centerPos - plyPos
        local sidewayForce = angles:Right() * toCenter:Dot(angles:Right()) + angles:Up() * toCenter:Dot(angles:Up())
        local baseForce = (beam.LinearForce or 0) * 0.5
        local forwardForce = angles:Forward() * baseForce

        local totalForce = forwardForce + sidewayForce
        local moveDirection = Vector()

        if bit.band(mv:GetButtons(), IN_FORWARD) ~= 0 then
            moveDirection = mv:GetMoveAngles():Forward()
        elseif bit.band(mv:GetButtons(), IN_BACK) ~= 0 then
            moveDirection = -plyAng:Forward()
        elseif bit.band(mv:GetButtons(), IN_MOVELEFT) ~= 0 then
            moveDirection = -plyAng:Right()
        elseif bit.band(mv:GetButtons(), IN_MOVERIGHT) ~= 0 then
            moveDirection = plyAng:Right()
        end

        local dot = angles:Forward():Dot(moveDirection)
        dot = 1 - math.abs(dot)

        totalForce = totalForce + (moveDirection * ply:GetWalkSpeed()) * dot

        mv:SetVelocity(totalForce)
    end
end

hook.Add("Move", "GP2::Move", function(ply, mv)
    TractorBeamMovement(ply, moveData)
    PortalMovement.LookForPortalEnvironment(ply, mv)
    if PortalMovement.Move(ply, mv) then
        return true
    end
end)