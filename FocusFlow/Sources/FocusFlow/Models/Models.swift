import Foundation
import SwiftUI

// MARK: - Sound Model

struct Sound: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let nameCN: String
    let category: SoundCategory
    let fileName: String
    let icon: String
    let isFree: Bool
    let isDownloaded: Bool
    var volume: Float

    init(
        id: String,
        name: String,
        nameCN: String,
        category: SoundCategory,
        fileName: String,
        icon: String,
        isFree: Bool = false,
        isDownloaded: Bool = false,
        volume: Float = 0.7
    ) {
        self.id = id
        self.name = name
        self.nameCN = nameCN
        self.category = category
        self.fileName = fileName
        self.icon = icon
        self.isFree = isFree
        self.isDownloaded = isDownloaded
        self.volume = volume
    }

    var displayName: String { nameCN }

    var localURL: URL? {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first
        return appSupport?.appendingPathComponent("FocusFlow/Sounds/\(fileName)")
    }

    var bundleURL: URL? {
        Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".aac", with: ""),
                        withExtension: "aac")
    }

    var remoteURL: URL? {
        URL(string: "https://github.com/ZhangShiCheng3D/FocusFlow/releases/download/sounds-v1/\(fileName)")
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Sound, rhs: Sound) -> Bool { lhs.id == rhs.id }
}

// MARK: - Sound Category

enum SoundCategory: String, Codable, CaseIterable {
    case nature = "自然"
    case water = "水声"
    case urban = "城市"
    case whiteNoise = "白噪音"
    case music = "音乐"
    case special = "特殊"

    var icon: String {
        switch self {
        case .nature: return "leaf"
        case .water: return "drop"
        case .urban: return "building.2"
        case .whiteNoise: return "waveform"
        case .music: return "music.note"
        case .special: return "sparkles"
        }
    }
}

// MARK: - Soundscape Preset

struct Soundscape: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var soundMix: [SoundMixEntry]
    var isBuiltIn: Bool
    var shareCode: String?

    struct SoundMixEntry: Codable, Equatable {
        let soundId: String
        var volume: Float
    }

    init(
        id: UUID = UUID(),
        name: String,
        soundMix: [SoundMixEntry],
        isBuiltIn: Bool = false,
        shareCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.soundMix = soundMix
        self.isBuiltIn = isBuiltIn
        self.shareCode = shareCode
    }

    static func == (lhs: Soundscape, rhs: Soundscape) -> Bool { lhs.id == rhs.id }

    static let presets: [Soundscape] = [
        Soundscape(name: "暴风雨", soundMix: [
            SoundMixEntry(soundId: "rain_heavy", volume: 0.8),
            SoundMixEntry(soundId: "thunder", volume: 0.4)
        ], isBuiltIn: true),
        Soundscape(name: "咖啡馆工作", soundMix: [
            SoundMixEntry(soundId: "cafe", volume: 0.6),
            SoundMixEntry(soundId: "keyboard", volume: 0.3)
        ], isBuiltIn: true),
        Soundscape(name: "深夜自习室", soundMix: [
            SoundMixEntry(soundId: "library", volume: 0.5),
            SoundMixEntry(soundId: "clock_tick", volume: 0.3)
        ], isBuiltIn: true),
        Soundscape(name: "海边学习", soundMix: [
            SoundMixEntry(soundId: "ocean_wave", volume: 0.7),
            SoundMixEntry(soundId: "seagull", volume: 0.2)
        ], isBuiltIn: true),
        Soundscape(name: "森林冥想", soundMix: [
            SoundMixEntry(soundId: "forest_bird", volume: 0.6),
            SoundMixEntry(soundId: "stream", volume: 0.5)
        ], isBuiltIn: true)
    ]
}

// MARK: - Sound Catalog

