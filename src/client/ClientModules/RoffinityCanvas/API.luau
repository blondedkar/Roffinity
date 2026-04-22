local Internal = require(script.Parent:WaitForChild("Internal"))
local Parallel = require(script.Parent:WaitForChild("Parallel"))
local Utility = require(script.Parent:WaitForChild("Utility"))

local API = {}

function API.SetBuffer(Canvas, PixelBuffer: buffer, X: number?, Y: number?, BufferWidth: number?, BufferHeight: number?)
	local StartX = X or 1
	local StartY = Y or 1
	local Width = BufferWidth or Canvas.CurrentResX
	local Height = BufferHeight or Canvas.CurrentResY

	for BufferY = 1, Height do
		for BufferX = 1, Width do
			local SourceOffset = Utility.XYToIndex(BufferX, BufferY, Width)
			local TargetX = StartX + BufferX - 1
			local TargetY = StartY + BufferY - 1

			if Utility.InBounds(TargetX, TargetY, Canvas.CurrentResX, Canvas.CurrentResY) then
				Internal.WriteRGBA(
					Canvas,
					TargetX,
					TargetY,
					buffer.readu8(PixelBuffer, SourceOffset) / 255,
					buffer.readu8(PixelBuffer, SourceOffset + 1) / 255,
					buffer.readu8(PixelBuffer, SourceOffset + 2) / 255,
					buffer.readu8(PixelBuffer, SourceOffset + 3) / 255
				)
			end
		end
	end
end

function API.GetBuffer(Canvas, X: number?, Y: number?, BufferWidth: number?, BufferHeight: number?): buffer
	local StartX = X or 1
	local StartY = Y or 1
	local Width = BufferWidth or Canvas.CurrentResX
	local Height = BufferHeight or Canvas.CurrentResY
	local PixelBuffer = buffer.create(Width * Height * 4)

	for BufferY = 1, Height do
		for BufferX = 1, Width do
			local SourceX = StartX + BufferX - 1
			local SourceY = StartY + BufferY - 1
			local TargetOffset = Utility.XYToIndex(BufferX, BufferY, Width)
			local R, G, B, A = Internal.ReadRGBA(Canvas, SourceX, SourceY)

			buffer.writeu8(PixelBuffer, TargetOffset, Utility.ClampInteger(R * 255, 0, 255))
			buffer.writeu8(PixelBuffer, TargetOffset + 1, Utility.ClampInteger(G * 255, 0, 255))
			buffer.writeu8(PixelBuffer, TargetOffset + 2, Utility.ClampInteger(B * 255, 0, 255))
			buffer.writeu8(PixelBuffer, TargetOffset + 3, Utility.ClampInteger(A * 255, 0, 255))
		end
	end

	return PixelBuffer
end

function API.SetRGB(Canvas, X: number, Y: number, R: number, G: number, B: number)
	local _, _, _, A = Internal.ReadRGBA(Canvas, X, Y)
	Internal.WriteRGBA(Canvas, X, Y, R, G, B, A)
end

function API.SetRGBA(Canvas, X: number, Y: number, R: number, G: number, B: number, A: number?)
	Internal.WriteRGBA(Canvas, X, Y, R, G, B, A or 1)
end

function API.SetPixel(Canvas, XOrPoint, YOrColour, Colour: Color3?, Alpha: number?)
	if typeof(XOrPoint) == "Vector2" then
		local X, Y = Utility.PointToXY(XOrPoint)
		local PixelColour = YOrColour :: Color3
		Internal.WriteRGBA(Canvas, X, Y, PixelColour.R, PixelColour.G, PixelColour.B, Alpha or 1)
	else
		local X = XOrPoint :: number
		local Y = YOrColour :: number
		local PixelColour = Colour :: Color3
		Internal.WriteRGBA(Canvas, X, Y, PixelColour.R, PixelColour.G, PixelColour.B, Alpha or 1)
	end
end

function API.SetAlpha(Canvas, X: number, Y: number, Alpha: number)
	local R, G, B = Internal.ReadRGBA(Canvas, X, Y)
	Internal.WriteRGBA(Canvas, X, Y, R, G, B, Alpha)
end

function API.SetU32(Canvas, X: number, Y: number, ColourU32: number)
	local R, G, B, A = Utility.GetRGBAFromColourU32(ColourU32)
	Internal.WriteRGBA(Canvas, X, Y, R, G, B, A)
end

function API.GetRGB(Canvas, X: number, Y: number): (number, number, number)
	local R, G, B = Internal.ReadRGBA(Canvas, X, Y)
	return R, G, B
end

function API.GetRGBA(Canvas, X: number, Y: number): (number, number, number, number)
	return Internal.ReadRGBA(Canvas, X, Y)
end

function API.GetAlpha(Canvas, X: number, Y: number): number
	local _, _, _, A = Internal.ReadRGBA(Canvas, X, Y)
	return A
end

function API.GetU32(Canvas, X: number, Y: number): number
	local R, G, B, A = Internal.ReadRGBA(Canvas, X, Y)
	return Utility.GetColourU32(R, G, B, A)
end

function API.GetPixel(Canvas, Point: Vector2): Color3
	local X, Y = Utility.PointToXY(Point)
	local R, G, B = Internal.ReadRGBA(Canvas, X, Y)
	return Color3.new(R, G, B)
end

function API.GetPixelXY(Canvas, X: number, Y: number): Color3
	local R, G, B = Internal.ReadRGBA(Canvas, X, Y)
	return Color3.new(R, G, B)
end

