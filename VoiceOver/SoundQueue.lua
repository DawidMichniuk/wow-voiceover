setfenv(1, select(2, ...))
VoiceOverSoundQueue = {}
VoiceOverSoundQueue.__index = VoiceOverSoundQueue

function VoiceOverSoundQueue:new()
    local soundQueue = {}
    setmetatable(soundQueue, VoiceOverSoundQueue)

    soundQueue.soundIdCounter = 0
    soundQueue.sounds = {}
    soundQueue.isPaused = false
    soundQueue.ui = SoundQueueUI:new(soundQueue)

    return soundQueue
end

function VoiceOverSoundQueue:addSoundToQueue(soundData)
    DataModules:PrepareSound(soundData)

    if not VoiceOverUtils:willSoundPlay(soundData) or soundData.fileName == nil then
        print("Sound does not exist for: ", soundData.title)
        if soundData.stopCallback then
            soundData.stopCallback()
        end
        return
    end

    -- Check if the sound is already in the queue
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.fileName == soundData.fileName then
            return
        end
    end

    -- Don't play gossip if there are quest sounds in the queue
    local questSoundExists = false
    for _, queuedSound in ipairs(self.sounds) do
        if queuedSound.questId ~= nil then
            questSoundExists = true
            break
        end
    end

    if soundData.questId == nil and questSoundExists then
        return
    end

    self.soundIdCounter = self.soundIdCounter + 1
    soundData.id = self.soundIdCounter

    table.insert(self.sounds, soundData)
    self.ui:updateSoundQueueDisplay()

    -- If the sound queue only contains one sound, play it immediately
    if #self.sounds == 1 and not Addon.db.char.isPaused then
        self:playSound(soundData)
    end
end

function VoiceOverSoundQueue:playSound(soundData)
    local channel = Addon.db.profile.main.SoundChannel
    local willPlay, handle = PlaySoundFile(soundData.filePath, channel)
    if soundData.startCallback then
        soundData.startCallback()
    end
    local nextSoundTimer = C_Timer.NewTimer(soundData.length + 0.55, function()
        self:removeSoundFromQueue(soundData)
    end)

    soundData.nextSoundTimer = nextSoundTimer
    soundData.handle = handle
end

function VoiceOverSoundQueue:pauseQueue()
    if Addon.db.char.isPaused then
        return
    end

    Addon.db.char.isPaused = true

    if #self.sounds > 0 then
        local currentSound = self.sounds[1]
        StopSound(currentSound.handle)
        currentSound.nextSoundTimer:Cancel()
    end
end

function VoiceOverSoundQueue:resumeQueue()
    if not Addon.db.char.isPaused then
        return
    end

    Addon.db.char.isPaused = false
    if #self.sounds > 0 then
        local currentSound = self.sounds[1]
        self:playSound(currentSound)
    end
end

function VoiceOverSoundQueue:removeSoundFromQueue(soundData)
    local removedIndex = nil
    for index, queuedSound in ipairs(self.sounds) do
        if queuedSound.id == soundData.id then
            removedIndex = index
            table.remove(self.sounds, index)
            break
        end
    end

    if soundData.stopCallback then
        soundData.stopCallback()
    end

    if removedIndex == 1 and not Addon.db.char.isPaused then
        StopSound(soundData.handle)
        soundData.nextSoundTimer:Cancel()

        if #self.sounds > 0 then
            local nextSoundData = self.sounds[1]
            self:playSound(nextSoundData)
        end
    end

    self.ui:updateSoundQueueDisplay()
end
