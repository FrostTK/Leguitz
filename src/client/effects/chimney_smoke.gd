class_name ChimneySmoke
extends Node3D
## The smoke of the chimneys a fire burns under (ChunkMesher.Result.smokes,
## gathered by WorldView3D near the player): puffs rising from their pots,
## swelling, drifting and thinning away, lit like the world (dark at
## night). In world space, outside the world root's stretch: placed from
## local units through the parent's transform every frame.

## How often a chimney puffs (seconds), how long a puff lasts, how fast it
## rises (local units a second) and drifts.
const PUFF_EVERY := 0.55
const PUFF_SECONDS := 4.5
const RISE := 0.5
const DRIFT := Vector3(0.16, 0.0, 0.07)
## At most so many puffs at once.
const MOST := 200
const COLOR := Color("8a8682")

var _puffs: Array[Array] = []
var _mesh := BoxMesh.new()
var _clock := 0.0


func _ready() -> void:
	_mesh.size = Vector3.ONE * 0.22
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.roughness = 1.0
	_mesh.material = material


## Puffs from `spots` (local units), and the puffs out move on.
func update(delta: float, spots: Array[Vector3]) -> void:
	_clock += delta
	for spot in spots:
		var phase := fposmod(spot.x * 0.37 + spot.z * 0.61, PUFF_EVERY)
		if fposmod(_clock + phase, PUFF_EVERY) < delta and _puffs.size() < MOST:
			_puff(spot)
	var root := get_parent() as Node3D
	for i in range(_puffs.size() - 1, -1, -1):
		var puff: Array = _puffs[i]
		var node := puff[0] as MeshInstance3D
		puff[1] += delta
		var t: float = puff[1] / PUFF_SECONDS
		if t >= 1.0:
			node.queue_free()
			_puffs.remove_at(i)
			continue
		# Slower as it rises, carried further by the wind.
		puff[2] += (Vector3(0.0, RISE * (1.0 - t * 0.6), 0.0) + DRIFT * (0.5 + t)) * delta
		node.global_position = root.global_transform * (puff[2] as Vector3)
		node.scale = Vector3.ONE * (0.7 + 2.2 * t) * (1.0 - t * t)


func _puff(at: Vector3) -> void:
	var puff := MeshInstance3D.new()
	puff.mesh = _mesh
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.top_level = true
	add_child(puff)
	var jitter := Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.06, 0.06))
	_puffs.append([puff, 0.0, at + jitter])
