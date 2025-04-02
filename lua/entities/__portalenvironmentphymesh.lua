AddCSLuaFile()

ENT.Type = "anim"
ENT.Spawnable = false
ENT.PrecachedVertices = {}

local IS_PRECACHED_FACES = false
local PRECACHED_FACES = {}
local PRECACHED_FACE_DATA = {}
local PRECACHED_FACE_CALCS = {}
local INSTANCE = NULL
local INSTANCE_BUILT_CONVEX_MESH = {}

function ENT:SetupDataTables()
    self:NetworkVar("Angle", "PortalAngles")
end

-- Calculate the center of a face
function ENT:CalculateFaceCenter(faceDatas)
    local sum = Vector(0, 0, 0)
    for _, vertex in ipairs(faceDatas) do
        sum = sum + vertex
    end
    return sum / #faceDatas
end

-- Precache face data and calculations
function ENT:PrecacheFaces()
    if IS_PRECACHED_FACES then return end

    local faces = NikNaks.CurrentMap:GetFaces()
    for i = 1, #faces do
        local face = faces[i]

        if not face:IsWorld() or face:HasTexInfoFlag(0x00001000) then
            continue
        end

        local vertexData = face:GenerateVertexData()
        PRECACHED_FACES[#PRECACHED_FACES + 1] = face
        PRECACHED_FACE_DATA[#PRECACHED_FACE_DATA + 1] = vertexData

        -- Precalculate operations for each face's vertices
        local cachedCalcs = {}
        for _, data in ipairs(vertexData) do
            cachedCalcs[#cachedCalcs + 1] = {
                point = data.pos,
                offset = data.pos - data.normal * 4,
                normal = data.normal,
            }
        end
        PRECACHED_FACE_CALCS[#PRECACHED_FACE_CALCS + 1] = cachedCalcs
    end

    IS_PRECACHED_FACES = true
end

-- Rebuild the physics mesh
function ENT:RebuildPhymesh()
    local startTime = SysTime()

    -- Ensure faces are precached
    self:PrecacheFaces()

    INSTANCE_BUILT_CONVEX_MESH = {}
    local pos = self:GetPos()
    local up = self:GetPortalAngles():Up()
    local thresholdSquared = 256 * 256

    for i = 1, #PRECACHED_FACES do
        local faceCalcs = PRECACHED_FACE_CALCS[i]
        local isFar = true
        local quad = {}

        for _, calc in ipairs(faceCalcs) do
            local point = calc.point
            local offset = calc.offset

            -- Check if the face is near the entity
            if point:DistToSqr(pos) <= thresholdSquared then
                isFar = false
            end

            -- Skip faces aligned with the entity's "up" direction
            if calc.normal == up then
                continue
            end

            quad[#quad + 1] = point
            quad[#quad + 1] = offset
        end

        if not isFar then
            INSTANCE_BUILT_CONVEX_MESH[#INSTANCE_BUILT_CONVEX_MESH + 1] = quad
        end
    end

    GP2.Print("Phymesh executed in %.6f seconds", SysTime() - startTime)
end

function ENT:Initialize()
    if SERVER and IsValid(INSTANCE) then
        self:Remove()
        return
    end

    INSTANCE = self
    self:RebuildPhymesh()

    self:DrawShadow(false)
    self:PhysicsInitMultiConvex(INSTANCE_BUILT_CONVEX_MESH)
    self:SetSolid(SOLID_VPHYSICS)
    self:GetPhysicsObject():EnableMotion(false)
    self:EnableCustomCollisions()

    timer.Simple(0, function()
        if not IsValid(self) then return end
        self:SetPos(Vector(0, 0, 0))
    end)

    if CLIENT then
        self:SetRenderBoundsWS(Vector(-16000, -16000, -16000), Vector(16000, 16000, 16000))
    end
end

local DEBUG_COLOR = Color(155, 255, 0, 4)

function ENT:Draw()

end

function ENT:TestCollision(startpos, delta, isbox, extents, mask)
    if bit.band(mask, CONTENTS_GRATE) ~= 0 then
        return true
    end
end
