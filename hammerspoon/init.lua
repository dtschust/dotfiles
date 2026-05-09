require("hs.ipc")

-- Whisper push-to-talk for macOS (Hammerspoon)
-- Hold ⌥Space (Alt+Space) to record; release to transcribe + paste

-- Setup:
-- brew install hammerspoon, ffmpeg, whisper-cpp
-- download ggml-base.en.bin from https://huggingface.co/ggerganov/whisper.cpp/tree/main
-- put it in ~/models/whisper/
-- go!

-----------------------
-- User configuration
-----------------------
local HOTKEY_MODS = {"ctrl"}
local HOTKEY_KEY  = "space"

-- Set your mic index (find via: ffmpeg -f avfoundation -list_devices true -i "")
-- local MIC_INDEX   = "1"

-- detect the default input microphone device name
local defaultMic = hs.audiodevice.defaultInputDevice()
local MIC_NAME = defaultMic and defaultMic:name() or nil

-- Whisper model (override with WHISPER_MODEL env if you prefer)
local MODEL_PATH  = os.getenv("WHISPER_MODEL")
                      or (os.getenv("HOME") .. "/models/whisper/ggml-base.en.bin")

-- Language: "en" for fixed English, "" to auto-detect
local LANGUAGE    = "en"

-- Safety timeout (sec) in case the key gets stuck
local MAX_RECORD_SECONDS = 120

-----------------------
-- Path helpers
-----------------------
-- Resolve binaries using your login shell so Homebrew paths are available
local function whichLogin(cmd)
  local out = hs.execute('/bin/zsh -lc "command -v ' .. cmd .. ' 2>/dev/null"')
  if out and #out > 0 then return (out:gsub("%s+$","")) end
  return nil
end

-- Prefer absolute paths discovered via a login shell
local FFMPEG  = whichLogin("ffmpeg")
local WHISPER = whichLogin("whisper-cli") or whichLogin("whisper-cpp")

if not FFMPEG or not WHISPER then
  local msg = "Missing ffmpeg or whisper-cpp/whisper-cli.\n"
  msg = msg .. "ffmpeg: " .. tostring(FFMPEG) .. "\n"
  msg = msg .. "whisper: " .. tostring(WHISPER)
  hs.alert.show(msg, {}, 8)
end

-----------------------
-- Task env helper (ensures PATH & Metal kernels)
-----------------------
local function addTaskEnv(task)
  if not task then return end
  local env = task:environment() or {}
  -- Pull the full PATH from your login shell so subprocesses behave like Terminal
  local fullPATH = hs.execute('/bin/zsh -lc "printf %s \\"$PATH\\""'):gsub("%s+$","")
  if fullPATH and #fullPATH > 0 then env["PATH"] = fullPATH end
  -- Speed on Apple Silicon if whisper-cpp was installed via Homebrew
  local brewPrefix = hs.execute("/opt/homebrew/bin/brew --prefix whisper-cpp 2>/dev/null"):gsub("%s+$","")
  if brewPrefix and #brewPrefix > 0 then
    env["GGML_METAL_PATH_RESOURCES"] = brewPrefix.."/share/whisper-cpp"
  end
  task:setEnvironment(env)
end

-----------------------
-- State & small utils
-----------------------
local tmpWav    = "/tmp/whisper_ptt.wav"
local tmpCaf    = "/tmp/whisper_ptt.caf"
local outPrefix = "/tmp/whisper_ptt"
local FFLOG     = "/tmp/wh_min_ff.log"
local recordTask, transcribeTask
local alertId
local isRecording = false
local pendingStop = false
local pendingStopTimer = nil
local recordStartAt = nil -- hs.timer.absoluteTime() at start

local function showAlert(msg, dur)
  if alertId then hs.alert.closeSpecific(alertId) end
  alertId = hs.alert.show(msg, {}, dur or 9999) -- sticky by default
end
local function clearAlert()
  if alertId then hs.alert.closeSpecific(alertId); alertId = nil end
end
local function readFile(path)
  local f = io.open(path, "r"); if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end
