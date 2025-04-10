-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Controls player movement through portals (shared due prediction)
-- ----------------------------------------------------------------------------

AddCSLuaFile()

PortalMovement = PortalMovement or {}

local developer = GetConVar("developer")

local util_TraceHull = util.TraceHull
local print = GP2.Print

local gp2_portal_movement = CreateConVar("gp2_portal_movement", "1", FCVAR_REPLICATED + FCVAR_NOTIFY,
	"Toggle custom Source movement reimplementation for portal environments")

local sv_airaccelerate = GetConVar("sv_airaccelerate")
local sv_friction = GetConVar("sv_friction")
local sv_gravity = GetConVar("sv_gravity")

local DEBUG_COLOR_IN_PORTAL = Color(255, 0, 0, 1)
local DEBUG_COLOR_NOT_IN_PORTAL = Color(0, 255, 255, 1)
local DEBUG_COLOR_PURPLE_FILLED = Color(210, 0, 255, 255)
local DEBUG_SMALL_BOX = Vector(0.3, 0.3, 0.3)
local DEBUG_SMALL_BOX_NEG = -DEBUG_SMALL_BOX

local debugoverlay_Box = debugoverlay.Box
local debugoverlay_Line = debugoverlay.Line

function TranslateHullByNormal(mins, maxs, normal, multiplier)
	local normalizedNormal = normal:GetNormalized()
	local offset = normalizedNormal * multiplier
	mins = mins + offset
	maxs = maxs + offset
	return mins, maxs
end

-- Quake-style air movement (allows strafe-jumping/air control)
local function AirMove(ply, vel, wishdir, wishspeed, accel)
	local currentspeed = vel:Dot(wishdir)
	local addspeed = wishspeed - currentspeed

	if (addspeed <= 0) then return vel end

	local accelspeed = accel * FrameTime() * wishspeed * ply:GetFriction()     -- Adjust friction for air control

	if (accelspeed > addspeed) then accelspeed = addspeed end

	return vel + accelspeed * wishdir
end

function PortalMovement.LookForPortalEnvironment(ply, mv)
    local plyPos = ply:GetPos()
    local mins, maxs = ply:GetHull()

    local tr = util.TraceHull({
        start = plyPos,
        endpos = plyPos,
        mins = mins,
        maxs = maxs,
        filter = {"prop_portal"},
        whitelist = true,
        ignoreworld = true
    })

    if IsValid(tr.Entity) then
        debugoverlay.Box(plyPos, mins, maxs, 0.05, DEBUG_COLOR_NOT_IN_PORTAL)
    end

    if IsValid(tr.Entity) and tr.Entity:GetClass() == "prop_portal" and IsValid(tr.Entity:GetLinkedPartner()) and not ply.InPortalEnvironment then
        ply.PortalEnvironment = {
			portal = tr.Entity,
			linkedPortal = tr.Entity:GetLinkedPartner()
		}

		--ply:SetNWBool("GP2:InPortalEnvironment", true)
    elseif not IsValid(tr.Entity) and ply.PortalEnvironment then
        ply.PortalEnvironment = nil
		ply:SetNWBool("GP2:InPortalEnvironment", false)
        ply:SetMoveType(MOVETYPE_WALK)

        local moveTrace = util.TraceHull({
            start = ply:GetPos(),
            endpos = ply:GetPos() + Vector(0, 0, 0.1),
            mins = ply:OBBMins(),
            maxs = ply:OBBMaxs(),
            mask = MASK_PLAYERSOLID,
            filter = {ply, "prop_portal"},
            collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
        })

        if moveTrace.StartSolid then
            local directions = {
                Vector(1, 0, 0), Vector(-1, 0, 0),
                Vector(0, 1, 0), Vector(0, -1, 0),
                Vector(0, 0, 1), Vector(0, 0, -1)
            }

            local attempts = 100
            local stepSize = 1

            print("Player in solid after portal interaction, trying to unstuck")

            for attempt = 1, attempts do
                for _, dir in ipairs(directions) do
                    local attemptPos = ply:GetPos() + dir * (stepSize * attempt)
                    local attemptTrace = util.TraceHull({
                        start = attemptPos,
                        endpos = attemptPos,
                        mins = ply:OBBMins(),
                        maxs = ply:OBBMaxs(),
                        mask = MASK_PLAYERSOLID,
                        filter = {ply, "prop_portal"},
                        collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT
                    })

                    if not attemptTrace.StartSolid then
                        mv:SetOrigin(attemptPos)
                        mv:SetVelocity(vector_origin)
                        ply:SetGroundEntity(attemptTrace.Entity)
                        print("Player successfully unstuck")
                        return
                    end
                end
            end

            print("Failed to unstuck player after multiple attempts")
        else
            mv:SetOrigin(moveTrace.HitPos + moveTrace.HitNormal * 0.035)
            ply:SetGroundEntity(moveTrace.Entity)
        end

        print("Fixing pos up")
    end
end

