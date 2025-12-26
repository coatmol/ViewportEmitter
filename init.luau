--!strict
local RunService = game:GetService("RunService")

local Emitter = {}
Emitter.__index = Emitter

local EmissionDirections: { [Enum.NormalId]: Vector3 } = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
}

type Particle = {
	_instance: Part,
	_decal: Decal,
	_velocity: Vector3,
	_rotSpeed: number,
	_prevRot: number,
	_life: number,
	_age: number,
}

export type Emitter = {
	Acceleration: Vector3,
	Brightness: number,
	Color: ColorSequence,
	Drag: number,
	EmissionDirection: Enum.NormalId,
	FlipbookFramerate: NumberRange, -- NOT IMPLEMENTED
	FlipbookIncompatible: string, -- NOT IMPLEMENTED
	FlipbookLayout: Enum.ParticleFlipbookLayout, -- NOT IMPLEMENTED
	FlipbookMode: Enum.ParticleFlipbookMode, -- NOT IMPLEMENTED
	FlipbookSizeX: number, -- NOT IMPLEMENTED
	FlipbookSizeY: number, -- NOT IMPLEMENTED
	FlipbookStartRandom: boolean, -- NOT IMPLEMENTED
	Lifetime: NumberRange,
	LockedToPart: boolean, -- NOT IMPLEMENTED
	Orientation: Enum.ParticleOrientation,
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
	Squash: NumberSequence, -- BASIC IMPLEMENTATION
	Texture: string,
	TimeScale: number,
	Transparency: NumberSequence,
	VelocityInheritance: number, -- NOT IMPLEMENTED
	WindAffectsDrag: boolean,

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

local function rotateVectorTo(v: Vector3, dir: Vector3): Vector3
	-- v: vector in local space (+Y = forward)
	-- dir: desired forward direction (emissionDir)
	if dir.Magnitude == 0 then
		return v
	end

	dir = dir.Unit
	local rotationAxis = Vector3.new(0, 1, 0):Cross(dir)
	local dot = Vector3.new(0, 1, 0):Dot(dir)

	-- If forward is already aligned, no rotation needed
	if rotationAxis.Magnitude < 0.0001 then
		return v * dot
	end

	rotationAxis = rotationAxis.Unit
	local angle = math.acos(dot)

	-- Rodrigues' rotation formula
	return v * math.cos(angle)
		+ rotationAxis:Cross(v) * math.sin(angle)
		+ rotationAxis * rotationAxis:Dot(v) * (1 - math.cos(angle))
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
	self.WindAffectsDrag = false

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
	self.WindAffectsDrag = particle.WindAffectsDrag

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
		local squash = sampleNumberSequence(self.Squash, 0)
		part.Size = Vector3.new(1 + squash, 1 - squash, 1 + squash) * sampleNumberSequence(self.Transparency, 0)
		part.Parent = self._parent

		local decal = Instance.new("Decal")
		decal.Texture = self.Texture
		decal.Color3 = sampleColorSequence(self.Color, 0)
		decal.Transparency = sampleNumberSequence(self.Transparency, 0)
		decal.Face = Enum.NormalId.Front
		decal.Parent = part

		local rot = math.random() * (self.Rotation.Max - self.Rotation.Min) + self.Rotation.Min
		part.Rotation = Vector3.new(0, rot, 0)

		local emissionDir = EmissionDirections[self.EmissionDirection].Unit

		local theta = math.rad((math.random() - 0.5) * self.SpreadAngle.X) -- horizontal
		local phi = math.rad((math.random() - 0.5) * self.SpreadAngle.Y) -- vertical

		local localDir = Vector3.new(math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta))

		local dir = rotateVectorTo(localDir, emissionDir).Unit

		-- Speed, lifetime, rotation speed
		local speed = math.random() * (self.Speed.Max - self.Speed.Min) + self.Speed.Min
		local life = math.random() * (self.Lifetime.Max - self.Lifetime.Min) + self.Lifetime.Min
		local rotSpeed = math.random() * (self.RotSpeed.Max - self.RotSpeed.Min) + self.RotSpeed.Min

		table.insert(self._particles, {
			_instance = part,
			_decal = decal,
			_velocity = dir * speed,
			_rotSpeed = rotSpeed,
			_prevRot = rot,
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
			local alpha = particle._age / particle._life
			particle._velocity *= 1 - self.Drag * dt

			if self.WindAffectsDrag then
				particle._velocity += workspace.GlobalWind * dt
			end

			particle._instance.Position += particle._velocity * self.TimeScale * dt

			local squash = sampleNumberSequence(self.Squash, alpha)
			particle._instance.Size = Vector3.new(1 + squash, 1 - squash, 1 + squash)
				* sampleNumberSequence(self.Size, particle._age / particle._life)

			particle._prevRot += particle._rotSpeed * self.TimeScale * dt
			local lookCFrame = CFrame.lookAt(particle._instance.Position, self._camera.CFrame.Position)
			if self.Orientation == Enum.ParticleOrientation.FacingCamera then
				local rotation = CFrame.Angles(0, 0, particle._prevRot)
				particle._instance.CFrame = lookCFrame * rotation
			elseif self.Orientation == Enum.ParticleOrientation.FacingCameraWorldUp then
				-- Faces camera, world-up alignment
				lookCFrame = CFrame.lookAt(
					particle._instance.Position,
					self._camera.CFrame.Position,
					Vector3.new(0, 1, 0) -- world up
				)
				particle._instance.CFrame = lookCFrame * CFrame.Angles(0, 0, particle._prevRot)
			elseif self.Orientation == Enum.ParticleOrientation.VelocityParallel then
				if particle._velocity.Magnitude > 0 then
					local forward = particle._velocity.Unit
					local up = Vector3.new(0, 1, 0)
					if math.abs(forward:Dot(up)) > 0.99 then
						up = Vector3.new(1, 0, 0)
					end
					lookCFrame = CFrame.fromMatrix(particle._instance.Position, forward, up)
					particle._instance.CFrame = lookCFrame * CFrame.Angles(0, 0, particle._prevRot)
				end
			elseif self.Orientation == Enum.ParticleOrientation.VelocityPerpendicular then
				if particle._velocity.Magnitude > 0 then
					lookCFrame =
						CFrame.lookAt(particle._instance.Position, particle._instance.Position + particle._velocity)
					particle._instance.CFrame = lookCFrame * CFrame.Angles(0, 0, particle._prevRot)
				end
			end

			particle._decal.Transparency = sampleNumberSequence(self.Transparency, alpha)
			particle._decal.Color3 = sampleColorSequence(self.Color, alpha)
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
