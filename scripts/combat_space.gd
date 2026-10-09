extends RefCounted
class_name CombatSpace

# Single shared definition of the combat playfield.
#
# Force War is a vertical shmup presented in 3D: the playfield is the XZ plane at
# one fixed height. Screen-vertical movement is world Z (forward/back), screen
# horizontal movement is world X. Everything that can shoot or be shot - player,
# boss parts, every bullet - lives on PLANE_Y. The sea, wrecks and platforms live
# far below on UNDERWORLD_Y as scrolling decoration with no interaction.

const PLANE_Y := 2.0

const PLAYER_Z_NEAR := 2.5
const PLAYER_Z_FAR := -9.0
const PLAYER_X_LIMIT := 7.2

const BOSS_Z := -38.0
const BOSS_MODEL_SCALE := 1.62
const BOSS_PITCH_DEGREES := 20.0
# Past this z an air enemy that survived the pass pulls up and out of frame.
const BREAKOFF_Z := -1.5

const UNDERWORLD_Y := -13.5
const UNDERWORLD_DECOR_Y := -13.0

const CAMERA_OFFSET := Vector3(0.0, 11.0, 12.0)
const CAMERA_LOOK := Vector3(0.0, 1.4, -16.0)
const CAMERA_FOV := 64.0


static func clamp_player(x: float, z: float) -> Vector2:
	return Vector2(
		clamp(x, -PLAYER_X_LIMIT, PLAYER_X_LIMIT),
		clamp(z, PLAYER_Z_FAR, PLAYER_Z_NEAR)
	)