--- Portal movement hook
--- @param ply Player Who moves
--- @param mv CMoveData Move data
function PortalMovement.Move(ply, mv)
	if not (gp2_portal_movement:GetBool() and ply.PortalEnvironment) then
		return false
	end
	
	local plyPos = ply:GetPos()
	local mins, maxs = ply:GetHull()
	local portalEnvironment = ply.PortalEnvironment

	local portal = portalEnvironment.portal
	local linkedPortal = portalEnvironment.linkedPortal
	local portalPos = portal:GetPos()
	local dot = (plyPos - portalPos):Dot(portal:GetUp())

	print(dot)

	if dot < 0.1 then
		local transformedPos, transformedAngles = PortalManager.TransformPortal(portal, linkedPortal, plyPos, ply:EyeAngles())

		--mv:SetOrigin(transformedPos)
		--ply:SetEyeAngles(transformedAngles)

		ply.PortalEnvironment = nil

		print("Ready to tp")
	end

	local transformedPos, transformedAngles = PortalManager.TransformPortal(portal, linkedPortal, plyPos, ply:EyeAngles())

	debugoverlay.Box(transformedPos, mins, maxs, 0.1, DEBUG_COLOR_IN_PORTAL)
	
	ply:SetMoveType(MOVETYPE_NOCLIP)

	local vel = mv:GetVelocity()
	local pos = mv:GetOrigin()
	local ang = mv:GetMoveAngles()

	-- Check if the player is on the ground
	local trace = util.TraceHull({
		start = pos,
		endpos = pos - Vector(0, 0, 2), -- Trace slightly downwards
		mins = ply:OBBMins(),
		maxs = ply:OBBMaxs(),
		filter = {ply, "prop_portal"},
		ignoreworld = true
	})

	if trace.Hit then
		if not IsValid(ply:SetGroundEntity()) or ply:GetGroundEntity() ~= trace.Entity then
			ply:SetGroundEntity(trace.Entity)
		end
	else
		ply:SetGroundEntity(NULL)
	end

	local onGround = trace.Hit and not trace.HitWorld

	-- Apply gravity if not on the ground
	if (not onGround) then
		vel.z = vel.z - (sv_gravity:GetFloat() * FrameTime())
	end

	-- Get wish direction and speed (desired movement direction and speed)
	local forward, right, up = ply:GetForward(), ang:Right(), ang:Up()
	local fmove, smove = mv:GetForwardSpeed(), mv:GetSideSpeed()
	local wishvel = (forward * fmove + right * smove) * (ply:IsSprinting() and 0.04 or (ply:IsWalking() and 0.01 or 0.02))
	wishvel.z = 0
	local wishdir = wishvel:GetNormalized()
	local wishspeed = wishvel:Length()

	-- Clamp wishspeed to jump speed if jumping
	if mv:KeyDown(IN_JUMP) and onGround then
		local jumpspeed = ply:GetJumpPower()
		if (wishspeed > jumpspeed) then wishspeed = jumpspeed end

		vel.z = jumpspeed -- Apply jump impulse
	end

	-- Apply air or ground acceleration
	if onGround then
		vel = vel * (1 - FrameTime() * sv_friction:GetFloat()) -- Apply ground friction

		local accelspeed = GetConVar("sv_accelerate"):GetFloat() * FrameTime() * wishspeed * ply:GetFriction()
		local addspeed = wishspeed - vel:Dot(wishdir)
		if (addspeed > 0) then
			accelspeed = math.min(addspeed, accelspeed)
			vel = vel + wishdir * accelspeed
		end
	else
		vel = AirMove(ply, vel, wishdir, wishspeed * 0.1, sv_airaccelerate:GetFloat()) -- Air acceleration
	end

	-- Clamp to max speed
	local maxSpeed = GetConVar("sv_maxvelocity"):GetFloat()
	if (vel:Length() > maxSpeed and not onGround) then -- Only clamp speed if in the air
		local velDir = vel:GetNormalized()
		vel = velDir * maxSpeed
	end

	-- Predict new position and check for collision
	local newPos = pos + vel * FrameTime()
	local moveTrace = util.TraceHull({
		start = pos,
		endpos = newPos,
		mins = ply:OBBMins(),
		maxs = ply:OBBMaxs(),
		filter = {ply, "prop_portal"},
		mask = MASK_PLAYERSOLID,
		collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT,
		ignoreworld = true
	})

	-- Handle collision
	if (moveTrace.Hit and not moveTrace.HitWorld) then
		newPos = moveTrace.HitPos + moveTrace.HitNormal * 0.035
		local dot = vel:Dot(moveTrace.HitNormal)
		if (dot < 0) then
			vel = vel - moveTrace.HitNormal * dot
		end

		ply:SetGroundEntity(moveTrace.Entity)
	else
		ply:SetGroundEntity(NULL)
	end

	mv:SetVelocity(vel)
	mv:SetOrigin(newPos)

	return true
end

hook.Add("CalcView", "TEMP_Z_NEAR_FIX", function(ply, pos, angles, fov, znear, zfar)
	if not ply:GetNWBool("GP2:InPortalEnvironment") then return { znear = znear } end

	print("Altering znear")

	return {
		znear = 0.01
	}
end)
