shader_type spatial;
// What is in hand in first person and the arm (HeldView): the voxel
// models' shader, drawn with a field of view of its own and in front of the
// world (view_model.gdshaderinc). Only this one writes POSITION: a shader
// writing it must write it for every vertex.

render_mode world_vertex_coords;

#define VIEW_MODEL
#include "res://src/client/shaders/voxel.gdshaderinc"
