--!strict
local RunService = game:GetService("RunService")

local Emitter = {}
Emitter.__index = Emitter

type Particle = {
	_instance: Part,
	_decal: Decal,
	_velocity: Vector3,
	_life: number,
	_age: number,
}

export type Emitter = {
	Acceleration: Vector3,
	Brightness: number,
	Color: ColorSequence,
	Drag: number, -- NOT IMPLEMENTED
	EmissionDirection: Enum.NormalId, -- NOT IMPLEMENTED
	FlipbookFramerate: NumberRange, -- NOT IMPLEMENTED
	FlipbookIncompatible: string, -- NOT IMPLEMENTED
	FlipbookLayout: Enum.ParticleFlipbookLayout, -- NOT IMPLEMENTED
	FlipbookMode: Enum.ParticleFlipbookMode, -- NOT IMPLEMENTED
	FlipbookSizeX: number, -- NOT IMPLEMENTED
	FlipbookSizeY: number, -- NOT IMPLEMENTED
	FlipbookStartRandom: boolean, -- NOT IMPLEMENTED
	Lifetime: NumberRange,
	LockedToPart: boolean, -- NOT IMPLEMENTED
	Orientation: Enum.ParticleOrientation, -- NOT IMPLEMENTED
	Rate: number,
	Rotation: NumberRange,
	RotSpeed: NumberRange,
	Shape: Enum.ParticleEmitterShape, -- NOT IMPLEMENTED
	ShapeInOut: Enum.ParticleEmitterShapeInOut, -- NOT IMPLEMENTED
	ShapePartial: number, -- NOT IMPLEMENTED
	ShapeStyle: Enum.ParticleEmitterShapeStyle, -- NOT IMPLEMENTED
	Size: NumberSequence,
	Speed: NumberRange,
	SpreadAngle: Vector2,
	Squash: NumberSequence, -- NOT IMPLEMENTED
	Texture: string,
	TimeScale: number,
	Transparency: NumberSequence,
	VelocityInheritance: number, -- NOT IMPLEMENTED
	WindAffectsDrag: boolean, -- NOT IMPLEMENTED

	_particles: { Particle },
	_parent: Part,
	_enabled: boolean,
	_accumulator: number,
	_updateConnection: RBXScriptConnection,
	_camera: Camera,
} & typeof(Emitter)

-- // HELPER FUNCTIONS \\ --

