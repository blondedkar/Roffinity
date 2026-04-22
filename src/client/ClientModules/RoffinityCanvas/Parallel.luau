local Parallel = {}

export type PixelWrite = {
	X: number,
	Y: number,
	Color: Color3,
	Transparency: number?,
}

function Parallel.ComputeRect(X: number, Y: number, Width: number, Height: number, Color: Color3, Transparency: number?): { PixelWrite }
	local Writes = {}
	local StartX = math.floor(X)
	local StartY = math.floor(Y)
	local EndX = math.floor(X + Width - 1)
	local EndY = math.floor(Y + Height - 1)

	for PixelY = StartY, EndY do
		for PixelX = StartX, EndX do
			table.insert(Writes, {
				X = PixelX,
				Y = PixelY,
				Color = Color,
				Transparency = Transparency,
			})
		end
	end

	return Writes
end

function Parallel.ComputeLine(X0: number, Y0: number, X1: number, Y1: number, Color: Color3, Transparency: number?): { PixelWrite }
	local Writes = {}
	X0 = math.floor(X0)
	Y0 = math.floor(Y0)
	X1 = math.floor(X1)
	Y1 = math.floor(Y1)

	local DeltaX = math.abs(X1 - X0)
	local StepX = if X0 < X1 then 1 else -1
	local DeltaY = -math.abs(Y1 - Y0)
	local StepY = if Y0 < Y1 then 1 else -1
	local Error = DeltaX + DeltaY

	while true do
		table.insert(Writes, {
			X = X0,
			Y = Y0,
			Color = Color,
			Transparency = Transparency,
		})

		if X0 == X1 and Y0 == Y1 then
			break
		end

		local Error2 = 2 * Error
		if Error2 >= DeltaY then
			Error += DeltaY
			X0 += StepX
		end

		if Error2 <= DeltaX then
			Error += DeltaX
			Y0 += StepY
		end
	end

	return Writes
end

function Parallel.ComputeClear(Width: number, Height: number, Color: Color3, Transparency: number?): { PixelWrite }
	local Writes = table.create(Width * Height)
	local Index = 0

	for Y = 1, Height do
		for X = 1, Width do
			Index += 1
			Writes[Index] = {
				X = X,
				Y = Y,
				Color = Color,
				Transparency = Transparency,
			}
		end
	end

	return Writes
end

function Parallel.RunNative(Compute: () -> { PixelWrite }): { PixelWrite }
	return Compute()
end

function Parallel.RunBestAvailable(Compute: () -> { PixelWrite }): { PixelWrite }
	local DidRunParallel, Result = pcall(function()
		task.desynchronize()
		local Writes = Compute()
		task.synchronize()
		return Writes
	end)

	if DidRunParallel then
		return Result
	end

	pcall(task.synchronize)
	return Parallel.RunNative(Compute)
end

function Parallel.RunChunked(Writes: { PixelWrite }, ChunkSize: number, CommitChunk: ({ PixelWrite }) -> ())
	local Total = #Writes
	local Index = 1
	local SafeChunkSize = math.max(math.floor(ChunkSize), 1)

	while Index <= Total do
		local Chunk = {}
		local EndIndex = math.min(Index + SafeChunkSize - 1, Total)

		for WriteIndex = Index, EndIndex do
			table.insert(Chunk, Writes[WriteIndex])
		end

		CommitChunk(Chunk)
		Index = EndIndex + 1
		task.wait()
	end
end

return Parallel
