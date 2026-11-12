import Observation
import SwiftUI
import WidgetKit

@Observable
final class DesignLibrary {
    var designs: [WidgetDesign] = []
    var errorMessage: String?

    init() {
        DesignStore.seedIfNeeded()
        DesignStore.removeLegacyGlassData()
        designs = DesignStore.load()
    }

    func upsert(_ design: WidgetDesign) {
        var d = design
        d.updatedAt = .now
        if let i = designs.firstIndex(where: { $0.id == d.id }) {
            designs[i] = d
        } else {
            designs.insert(d, at: 0)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        for i in offsets.sorted(by: >) {
            do {
                try DesignStore.deleteGIF(for: designs[i].id)
                DesignStore.deletePhoto(for: designs[i].id)
                designs.remove(at: i)
            } catch { errorMessage = error.localizedDescription }
        }
        persist()
    }

    func duplicate(_ design: WidgetDesign) {
        var copy = design
        copy.id = UUID()
        copy.name = design.name + " 복사본"
        if design.template == .gif {
            do { try DesignStore.copyGIF(from: design.id, to: copy.id) }
            catch { errorMessage = error.localizedDescription; return }
        } else if let photo = DesignStore.loadPhoto(for: design.id) {
            DesignStore.savePhoto(photo, for: copy.id)
        }
        upsert(copy)
    }

    private func persist() {
        DesignStore.save(designs)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

@main
struct WidgetStudioApp: App {
    @State private var library = DesignLibrary()

    var body: some Scene {
        WindowGroup {
            DesignListView()
                .environment(library)
                .task {
                    // 이전 버전에 저장한 GIF도 다시 고르지 않고 홈 재생을 시작하게 한다.
                    let ids = library.designs.filter { $0.template == .gif }.map(\.id)
                    let migrated = await Task.detached(priority: .utility) {
                        var changed = false
                        for id in ids where !DesignStore.hasGIFFrames(for: id) {
                            if DesignStore.prepareGIFFrames(for: id) { changed = true }
                        }
                        return changed
                    }.value
                    if migrated { WidgetCenter.shared.reloadAllTimelines() }
                }
        }
    }
}
