local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

warn("[Canvas] Canvas handler script started")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local PlayerScripts = Player:WaitForChild("PlayerScripts")
local Client = PlayerScripts:WaitForChild("Client")
local ClientModules = Client:WaitForChild("ClientModules")

local RoffinityCanvasModule = ClientModules:WaitForChild("RoffinityCanvas")
local RequireSuccess, RoffinityCanvas = pcall(require, RoffinityCanvasModule)
if not RequireSuccess then
	warn(("[Canvas] Failed to require RoffinityCanvas: %s"):format(tostring(RoffinityCanvas)))
	RoffinityCanvas = nil
else
	warn("[Canvas] RoffinityCanvas module required successfully")
end

local MainUI = PlayerGui:WaitForChild("Main")
local Constraint = MainUI:WaitForChild("Constraint")
local CanvasArea = Constraint:WaitForChild("CanvasArea")
local CanvasConstraint = CanvasArea:WaitForChild("CanvasConstraint")
local Navbar = Constraint:WaitForChild("Navbar")
local SelectionBar = Navbar:WaitForChild("Selectionbar")

local CanvasSelection = SelectionBar:WaitForChild("Canvas")
local WidthEntry = CanvasSelection:WaitForChild("Width"):WaitForChild("Entry") :: TextBox
local HeightEntry = CanvasSelection:WaitForChild("Height"):WaitForChild("Entry") :: TextBox
local SizeLabel = CanvasSelection:WaitForChild("Size") :: TextLabel

local CANVAS_MODE = "Canvas"
local DEFAULT_WIDTH = 256
local DEFAULT_HEIGHT = 256
local PIXEL_SIZE = 1
local MAX_FRAME_SIZE = 4096

local ActiveCanvas = nil
local IsDraggingCanvasBounds = false
local DragStart: Vector2? = nil
local PreviewFrame: Frame? = nil
local InputLayer: TextButton? = nil
local BoundsStroke: UIStroke? = nil
local BoundsStrokeTween: Tween? = nil
local ResizeCanvasFromEntries

local function DebugWarn(Message: string)
	warn(("[Canvas] %s"):format(Message))
end

local function ParseDimension(Text: string, Fallback: number): number
	local SanitizedText = Text:gsub("%s+", "")
	if SanitizedText == "" then
		return Fallback
	end

	local Value = tonumber(SanitizedText)
	if Value == nil then
		DebugWarn(("Could not parse dimension %q, using fallback %d"):format(Text, Fallback))
		return Fallback
	end

	local ParsedValue = math.clamp(math.floor(Value + 0.5), 1, MAX_FRAME_SIZE)
	if ParsedValue ~= Value then
		DebugWarn(("Normalized dimension %q to %d"):format(Text, ParsedValue))
	end

	return ParsedValue
end

local function FormatDimensionEntry(Entry: TextBox, Value: number)
	Entry.Text = tostring(Value)
end

local function UpdateSizeLabel(Width: number, Height: number)
	SizeLabel.Text = ("Size:%dx%d"):format(Width, Height)
end

local function IsCanvasMode(): boolean
	return Player:GetAttribute("CurrentMode") == CANVAS_MODE
end

local function GetRequestedCanvasSize(): (number, number)
	local CurrentWidth = if ActiveCanvas then ActiveCanvas.Width else DEFAULT_WIDTH
	local CurrentHeight = if ActiveCanvas then ActiveCanvas.Height else DEFAULT_HEIGHT
	local Width = ParseDimension(WidthEntry.Text, CurrentWidth)
	local Height = ParseDimension(HeightEntry.Text, CurrentHeight)

	DebugWarn(("Requested canvas size: %dx%d"):format(Width, Height))
	return Width, Height
end

local function FindCanvasParent(): GuiObject
	if CanvasConstraint:IsA("GuiObject") then
		DebugWarn(("Using canvas parent: %s"):format(CanvasConstraint:GetFullName()))
		return CanvasConstraint
	end

	error("Main.CanvasArea.CanvasConstraint must be a GuiObject")
end

local function GetConstraintLocalPoint(ScreenPosition: Vector2): Vector2
	local ConstraintPosition = CanvasConstraint.AbsolutePosition
	local ConstraintSize = CanvasConstraint.AbsoluteSize
	local X = math.clamp(ScreenPosition.X - ConstraintPosition.X, 0, ConstraintSize.X)
	local Y = math.clamp(ScreenPosition.Y - ConstraintPosition.Y, 0, ConstraintSize.Y)

	return Vector2.new(X, Y)
