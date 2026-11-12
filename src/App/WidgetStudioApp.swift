import Observation
import SwiftUI
import WidgetKit

@Observable
final class DesignLibrary {
    var designs: [WidgetDesign] = []

    init() {
        DesignStore.seedIfNeeded()
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
        for i in offsets { DesignStore.deletePhoto(for: designs[i].id) }
        designs.remove(atOffsets: offsets)
        persist()
    }

    func duplicate(_ design: WidgetDesign) {
        var copy = design
        copy.id = UUID()
        copy.name = design.name + " 복사본"
        if let photo = DesignStore.loadPhoto(for: design.id) {
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
        }
    }
}
