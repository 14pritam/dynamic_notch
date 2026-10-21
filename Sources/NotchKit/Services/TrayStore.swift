import AppKit
import Observation
import QuickLookThumbnailing

/// Files dropped on the notch, kept until the user drags them out or removes them.
/// Items are references to the original files (nothing is copied), saved across launches.
@MainActor
@Observable
public final class TrayStore {
    public struct Item: Identifiable, Equatable, Sendable, Codable {
        public let id: UUID
        public let url: URL
        public let addedAt: Date

        public var name: String { url.lastPathComponent }
    }

    public private(set) var items: [Item] = []
    /// Quick Look thumbnails, filled in lazily.
    public private(set) var thumbnails: [UUID: NSImage] = [:]

    public static let capacity = 30

    @ObservationIgnored private let storeURL: URL?
    @ObservationIgnored private let fileManager: FileManager

    /// `folder` is where the list is saved; nil keeps it in memory only (tests).
    public init(folder: URL? = TrayStore.defaultFolder, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        storeURL = folder?.appendingPathComponent("tray.json")
        load()
    }

    public nonisolated static var defaultFolder: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Dynamic Notch", isDirectory: true)
    }

    // MARK: Changes

    /// Adds files, skipping ones already in the tray and anything that isn't a file on disk.
    /// Returns how many were added.
    @discardableResult
    public func add(_ urls: [URL], now: Date = Date()) -> Int {
        let existing = Set(items.map { $0.url.standardizedFileURL })
        var added: [Item] = []
        for url in urls where url.isFileURL {
            let standard = url.standardizedFileURL
            guard !existing.contains(standard), !added.contains(where: { $0.url == standard }),
                  fileManager.fileExists(atPath: standard.path) else { continue }
            added.append(Item(id: UUID(), url: standard, addedAt: now))
        }
        guard !added.isEmpty else { return 0 }
        // Newest first; the oldest fall off past capacity.
        items = Array((added.reversed() + items).prefix(Self.capacity))
        save()
        added.forEach(loadThumbnail)
        return added.count
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        thumbnails[id] = nil
        save()
    }

    public func removeAll() {
        items.removeAll()
        thumbnails.removeAll()
        save()
    }

    /// Drops items whose files were moved or deleted since they were added.
    public func pruneMissing() {
        let kept = items.filter { fileManager.fileExists(atPath: $0.url.path) }
        guard kept.count != items.count else { return }
        let keptIDs = Set(kept.map(\.id))
        thumbnails = thumbnails.filter { keptIDs.contains($0.key) }
        items = kept
        save()
    }

    // MARK: Actions

    public func open(_ item: Item) {
        NSWorkspace.shared.open(item.url)
    }

    public func revealInFinder(_ item: Item) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    public func icon(for item: Item) -> NSImage {
        thumbnails[item.id] ?? NSWorkspace.shared.icon(forFile: item.url.path)
    }

    // MARK: Storage

    private func load() {
        guard let storeURL, let data = try? Data(contentsOf: storeURL),
              let saved = try? JSONDecoder().decode([Item].self, from: data) else { return }
        items = saved.filter { fileManager.fileExists(atPath: $0.url.path) }
        items.forEach(loadThumbnail)
    }

    private func save() {
        guard let storeURL else { return }
        do {
            try fileManager.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: storeURL, options: .atomic)
        } catch {
            // The tray still works for this session; it just won't survive a relaunch.
        }
    }

    private func loadThumbnail(_ item: Item) {
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 64, height: 64),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        let id = item.id
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let cgImage = representation?.cgImage else { return }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            let image = cgImage
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.items.contains(where: { $0.id == id }) else { return }
                    self.thumbnails[id] = NSImage(cgImage: image, size: size)
                }
            }
        }
    }
}
