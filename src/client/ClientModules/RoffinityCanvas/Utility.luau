local GuiService = game:GetService("GuiService")

local Utility = {}

Utility.MAX_SIZE = 1024
Utility.INTERNAL_RESOLUTION = Vector2.new(Utility.MAX_SIZE, Utility.MAX_SIZE)
Utility.DEFAULT_FRAME_SIZE = Vector2.new(256, 256)
Utility.DEFAULT_COLOR = Color3.new(1, 1, 1)
Utility.DEFAULT_ALPHA = 1
Utility.MAX_FRAME_SIZE = 4096

function Utility.ClampInteger(Value: number, Minimum: number, Maximum: number): number
	return math.clamp(math.floor(Value + 0.5), Minimum, Maximum)
end

function Utility.ClampUnit(Value: number?): number
	return math.clamp(Value or 0, 0, 1)
end

function Utility.IsValidParent(Parent: Instance): boolean
	return Parent:IsA("GuiObject")
end

function Utility.ClampResolution(Resolution: Vector2): Vector2
	return Vector2.new(
		Utility.ClampInteger(Resolution.X, 1, Utility.MAX_SIZE),
		Utility.ClampInteger(Resolution.Y, 1, Utility.MAX_SIZE)
	)
end

function Utility.ClampFrameSize(FrameSize: Vector2): Vector2
	return Vector2.new(
		Utility.ClampInteger(FrameSize.X, 1, Utility.MAX_FRAME_SIZE),
		Utility.ClampInteger(FrameSize.Y, 1, Utility.MAX_FRAME_SIZE)
	)
end

function Utility.PointToXY(Point: Vector2): (number, number)
	return math.ceil(Point.X), math.ceil(Point.Y)
end

function Utility.XYToIndex(X: number, Y: number, Width: number): number
	return ((Y - 1) * Width + (X - 1)) * 4
end

function Utility.InBounds(X: number, Y: number, Width: number, Height: number): boolean
	return X >= 1 and Y >= 1 and X <= Width and Y <= Height
end

function Utility.ColorToBytes(Color: Color3, Alpha: number?): (number, number, number, number)
	return Utility.ClampInteger(Color.R * 255, 0, 255),
		Utility.ClampInteger(Color.G * 255, 0, 255),
		Utility.ClampInteger(Color.B * 255, 0, 255),
		Utility.ClampInteger(Utility.ClampUnit(Alpha or 1) * 255, 0, 255)
end

function Utility.BytesToColor(R: number, G: number, B: number): Color3
	return Color3.fromRGB(R, G, B)
end

function Utility.GetColourU32(R: number, G: number, B: number, A: number?): number
	local ByteR = Utility.ClampInteger(Utility.ClampUnit(R) * 255, 0, 255)
	local ByteG = Utility.ClampInteger(Utility.ClampUnit(G) * 255, 0, 255)
	local ByteB = Utility.ClampInteger(Utility.ClampUnit(B) * 255, 0, 255)
	local ByteA = Utility.ClampInteger(Utility.ClampUnit(A or 1) * 255, 0, 255)

	return bit32.bor(bit32.lshift(ByteR, 24), bit32.lshift(ByteG, 16), bit32.lshift(ByteB, 8), ByteA)
end

function Utility.GetRGBAFromColourU32(ColourU32: number): (number, number, number, number)
	local R = bit32.rshift(bit32.band(ColourU32, 0xFF000000), 24) / 255
	local G = bit32.rshift(bit32.band(ColourU32, 0x00FF0000), 16) / 255
	local B = bit32.rshift(bit32.band(ColourU32, 0x0000FF00), 8) / 255
	local A = bit32.band(ColourU32, 0x000000FF) / 255
	return R, G, B, A
end

function Utility.ViewportToCanvasPoint(Canvas, ScreenPosition: Vector2): Vector2
	local GuiInset = GuiService:GetGuiInset()
	local CanvasPosition = Canvas.Frame.AbsolutePosition
	local CanvasSize = Canvas.Frame.AbsoluteSize
	local Relative = ScreenPosition - GuiInset - CanvasPosition
	local Normalized = Vector2.new(
		if CanvasSize.X > 0 then Relative.X / CanvasSize.X else 0,
		if CanvasSize.Y > 0 then Relative.Y / CanvasSize.Y else 0
	)

	return Vector2.new(
		math.ceil(Normalized.X * Canvas.CurrentResX),
		math.ceil(Normalized.Y * Canvas.CurrentResY)
	)
end

return Utility
