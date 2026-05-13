import AVFoundation
import Combine
import Foundation

// MARK: - Audio Manager

@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var playbackState: PlaybackState = .stopped
    @Published var activeSounds: [String: Float] = [:]  // soundId -> volume
    @Published var masterVolume: Float = 1.0

    private let engine = AVAudioEngine()
    private var players: [String: AVAudioPlayerNode] = [:]
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var volumeControls: [String: Float] = [:]
    private var isEngineRunning = false
    /// Sounds currently fading out — skip them when re-scheduling buffers after engine restart.
    private var fadingOutSoundIds: Set<String> = []

    private let maxSimultaneousSounds = 3
    private let fadeInDuration: TimeInterval = 0.5
    private let fadeOutDuration: TimeInterval = 1.0

    private init() {
        setupEngine()
    }

    // MARK: - Engine Lifecycle

    private func setupEngine() {
        // Configure audio session for playback
        let mainMixer = engine.mainMixerNode
        mainMixer.outputVolume = masterVolume
    }

    func startEngineIfNeeded() {
        guard !isEngineRunning else { return }
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            print("[AudioManager] Failed to start engine: \(error)")
        }
    }

    func suspendEngineIfIdle() {
        guard activeSounds.isEmpty && isEngineRunning else { return }
        engine.stop()
        isEngineRunning = false
        print("[AudioManager] Engine suspended to save power")
    }

    // MARK: - Sound Management

    func playSound(_ sound: Sound, volume: Float = 0.7) async throws {
        // Guard: already playing (not fading out)
        guard activeSounds[sound.id] == nil else {
            // Just update volume of existing player
            setVolume(for: sound.id, volume: volume)
            return
        }

        guard activeSounds.count < maxSimultaneousSounds else {
            throw AudioError.tooManySounds
        }

        // Load before touching the engine graph. This keeps existing ambient
        // audio alive while a direct-download fallback is still in flight.
        let buffer = try await loadBuffer(for: sound)

        if activeSounds[sound.id] != nil {
            setVolume(for: sound.id, volume: volume)
            return
        }

        guard activeSounds.count < maxSimultaneousSounds else {
            throw AudioError.tooManySounds
        }

        let wasRunning = isEngineRunning
        let existingPlayers = players // snapshot before modifying graph

        // AVAudioEngine requires stopping before modifying the node graph
        if wasRunning {
            // Pause all existing players first (they'll be re-scheduled after restart)
            for player in existingPlayers.values {
                player.pause()
            }
            engine.stop()
            isEngineRunning = false
        }

        // Attach and connect new player node
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let mainMixer = engine.mainMixerNode
        engine.connect(player, to: mainMixer, format: buffer.format)

        // Restart engine
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            // Clean up the new player that couldn't be started.
            engine.disconnectNodeInput(player)
            engine.detach(player)
            // Existing players remain in `players`/`buffers` in a paused state.
            // On the next successful `playSound` call, their buffers will be
            // re-scheduled (skipping any in `fadingOutSoundIds`), so they recover
            // without resurrecting intentionally stopped sounds.
            throw AudioError.engineStartFailed
        }

        // Re-schedule all EXISTING buffers (they were invalidated by engine stop)
        // Skip sounds that are fading out to avoid resurrecting stopped audio.
        for (soundId, existingBuffer) in buffers where !fadingOutSoundIds.contains(soundId) {
            guard let existingPlayer = players[soundId] else { continue }
            existingPlayer.scheduleBuffer(existingBuffer, at: nil, options: .loops, completionHandler: nil)
            existingPlayer.play()
        }

        // Schedule and play the NEW sound
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.volume = 0
        player.play()
        fadeIn(player: player, targetVolume: volume * masterVolume)

        // Update state
        players[sound.id] = player
        buffers[sound.id] = buffer
        volumeControls[sound.id] = volume
        activeSounds[sound.id] = volume
        playbackState = .playing
    }

    func stopSound(_ soundId: String) {
        guard let player = players[soundId], !fadingOutSoundIds.contains(soundId) else { return }

        // Immediately remove from active state so playSound's re-schedule loop skips it.
        // The player is kept alive by the fade-out closure until the fade completes.
        fadingOutSoundIds.insert(soundId)
        activeSounds.removeValue(forKey: soundId)
        volumeControls.removeValue(forKey: soundId)
        players.removeValue(forKey: soundId)
        buffers.removeValue(forKey: soundId)

        if activeSounds.isEmpty {
            playbackState = .stopped
        }

        // Fade out then disconnect
        fadeOut(player: player) { [weak self] in
            player.stop()
            self?.engine.disconnectNodeInput(player)
            self?.engine.detach(player)
            self?.fadingOutSoundIds.remove(soundId)

            if self?.activeSounds.isEmpty == true {
                self?.suspendEngineIfIdle()
            }
        }
    }

    func stopAllSounds() {
        let soundIds = Array(activeSounds.keys)
        for id in soundIds {
            stopSound(id)
        }
    }

    func setVolume(for soundId: String, volume: Float) {
        guard let player = players[soundId] else { return }
        volumeControls[soundId] = volume
        player.volume = volume * masterVolume
        activeSounds[soundId] = volume
    }

    func setMasterVolume(_ volume: Float) {
        masterVolume = volume
        engine.mainMixerNode.outputVolume = volume

        // Update individual player volumes proportionally
        for (id, baseVolume) in volumeControls {
            players[id]?.volume = baseVolume * volume
        }
    }

    func togglePause() {
        switch playbackState {
        case .playing:
            for player in players.values { player.pause() }
            playbackState = .paused
        case .paused:
            for player in players.values { player.play() }
            playbackState = .playing
        default:
            break
        }
    }

    // MARK: - Buffer Loading

    private func loadBuffer(for sound: Sound) async throws -> AVAudioPCMBuffer {
        // Try local cache first (ODR downloaded)
        if let localURL = sound.localURL, FileManager.default.fileExists(atPath: localURL.path) {
            return try loadBufferFromURL(localURL)
        }

        // Try bundle
        if let bundleURL = sound.bundleURL {
            return try loadBufferFromURL(bundleURL)
        }

        // Download from remote as a last-resort fallback.
        // Callers should prefer ODRManager.downloadSound() first for progress UI,
        // but this path ensures audio always works even when playSound is called
        // without a prior ODR pre-download (e.g. from Soundscape presets).
        if let remoteURL = sound.remoteURL {
            let data = try await downloadSound(from: remoteURL)
            let cachedURL = try await cacheSoundData(data, for: sound)
            return try loadBufferFromURL(cachedURL)
        }

        throw AudioError.fileNotFound
    }

    private func loadBufferFromURL(_ url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw AudioError.bufferCreationFailed
        }
        try file.read(into: buffer)
        return buffer
    }

    private func downloadSound(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AudioError.downloadFailed
        }
        return data
    }

    private func cacheSoundData(_ data: Data, for sound: Sound) async throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw AudioError.cacheDirectoryUnavailable
        }
        let soundsDir = appSupport.appendingPathComponent("FocusFlow/Sounds")
        try FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        let fileURL = soundsDir.appendingPathComponent(sound.fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    // MARK: - Fade Effects

    /// Smooth fade-in by ramping player volume over ``fadeInDuration`` seconds.
    ///
    /// Uses scheduled volume snapshots at ~30 fps. For ambient noise playback
    /// this produces a perceptually smooth fade without audible pops.
    /// For sample-accurate fades (e.g. music production apps), use
    /// ``AVAudioPlayerNode.scheduleSegment(_:startingFrame:frameCount:at:completionHandler:)``
    /// or VST-level automation instead.
    private func fadeIn(player: AVAudioPlayerNode, targetVolume: Float) {
        let stepCount = max(1, Int(fadeInDuration * 30)) // ~30 fps
        let stepTime = fadeInDuration / Double(stepCount)
        let stepVol = targetVolume / Float(stepCount)

        for i in 0...stepCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) { [weak player] in
                player?.volume = stepVol * Float(i)
            }
        }
    }

    /// Smooth fade-out then callback.
    private func fadeOut(player: AVAudioPlayerNode, completion: @escaping () -> Void) {
        let startVolume = player.volume
        let stepCount = max(1, Int(fadeOutDuration * 30)) // ~30 fps
        let stepTime = fadeOutDuration / Double(stepCount)
        let stepVol = startVolume / Float(stepCount)

        for i in 0...stepCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) { [weak player] in
                let newVol = startVolume - stepVol * Float(i)
                player?.volume = max(0, newVol)
                if i == stepCount { completion() }
            }
        }
    }

    // MARK: - Energy Management

    var energyImpact: String {
        if !isEngineRunning { return "Idle (< 0.1% CPU)" }
        if activeSounds.isEmpty { return "Suspended" }
        return "Active (~1-2% CPU)"
    }
}

// MARK: - Audio Errors

enum AudioError: LocalizedError {
    case tooManySounds
    case fileNotFound
    case bufferCreationFailed
    case downloadFailed
    case engineStartFailed
    case cacheDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .tooManySounds: return "最多同时播放 3 种声音"
        case .fileNotFound: return "音效文件未找到"
        case .bufferCreationFailed: return "音频缓冲创建失败"
        case .downloadFailed: return "音效下载失败"
        case .engineStartFailed: return "音频引擎启动失败"
        case .cacheDirectoryUnavailable: return "无法访问本地音效缓存目录"
        }
    }
}