local function fileSize(path)
  local f = io.open(path, "rb"); if not f then return 0 end
  local sz = f:seek("end"); f:close(); return sz or 0
end
local function cpuThreads()
  local out = hs.execute('/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null') or ""
  out = out:gsub("%s+","")
  local n = tonumber(out)
  if not n or n < 1 then n = 4 end
  return tostring(n)
end
--

-----------------------
-- Transcribe phase
-----------------------
local function transcribe()
  showAlert("🧠 Transcribing…")
  -- Revert to simple whisper-cli flags for stability
  local args = { "--model", MODEL_PATH, "--output-txt", "--output-file", outPrefix }
  if LANGUAGE and #LANGUAGE > 0 then
    table.insert(args, "--language"); table.insert(args, LANGUAGE)
  end
  table.insert(args, tmpWav)

  transcribeTask = hs.task.new(WHISPER, function(exitCode, stdout, stderr)
    -- give the filesystem a moment to flush the .txt file
    hs.timer.doAfter(0.2, function()
      local txtPath = outPrefix..".txt"
      local txt = readFile(txtPath) or ""
      if #txt == 0 then
        -- fallback: some builds may name like prefix.wav.txt or ignore -of; search /tmp
        local alt = hs.execute('/bin/zsh -lc "ls -t /tmp/whisper_ptt*.txt 2>/dev/null | head -n 1"') or ""
        alt = alt:gsub("%s+$", "")
        if #alt > 0 then
          local t2 = readFile(alt) or ""
          if #t2 > 0 then txt = t2; txtPath = alt end
        end
      end
      clearAlert()
      if #txt == 0 then
        hs.alert.show(("Whisper failed (code %d)"):format(exitCode), {}, 4)
      else
        hs.pasteboard.setContents(txt)
        hs.eventtap.keyStroke({"cmd"}, "v", 0) -- paste into frontmost app
        hs.alert.show("✅ Pasted transcription", {}, 1.2)
      end
      -- cleanup
      os.remove(tmpWav)
      os.remove(txtPath)
      transcribeTask = nil
    end)
  end, args)

  addTaskEnv(transcribeTask)
  transcribeTask:start()
end

-----------------------
-- Record phase
-----------------------
local function stopRecording()
  -- Guard: only stop if a recording is actually running
  if not recordTask then return end
  -- If ffmpeg not yet running, queue a stop as soon as it starts
  if not recordTask:isRunning() then
    if pendingStopTimer then pendingStopTimer:stop(); pendingStopTimer = nil end
    pendingStop = true
    showAlert("⏹️ Stopping…", 1.0)
    local tries = 0
    pendingStopTimer = hs.timer.doEvery(0.05, function()
      tries = tries + 1
      if recordTask and recordTask:isRunning() then
        pcall(function() recordTask:stdin("q") end)
        if pendingStopTimer then pendingStopTimer:stop(); pendingStopTimer = nil end
        pendingStop = false
      elseif tries > 60 then
        if pendingStopTimer then pendingStopTimer:stop(); pendingStopTimer = nil end
        pendingStop = false
        clearAlert()
        hs.alert.show("Recorder didn’t start — cancelled", {}, 1.2)
      end
    end)
    return
  end
  -- small minimum duration (250ms) before interrupt; then ask ffmpeg to quit
  local delay = 0
  if recordStartAt then
    local elapsedMs = math.floor((hs.timer.absoluteTime() - recordStartAt)/1e6)
    if elapsedMs < 250 then delay = (250 - elapsedMs)/1000.0 end
  end
  hs.timer.doAfter(delay, function()
    if recordTask and recordTask:isRunning() then
      pcall(function() recordTask:stdin("q") end)
    end
  end)
  -- then escalate if needed
  local pid = tostring(recordTask:pid())
  hs.timer.doAfter(1.0 + delay, function()
    if recordTask and recordTask:isRunning() then
      hs.execute("kill -TERM " .. pid)
    end
  end)
  hs.timer.doAfter(3.0 + delay, function()
    if recordTask and recordTask:isRunning() then
      hs.execute("kill -KILL " .. pid)
    end
  end)
