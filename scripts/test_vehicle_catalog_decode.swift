import Compression
import Foundation

struct CatalogEnvelope: Decodable {
    let encoding: String
    let uncompressedBytes: Int
    let data: String
}

struct CatalogMake: Decodable {
    let make: String
    let models: [CatalogModel]
}

struct CatalogModel: Decodable {
    let n: String
    let generations: [CatalogGeneration]
}

struct CatalogGeneration: Decodable {
    let n: String
    let from: Int?
    let to: Int?
    let body: String?
    let engines: [CatalogEngine]
}

struct CatalogEngine: Decodable {
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

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: test_vehicle_catalog_decode.swift <vehicle-catalog.json>")
}

let resource = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let envelope = try JSONDecoder().decode(CatalogEnvelope.self, from: resource)
guard envelope.encoding == "deflate-base64",
      envelope.uncompressedBytes > 0,
      let compressed = Data(base64Encoded: envelope.data) else {
    fatalError("Invalid compressed catalog envelope")
}

var decoded = Data(count: envelope.uncompressedBytes)
let decodedCount = compressed.withUnsafeBytes { source in
    decoded.withUnsafeMutableBytes { destination in
        guard let src = source.bindMemory(to: UInt8.self).baseAddress,
              let dst = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
        return compression_decode_buffer(dst, envelope.uncompressedBytes, src, compressed.count, nil, COMPRESSION_ZLIB)
    }
}
guard decodedCount == envelope.uncompressedBytes else { fatalError("Catalog decompression failed") }

let makes: [CatalogMake]
do {
    makes = try JSONDecoder().decode([CatalogMake].self, from: decoded)
} catch {
    fatalError("Full catalog model decode failed: \(error)")
}
let modelCount = makes.reduce(0) { $0 + $1.models.count }
let generationCount = makes.reduce(0) { count, make in count + make.models.reduce(0) { $0 + $1.generations.count } }
let engineCount = makes.reduce(0) { count, make in
    count + make.models.reduce(0) { modelTotal, model in modelTotal + model.generations.reduce(0) { $0 + $1.engines.count } }
}
guard makes.count == 32, modelCount == 1389, generationCount == 3841, engineCount == 23432 else {
    fatalError("Unexpected catalog counts: \(makes.count) makes, \(modelCount) models, \(generationCount) generations, \(engineCount) engines")
}
let bmw = makes.first { $0.make == "BMW" }
let series3 = bmw?.models.first { $0.n == "3 Series" }
let touringLabels = Set(series3?.generations.map(\.n).filter { $0.contains("Touring") } ?? [])
guard touringLabels.contains("3 Series Touring · G21 (2019–2026)"),
      touringLabels.contains("3 Series Touring · F31 (2012–2019)") else {
    fatalError("BMW 3 Series Touring body codes or production ranges are missing")
}
print("Apple Compression and full catalog decode OK: \(makes.count) makes, \(modelCount) models, \(generationCount) generation groups, \(engineCount) distinct engines; BMW Touring mappings verified")
