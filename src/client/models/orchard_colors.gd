class_name OrchardColors
extends RefCounted
## The colors of the fruit trees (TreeModels._fruit_tree, SaplingModels,
## BlockColors): their bark, leaves, blossom and fruit.

const APPLE_LEAVES := ["#1f4a22", "#2e6230", "#3f7c3a", "#5a9a48", "#86c060"]
const CHERRY_LEAVES := ["#24502a", "#336a34", "#468440", "#64a052", "#8cc068"]
const ORANGE_LEAVES := ["#123e1e", "#1c5428", "#286a32", "#3a843e", "#5aa250"]
const APPLE_BARK := ["#3a2618", "#5a3a24", "#7a5232", "#94683f"]
const CHERRY_BARK := ["#3a1e1a", "#5a2e28", "#7a4038", "#94564a"]
const ORANGE_BARK := ["#4a3a2a", "#655040", "#806850", "#9a8062"]
const PEACH_LEAVES := ["#244e22", "#34682e", "#4a843a", "#66a04a", "#8cc066"]
const PEACH_BARK := ["#3e2c24", "#5a4034", "#765646", "#8e6c58"]
## Each fruit tree (in blossom; Growth.FRUITING): [bark, leaves, blossom
## (dark to light), fruit (dark to light)].
const TREES := {
	Tiles.Block.APPLE_TREE:
	[
		APPLE_BARK,
		APPLE_LEAVES,
		["#f2c2d4", "#f6e6ee", "#ffffff"],
		["#8e1218", "#c8282a", "#ec5a3a"],
	],
	Tiles.Block.CHERRY_TREE:
	[
		CHERRY_BARK,
		CHERRY_LEAVES,
		["#e88ab0", "#f4aecb", "#ffd6e6"],
		["#4a0810", "#7a1220", "#a8202c"],
	],
	Tiles.Block.ORANGE_TREE:
	[
		ORANGE_BARK,
		ORANGE_LEAVES,
		["#f2ead2", "#fff6dc", "#ffffff"],
		["#c8541a", "#ec7f22", "#ffab45"],
	],
	Tiles.Block.PEACH_TREE:
	[
		PEACH_BARK,
		PEACH_LEAVES,
		["#c83c70", "#e46e9a", "#f6a2c2"],
		["#d0443a", "#f8b070", "#ffe0a8"],
	],
}
## How many of a crown's outer leaves hold a blossom, and a fruit.
const BLOSSOMS := {
	Tiles.Block.APPLE_TREE: 0.16,
	Tiles.Block.CHERRY_TREE: 0.45,
	Tiles.Block.ORANGE_TREE: 0.1,
	Tiles.Block.PEACH_TREE: 0.3,
}
const FRUITS := {
	Tiles.Block.APPLE_TREE: 0.05,
	Tiles.Block.CHERRY_TREE: 0.1,
	Tiles.Block.ORANGE_TREE: 0.05,
	Tiles.Block.PEACH_TREE: 0.05,
}
