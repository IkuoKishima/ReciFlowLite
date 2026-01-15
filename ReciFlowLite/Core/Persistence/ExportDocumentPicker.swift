/// MARK: - ExportDocumentPicker.swift

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ExportDocumentPicker: UIViewControllerRepresentable {
    let fileURL: URL
    let onDone: (Bool) -> Void   // true: 保存完了 / false: キャンセル

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        vc.delegate = context.coordinator
        vc.shouldShowFileExtensions = true
        return vc
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDone: (Bool) -> Void
        init(onDone: @escaping (Bool) -> Void) { self.onDone = onDone }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDone(false)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // urls は保存先（プロバイダにより挙動差あり）
            onDone(true)
        }
    }
}