end

local function GetPreviewBounds(StartPoint: Vector2, EndPoint: Vector2): (number, number, number, number)
	local MinX = math.floor(math.min(StartPoint.X, EndPoint.X))
	local MinY = math.floor(math.min(StartPoint.Y, EndPoint.Y))
	local MaxX = math.ceil(math.max(StartPoint.X, EndPoint.X))
	local MaxY = math.ceil(math.max(StartPoint.Y, EndPoint.Y))

	local Width = math.max(MaxX - MinX, 1)
	local Height = math.max(MaxY - MinY, 1)
	return MinX, MinY, Width, Height
end

local function EnsurePreviewFrame(): Frame
	if PreviewFrame then
		return PreviewFrame
	end

	local NewPreviewFrame = Instance.new("Frame")
	NewPreviewFrame.Name = "CanvasSizePreview"
	NewPreviewFrame.BackgroundColor3 = Color3.fromRGB(135, 206, 250)
	NewPreviewFrame.BackgroundTransparency = 0.72
	NewPreviewFrame.BorderColor3 = Color3.fromRGB(80, 170, 235)
	NewPreviewFrame.BorderSizePixel = 2
	NewPreviewFrame.Visible = false
	NewPreviewFrame.ZIndex = 100
	NewPreviewFrame.Parent = CanvasConstraint

	PreviewFrame = NewPreviewFrame
	return NewPreviewFrame
end

local function EnsureInputLayer(): TextButton
	if InputLayer then
		return InputLayer
	end

	local NewInputLayer = Instance.new("TextButton")
	NewInputLayer.Name = "CanvasCreationInput"
	NewInputLayer.Active = true
	NewInputLayer.AutoButtonColor = false
	NewInputLayer.BackgroundTransparency = 1
	NewInputLayer.BorderSizePixel = 0
	NewInputLayer.Modal = false
	NewInputLayer.Selectable = false
	NewInputLayer.Size = UDim2.fromScale(1, 1)
	NewInputLayer.Text = ""
	NewInputLayer.Visible = false
	NewInputLayer.ZIndex = 99
	NewInputLayer.Parent = CanvasConstraint

	InputLayer = NewInputLayer
	return NewInputLayer
end

local function EnsureBoundsStroke(): UIStroke
	if BoundsStroke then
		return BoundsStroke
	end

	local NewBoundsStroke = Instance.new("UIStroke")
	NewBoundsStroke.Name = "CanvasConstraintDragStroke"
	NewBoundsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	NewBoundsStroke.Color = Color3.fromRGB(255, 45, 45)
	NewBoundsStroke.Enabled = false
	NewBoundsStroke.Thickness = 2
	NewBoundsStroke.Transparency = 0.85
	NewBoundsStroke.Parent = CanvasConstraint

	BoundsStroke = NewBoundsStroke
	return NewBoundsStroke
end

local function SetBoundsBreathing(Enabled: boolean)
	local Stroke = EnsureBoundsStroke()

	if BoundsStrokeTween then
		BoundsStrokeTween:Cancel()
		BoundsStrokeTween = nil
	end

	if not Enabled then
		Stroke.Enabled = false
		Stroke.Transparency = 0.85
		return
	end

	Stroke.Enabled = true
	Stroke.Transparency = 0.85
	BoundsStrokeTween =
		TweenService:Create(Stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.15,
		})

	BoundsStrokeTween:Play()
end

local function SetCanvasInputEnabled(Enabled: boolean)
	local Layer = EnsureInputLayer()
	Layer.Visible = Enabled
	Layer.Active = Enabled
end

local function UpdatePreviewRectangle(CurrentPoint: Vector2)
	if not DragStart then
		return
	end

	local MinX, MinY, Width, Height = GetPreviewBounds(DragStart, CurrentPoint)
	local Frame = EnsurePreviewFrame()
	Frame.Position = UDim2.fromOffset(MinX, MinY)
	Frame.Size = UDim2.fromOffset(Width, Height)
	Frame.Visible = true
	UpdateSizeLabel(Width, Height)
end

