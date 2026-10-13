import Foundation
import UniformTypeIdentifiers

enum VehicleDocumentError: LocalizedError {
    case fileTooLarge
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: "Файл больше 20 МБ."
        case .unsupportedType: "Поддерживаются PDF, JPG, PNG и WebP."
        }
    }
}

enum VehicleDocumentStore {
    static func importFile(at sourceURL: URL) throws -> VehicleDocument {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 20 * 1024 * 1024 else {
            throw VehicleDocumentError.fileTooLarge
        }
        let data = try Data(contentsOf: sourceURL)
        guard data.count <= 20 * 1024 * 1024 else { throw VehicleDocumentError.fileTooLarge }

        let type = UTType(filenameExtension: sourceURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        guard ["application/pdf", "image/jpeg", "image/png", "image/webp"].contains(type) else {
            throw VehicleDocumentError.unsupportedType
        }
        return VehicleDocument(
            filename: sourceURL.lastPathComponent,
            contentType: type,
            fileData: data
        )
    }

    static func url(for document: VehicleDocument) -> URL? {
        do {
            let directory = try cacheDirectory()
            let filename = "\(document.id.uuidString)_\(document.filename)"
            let destination = directory.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try document.fileData.write(to: destination, options: .atomic)
            }
            return destination
        } catch {
            return nil
        }
    }

    static func delete(_ document: VehicleDocument) {
        guard let url = try? cacheDirectory().appendingPathComponent("\(document.id.uuidString)_\(document.filename)") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func cacheDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("EuroAuto/DocumentCache", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
