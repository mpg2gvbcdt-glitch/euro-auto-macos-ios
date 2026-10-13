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
    let yf: Int?
    let yt: Int?
    var id: String { "\(n)|\(yf ?? 0)|\(yt ?? 0)|\(cc ?? 0)|\(hp ?? 0)" }

    private enum CodingKeys: String, CodingKey {
        case n, f, cy, cc, hp, dr, tr, l, w, h, wb, kg, yf, yt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        n = try values.decode(String.self, forKey: .n)
        f = try values.decodeIfPresent(String.self, forKey: .f)
        cy = try values.decodeCatalogInteger(forKey: .cy)
        cc = try values.decodeCatalogInteger(forKey: .cc)
        hp = try values.decodeCatalogInteger(forKey: .hp)
        dr = try values.decodeIfPresent(String.self, forKey: .dr)
        tr = try values.decodeIfPresent(String.self, forKey: .tr)
        l = try values.decodeCatalogInteger(forKey: .l)
        w = try values.decodeCatalogInteger(forKey: .w)
        h = try values.decodeCatalogInteger(forKey: .h)
        wb = try values.decodeCatalogInteger(forKey: .wb)
        kg = try values.decodeCatalogInteger(forKey: .kg)
        yf = try values.decodeCatalogInteger(forKey: .yf)
        yt = try values.decodeCatalogInteger(forKey: .yt)
    }

    func isAvailable(in year: Int?) -> Bool {
        guard let year else { return true }
        if let yf, year < yf { return false }
        if let yt, year > yt { return false }
        return true
    }

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

private extension KeyedDecodingContainer {
    func decodeCatalogInteger(forKey key: Key) throws -> Int? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        if let integer = try? decode(Int.self, forKey: key) { return integer }

        let number = try decode(Double.self, forKey: key)
        guard number.isFinite,
              number >= Double(Int.min),
              number <= Double(Int.max) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Catalog value must be a finite number within the Int range."
            )
        }
        return Int(number.rounded())
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
