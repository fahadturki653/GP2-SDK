-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Tractor Beam Effect
-- Credits: The Aperture addon
-- ----------------------------------------------------------------------------

local normalColor = Color(11, 37, 145)
local reversedColor = Color(121, 48, 0)

function EFFECT:Init(data)
  local ent = data:GetEntity()
  local radius = data:GetRadius()
  local magnitude = data:GetMagnitude()
  local linearForce = ent:Get_LinearForce()
  local reversed = linearForce < 0
  local color = reversed and reversedColor or normalColor
  local dir = reversed and -1 or 1
  
  if not self.Emitter then
    self.Emitter = ParticleEmitter(ent:GetPos())
  end

  for i = 0, 1, 0.5 do
    for k = 1, 2 do
      local cossinValues = CurTime() * magnitude * dir + ((math.pi * 2) / 3) * k
      local multWidth = i * radius
      local localVec = Vector(math.cos(cossinValues) * multWidth, math.sin(cossinValues) * multWidth, 5)
      local particlePos = ent:LocalToWorld(localVec) + VectorRand() * 30
  
      local p = self.Emitter:Add("sprites/light_glow02_add", particlePos)
      local duration = math.Clamp(math.abs(linearForce) / 30, 1, 3)
      p:SetDieTime(duration * ((0 - i) / 2 + 1))
      p:SetStartAlpha(math.random(0, 16))
      p:SetEndAlpha(255)
      p:SetStartSize(math.random(10, 20))
      p:SetEndSize(0)
	  if reversed then
      	p:SetVelocity(ent:GetForward() * -linearForce * dir)
	  else
		p:SetVelocity(ent:GetForward() * linearForce * dir)
	  end
      p:SetGravity(VectorRand() * 5)
      p:SetColor(color.r, color.g, color.b)
      p:SetCollide(true)
    end
  end
  
  self.Emitter:Finish()
end

function EFFECT:Think()
end

function EFFECT:Render()
end
