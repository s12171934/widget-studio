import SwiftUI
import UniformTypeIdentifiers

/// 라이브러리와 편집기에서 같은 네이티브 파일 선택기를 사용한다.
struct GIFFilePicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.gif], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let owner: GIFFilePicker
        init(_ owner: GIFFilePicker) { self.owner = owner }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { owner.onPick(url) }
            else { owner.onCancel() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { owner.onCancel() }
    }
}
