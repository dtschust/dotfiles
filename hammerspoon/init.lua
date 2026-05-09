require("hs.ipc")

-- Whisper push-to-talk for macOS.
-- Tap Ctrl-Space to start recording; tap again to transcribe and paste.

local HOTKEY_MODS = {"ctrl"}
local HOTKEY_KEY = "space"

local defaultMic = hs.audiodevice.defaultInputDevice()
local MIC_NAME = defaultMic and defaultMic:name() or nil

local MODEL_PATH = os.getenv("WHISPER_MODEL")
  or (os.getenv("HOME") .. "/models/whisper/ggml-base.en.bin")

local LANGUAGE = "en"
local MAX_RECORD_SECONDS = 120

local function whichLogin(cmd)
  local out = hs.execute('/bin/zsh -lc "command -v ' .. cmd .. ' 2>/dev/null"')
  if out and #out > 0 then
    return (out:gsub("%s+$", ""))
  end
  return nil
end

local FFMPEG = whichLogin("ffmpeg")
local WHISPER = whichLogin("whisper-cli") or whichLogin("whisper-cpp")

if not FFMPEG or not WHISPER then
  local msg = "Missing ffmpeg or whisper-cpp/whisper-cli.\n"
  msg = msg .. "ffmpeg: " .. tostring(FFMPEG) .. "\n"
  msg = msg .. "whisper: " .. tostring(WHISPER)
  hs.alert.show(msg, {}, 8)
end

local function addTaskEnv(task)
  if not task then
    return
  end

  local env = task:environment() or {}
  local fullPATH = hs.execute('/bin/zsh -lc "printf %s \\"$PATH\\""'):gsub("%s+$", "")
  if fullPATH and #fullPATH > 0 then
    env["PATH"] = fullPATH
  end

  local brewPrefix = hs.execute("/opt/homebrew/bin/brew --prefix whisper-cpp 2>/dev/null"):gsub("%s+$", "")
  if brewPrefix and #brewPrefix > 0 then
    env["GGML_METAL_PATH_RESOURCES"] = brewPrefix .. "/share/whisper-cpp"
  end

  task:setEnvironment(env)
end

local tmpWav = "/tmp/whisper_ptt.wav"
local tmpCaf = "/tmp/whisper_ptt.caf"
local outPrefix = "/tmp/whisper_ptt"
local ffLog = "/tmp/whisper_ptt_ffmpeg.log"

local recordTask, transcribeTask
local alertId
local isRecording = false
local recordingActive = false
local pendingStop = false
local pendingStopTimer = nil
local recordStartAt = nil

local function showAlert(msg, dur)
  if alertId then
    hs.alert.closeSpecific(alertId)
  end
  alertId = hs.alert.show(msg, {}, dur or 9999)
end

local function clearAlert()
  if alertId then
    hs.alert.closeSpecific(alertId)
    alertId = nil
  end
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

local function fileSize(path)
  local f = io.open(path, "rb")
  if not f then
    return 0
  end
  local sz = f:seek("end")
  f:close()
  return sz or 0
end

local function transcribe()
  showAlert("Transcribing...")

  local args = {"--model", MODEL_PATH, "--output-txt", "--output-file", outPrefix}
  if LANGUAGE and #LANGUAGE > 0 then
    table.insert(args, "--language")
    table.insert(args, LANGUAGE)
  end
  table.insert(args, tmpWav)

  transcribeTask = hs.task.new(WHISPER, function(exitCode)
    hs.timer.doAfter(0.2, function()
      local txtPath = outPrefix .. ".txt"
      local txt = readFile(txtPath) or ""

      if #txt == 0 then
        local alt = hs.execute('/bin/zsh -lc "ls -t /tmp/whisper_ptt*.txt 2>/dev/null | head -n 1"') or ""
        alt = alt:gsub("%s+$", "")
        if #alt > 0 then
          local t2 = readFile(alt) or ""
          if #t2 > 0 then
            txt = t2
            txtPath = alt
          end
        end
      end

      clearAlert()
      if #txt == 0 then
        hs.alert.show(("Whisper failed (code %d)"):format(exitCode), {}, 4)
      else
        hs.pasteboard.setContents(txt)
        hs.eventtap.keyStroke({"cmd"}, "v", 0)
        hs.alert.show("Pasted transcription", {}, 1.2)
      end

      os.remove(tmpWav)
      os.remove(txtPath)
      transcribeTask = nil
    end)
  end, args)

  addTaskEnv(transcribeTask)
  transcribeTask:start()