local function sampleNumberSequence(seq: NumberSequence, alpha: number): number
	alpha = math.clamp(alpha, 0, 1)

	local keypoints = seq.Keypoints

	for i = 1, #keypoints - 1 do
		local k0 = keypoints[i]
		local k1 = keypoints[i + 1]

		if alpha >= k0.Time and alpha <= k1.Time then
			local t = (alpha - k0.Time) / (k1.Time - k0.Time)
			return k0.Value + (k1.Value - k0.Value) * t
		end
	end

	return keypoints[#keypoints].Value
end

local function sampleColorSequence(seq: ColorSequence, alpha: number): Color3
	alpha = math.clamp(alpha, 0, 1)

	local keypoints = seq.Keypoints

	for i = 1, #keypoints - 1 do
		local k0 = keypoints[i]
		local k1 = keypoints[i + 1]

		if alpha >= k0.Time and alpha <= k1.Time then
			local t = (alpha - k0.Time) / (k1.Time - k0.Time)
			return k0.Value:Lerp(k1.Value, t)
		end
	end

	return keypoints[#keypoints].Value
end

-- // CLASS \\ --

function Emitter.new(parent: Part, camera: Camera): Emitter
	assert(parent, "No ViewportEmitter parent part given.")
	assert(camera, "No Camera given.")

	local self = setmetatable({}, Emitter)

	-- Set default values based on Roblox ParticleEmitter defaults
	self.Acceleration = Vector3.new(0, 0, 0)
	self.Brightness = 1
	self.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	self.Drag = 0
	self.EmissionDirection = Enum.NormalId.Top
	self.Enabled = true
	self.Lifetime = NumberRange.new(1, 1.25)
	self.LightEmission = 0
	self.LightInfluence = 0
	self.LocalTransparencyModifier = 1
	self.LockedToPart = false
	self.Orientation = Enum.ParticleOrientation.FacingCamera
	self.Rate = 20
	self.Rotation = NumberRange.new(0, 0)
	self.RotSpeed = NumberRange.new(0, 0)
	self.Size = NumberSequence.new(1, 1)
	self.Speed = NumberRange.new(5, 5)
	self.SpreadAngle = Vector2.new(0, 0)
	self.Squash = NumberSequence.new(0, 0)
	self.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	self.TimeScale = 1
	self.Transparency = NumberSequence.new(0, 0)

	-- Initialize internal properties
	self._particles = {}
	self._parent = parent
	self._enabled = false
	self._accumulator = 0
	self._camera = camera

	return self :: Emitter
end

function Emitter.fromParticleEmitter(particle: ParticleEmitter, parent: Part, camera: Camera): Emitter
	assert(parent, "No ViewportEmitter parent part given.")
	assert(camera, "No Camera given.")

	local self = setmetatable({}, Emitter)

	-- Copy all properties from the existing ParticleEmitter
	self.Acceleration = particle.Acceleration
	self.Brightness = particle.Brightness
	self.Color = particle.Color
	self.Drag = particle.Drag
	self.EmissionDirection = particle.EmissionDirection
	self.Enabled = particle.Enabled
	self.Lifetime = particle.Lifetime
	self.LightEmission = particle.LightEmission
	self.LightInfluence = particle.LightInfluence
	self.LocalTransparencyModifier = particle.LocalTransparencyModifier
	self.LockedToPart = particle.LockedToPart
	self.Orientation = particle.Orientation
	self.Rate = particle.Rate
	self.Rotation = particle.Rotation
	self.RotSpeed = particle.RotSpeed
	self.Size = particle.Size
	self.Speed = particle.Speed
	self.SpreadAngle = particle.SpreadAngle
	self.Squash = particle.Squash
	self.Texture = particle.Texture
	self.TimeScale = particle.TimeScale
	self.Transparency = particle.Transparency

	-- Initialize internal properties
	self._particles = {}
	self._parent = parent
	self._enabled = false
	self._accumulator = 0
	self._camera = camera

	return self :: Emitter
end

function Emitter._emit(self: Emitter, dt: number)
	self._accumulator += dt

	if self._accumulator >= 1 / self.Rate or dt == 0 then
		self._accumulator -= dt ~= 0 and (1 / self.Rate) or 0

		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1

		local size = sampleNumberSequence(self.Transparency, 0)
		part.Size = Vector3.one * size
		part.Parent = self._parent

		local decal = Instance.new("Decal")
		decal.Texture = self.Texture
		decal.Color3 = sampleColorSequence(self.Color, 0)
		decal.Transparency = sampleNumberSequence(self.Transparency, 0)
		decal.Face = Enum.NormalId.Front
		decal.Parent = part

		local theta = math.rad(math.random() * self.SpreadAngle.X)
		local phi = math.rad(math.random() * self.SpreadAngle.Y)

		local dir = Vector3.new(math.cos(theta) * math.sin(phi), math.cos(phi), math.sin(theta) * math.sin(phi))

		local speed = math.random() * (self.Speed.Max - self.Speed.Min) + self.Speed.Min
		local life = math.random() * (self.Lifetime.Max - self.Lifetime.Min) + self.Lifetime.Min

		table.insert(self._particles, {
			_instance = part,
			_decal = decal,
			_velocity = dir * speed,
			_life = life,
			_age = 0,
		})
	end
end

function Emitter._update(self: Emitter, dt: number)
	for i, particle in self._particles do
		particle._age += dt

		if particle._age >= particle._life then
			particle._instance:Destroy()
			table.remove(self._particles, i)
		else
			particle._instance.Position += particle._velocity * dt * self.TimeScale
			particle._instance.Size = Vector3.one * sampleNumberSequence(self.Size, particle._age / particle._life)
			particle._instance.CFrame = CFrame.lookAt(particle._instance.Position, self._camera.CFrame.Position)

			particle._decal.Transparency = sampleNumberSequence(self.Transparency, particle._age / particle._life)
			particle._decal.Color3 = sampleColorSequence(self.Color, particle._age / particle._life)
		end
	end
end

function Emitter.Start(self: Emitter)
	self._enabled = true

	self._updateConnection = RunService.PreRender:Connect(function(dt: number)
		if self._enabled then
			self:_emit(dt)
		end

		self:_update(dt)
	end)
end

function Emitter.Emit(self: Emitter, amount: number)
	for _ = 1, amount do
		self:_emit(0)
	end
end

function Emitter.Stop(self: Emitter)
	self._enabled = false
end

function Emitter.IsEnabled(self: Emitter)
	return self._enabled
end

function Emitter.Destroy(self: Emitter)
	self._updateConnection:Disconnect()

	for _, particle in self._particles do
		if particle._instance then
			particle._instance:Destroy()
		end
	end
end

return Emitter