end

local function startRecording()
  -- If a previous ffmpeg somehow lingered, try to stop it first
  if recordTask and recordTask:isRunning() then
    recordTask:interrupt()
  end

  -- Remove any stale files so we don't read old text/audio
  os.remove(tmpWav)
  os.remove(tmpCaf)
  os.remove(outPrefix..".txt")

  showAlert("⏳ Starting mic…")
  local args = {
    "-hide_banner", "-nostats", "-loglevel", "error",
    "-fflags", "nobuffer",
    "-flags", "+low_delay",
    "-probesize", "32k",
    "-analyzeduration", "0",
    "-f", "avfoundation",
    -- "-i", ":"..MIC_INDEX,
		-- "-i", ":\'" .. MIC_NAME .. "\'",          -- audio-only
		"-i", string.format(":%s", MIC_NAME), -- audio-only
    "-ac", "1", "-ar", "16000",    -- mono, 16 kHz
    "-f", "caf",
    "-y", tmpCaf
  }

  recordTask = hs.task.new(FFMPEG, function()
    -- When ffmpeg exits (we interrupted), ensure we actually captured audio
    isRecording = false
    local tries = 0
    local function waitForCaf()
      tries = tries + 1
      local sz = fileSize(tmpCaf)
      if sz > 1024 then
        -- Convert CAF -> WAV for whisper compatibility
        local convArgs = {
          "-y", "-hide_banner", "-nostats", "-loglevel", "error",
          "-i", tmpCaf,
          "-f", "wav", "-c:a", "pcm_s16le",
          tmpWav
        }
        local conv = hs.task.new(FFMPEG, function(ec)
          os.remove(tmpCaf)
          if ec == 0 and fileSize(tmpWav) > 128 then
            transcribe()
          else
            clearAlert(); hs.alert.show("Finalize failed (CAF->WAV)", {}, 2.0)
          end
        end, convArgs)
        addTaskEnv(conv)
        conv:start()
      elseif tries < 100 then
        hs.timer.doAfter(0.05, waitForCaf)
      else
        clearAlert(); hs.alert.show("No audio captured", {}, 2.0)
      end
    end
    waitForCaf()
  end, args)

  addTaskEnv(recordTask)
  -- add ffmpeg logging for diagnosis
  local env = recordTask:environment() or {}
  env["FFREPORT"] = "file="..FFLOG..":level=32"
  recordTask:setEnvironment(env)
  local ok = recordTask:start()
  if not ok then
    clearAlert(); hs.alert.show("Failed to start ffmpeg task", {}, 2.0)
    isRecording = false
    return
  end
  isRecording = true
  pendingStop = false
  recordStartAt = hs.timer.absoluteTime()

  -- Update UI to "Recording…" only after bytes are written
  local tries = 0
  hs.timer.doEvery(0.3, function(t)
    tries = tries + 1
    if fileSize(tmpCaf) > 24 then
      showAlert("🎙️ Recording… (hold)")
      t:stop()
    elseif tries > 1 then
      -- 2s grace: show recording anyway
      showAlert("🎙️ Recording… (hold)")
      t:stop()
    end
  end)

  -- Safety: auto-stop after MAX_RECORD_SECONDS
  hs.timer.doAfter(MAX_RECORD_SECONDS, function()
    if recordTask and recordTask:isRunning() then
      hs.alert.show("⏱️ Auto-stopping…", {}, 1.0)
      stopRecording()
    end
  end)
end

-----------------------
-- Hotkey binding
-----------------------
-- Hold-to-talk: press to start, release to stop
hs.hotkey.bind(HOTKEY_MODS, HOTKEY_KEY,
  function() -- key down
    if not isRecording then startRecording() end
  end,
  function() -- key up
    if isRecording then
      hs.alert.show("⏹️ Stopping…", {}, 0.6)
      stopRecording()
    end
  end
)

-- hs.alert.show("Whisper PTT loaded — hold ctrl-space", {}, 2.0)