local function CommitPreviewRectangle()
	if not PreviewFrame or not DragStart then
		return
	end

	local Width = math.max(PreviewFrame.Size.X.Offset, 1)
	local Height = math.max(PreviewFrame.Size.Y.Offset, 1)
	local PositionX = PreviewFrame.Position.X.Offset
	local PositionY = PreviewFrame.Position.Y.Offset
	PreviewFrame.Visible = false
	DragStart = nil
	IsDraggingCanvasBounds = false

	FormatDimensionEntry(WidthEntry, Width)
	FormatDimensionEntry(HeightEntry, Height)
	UpdateSizeLabel(Width, Height)
	ResizeCanvasFromEntries()

	if ActiveCanvas and ActiveCanvas.Frame then
		ActiveCanvas.Frame.Position = UDim2.fromOffset(PositionX, PositionY)
	end
end

local function IsDragStartInput(Input: InputObject): boolean
	return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

local function IsDragMoveInput(Input: InputObject): boolean
	return Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch
end

local function InputToScreenPoint(Input: InputObject): Vector2
	return Vector2.new(Input.Position.X, Input.Position.Y)
end

local function ShowCanvasHost(Width: number, Height: number): GuiObject
	if CanvasArea:IsA("GuiObject") then
		CanvasArea.Visible = true
	end

	CanvasConstraint.Visible = true

	if CanvasConstraint.AbsoluteSize.X <= 0 or CanvasConstraint.AbsoluteSize.Y <= 0 then
		DebugWarn(
			("CanvasConstraint had zero AbsoluteSize (%d, %d), sizing it to %dx%d"):format(
				CanvasConstraint.AbsoluteSize.X,
				CanvasConstraint.AbsoluteSize.Y,
				Width,
				Height
			)
		)
		CanvasConstraint.Size = UDim2.fromOffset(Width, Height)
	end

	DebugWarn(
		("Canvas host visible=%s size=(%d, %d) absolute=(%d, %d)"):format(
			tostring(CanvasConstraint.Visible),
			CanvasConstraint.Size.X.Offset,
			CanvasConstraint.Size.Y.Offset,
			CanvasConstraint.AbsoluteSize.X,
			CanvasConstraint.AbsoluteSize.Y
		)
	)

	return FindCanvasParent()
end

local function CreateFallbackCanvas(Parent: GuiObject, Width: number, Height: number)
	local ExistingCanvas = Parent:FindFirstChild("EditableCanvas")
	if ExistingCanvas and ExistingCanvas:IsA("Frame") then
		ExistingCanvas.Size = UDim2.fromOffset(Width, Height)
		ExistingCanvas.Visible = true
		ExistingCanvas.BackgroundColor3 = Color3.new(1, 1, 1)
		ExistingCanvas.BackgroundTransparency = 0
		return {
			Width = Width,
			Height = Height,
			Frame = ExistingCanvas,
			Resize = function(Canvas, NewWidth: number, NewHeight: number)
				Canvas.Width = NewWidth
				Canvas.Height = NewHeight
				Canvas.Frame.Size = UDim2.fromOffset(NewWidth, NewHeight)
			end,
		}
	end

	local CanvasFrame = Instance.new("Frame")
	CanvasFrame.Name = "EditableCanvas"
	CanvasFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	CanvasFrame.BackgroundTransparency = 0
	CanvasFrame.BorderSizePixel = 0
	CanvasFrame.Size = UDim2.fromOffset(Width, Height)
	CanvasFrame.Visible = true
	CanvasFrame.ZIndex = 10
	CanvasFrame.Parent = Parent

	return {
		Width = Width,
		Height = Height,
		Frame = CanvasFrame,
		Resize = function(Canvas, NewWidth: number, NewHeight: number)
			Canvas.Width = NewWidth
			Canvas.Height = NewHeight
			Canvas.Frame.Size = UDim2.fromOffset(NewWidth, NewHeight)
		end,
	}
end

