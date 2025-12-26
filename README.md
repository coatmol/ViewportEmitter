# ViewportEmitter

A Luau library for rendering particle effects in Roblox ViewportFrames. ViewportEmitter provides a ParticleEmitter-like API that works within ViewportFrames, enabling particle effects in UI elements.

## Features

- **ParticleEmitter-compatible API** - Familiar properties and methods
- **ViewportFrame support** - Render particles in UI ViewportFrames
- **Multiple particle orientations** - FacingCamera, VelocityParallel, VelocityPerpendicular, etc.
- **property support** - Color sequences, number sequences, spread angles, and more... However, there are alot of missing properties as highlighted in [Limitations](#limitations)
- **Performance optimized** - Efficient particle lifecycle management
- **No external dependencies** - Doesn't require any external libraries or modules

## Limitations

- **Missing properties** - Some properties are not supported due to limitations in the underlying ParticleEmitter implementation. These properties are highlighted in the [API Reference](#api-reference).
- **Performance** - Performance is optimized for rendering particles in ViewportFrames, but may not be optimal for other use cases.
- **No external dependencies** - The library does not require any external dependencies or modules.

## Installation

### Wally

Add ViewportEmitter to your `wally.toml`:

```toml
[dependencies]
ViewportEmitter = "coatmol/viewportemitter@1.0.0"
```

Then run:

```bash
wally install
```

### Manual Installation

Copy the `init.luau` file into your project and require it where needed.

## Quick Start

```lua
local ViewportEmitter = require(path.to.ViewportEmitter)

-- Create a new emitter
local emitter = ViewportEmitter.new(parentPart, camera)

-- Configure properties (similar to ParticleEmitter)
emitter.Rate = 50
emitter.Lifetime = NumberRange.new(1, 2)
emitter.Speed = NumberRange.new(10, 20)
emitter.Color = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(1, 1, 0))
emitter.Texture = "rbxasset://textures/particles/fire_main.dds"

-- Start emitting particles
emitter:Start()

-- Stop when done
emitter:Stop()
emitter:Destroy()
```

## API Reference

### Constructor

#### `ViewportEmitter.new(parent: Part, camera: Camera): Emitter`

Creates a new ViewportEmitter instance.

- `parent` - The Part that will contain the particle instances
- `camera` - The Camera used for particle orientation calculations

#### `ViewportEmitter.fromParticleEmitter(particle: ParticleEmitter, parent: Part, camera: Camera): Emitter`

Creates a ViewportEmitter by copying properties from an existing ParticleEmitter.

### Properties

ViewportEmitter supports most ParticleEmitter properties:

| Property            | Type                     | Description                                     |
| ------------------- | ------------------------ | ----------------------------------------------- |
| `Acceleration`      | Vector3                  | Constant acceleration applied to particles      |
| `Brightness`        | number                   | Brightness multiplier for particles             |
| `Color`             | ColorSequence            | Color animation over particle lifetime          |
| `Drag`              | number                   | Air resistance applied to particles             |
| `EmissionDirection` | Enum.NormalId            | Direction particles are emitted                 |
| `Lifetime`          | NumberRange              | How long particles live (seconds)               |
| `Orientation`       | Enum.ParticleOrientation | How particles face the camera                   |
| `Rate`              | number                   | Particles emitted per second                    |
| `Rotation`          | NumberRange              | Initial rotation of particles (degrees)         |
| `RotSpeed`          | NumberRange              | Rotation speed (degrees/second)                 |
| `Size`              | NumberSequence           | Size animation over particle lifetime           |
| `Speed`             | NumberRange              | Initial speed of particles                      |
| `SpreadAngle`       | Vector2                  | Emission cone angles (X=horizontal, Y=vertical) |
| `Squash`            | NumberSequence           | Particle squashing effect                       |
| `Texture`           | string                   | Particle texture ID                             |
| `TimeScale`         | number                   | Time multiplier for particle simulation         |
| `Transparency`      | NumberSequence           | Transparency animation over lifetime            |
| `WindAffectsDrag`   | boolean                  | Whether GlobalWind affects particles            |

### Methods

#### `emitter:Start()`

Begins particle emission and updates.

#### `emitter:Stop()`

Stops particle emission (existing particles continue to update).

#### `emitter:Emit(amount: number)`

Immediately emits the specified number of particles.

#### `emitter:IsEnabled(): boolean`

Returns whether the emitter is currently emitting particles.

#### `emitter:Destroy()`

Stops the emitter and cleans up all particles and connections.

## Limitations

Some ParticleEmitter features are not yet implemented:

- Flipbook animations
- Shape-based emission
- LockedToPart behavior
- VelocityInheritance

These features are marked as "NOT IMPLEMENTED" in the code and may be added in future versions.
Please contribute to this project and help me add these features if you're interested.

## License

MIT License - see the license file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
