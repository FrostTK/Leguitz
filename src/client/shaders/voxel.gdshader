shader_type spatial;
// Voxel models (trees, plants, rocks, the player). Vertex data comes from
// VoxelMesher: COLOR.rgb sRGB color, COLOR.a ambient occlusion,
// UV.x wind bending weight, UV.y 1 for foliage, 2 for glowing voxels (fire:
// they light themselves). Instances may carry
// INSTANCE_CUSTOM = (tint r, g, b, sky light level + wind phase): props
// (ChunkMesher) carry the sky light they stand in (0..15, the integer
// part, + 16 if deciduous, + 32 where winters bite: the seasons; see
// sky_light.gdshaderinc), bodies are given theirs (sky_light).

render_mode world_vertex_coords;

#include "res://src/client/shaders/voxel.gdshaderinc"
