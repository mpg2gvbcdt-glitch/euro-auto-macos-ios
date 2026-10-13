import Foundation
import Observation
import Compression

struct CatalogMake: Decodable, Identifiable {
    let make: String
    let models: [CatalogModel]
    var id: String { make }
}

struct CatalogModel: Decodable, Identifiable {
    let n: String
    let generations: [CatalogGeneration]
    var id: String { n }
}

struct CatalogGeneration: Decodable, Identifiable {
    let n: String
    let from: Int?
    let to: Int?
    let body: String?
    let engines: [CatalogEngine]
    var id: String { n }
}

struct CatalogEngine: Decodable, Identifiable {
    let n: String
    let f: String?
    let cy: Int?
    let cc: Int?
    let hp: Int?
    let dr: String?
    let tr: String?
    let l: Int?
    let w: Int?
    let h: Int?
    let wb: Int?
    let kg: Int?
    var id: String { n }

    var localizedFuel: String {
        switch (f ?? "").lowercased() {
        case "gasoline", "petrol": "Бензин"
        case "diesel": "Дизель"
        case "electric": "Электро"
        case "hybrid": "Гибрид"
        default: f ?? ""
        }
    }

    var localizedDrive: String {
        switch (dr ?? "").lowercased() {
        case "front wheel drive": "Передний"
        case "rear wheel drive": "Задний"
        case "all wheel drive", "four wheel drive": "Полный"
        default: dr ?? ""
        }
    }
}

@MainActor
@Observable
final class VehicleCatalogStore {
    static let shared = VehicleCatalogStore()

    private(set) var makes: [CatalogMake] = []
    private(set) var loadError: String?

    private init() {
        guard let url = Bundle.main.url(forResource: "vehicle-catalog", withExtension: "json") else {
            loadError = "Не найден локальный каталог автомобилей."
            return
        }
        do {
            let resource = try Data(contentsOf: url)
            let catalogData = try Self.decodeCatalogResource(resource)
            makes = try JSONDecoder().decode([CatalogMake].self, from: catalogData)
                .sorted { $0.make.localizedStandardCompare($1.make) == .orderedAscending }
            if makes.isEmpty { loadError = "Каталог автомобилей пуст." }
        } catch {
            loadError = "Не удалось прочитать каталог: \(error.localizedDescription)"
        }
    }

    private struct CompressedCatalog: Decodable {
        let encoding: String
        let uncompressedBytes: Int
        let data: String
    }

    private static func decodeCatalogResource(_ resource: Data) throws -> Data {
        guard let envelope = try? JSONDecoder().decode(CompressedCatalog.self, from: resource) else {
            return resource
        }
        guard envelope.encoding == "deflate-base64",
              envelope.uncompressedBytes > 0,
              envelope.uncompressedBytes <= 20_000_000,
              let compressed = Data(base64Encoded: envelope.data) else {
            throw CatalogError.invalidEnvelope
        }

        var decoded = Data(count: envelope.uncompressedBytes)
        let decodedCount = compressed.withUnsafeBytes { source in
            decoded.withUnsafeMutableBytes { destination in
                guard let sourceAddress = source.bindMemory(to: UInt8.self).baseAddress,
                      let destinationAddress = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    destinationAddress,
                    envelope.uncompressedBytes,
                    sourceAddress,
                    compressed.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedCount == envelope.uncompressedBytes else { throw CatalogError.decompressionFailed }
        return decoded
    }

    private enum CatalogError: Error {
        case invalidEnvelope
        case decompressionFailed
    }

    func models(for make: String) -> [CatalogModel] {
        makes.first(where: { $0.make == make })?.models ?? []
    }

    func generations(for make: String, model: String) -> [CatalogGeneration] {
        models(for: make).first(where: { $0.n == model })?.generations ?? []
    }

    func engines(for make: String, model: String, generation: String) -> [CatalogEngine] {
        generations(for: make, model: model).first(where: { $0.n == generation })?.engines ?? []
    }
}
