import XCTest
import Carbon.HIToolbox
@testable import FocusFlow

final class FocusFlowTests: XCTestCase {

    // MARK: - Sound Model Tests

    func testSoundCatalogCount() {
        XCTAssertEqual(SoundCatalog.allSounds.count, 24)
    }

    func testFreeTierSounds() {
        let freeSounds = SoundCatalog.allSounds.filter { $0.isFree }
        XCTAssertEqual(freeSounds.count, 3)
        XCTAssertTrue(freeSounds.contains(where: { $0.id == "white_noise" }))
        XCTAssertTrue(freeSounds.contains(where: { $0.id == "rain_light" }))
        XCTAssertTrue(freeSounds.contains(where: { $0.id == "cafe" }))
    }

    func testSoundCategoriesExist() {
        let categories = Set(SoundCatalog.allSounds.map { $0.category })
        XCTAssertTrue(categories.contains(.nature))
        XCTAssertTrue(categories.contains(.water))
        XCTAssertTrue(categories.contains(.urban))
        XCTAssertTrue(categories.contains(.whiteNoise))
        XCTAssertTrue(categories.contains(.music))
        XCTAssertTrue(categories.contains(.special))
    }

    func testSoundUniqueness() {
        let ids = SoundCatalog.allSounds.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "All sound IDs must be unique")
    }

    // MARK: - Soundscape Presets

    func testPresetsExist() {
        XCTAssertFalse(Soundscape.presets.isEmpty)
        XCTAssertEqual(Soundscape.presets.count, 5)
    }

    func testPresetSoundsValid() {
        for preset in Soundscape.presets {
            for entry in preset.soundMix {
                XCTAssertTrue(
                    SoundCatalog.allSounds.contains(where: { $0.id == entry.soundId }),
                    "Preset '\(preset.name)' references invalid sound '\(entry.soundId)'"
                )
            }
        }
    }

    func testPresetMaxMixCount() {
        for preset in Soundscape.presets {
            XCTAssertLessThanOrEqual(preset.soundMix.count, 3, "Preset should not exceed max 3 sounds")
        }
    }

    // MARK: - Focus Session

    func testFocusSessionCreation() {
        let session = FocusSession(
            durationMinutes: 25,
            soundsUsed: ["rain_light"],
            wasCompleted: true
        )
        XCTAssertEqual(session.durationMinutes, 25)
        XCTAssertEqual(session.soundsUsed.count, 1)
        XCTAssertTrue(session.wasCompleted)
    }

    func testFocusSessionActualDuration() {
        let start = Date().addingTimeInterval(-1500) // 25 min ago
        let session = FocusSession(
            startTime: start,
            endTime: Date(),
            durationMinutes: 25,
            wasCompleted: true
        )
        XCTAssertEqual(session.actualDuration, 1500, accuracy: 5)
    }

    // MARK: - Timer Presets

    func testTimerPresets() {
        let presets = TimerPreset.defaults
        XCTAssertEqual(presets.count, 3)
        XCTAssertEqual(presets[0].minutes, 25)
        XCTAssertEqual(presets[1].minutes, 45)
        XCTAssertEqual(presets[2].minutes, 60)
    }

    // MARK: - Integration Status

    func testIntegrationErrorDescriptions() {
        XCTAssertFalse(IntegrationStatus.IntegrationError.adminConsentRequired.description.isEmpty)
        XCTAssertFalse(IntegrationStatus.IntegrationError.userDenied.description.isEmpty)
        XCTAssertFalse(IntegrationStatus.IntegrationError.networkError.description.isEmpty)
        XCTAssertFalse(IntegrationStatus.IntegrationError.tokenExpired.description.isEmpty)
    }

    func testSilentErrors() {
        XCTAssertTrue(IntegrationStatus.IntegrationError.adminConsentRequired.isSilent)
        XCTAssertTrue(IntegrationStatus.IntegrationError.networkError.isSilent)
        XCTAssertTrue(IntegrationStatus.IntegrationError.tokenExpired.isSilent)
        XCTAssertFalse(IntegrationStatus.IntegrationError.userDenied.isSilent)
    }

    func testIntegrationProviderIDsAreStableForProxyAndTokens() {
        XCTAssertEqual(IntegrationType.slack.providerID, "slack")
        XCTAssertEqual(IntegrationType.discord.providerID, "discord")
        XCTAssertEqual(IntegrationType.teams.providerID, "teams")
    }

    // MARK: - Preferences Defaults

    @MainActor
    func testPreferencesDefaultValues() {
        // Reset to ensure clean state
        PreferencesManager.shared.resetAll()
        let prefs = PreferencesManager.shared
        XCTAssertEqual(prefs.defaultDuration, 25)
        XCTAssertFalse(prefs.launchAtLogin)
        XCTAssertFalse(prefs.useGlobalHotkey)
        XCTAssertFalse(prefs.hasCompletedOnboarding)
        XCTAssertEqual(prefs.countdownDisplayMode, .full)
    }

    @MainActor
    func testTimerProgressClampsToBounds() {
        let timer = TimerManager.shared
        timer.stop()

        timer.totalSeconds = 60
        timer.remainingSeconds = -5
        XCTAssertEqual(timer.progress, 1)

        timer.remainingSeconds = 70
        XCTAssertEqual(timer.progress, 0)

        timer.stop()
    }

    // MARK: - ODR URL Generation

    func testSoundRemoteURLs() {
        for sound in SoundCatalog.allSounds {
            XCTAssertNotNil(sound.remoteURL, "Sound '\(sound.name)' should have a remote fallback URL")
            XCTAssertTrue(sound.remoteURL!.absoluteString.contains("github.com/ZhangShiCheng3D/FocusFlow/releases/download"),
                          "Sound URL should point to GitHub Releases")
        }
    }

    @MainActor
    func testBundledDownloadStateRequiresActualBundleResource() {
        for sound in SoundCatalog.allSounds where sound.isDownloaded {
            XCTAssertEqual(
                ODRManager.shared.isSoundDownloaded(sound),
                sound.bundleURL != nil,
                "Bundled sound '\(sound.id)' must not be reported as downloaded unless the resource exists"
            )
        }
    }

    // MARK: - Sound Local URLs

    func testSoundLocalURLs() {
        for sound in SoundCatalog.allSounds {
            let localURL = sound.localURL
            XCTAssertNotNil(localURL)
            XCTAssertTrue(localURL!.path.contains("Application Support/FocusFlow/Sounds"))
        }
    }

    // MARK: - Focus Session Codable

    func testFocusSessionCodable() throws {
        let session = FocusSession(
            durationMinutes: 45,
            soundsUsed: ["rain_light", "cafe"],
            wasCompleted: true
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(FocusSession.self, from: data)
        XCTAssertEqual(decoded.durationMinutes, 45)
        XCTAssertEqual(decoded.soundsUsed, ["rain_light", "cafe"])
        XCTAssertTrue(decoded.wasCompleted)
    }

    // MARK: - Global Hotkey Combo Parsing

    func testHotKeyComboRejectsInvalidStrings() {
        XCTAssertNil(HotKeyCombo(string: ""), "empty string is not a valid combo")
        XCTAssertNil(HotKeyCombo(string: "F"), "a key with no modifier is invalid")
        XCTAssertNil(HotKeyCombo(string: "⌘"), "a modifier with no key is invalid")
        XCTAssertNil(HotKeyCombo(string: "⌘⌥-"), "a non-alphanumeric key is invalid")
    }

    func testHotKeyComboParsesModifiersAndKey() {
        let combo = HotKeyCombo(string: "⌘⌥F")
        XCTAssertNotNil(combo)
        XCTAssertEqual(combo?.keyCode, UInt32(kVK_ANSI_F))
        XCTAssertEqual(combo!.carbonModifiers & UInt32(cmdKey), UInt32(cmdKey))
        XCTAssertEqual(combo!.carbonModifiers & UInt32(optionKey), UInt32(optionKey))
        XCTAssertEqual(combo!.carbonModifiers & UInt32(shiftKey), 0)
    }

    func testHotKeyComboIsCaseInsensitive() {
        XCTAssertEqual(HotKeyCombo(string: "⌃a")?.keyCode, UInt32(kVK_ANSI_A))
        XCTAssertEqual(HotKeyCombo(string: "⌃A")?.keyCode, UInt32(kVK_ANSI_A))
    }

    // MARK: - Session Timing (Robust)

    func testFocusSessionActualDuration_Robust() {
        // Use fixed dates to avoid timing dependency
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_001_500)
        let session = FocusSession(
            startTime: start,
            endTime: end,
            durationMinutes: 25,
            wasCompleted: true
        )
        XCTAssertEqual(session.actualDuration, 1500, accuracy: 0.001)
    }
}
