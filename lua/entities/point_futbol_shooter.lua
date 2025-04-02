-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Bomb shooter
-- ----------------------------------------------------------------------------

ENT.Type = "point"

function ENT:Initialize()
    self.TargetEntity = nil
    self.LaunchSpeed = 500
end

function ENT:KeyValue(key, value)
    if key == "launchSpeed" then
        self.LaunchSpeed = tonumber(value)
    end
end

function ENT:AcceptInput(inputName, activator, caller, data)
    inputName = inputName:lower()

    if inputName == "settarget" then
        local target = ents.FindByName(data)[1]

        if not IsValid(target) then
            return
        end

        self.TargetPos = target:GetPos()
    elseif inputName == "shootfutbol" then
        self:ShootFutbol()
    end
end

-- this is not my code
local function CalculateBallisticTrajectory(startPos, endPos, initialFutbolVelocity)
    local gravity = 600
    local displacement = endPos - startPos
    local dx = Vector(displacement.x, displacement.y, 0):Length()
    local dy = displacement.z
    local g = gravity

    local v = initialFutbolVelocity
    local maxVelocity = 2000
    local stepVelocity = 10

    local foundSolution = false
    local velocity = Vector(0, 0, 0)

    while v <= maxVelocity do
        local vSquared = v * v

        local discriminant = vSquared * vSquared - g * (g * dx * dx + 2 * dy * vSquared)

        if discriminant >= 0 then
            local sqrtDiscriminant = math.sqrt(discriminant)

            -- Calculate the two possible angles of launch (theta)
            local angleHigh = math.atan((vSquared + sqrtDiscriminant) / (g * dx))

            -- Choose the higher angle for a higher ar
            local theta = angleHigh

            -- Calculate initial velocities in X and Z directions
            local vx = v * math.cos(theta)
            local vz = v * math.sin(theta)

            -- Get the horizontal direction vector
            local horizontalDir = Vector(displacement.x, displacement.y, 0):GetNormalized()

            -- Build the final velocity vector
            velocity = horizontalDir * vx
            velocity.z = vz

            foundSolution = true
            break  -- Exit the loop as we've found a valid solution
        else
            -- No solution at this velocity, increase futbol velocity and try again
            v = v + stepVelocity
        end
    end

    return foundSolution, velocity
end

function ENT:ShootFutbol()
    local startPos = self:GetPos()
    local endPos = self.TargetPos

    -- Create the futbol entity
    local futbol = ents.Create("prop_exploding_futbol")
    if not IsValid(futbol) then return end

    futbol:SetPos(startPos)
    futbol:SetExplosionOnTouch(true)
    futbol:Spawn()

    local success, velocity = CalculateBallisticTrajectory(startPos, endPos, self.LaunchSpeed)

    if not success then
        GP2.Error("Cannot compute trajectory to target pos %s. Target may be out of range.", tostring(self.TargetPos))
        return
    end

    local phys = futbol:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(velocity)
    end
end