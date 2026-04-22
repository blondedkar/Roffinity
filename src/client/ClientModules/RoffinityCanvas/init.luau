local RunService = game:GetService("RunService")

local API = require(script:WaitForChild("API"))
local Internal = require(script:WaitForChild("Internal"))
local Utility = require(script:WaitForChild("Utility"))

local RoffinityCanvas = {}
RoffinityCanvas.__index = RoffinityCanvas

RoffinityCanvas.BlendingModes = {
	Normal = 0,
	Replace = 1,
	AddAlpha = 2,
}

export type Canvas = any
export type Options = any

local function NormalizeConstructorArgs(ParentOrOptions, Resolution: Vector2?, CanvasColour: Color3?, Blur: boolean?)
	if typeof(ParentOrOptions) == "table" and ParentOrOptions.Parent then
		local Options = ParentOrOptions
		local FrameWidth = Options.Width or Options.FrameWidth or (Options.FrameSize and Options.FrameSize.X)
			or (Options.Resolution and Options.Resolution.X)
			or Utility.DEFAULT_FRAME_SIZE.X
		local FrameHeight = Options.Height or Options.FrameHeight or (Options.FrameSize and Options.FrameSize.Y)
			or (Options.Resolution and Options.Resolution.Y)
			or Utility.DEFAULT_FRAME_SIZE.Y

		return {
			Parent = Options.Parent,
			FrameSize = Vector2.new(FrameWidth, FrameHeight),
			Resolution = Utility.INTERNAL_RESOLUTION,
			CanvasColour = Options.CanvasColour or Options.BackgroundColor or CanvasColour,
			Blur = if Options.Blur ~= nil then Options.Blur else Blur,
			Name = Options.Name,
		}
	end

	return {
		Parent = ParentOrOptions,
		FrameSize = Resolution or Utility.DEFAULT_FRAME_SIZE,
		Resolution = Utility.INTERNAL_RESOLUTION,
		CanvasColour = CanvasColour,
		Blur = Blur,
		Name = "RoffinityCanvas",
	}
end

function RoffinityCanvas.GetColourU32(R: number, G: number, B: number, A: number?): number
	return Utility.GetColourU32(R, G, B, A)
end

function RoffinityCanvas.GetRGBAFromColourU32(ColourU32: number): (number, number, number, number)
	return Utility.GetRGBAFromColourU32(ColourU32)
end

function RoffinityCanvas.GetRGBFromColourU32(ColourU32: number): (number, number, number)
	local R, G, B = Utility.GetRGBAFromColourU32(ColourU32)
	return R, G, B
end

function RoffinityCanvas.CreateBlankImageData(Width: number, Height: number)
	return {
		Width = Width,
		Height = Height,
		ImageResolution = Vector2.new(Width, Height),
		ImageBuffer = Internal.CreateBuffer(Width, Height, Utility.DEFAULT_COLOR, 0),
	}
end

function RoffinityCanvas.new(ParentOrOptions, Resolution: Vector2?, CanvasColour: Color3?, Blur: boolean?): Canvas
	local Options = NormalizeConstructorArgs(ParentOrOptions, Resolution, CanvasColour, Blur)
	assert(Options.Parent ~= nil, "RoffinityCanvas requires a parent")
	assert(Utility.IsValidParent(Options.Parent), "RoffinityCanvas parent must be a GuiObject")

	local TargetResolution = Utility.INTERNAL_RESOLUTION
	local TargetFrameSize = Utility.ClampFrameSize(Options.FrameSize or Utility.DEFAULT_FRAME_SIZE)
	local TargetColour = Options.CanvasColour or Options.Parent.BackgroundColor3 or Utility.DEFAULT_COLOR
	local Frame, ImageLabel =
		Internal.CreateDisplay(Options.Parent, Options.Name or "RoffinityCanvas", TargetColour, Options.Blur, TargetFrameSize)
	local EditableImage = Internal.CreateEditableImage(TargetResolution)
	Internal.AttachEditableImage(ImageLabel, EditableImage)

	local EventsFolder = Instance.new("Folder")
	EventsFolder.Name = "Events"
	EventsFolder.Parent = Frame

	local OnRenderedBindable = Instance.new("BindableEvent")
	OnRenderedBindable.Name = "OnRenderedEvent"
	OnRenderedBindable.Parent = EventsFolder

	local self = setmetatable({}, RoffinityCanvas)
	self.OutputWarnings = true
	self.AutoRender = true
	self.AutoRenderFpsLimit = 0
	self.AlphaBlendingMode = RoffinityCanvas.BlendingModes.Replace
	self.GridTransparency = 1
	self.GridColour = Color3.new(1, 1, 1)
	self.CanvasColour = TargetColour
	self.ClearAlpha = 1
	self.Resolution = TargetResolution
	self.CurrentResX = TargetResolution.X
	self.CurrentResY = TargetResolution.Y
	self.Width = TargetFrameSize.X
	self.Height = TargetFrameSize.Y
	self.FrameSize = TargetFrameSize
	self.InternalResolution = TargetResolution
	self.Parent = Options.Parent
	self.Frame = Frame
	self.Container = Frame
	self.ImageLabel = ImageLabel
	self.EditableImage = EditableImage
	self.Buffer = Internal.CreateBuffer(TargetResolution.X, TargetResolution.Y, TargetColour, self.ClearAlpha)
	self.NeedsRender = true
	self.EventsFolder = EventsFolder
	self.OnRendered = OnRenderedBindable.Event

	local LastRender = os.clock()
	self.AutoUpdateConnection = RunService.Heartbeat:Connect(function()
		if not self.AutoRender then
			return
		end

		local Now = os.clock()
		if self.AutoRenderFpsLimit > 0 and Now - LastRender < 1 / self.AutoRenderFpsLimit then
			return
		end

		if self.NeedsRender then
			self:Render()
			OnRenderedBindable:Fire(Now - LastRender)
			LastRender = Now
		end
	end)

	self:Clear()
	self:Render()

	return self
end

for MethodName, Method in pairs(API) do
	RoffinityCanvas[MethodName] = Method
end

return RoffinityCanvas
