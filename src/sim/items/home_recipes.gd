class_name HomeRecipes
extends RefCounted
## The house's furniture recipes (Recipes.all takes them after its SHAPED):
## the bedroom's and the living room's (ROOMS; phase 8, step 7), the
## ambiance's (AMBIANCE; step 8: lights, hearths, what hangs on walls,
## cloth and plants, the bathroom, a few more).

const PLANKS := Recipes.PLANKS
const CLOTH := Recipes.CLOTH
const FLOWERS: Array[int] = [
	Items.Id.FLOWER_RED,
	Items.Id.FLOWER_YELLOW,
	Items.Id.FLOWER_BLUE,
	Items.Id.FLOWER_WHITE,
	Items.Id.FLOWER_PINK,
]
## A bed, what stores things, a shelf, seats, tables, a tablecloth.
const ROOMS := [
	{"pattern": ["WWW", "PPP"], "keys": {"W": CLOTH, "P": PLANKS}, "result": [Items.Id.BED, 1]},
	{"pattern": ["C", "C"], "keys": {"C": Items.Id.CHEST}, "result": [Items.Id.WARDROBE, 1]},
	{
		"pattern": ["PGP", "PCP"],
		"keys": {"P": PLANKS, "G": Items.Id.GLASS_PANE, "C": Items.Id.CHEST},
		"result": [Items.Id.DRESSER, 1],
	},
	{
		"pattern": ["PPP", "HHH", "PPP"],
		"keys": {"P": PLANKS, "H": Items.Id.HIDE},
		"result": [Items.Id.BOOKCASE, 1],
	},
	{
		"pattern": ["PPP", "PCP"],
		"keys": {"P": PLANKS, "C": Items.Id.CHEST},
		"result": [Items.Id.COMMODE, 1],
	},
	{
		"pattern": ["PCP"],
		"keys": {"P": PLANKS, "C": Items.Id.CHEST},
		"result": [Items.Id.WALL_CUPBOARD, 1],
	},
	{
		"pattern": ["PSP", "S S", "PSP"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.CRATE, 1],
	},
	{"pattern": ["S S", "SSS"], "keys": {"S": Items.Id.STICK}, "result": [Items.Id.BASKET, 1]},
	{
		"pattern": ["PPP", " S "],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.SHELF, 2],
	},
	{
		"pattern": ["W W", "WWW", "P P"],
		"keys": {"W": CLOTH, "P": PLANKS},
		"result": [Items.Id.ARMCHAIR, 1],
	},
	{
		"pattern": ["WWW", "WWW", "P P"],
		"keys": {"W": CLOTH, "P": PLANKS},
		"result": [Items.Id.SOFA, 1],
	},
	{"pattern": ["PPP", "P P"], "keys": {"P": PLANKS}, "result": [Items.Id.BENCH, 1]},
	{
		"pattern": ["P", "S"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.STOOL, 1],
	},
	{
		"ingredients": [Items.Id.CHAIR, Items.Id.STICK, Items.Id.STICK],
		"result": [Items.Id.ROCKING_CHAIR, 1],
	},
	{
		"pattern": ["SPS"],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.COFFEE_TABLE, 1],
	},
	{
		"pattern": ["PPP", "C S"],
		"keys": {"P": PLANKS, "C": Items.Id.CHEST, "S": Items.Id.STICK},
		"result": [Items.Id.DESK, 1],
	},
	{
		"pattern": ["P", "C"],
		"keys": {"P": PLANKS, "C": Items.Id.CHEST},
		"result": [Items.Id.NIGHTSTAND, 1],
	},
	{
		"pattern": ["PPP", " S ", " P "],
		"keys": {"P": PLANKS, "S": Items.Id.STICK},
		"result": [Items.Id.PEDESTAL_TABLE, 1],
	},
	{"pattern": ["WWW"], "keys": {"W": CLOTH}, "result": [Items.Id.TABLECLOTH, 2]},
]
const AMBIANCE := [
	# Lights: candles (beeswax), a candelabra, a chandelier, a bedside oil
	# lamp, a wall sconce.
	{
		"pattern": ["S", "H"],
		"keys": {"S": Items.Id.STRING, "H": Items.Id.HONEYCOMB},
		"result": [Items.Id.CANDLE, 4],
	},
	{
		"pattern": ["CCC", " U "],
		"keys": {"C": Items.Id.CANDLE, "U": Items.Id.COPPER_INGOT},
		"result": [Items.Id.CANDELABRA, 1],
	},
	{
		"pattern": ["CIC", "III"],
		"keys": {"C": Items.Id.CANDLE, "I": Items.Id.IRON_INGOT},
		"result": [Items.Id.CHANDELIER, 1],
	},
	{
		"pattern": ["W", "O", "U"],
		"keys": {"W": CLOTH, "O": Items.Id.LINSEED_OIL, "U": Items.Id.COPPER_INGOT},
		"result": [Items.Id.BEDSIDE_LAMP, 1],
	},
	{
		"pattern": ["G", "C", "U"],
		"keys": {"G": Items.Id.GLASS, "C": Items.Id.CANDLE, "U": Items.Id.COPPER_INGOT},
		"result": [Items.Id.WALL_SCONCE, 2],
	},
	# A fireplace of bricks on stone, a stove of iron over an oven.
	{
		"pattern": ["BBB", "B B", "SSS"],
		"keys": {"B": Items.Id.BRICKS, "S": Items.Id.STONE_BRICKS},
		"result": [Items.Id.FIREPLACE, 1],
	},
	{
		"pattern": ["III", "IFI"],
		"keys": {"I": Items.Id.IRON_INGOT, "F": Items.Id.FOOD_FURNACE},
		"result": [Items.Id.STOVE, 1],
	},
	# On the walls.
	{
		"pattern": ["SSS", "SWS", "SSS"],
		"keys": {"S": Items.Id.STICK, "W": CLOTH},
		"result": [Items.Id.PAINTING, 1],
	},
	{"ingredients": [Items.Id.PAINTING, Items.Id.COPPER_INGOT], "result": [Items.Id.PORTRAIT, 1]},
	{
		"pattern": ["PGP", " U "],
		"keys": {"P": PLANKS, "G": Items.Id.GLASS, "U": Items.Id.COPPER_INGOT},
		"result": [Items.Id.WALL_CLOCK, 1],
	},
	{
		"pattern": ["PGP", " I "],
		"keys": {"P": PLANKS, "G": Items.Id.GLASS, "I": Items.Id.IRON_INGOT},
		"result": [Items.Id.MIRROR, 1],
	},
	{
		"pattern": ["SSS", "SHS", "SSS"],
		"keys": {"S": Items.Id.STICK, "H": Items.Id.HIDE},
		"result": [Items.Id.FRAMED_MAP, 1],
	},
	{
		"pattern": ["S S", " H ", " P "],
		"keys": {"S": Items.Id.STICK, "H": Items.Id.HIDE, "P": PLANKS},
		"result": [Items.Id.DEER_TROPHY, 1],
	},
	{
		"pattern": ["H H", "HHH", " P "],
		"keys": {"H": Items.Id.HIDE, "P": PLANKS},
		"result": [Items.Id.BEAR_TROPHY, 1],
	},
	{
		"pattern": ["SSS", "WWW", "WWW"],
		"keys": {"S": Items.Id.STICK, "W": CLOTH},
		"result": [Items.Id.TAPESTRY, 1],
	},
	{
		"pattern": ["BBB", "PPP"],
		"keys": {"B": Items.Id.GLASS_BOTTLE, "P": PLANKS},
		"result": [Items.Id.SPICE_RACK, 1],
	},
	{
		"pattern": ["SSS", "PPP"],
		"keys": {"S": Items.Id.STICK, "P": PLANKS},
		"result": [Items.Id.COAT_RACK, 1],
	},
	# Cloth, plants.
	{
		"pattern": ["W", "F", "W"],
		"keys": {"W": CLOTH, "F": Items.Id.FEATHER},
		"result": [Items.Id.CUSHION, 2],
	},
	{"pattern": ["B B", " B "], "keys": {"B": Items.Id.BRICK}, "result": [Items.Id.FLOWER_POT, 1]},
	{
		"pattern": ["FFF", "PDP"],
		"keys": {"F": FLOWERS, "P": PLANKS, "D": Items.Id.DIRT},
		"result": [Items.Id.WINDOW_BOX, 1],
	},
	{
		"ingredients": [Items.Id.FLOWER_POT, Items.Id.FERN, Items.Id.FERN],
		"result": [Items.Id.HOUSEPLANT, 1],
	},
	# The bathroom.
	{
		"pattern": ["Q Q", "QQQ"],
		"keys": {"Q": Items.Id.SMOOTH_STONE},
		"result": [Items.Id.BATHTUB, 1],
	},
	{
		"pattern": ["UU", " U", " U"],
		"keys": {"U": Items.Id.COPPER_INGOT},
		"result": [Items.Id.SHOWER, 1],
	},
	{
		"pattern": ["Q Q", " Q ", " Q "],
		"keys": {"Q": Items.Id.SMOOTH_STONE},
		"result": [Items.Id.WASHBASIN, 1],
	},
	# And more: a grandfather clock, a toy chest, a piano, a cradle, a
	# folding screen.
	{
		"pattern": ["P", "K", "P"],
		"keys": {"P": PLANKS, "K": Items.Id.WALL_CLOCK},
		"result": [Items.Id.GRANDFATHER_CLOCK, 1],
	},
	{
		"ingredients": [Items.Id.CHEST, Items.Id.WOOL, Items.Id.STICK],
		"result": [Items.Id.TOY_CHEST, 1],
	},
	{
		"pattern": ["PPP", "SSS", "PIP"],
		"keys": {"P": PLANKS, "S": Items.Id.STRING, "I": Items.Id.IRON_INGOT},
		"result": [Items.Id.PIANO, 1],
	},
	{
		"pattern": ["PWP", "S S"],
		"keys": {"P": PLANKS, "W": CLOTH, "S": Items.Id.STICK},
		"result": [Items.Id.CRADLE, 1],
	},
	{
		"pattern": ["SWS", "SWS"],
		"keys": {"S": Items.Id.STICK, "W": CLOTH},
		"result": [Items.Id.FOLDING_SCREEN, 1],
	},
]
