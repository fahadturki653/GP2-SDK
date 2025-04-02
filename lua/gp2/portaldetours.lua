-- detours so stuff go through portals
AddCSLuaFile()

-- bullet detour
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
	if PortalManager.PortalIndex < 1 then return end
	local tr = PortalManager.TraceLinePortal({start = data.Src, endpos = data.Src + data.Dir * data.Distance, filter = entity})
	
	data.Src = tr.StartPos
	data.Dir = tr.Normal

	return true
end)

-- effect detour (Thanks to WasabiThumb)
local tabEffectClass = {["phys_unfreeze"] = true, ["phys_freeze"] = true}
local oldUtilEffect = util.Effect
local function effect(name, b, c, d)
	 if PortalManager.PortalIndex > 0 and
	    name and tabEffectClass[name] then return end
	oldUtilEffect(name, b, c, d)
end
util.Effect = effect

if SERVER then return end

-- sound detour
hook.Add("EntityEmitSound", "GP2::PortalDetourSound", function(t)
	if !PortalManager or PortalManager.PortalIndex < 1 then return end
	for k, v in ipairs(ents.FindByClass("prop_portal")) do
		local exitportal = v:GetLinkedPartner()
		if !v.ExitPortal or !exitportal or !exitportal:IsValid() or !exitportal.GetExitSize then continue end
		if !t.Pos or !t.Entity or t.Entity == NULL then continue end
		if t.Pos:DistToSqr(v:GetPos()) < 50000 * exitportal:GetExitSize()[1] and (t.Pos - v:GetPos()):Dot(v:GetUp()) > 0 then
			local newPos = PortalManager.TransformPortal(v, exitportal, t.Pos, Angle())
			local oldPos = t.Entity:GetPos() or Vector()
			t.Entity:SetPos(newPos)
			EmitSound(t.SoundName, newPos, t.Entity:EntIndex(), t.Channel, t.Volume, t.SoundLevel, t.Flags, t.Pitch, t.DSP)
			t.Entity:SetPos(oldPos)
		end
	end
end)
