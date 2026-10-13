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
    let generations: [CatalogGeneration]
}

struct CatalogGeneration: Decodable {
    let engines: [CatalogEngine]
}

struct CatalogEngine: Decodable {}

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

let makes = try JSONDecoder().decode([CatalogMake].self, from: decoded)
let modelCount = makes.reduce(0) { $0 + $1.models.count }
let generationCount = makes.reduce(0) { count, make in count + make.models.reduce(0) { $0 + $1.generations.count } }
let engineCount = makes.reduce(0) { count, make in
    count + make.models.reduce(0) { modelTotal, model in modelTotal + model.generations.reduce(0) { $0 + $1.engines.count } }
}
guard makes.count == 32, modelCount == 1389, generationCount == 4791, engineCount == 23572 else {
    fatalError("Unexpected catalog counts: \(makes.count) makes, \(modelCount) models, \(generationCount) generations, \(engineCount) engines")
}
print("Apple Compression catalog decode OK: \(makes.count) makes, \(modelCount) models")
