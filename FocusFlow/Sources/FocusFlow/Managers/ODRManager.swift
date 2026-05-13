import Foundation
import Combine

// MARK: - ODR Manager (On-Demand Resources)

@MainActor
final class ODRManager: NSObject, ObservableObject {
    static let shared = ODRManager()

    @Published var downloadProgress: [String: Double] = [:]  // soundId -> progress 0...1
    @Published var downloadingSoundIds: Set<String> = []

    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }()
    private var downloadContinuations: [String: CheckedContinuation<Data, Error>] = [:]
    private var downloadDataTasks: [String: URLSessionDataTask] = [:]
    private var downloadTasks: [String: Task<Void, Error>] = [:]
    private var accumulatedData: [String: Data] = [:]
    private var expectedLengths: [String: Int64] = [:]

    override private init() {
        super.init()
    }

    // MARK: - Check & Download

    func isSoundDownloaded(_ sound: Sound) -> Bool {
        if sound.isDownloaded { return true }  // Bundle sounds
        guard let localURL = sound.localURL else { return false }
        return FileManager.default.fileExists(atPath: localURL.path)
    }

    func downloadSound(_ sound: Sound) async throws {
        guard !isSoundDownloaded(sound) else { return }

        if let existingTask = downloadTasks[sound.id] {
            try await existingTask.value
            return
        }

        let task = Task { @MainActor in
            try await self.performDownload(sound)
        }
        downloadTasks[sound.id] = task

        do {
            try await task.value
            downloadTasks.removeValue(forKey: sound.id)
        } catch {
            downloadTasks.removeValue(forKey: sound.id)
            throw error
        }
    }

    func downloadSounds(_ sounds: [Sound]) async {
        for sound in sounds {
            do {
                try await downloadSound(sound)
            } catch {
                print("[ODR] Failed to download \(sound.name): \(error)")
            }
        }
    }

    func preloadProSounds() async {
        let proSounds = SoundCatalog.allSounds.filter { !$0.isFree }
        await downloadSounds(proSounds)
    }

    // MARK: - Lifecycle

    func invalidateSession() {
        for task in downloadTasks.values {
            task.cancel()
        }
        downloadTasks.removeAll()
        session.invalidateAndCancel()
    }

    private func performDownload(_ sound: Sound) async throws {
        guard let remoteURL = sound.remoteURL else { throw ODRError.invalidURL }

        downloadingSoundIds.insert(sound.id)
        downloadProgress[sound.id] = 0.05

        do {
            let data = try await downloadData(for: sound, remoteURL: remoteURL)
            let soundsDir = try soundsDirectory()
            try FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)

            let fileURL = soundsDir.appendingPathComponent(sound.fileName)
            try data.write(to: fileURL, options: .atomic)

            downloadProgress[sound.id] = 1.0
            downloadingSoundIds.remove(sound.id)
        } catch {
            resetDownloadState(for: sound.id, keepProgress: false)
            throw error
        }
    }

    private func downloadData(for sound: Sound, remoteURL: URL) async throws -> Data {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                downloadContinuations[sound.id] = continuation
                accumulatedData[sound.id] = Data()

                let task = session.dataTask(with: remoteURL)
                downloadDataTasks[sound.id] = task
                task.resume()
            }
        } onCancel: {
            Task { @MainActor in
                self.downloadDataTasks[sound.id]?.cancel()
            }
        }
    }

    private func resetDownloadState(for soundId: String, keepProgress: Bool) {
        downloadDataTasks.removeValue(forKey: soundId)
        downloadContinuations.removeValue(forKey: soundId)
        accumulatedData.removeValue(forKey: soundId)
        expectedLengths.removeValue(forKey: soundId)
        downloadingSoundIds.remove(soundId)
        if !keepProgress {
            downloadProgress.removeValue(forKey: soundId)
        }
    }

    private func soundsDirectory() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw ODRError.cacheDirectoryUnavailable
        }
        return appSupport.appendingPathComponent("FocusFlow/Sounds")
    }

    // MARK: - URLSessionDataDelegate (Progress Tracking)

    // Note: Using completionHandler-based delegate methods for macOS 13 compatibility.
    // The async delegate method variants require macOS 14+.

    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                                didReceive response: URLResponse,
                                completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let url = dataTask.originalRequest?.url?.lastPathComponent else {
            completionHandler(.cancel)
            return
        }
        let soundId = url.replacingOccurrences(of: ".aac", with: "")
        Task { @MainActor in
            self.expectedLengths[soundId] = httpResponse.expectedContentLength
            completionHandler(.allow)
        }
    }

    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                                didReceive data: Data) {
        guard let url = dataTask.originalRequest?.url?.lastPathComponent else { return }
        let soundId = url.replacingOccurrences(of: ".aac", with: "")
        Task { @MainActor in
            self.accumulatedData[soundId]?.append(data)

            if let expected = self.expectedLengths[soundId], expected > 0 {
                let current = Int64(self.accumulatedData[soundId]?.count ?? 0)
                self.downloadProgress[soundId] = max(0.05, min(0.95, Double(current) / Double(expected)))
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url?.lastPathComponent else { return }
        let soundId = url.replacingOccurrences(of: ".aac", with: "")

        Task { @MainActor in
            if let error = error {
                self.downloadContinuations[soundId]?.resume(throwing: error)
            } else if let data = self.accumulatedData[soundId], !data.isEmpty {
                self.downloadContinuations[soundId]?.resume(returning: data)
            } else {
                self.downloadContinuations[soundId]?.resume(throwing: ODRError.downloadFailed)
            }

            self.resetDownloadState(for: soundId, keepProgress: true)
        }
    }
}

// MARK: - URLSessionDataDelegate Conformance

extension ODRManager: URLSessionDataDelegate {}

// MARK: - Cache Management

extension ODRManager {

    func clearCache() throws {
        for task in downloadTasks.values {
            task.cancel()
        }
        downloadTasks.removeAll()
        downloadProgress.removeAll()
        downloadingSoundIds.removeAll()

        let soundsDir = try soundsDirectory()
        if FileManager.default.fileExists(atPath: soundsDir.path) {
            try FileManager.default.removeItem(at: soundsDir)
        }
    }

    func cacheSize() -> Int64 {
        guard let soundsDir = try? soundsDirectory() else { return 0 }
        guard FileManager.default.fileExists(atPath: soundsDir.path) else { return 0 }

        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: soundsDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                size += Int64(values?.fileSize ?? 0)
            }
        }
        return size
    }
}

enum ODRError: LocalizedError {
    case invalidURL
    case downloadFailed
    case cacheDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的音效下载链接"
        case .downloadFailed: return "音效下载失败，请检查网络连接"
        case .cacheDirectoryUnavailable: return "无法访问本地音效缓存目录"
        }
    }
}
