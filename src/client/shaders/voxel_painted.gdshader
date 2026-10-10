shader_type spatial;
// The boats (BoatsView): the voxel models' shader with their paint (PAINTED:
// the instance uniforms paint_color and stripe_color, set per hull). Kept
// apart from voxel.gdshader: instance uniforms take room in a buffer of the
// renderer's for every instance drawn with the shader, and the props seen
// in first person are many (the buffer ran out).

render_mode world_vertex_coords;

#define PAINTED
#include "res://src/client/shaders/voxel.gdshaderinc"