local function EnsureCanvas()
	if ActiveCanvas then
		DebugWarn("Canvas already exists, reusing active canvas")
		return ActiveCanvas
	end

	local Width, Height = GetRequestedCanvasSize()
	FormatDimensionEntry(WidthEntry, Width)
	FormatDimensionEntry(HeightEntry, Height)
	UpdateSizeLabel(Width, Height)

	DebugWarn(("Creating canvas frame at %dx%d with fixed 1024x1024 internal resolution"):format(Width, Height))
	local CanvasParent = ShowCanvasHost(Width, Height)
	if RoffinityCanvas then
		local CreateSuccess, CreatedCanvas = pcall(function()
			return RoffinityCanvas.new({
				Parent = CanvasParent,
				Width = Width,
				Height = Height,
				PixelSize = PIXEL_SIZE,
				Name = "EditableCanvas",
				CanvasColour = Color3.new(1, 1, 1),
			})
		end)

		if CreateSuccess then
			ActiveCanvas = CreatedCanvas
		else
			DebugWarn(("RoffinityCanvas.new failed, creating fallback frame: %s"):format(tostring(CreatedCanvas)))
			ActiveCanvas = CreateFallbackCanvas(CanvasParent, Width, Height)
		end
	else
		DebugWarn("RoffinityCanvas module unavailable, creating fallback frame")
		ActiveCanvas = CreateFallbackCanvas(CanvasParent, Width, Height)
	end

	ActiveCanvas.Frame.Visible = true
	ActiveCanvas.Frame.BackgroundColor3 = Color3.new(1, 1, 1)
	ActiveCanvas.Frame.BackgroundTransparency = 0
	UpdateSizeLabel(ActiveCanvas.Width, ActiveCanvas.Height)
	DebugWarn("Canvas created successfully")
	return ActiveCanvas
end

function ResizeCanvasFromEntries()
	local Canvas = EnsureCanvas()
	local Width, Height = GetRequestedCanvasSize()

	FormatDimensionEntry(WidthEntry, Width)
	FormatDimensionEntry(HeightEntry, Height)
	UpdateSizeLabel(Width, Height)
	DebugWarn(("Resizing canvas frame to %dx%d; internal resolution remains 1024x1024"):format(Width, Height))
	local ResizeSuccess, ResizeError = pcall(function()
		Canvas:Resize(Width, Height, PIXEL_SIZE)
	end)

	if not ResizeSuccess then
		DebugWarn(("Canvas resize failed: %s"):format(tostring(ResizeError)))
		Canvas.Frame.Size = UDim2.fromOffset(Width, Height)
		Canvas.Width = Width
		Canvas.Height = Height
	end

	UpdateSizeLabel(Canvas.Width, Canvas.Height)
	DebugWarn("Canvas resize complete")
end

local function UpdateCanvasForMode()
	local CanvasModeEnabled = IsCanvasMode()
	SetCanvasInputEnabled(CanvasModeEnabled)
	SetBoundsBreathing(CanvasModeEnabled)

	if CanvasModeEnabled then
		DebugWarn("Canvas mode detected")
		EnsureCanvas()
	else
		IsDraggingCanvasBounds = false
		DragStart = nil
		if PreviewFrame then
			PreviewFrame.Visible = false
		end

		DebugWarn(
			("CurrentMode is %q, canvas creation not required"):format(tostring(Player:GetAttribute("CurrentMode")))
		)
	end
end

local CanvasInputLayer = EnsureInputLayer()

CanvasInputLayer.InputBegan:Connect(function(Input)
	if not IsCanvasMode() or not IsDragStartInput(Input) then
		return
	end

	IsDraggingCanvasBounds = true
	DragStart = GetConstraintLocalPoint(InputToScreenPoint(Input))
	UpdatePreviewRectangle(DragStart)
	DebugWarn(("Started canvas size preview at %.0f,%.0f"):format(DragStart.X, DragStart.Y))
end)

UserInputService.InputChanged:Connect(function(Input)
	if not IsDraggingCanvasBounds or not DragStart or not IsCanvasMode() or not IsDragMoveInput(Input) then
		return
	end

	UpdatePreviewRectangle(GetConstraintLocalPoint(InputToScreenPoint(Input)))
end)

UserInputService.InputEnded:Connect(function(Input)
	if not IsDraggingCanvasBounds or not IsDragStartInput(Input) then
		return
	end

	DebugWarn("Committed canvas size preview")
	CommitPreviewRectangle()
end)

WidthEntry.FocusLost:Connect(function()
	DebugWarn("Width entry focus lost")
	ResizeCanvasFromEntries()
end)

HeightEntry.FocusLost:Connect(function()
	DebugWarn("Height entry focus lost")
	ResizeCanvasFromEntries()
end)

Player:GetAttributeChangedSignal("CurrentMode"):Connect(UpdateCanvasForMode)
DebugWarn("Canvas handler initialized")
UpdateSizeLabel(DEFAULT_WIDTH, DEFAULT_HEIGHT)
UpdateCanvasForMode()