end

local function stopRecording()
  recordingActive = false

  if not recordTask then
    return
  end

  if not recordTask:isRunning() then
    if pendingStopTimer then
      pendingStopTimer:stop()
      pendingStopTimer = nil
    end

    pendingStop = true
    showAlert("Stopping...", 1.0)
    local tries = 0
    pendingStopTimer = hs.timer.doEvery(0.05, function()
      tries = tries + 1
      if recordTask and recordTask:isRunning() then
        pcall(function()
          recordTask:stdin("q")
        end)
        if pendingStopTimer then
          pendingStopTimer:stop()
          pendingStopTimer = nil
        end
        pendingStop = false
      elseif tries > 60 then
        if pendingStopTimer then
          pendingStopTimer:stop()
          pendingStopTimer = nil
        end
        pendingStop = false
        clearAlert()
        hs.alert.show("Recorder did not start; cancelled", {}, 1.2)
      end
    end)
    return
  end

  local delay = 0
  if recordStartAt then
    local elapsedMs = math.floor((hs.timer.absoluteTime() - recordStartAt) / 1e6)
    if elapsedMs < 250 then
      delay = (250 - elapsedMs) / 1000.0
    end
  end

  hs.timer.doAfter(delay, function()
    if recordTask and recordTask:isRunning() then
      pcall(function()
        recordTask:stdin("q")
      end)
    end
  end)

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
  if not FFMPEG or not WHISPER or not MIC_NAME then
    hs.alert.show("Whisper PTT is missing ffmpeg, whisper, or microphone input", {}, 4)
    recordingActive = false
    return false
  end

  if recordTask and recordTask:isRunning() then
    recordTask:interrupt()
  end

  os.remove(tmpWav)
  os.remove(tmpCaf)
  os.remove(outPrefix .. ".txt")

  showAlert("Starting mic...")
  local args = {
    "-hide_banner", "-nostats", "-loglevel", "error",
    "-fflags", "nobuffer",
    "-flags", "+low_delay",
    "-probesize", "32k",
    "-analyzeduration", "0",
    "-f", "avfoundation",
    "-i", string.format(":%s", MIC_NAME),
    "-ac", "1", "-ar", "16000",
    "-f", "caf",
    "-y", tmpCaf
  }

  recordTask = hs.task.new(FFMPEG, function()
    isRecording = false
    local tries = 0

    local function waitForCaf()
      tries = tries + 1
      local sz = fileSize(tmpCaf)
      if sz > 1024 then
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
            clearAlert()
            hs.alert.show("Finalize failed (CAF to WAV)", {}, 2.0)
          end
        end, convArgs)
        addTaskEnv(conv)
        conv:start()
      elseif tries < 100 then
        hs.timer.doAfter(0.05, waitForCaf)
      else
        clearAlert()
        hs.alert.show("No audio captured", {}, 2.0)
      end
    end

    waitForCaf()
  end, args)

  addTaskEnv(recordTask)
  local env = recordTask:environment() or {}
  env["FFREPORT"] = "file=" .. ffLog .. ":level=32"
  recordTask:setEnvironment(env)

  local ok = recordTask:start()
  if not ok then
    clearAlert()
    hs.alert.show("Failed to start ffmpeg task", {}, 2.0)
    isRecording = false
    recordingActive = false
    return false
  end

  isRecording = true
  pendingStop = false
  recordStartAt = hs.timer.absoluteTime()

  local tries = 0
  hs.timer.doEvery(0.3, function(t)
    tries = tries + 1
    if fileSize(tmpCaf) > 24 then
      showAlert("Recording...")
      t:stop()
    elseif tries > 6 then
      showAlert("Recording...")
      t:stop()
    end
  end)

  hs.timer.doAfter(MAX_RECORD_SECONDS, function()
    if recordTask and recordTask:isRunning() then
      hs.alert.show("Auto-stopping...", {}, 1.0)
      stopRecording()
    end
  end)

  return true
end

hs.hotkey.bind(HOTKEY_MODS, HOTKEY_KEY, function()
  if recordingActive or isRecording then
    showAlert("Stopping...", 0.6)
    stopRecording()
  else
    recordingActive = startRecording()
  end
end)

hs.alert.show("Whisper PTT loaded: tap Ctrl-Space", {}, 2.0)