function API.FillRGBA(Canvas, R: number, G: number, B: number, A: number?)
	local Alpha = A or 1
	local Writes = Parallel.RunBestAvailable(function()
		return Parallel.ComputeClear(Canvas.CurrentResX, Canvas.CurrentResY, Color3.new(R, G, B), 1 - Alpha)
	end)

	for _, Write in ipairs(Writes) do
		Internal.WriteRGBA(Canvas, Write.X, Write.Y, Write.Color.R, Write.Color.G, Write.Color.B, 1 - (Write.Transparency or 0))
	end
end

function API.Fill(Canvas, Colour: Color3, Alpha: number?)
	API.FillRGBA(Canvas, Colour.R, Colour.G, Colour.B, Alpha or 1)
end

function API.Clear(Canvas)
	API.Fill(Canvas, Canvas.CanvasColour, Canvas.ClearAlpha)
end

function API.SetClearRGBA(Canvas, R: number, G: number, B: number, A: number)
	Canvas.CanvasColour = Color3.new(R, G, B)
	Canvas.ClearAlpha = A
end

function API.DrawLine(Canvas, PointA: Vector2, PointB: Vector2, Colour: Color3, Thickness: number?, _RoundedCaps: boolean?)
	local TargetAlpha = 1
	local TargetThickness = math.max(math.floor(Thickness or 1), 1)
	local Writes = Parallel.RunBestAvailable(function()
		return Parallel.ComputeLine(PointA.X, PointA.Y, PointB.X, PointB.Y, Colour, 1 - TargetAlpha)
	end)

	for _, Write in ipairs(Writes) do
		local Radius = math.floor(TargetThickness / 2)
		for OffsetY = -Radius, Radius do
			for OffsetX = -Radius, Radius do
				Internal.WriteRGBA(Canvas, Write.X + OffsetX, Write.Y + OffsetY, Write.Color.R, Write.Color.G, Write.Color.B, TargetAlpha)
			end
		end
	end
end

function API.DrawRectangle(Canvas, PointA: Vector2, PointB: Vector2, Colour: Color3, Alpha: number?, Fill: boolean?)
	local MinX = math.min(PointA.X, PointB.X)
	local MinY = math.min(PointA.Y, PointB.Y)
	local MaxX = math.max(PointA.X, PointB.X)
	local MaxY = math.max(PointA.Y, PointB.Y)
	local TargetAlpha = Alpha or 1

	if Fill then
		for Y = MinY, MaxY do
			for X = MinX, MaxX do
				Internal.WriteRGBA(Canvas, X, Y, Colour.R, Colour.G, Colour.B, TargetAlpha)
			end
		end
		return
	end

	API.DrawLine(Canvas, Vector2.new(MinX, MinY), Vector2.new(MaxX, MinY), Colour)
	API.DrawLine(Canvas, Vector2.new(MaxX, MinY), Vector2.new(MaxX, MaxY), Colour)
	API.DrawLine(Canvas, Vector2.new(MaxX, MaxY), Vector2.new(MinX, MaxY), Colour)
	API.DrawLine(Canvas, Vector2.new(MinX, MaxY), Vector2.new(MinX, MinY), Colour)
end

function API.Resize(Canvas, NewResolution, Height: number?)
	if typeof(NewResolution) == "number" then
		NewResolution = Vector2.new(NewResolution, Height or NewResolution)
	end

	Internal.Resize(Canvas, NewResolution)
end

function API.DrawRect(Canvas, X: number, Y: number, Width: number, Height: number, Colour: Color3, Alpha: number?)
	API.DrawRectangle(Canvas, Vector2.new(X, Y), Vector2.new(X + Width - 1, Y + Height - 1), Colour, Alpha, true)
end

function API.Render(Canvas)
	Internal.Render(Canvas)
end

function API.SetBlur(Canvas, Enabled: boolean)
	Canvas.ImageLabel.ResampleMode = if Enabled then Enum.ResamplerMode.Default else Enum.ResamplerMode.Pixelated
end

function API.SetStretchToFit(Canvas, Enabled: boolean)
	local AspectRatio = Canvas.ImageLabel:FindFirstChildOfClass("UIAspectRatioConstraint")
	if Enabled and AspectRatio then
		AspectRatio:Destroy()
	elseif not Enabled and not AspectRatio then
		AspectRatio = Instance.new("UIAspectRatioConstraint")
		AspectRatio.AspectRatio = Canvas.CurrentResX / Canvas.CurrentResY
		AspectRatio.Parent = Canvas.ImageLabel
	end
end

function API.ViewportToCanvasPoint(Canvas, ScreenPosition: Vector2): Vector2
	return Utility.ViewportToCanvasPoint(Canvas, ScreenPosition)
end

function API.GetMousePoint(Canvas): Vector2?
	local MouseLocation = game:GetService("UserInputService"):GetMouseLocation()
	local Point = API.ViewportToCanvasPoint(Canvas, MouseLocation)

	if Utility.InBounds(Point.X, Point.Y, Canvas.CurrentResX, Canvas.CurrentResY) then
		return Point
	end

	return nil
end

function API.MouseIsOnTop(Canvas): boolean
	return API.GetMousePoint(Canvas) ~= nil
end

function API.Destroy(Canvas)
	if Canvas.AutoUpdateConnection then
		Canvas.AutoUpdateConnection:Disconnect()
	end

	if Canvas.EventsFolder then
		Canvas.EventsFolder:Destroy()
	end

	if Canvas.Frame then
		Canvas.Frame:Destroy()
	end

	Canvas.EditableImage = nil
	Canvas.Buffer = nil
end

function API.GetColourU32(_Canvas, R: number, G: number, B: number, A: number?): number
	return Utility.GetColourU32(R, G, B, A)
end

function API.GetRGBAFromColourU32(_Canvas, ColourU32: number): (number, number, number, number)
	return Utility.GetRGBAFromColourU32(ColourU32)
end

return API