struct SoundCatalog {
    static let allSounds: [Sound] = [
        // Free Tier (3 sounds)
        Sound(id: "white_noise", name: "White Noise", nameCN: "白噪音", category: .whiteNoise,
              fileName: "white_noise.aac", icon: "waveform.circle", isFree: true, isDownloaded: true),
        Sound(id: "rain_light", name: "Light Rain", nameCN: "雨声", category: .water,
              fileName: "rain_light.aac", icon: "cloud.rain", isFree: true, isDownloaded: true),
        Sound(id: "cafe", name: "Cafe", nameCN: "咖啡馆", category: .urban,
              fileName: "cafe.aac", icon: "cup.and.saucer", isFree: true, isDownloaded: true),

        // Pro Tier (17+ sounds)
        Sound(id: "rain_heavy", name: "Heavy Rain", nameCN: "暴雨", category: .water,
              fileName: "rain_heavy.aac", icon: "cloud.heavyrain"),
        Sound(id: "thunder", name: "Thunder", nameCN: "雷声", category: .nature,
              fileName: "thunder.aac", icon: "cloud.bolt"),
        Sound(id: "ocean_wave", name: "Ocean Waves", nameCN: "海浪", category: .water,
              fileName: "ocean_wave.aac", icon: "water.waves"),
        Sound(id: "stream", name: "Stream", nameCN: "溪流", category: .water,
              fileName: "stream.aac", icon: "drop"),
        Sound(id: "waterfall", name: "Waterfall", nameCN: "瀑布", category: .water,
              fileName: "waterfall.aac", icon: "waterfall"),
        Sound(id: "campfire", name: "Campfire", nameCN: "篝火", category: .nature,
              fileName: "campfire.aac", icon: "flame"),
        Sound(id: "forest_bird", name: "Forest Birds", nameCN: "森林鸟鸣", category: .nature,
              fileName: "forest_bird.aac", icon: "bird"),
        Sound(id: "night_cricket", name: "Night Crickets", nameCN: "夜晚虫鸣", category: .nature,
              fileName: "night_cricket.aac", icon: "moon.stars"),
        Sound(id: "library", name: "Library", nameCN: "图书馆", category: .urban,
              fileName: "library.aac", icon: "books.vertical"),
        Sound(id: "keyboard", name: "Keyboard", nameCN: "键盘打字", category: .urban,
              fileName: "keyboard.aac", icon: "keyboard"),
        Sound(id: "fan", name: "Fan", nameCN: "风扇", category: .whiteNoise,
              fileName: "fan.aac", icon: "fan"),
        Sound(id: "pink_noise", name: "Pink Noise", nameCN: "粉红噪音", category: .whiteNoise,
              fileName: "pink_noise.aac", icon: "waveform"),
        Sound(id: "brown_noise", name: "Brown Noise", nameCN: "棕噪音", category: .whiteNoise,
              fileName: "brown_noise.aac", icon: "waveform"),
        Sound(id: "wind_chime", name: "Wind Chime", nameCN: "风铃", category: .music,
              fileName: "wind_chime.aac", icon: "wind"),
        Sound(id: "piano", name: "Piano", nameCN: "钢琴", category: .music,
              fileName: "piano.aac", icon: "pianokeys"),
        Sound(id: "choir", name: "Choir", nameCN: "唱诗班", category: .music,
              fileName: "choir.aac", icon: "music.mic"),
        Sound(id: "train", name: "Train", nameCN: "火车", category: .special,
              fileName: "train.aac", icon: "tram"),
        Sound(id: "spaceship", name: "Spaceship", nameCN: "太空飞船", category: .special,
              fileName: "spaceship.aac", icon: "rocket"),
        Sound(id: "japanese_garden", name: "Japanese Garden", nameCN: "日式庭院", category: .special,
              fileName: "japanese_garden.aac", icon: "torii"),
        Sound(id: "clock_tick", name: "Clock Tick", nameCN: "钟表滴答", category: .urban,
              fileName: "clock_tick.aac", icon: "clock"),
        Sound(id: "seagull", name: "Seagull", nameCN: "海鸥", category: .nature,
              fileName: "seagull.aac", icon: "tropicalstorm"),
    ]
}

// MARK: - Focus Session

struct FocusSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let durationMinutes: Int
    let durationSeconds: Int
    let soundsUsed: [String]
    let wasCompleted: Bool

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        durationMinutes: Int,
        durationSeconds: Int = 0,
        soundsUsed: [String] = [],
        wasCompleted: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds
        self.soundsUsed = soundsUsed
        self.wasCompleted = wasCompleted
    }

    var actualDuration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
}

// MARK: - App State

enum FocusState: Equatable {
    case idle
    case ready(duration: Int)
    case focusing(endTime: Date, duration: Int)
    case paused(remaining: TimeInterval)
}

enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
}

// MARK: - Timer Preset

struct TimerPreset: Identifiable, Equatable {
    let id: UUID = UUID()
    let minutes: Int
    let label: String

    static let defaults: [TimerPreset] = [
        TimerPreset(minutes: 25, label: "番茄钟"),
        TimerPreset(minutes: 45, label: "深度工作"),
        TimerPreset(minutes: 60, label: "长专注"),
    ]
}

// MARK: - Integration Status

enum IntegrationType: String, CaseIterable, Codable {
    case slack = "Slack"
    case discord = "Discord"
    case teams = "Microsoft Teams"

    var providerID: String {
        switch self {
        case .slack: return "slack"
        case .discord: return "discord"
        case .teams: return "teams"
        }
    }

    var icon: String {
        switch self {
        case .slack: return "slack"
        case .discord: return "discord"
        case .teams: return "teams"
        }
    }
}

enum IntegrationStatus: Equatable {
    case notConfigured
    case authorized
    case failed(reason: IntegrationError)

    enum IntegrationError: Error, Equatable {
        case userDenied
        case adminConsentRequired
        case networkError
        case tokenExpired
        case unknown

        var description: String {
            switch self {
            case .userDenied: return "授权已取消"
            case .adminConsentRequired: return "需要管理员批准（可能被组织策略拦截）"
            case .networkError: return "网络连接失败"
            case .tokenExpired: return "授权已过期，请重新连接"
            case .unknown: return "连接失败"
            }
        }

        var isSilent: Bool {
            // These errors should never trigger a popup during focus
            switch self {
            case .adminConsentRequired, .networkError, .tokenExpired: return true
            case .userDenied, .unknown: return false
            }
        }
    }
}
