--[[
	StationSpecs
	Single source of truth for every piece of gym equipment: dimensions that the
	map builder uses to make the machine AND that the animation code uses to put
	hands on bars, feet on pedals, butts on seats.

	Station-local space: origin on the floor at the station's center, +Y up,
	the athlete faces -Z (LookVector) unless noted.

	Slot order = unlock order (RackSlots upgrade gives 4, 6, 8, 10, 12 slots).
]]

local StationSpecs = {}

StationSpecs.SLOT_EXERCISES = {
	"Treadmill", -- 1
	"BenchPress", -- 2
	"DumbbellCurl", -- 3
	"Bike", -- 4
	"LatPulldown", -- 5
	"Squat", -- 6
	"CableRow", -- 7
	"LegExtension", -- 8
	"Treadmill", -- 9
	"Deadlift", -- 10
	"ShoulderPress", -- 11
	"PullUp", -- 12
}

StationSpecs.DISPLAY_NAMES = {
	Treadmill = "Treadmill",
	BenchPress = "Bench Press",
	DumbbellCurl = "Dumbbell Curls",
	Bike = "Spin Bike",
	LatPulldown = "Lat Pulldown",
	Squat = "Squat Rack",
	CableRow = "Seated Cable Row",
	LegExtension = "Leg Extension",
	Deadlift = "Deadlift Platform",
	ShoulderPress = "Shoulder Press",
	PullUp = "Chin / Dip Assist",
}

-- Olympic barbell (shared by bench, squat, deadlift)
StationSpecs.BARBELL = {
	Length = 7.2,
	ShaftDiameter = 0.12,
	SleeveStart = 2.35, -- |x| where the loading sleeve begins
	SleeveDiameter = 0.2,
	PlateDiameter = 1.5,
	PlateThickness = 0.16,
	Plates = 2, -- plates per side
}

StationSpecs.Treadmill = {
	DeckLength = 6.4,
	DeckWidth = 2.8,
	BeltTop = 0.56,
	BeltLength = 5.8,
	BeltWidth = 2.1,
	BeltSpeed = 6.5, -- studs / second
	Slats = 12,
	PelvisZ = 0.35,
	Cadence = 1.4, -- strides per second (one stride = left + right step)
	Footprint = Vector3.new(3.2, 0, 7.2),
}

StationSpecs.Bike = {
	SaddleTop = 3.15,
	SaddleZ = 0.95,
	CrankCenter = Vector3.new(0, 1.15, 0.05),
	CrankRadius = 0.55,
	PedalX = 0.6,
	HandlebarPos = Vector3.new(0, 3.62, -1.35),
	HandlebarGripX = 0.72,
	FlywheelCenter = Vector3.new(0, 1.2, -1.05),
	FlywheelDiameter = 1.6,
	Cadence = 1.25, -- crank revolutions per second
	Footprint = Vector3.new(2.4, 0, 4.2),
}

StationSpecs.BenchPress = {
	PadTop = 1.4,
	PadZ0 = -1.6, -- foot end of the pad
	PadZ1 = 2.6, -- head end of the pad
	PadWidth = 1.05,
	PelvisZ = 0.0,
	UprightX = 2.15,
	HookY = 3.62, -- bar center when racked
	HookZ = 1.95,
	FootZ = -1.55,
	FootX = 1.35,
	Footprint = Vector3.new(7.6, 0, 5.8),
}

StationSpecs.DumbbellCurl = {
	HandleLength = 0.55,
	HeadDiameter = 0.6,
	HeadLength = 0.34,
	FootX = 0.72,
	Footprint = Vector3.new(3, 0, 3),
}

StationSpecs.LatPulldown = {
	SeatTop = 1.55,
	SeatZ = 0.45,
	KneePadY = 2.55,
	KneePadZ = -0.45,
	PulleyTop = Vector3.new(0, 7.6, -0.25),
	BarRestY = 6.2,
	BarZ = -0.25,
	BarLength = 4.4,
	GripX = 1.85,
	StackPos = Vector3.new(0, 0.35, -2.45), -- bottom of the weight stack
	StackPlates = 14,
	PlateHeight = 0.2,
	FootZ = -1.05,
	Footprint = Vector3.new(4.8, 0, 5.4),
}

StationSpecs.Squat = {
	PostX = 2.15,
	FrontPostZ = 0.95,
	BackPostZ = 3.35,
	HookY = 4.4, -- bar center when racked
	HookZ = 0.55,
	SafetyY = 2.55,
	FootX = 0.78,
	Height = 8.2,
	Footprint = Vector3.new(7.8, 0, 7),
}

StationSpecs.CableRow = {
	SeatTop = 1.35,
	SeatZ = 0.7,
	PlateZ = -1.95, -- foot plate
	PlateY = 0.95,
	PulleyExit = Vector3.new(0, 1.0, -2.75),
	ColumnZ = -3.25,
	StackPos = Vector3.new(0, 0.35, -3.25),
	StackPlates = 14,
	PlateHeight = 0.2,
	HandleRest = Vector3.new(0, 1.05, -2.2),
	Footprint = Vector3.new(3.2, 0, 7.4),
}

StationSpecs.LegExtension = {
	SeatTop = 1.72,
	PivotY = 1.95,
	PivotZ = -0.95,
	SeatZ = 0.15,
	HandleX = 1.15,
	StackPos = Vector3.new(0, 0.35, 2.35),
	StackPlates = 12,
	PlateHeight = 0.2,
	Footprint = Vector3.new(3.4, 0, 5.4),
}

StationSpecs.Deadlift = {
	PlatformSize = Vector3.new(8, 0.15, 7),
	BarZ = -0.15,
	GripX = 1.22,
	FootX = 0.62,
	Footprint = Vector3.new(8, 0, 7),
}

StationSpecs.ShoulderPress = {
	SeatTop = 1.55,
	SeatZ = 0.2,
	BackZ = 0.9,
	FootX = 1.25,
	FootZ = -1.25,
	Footprint = Vector3.new(3, 0, 3.6),
}

StationSpecs.PullUp = {
	HandleY = 8.7,
	HandleX = 1.55,
	HandleZ = -0.75,
	DipY = 5.2,
	StepY = 1.25,
	StepZ = 0.65,
	KneePadZ = 0.2,
	PadRestTop = 4.8, -- assist pad parks at the top (counterweighted)
	RestZ = -2.0, -- where the athlete stands between sets
	StackPos = Vector3.new(0, 0.35, 1.75),
	StackPlates = 12,
	PlateHeight = 0.2,
	Footprint = Vector3.new(4.4, 0, 4.2),
}

return StationSpecs
