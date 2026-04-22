local AssetService = game:GetService("AssetService")

local Utility = require(script.Parent:WaitForChild("Utility"))

local Internal = {}

function Internal.CreateDisplay(
	Parent: GuiObject,
	CanvasName: string,
	CanvasColour: Color3,
	Blur: boolean?,
	Resolution: Vector2
): (Frame, ImageLabel)
	local Holder = Instance.new("Frame")
	Holder.Name = CanvasName
	Holder.BackgroundColor3 = CanvasColour
	Holder.BackgroundTransparency = 0
	Holder.BorderSizePixel = 0
	Holder.ClipsDescendants = true
	Holder.Size = UDim2.fromOffset(Resolution.X, Resolution.Y)
	Holder.Parent = Parent

	local ImageLabel = Instance.new("ImageLabel")
	ImageLabel.Name = "Display"
	ImageLabel.BackgroundTransparency = 1
	ImageLabel.BorderSizePixel = 0
	ImageLabel.Size = UDim2.fromScale(1, 1)
	ImageLabel.ResampleMode = if Blur then Enum.ResamplerMode.Default else Enum.ResamplerMode.Pixelated
	ImageLabel.Parent = Holder

	return Holder, ImageLabel
end

function Internal.CreateEditableImage(Resolution: Vector2): EditableImage?
	local Success, EditableImage = pcall(function()
		return AssetService:CreateEditableImage({
			Size = Resolution,
		})
	end)

	if Success then
		return EditableImage
	end

	warn("[RoffinityCanvas] EditableImage creation failed. Buffer API will still work, but rendering may be unavailable.")
	return nil
end

function Internal.AttachEditableImage(ImageLabel: ImageLabel, EditableImage: EditableImage?)
	if not EditableImage then
		return
	end

	pcall(function()
		ImageLabel.ImageContent = Content.fromObject(EditableImage)
	end)
end

function Internal.CreateBuffer(Width: number, Height: number, Color: Color3, Alpha: number): buffer
	local PixelBuffer = buffer.create(Width * Height * 4)
	local R, G, B, A = Utility.ColorToBytes(Color, Alpha)

	for Offset = 0, buffer.len(PixelBuffer) - 4, 4 do
		buffer.writeu8(PixelBuffer, Offset, R)
		buffer.writeu8(PixelBuffer, Offset + 1, G)
		buffer.writeu8(PixelBuffer, Offset + 2, B)
		buffer.writeu8(PixelBuffer, Offset + 3, A)
	end

	return PixelBuffer
end

function Internal.WriteRGBA(Canvas, X: number, Y: number, R: number, G: number, B: number, A: number)
	X = math.ceil(X)
	Y = math.ceil(Y)

	if not Utility.InBounds(X, Y, Canvas.CurrentResX, Canvas.CurrentResY) then
		return
	end

	local Offset = Utility.XYToIndex(X, Y, Canvas.CurrentResX)
	buffer.writeu8(Canvas.Buffer, Offset, Utility.ClampInteger(R * 255, 0, 255))
	buffer.writeu8(Canvas.Buffer, Offset + 1, Utility.ClampInteger(G * 255, 0, 255))
	buffer.writeu8(Canvas.Buffer, Offset + 2, Utility.ClampInteger(B * 255, 0, 255))
	buffer.writeu8(Canvas.Buffer, Offset + 3, Utility.ClampInteger((A or 1) * 255, 0, 255))
	Canvas.NeedsRender = true
end

function Internal.ReadRGBA(Canvas, X: number, Y: number): (number, number, number, number)
	X = math.ceil(X)
	Y = math.ceil(Y)

	if not Utility.InBounds(X, Y, Canvas.CurrentResX, Canvas.CurrentResY) then
		return 0, 0, 0, 0
	end

	local Offset = Utility.XYToIndex(X, Y, Canvas.CurrentResX)
	return buffer.readu8(Canvas.Buffer, Offset) / 255,
		buffer.readu8(Canvas.Buffer, Offset + 1) / 255,
		buffer.readu8(Canvas.Buffer, Offset + 2) / 255,
		buffer.readu8(Canvas.Buffer, Offset + 3) / 255
end

function Internal.Render(Canvas)
	if not Canvas.EditableImage then
		Canvas.NeedsRender = false
		return
	end

	local Success = pcall(function()
		Canvas.EditableImage:WritePixelsBuffer(Vector2.zero, Canvas.Resolution, Canvas.Buffer)
	end)

	if not Success and Canvas.OutputWarnings then
		warn("[RoffinityCanvas] Render failed. Check EditableImage permissions and API availability.")
	end

	Canvas.NeedsRender = false
end

function Internal.Resize(Canvas, NewResolution: Vector2)
	local FrameSize = Utility.ClampFrameSize(NewResolution)
	Canvas.Width = FrameSize.X
	Canvas.Height = FrameSize.Y
	Canvas.FrameSize = FrameSize
	Canvas.Frame.Size = UDim2.fromOffset(FrameSize.X, FrameSize.Y)
end

return Internal
