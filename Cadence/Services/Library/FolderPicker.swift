import AppKit
import Foundation

enum FolderPicker {
    @MainActor
    static func pickMusicFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Выберите папку с музыкой"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Открыть"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url
    }
}
