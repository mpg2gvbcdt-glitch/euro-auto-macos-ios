import Foundation
import SwiftData

struct PortableBackup: Codable {
    var formatVersion: Int = 1
    var exportedAt: String
    var customers: [BackupCustomer]
    var vehicles: [BackupVehicle]
}

struct BackupCustomer: Codable {
    var code: String
    var name: String
    var phone: String
    var email: String
    var city: String
    var notes: String
}

struct BackupVehicle: Codable {
    var id: String?
    var vin: String
    var make: String
    var model: String
    var generation: String
    var engine: String
    var year: Int?
    var engineVolumeCc: Int?
    var enginePowerHp: Int?
    var engineType: String
    var engineCylinders: Int?
    var bodyType: String
    var driveType: String
    var transmission: String
    var vehicleLengthMm: Int?
    var vehicleWidthMm: Int?
    var vehicleHeightMm: Int?
    var wheelbaseMm: Int?
    var curbWeightKg: Int?
    var specSource: String
    var originCountry: String
    var purchaseDate: String?
    var supplierInvoice: String
    var currency: String
    var purchasePrice: Double
    var fxRate: Double
    var deliveryCost: Double
    var deliveryCurrency: String?
    var deliveryFxRate: Double?
    var freightCost: Double
    var freightCurrency: String?
    var freightFxRate: Double?
    var customsDuty: Double
    var customsFees: Double
    var recyclingFee: Double
    var certificationCost: Double
    var registrationCost: Double
    var otherCosts: Double
    var importType: String
    var customerCode: String?
    var orderDate: String?
    var clientContract: String
    var salePrice: Double
    var prepayment: Double
    var orderStatus: String
    var actualSalePrice: Double
    var vehicleStatus: String
    var location: String
    var documentsStatus: String
    var importerType: String
    var importRoute: String
    var notes: String
    var createdAt: String
    var updatedAt: String
    var documents: [BackupDocument]
}

struct BackupDocument: Codable {
    var filename: String
    var contentType: String
    var createdAt: String
    var dataBase64: String
}

struct BackupImportResult {
    var customers: Int
    var vehicles: Int
    var documents: Int
    var skippedDocuments: Int
}

enum PortableBackupError: LocalizedError {
    case unsupportedVersion
    case invalidDocument(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "Формат резервной копии не поддерживается."
        case .invalidDocument(let name): "Не удалось восстановить документ «\(name)»."
        }
    }
}

@MainActor
enum PortableBackupService {
    static func makeBackup(context: ModelContext) throws -> Data {
        let customers = try context.fetch(FetchDescriptor<Customer>())
        let vehicles = try context.fetch(FetchDescriptor<Vehicle>())
        let backup = PortableBackup(
            exportedAt: timestamp(.now),
            customers: customers.map {
                BackupCustomer(code: $0.code, name: $0.name, phone: $0.phone, email: $0.email, city: $0.city, notes: $0.notes)
            },
            vehicles: vehicles.map { vehicle in
                BackupVehicle(
                    id: vehicle.id.uuidString, vin: vehicle.vin, make: vehicle.make, model: vehicle.model, generation: vehicle.generation,
                    engine: vehicle.engine, year: vehicle.year, engineVolumeCc: vehicle.engineVolumeCc,
                    enginePowerHp: vehicle.enginePowerHp, engineType: vehicle.engineType, engineCylinders: vehicle.engineCylinders,
                    bodyType: vehicle.bodyType, driveType: vehicle.driveType, transmission: vehicle.transmission,
                    vehicleLengthMm: vehicle.vehicleLengthMm, vehicleWidthMm: vehicle.vehicleWidthMm,
                    vehicleHeightMm: vehicle.vehicleHeightMm, wheelbaseMm: vehicle.wheelbaseMm, curbWeightKg: vehicle.curbWeightKg,
                    specSource: vehicle.specSource, originCountry: vehicle.originCountry, purchaseDate: day(vehicle.purchaseDate),
                    supplierInvoice: vehicle.supplierInvoice, currency: vehicle.currency, purchasePrice: vehicle.purchasePrice,
                    fxRate: vehicle.fxRate, deliveryCost: vehicle.deliveryCost,
                    deliveryCurrency: vehicle.deliveryCurrency, deliveryFxRate: vehicle.deliveryFxRate,
                    freightCost: vehicle.freightCost, freightCurrency: vehicle.freightCurrency, freightFxRate: vehicle.freightFxRate,
                    customsDuty: vehicle.customsDuty, customsFees: vehicle.customsFees, recyclingFee: vehicle.recyclingFee,
                    certificationCost: vehicle.certificationCost, registrationCost: vehicle.registrationCost, otherCosts: vehicle.otherCosts,
                    importType: vehicle.importType, customerCode: vehicle.customer?.code, orderDate: day(vehicle.orderDate),
                    clientContract: vehicle.clientContract, salePrice: vehicle.salePrice, prepayment: vehicle.prepayment,
                    orderStatus: vehicle.orderStatus, actualSalePrice: vehicle.actualSalePrice, vehicleStatus: vehicle.vehicleStatus,
                    location: vehicle.location, documentsStatus: vehicle.documentsStatus, importerType: vehicle.importerType,
                    importRoute: vehicle.importRoute, notes: vehicle.notes, createdAt: timestamp(vehicle.createdAt),
                    updatedAt: timestamp(vehicle.updatedAt), documents: (vehicle.documents ?? []).map {
                        BackupDocument(filename: $0.filename, contentType: $0.contentType,
                                       createdAt: timestamp($0.createdAt), dataBase64: $0.fileData.base64EncodedString())
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func importBackup(from url: URL, context: ModelContext) throws -> BackupImportResult {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let backup = try JSONDecoder().decode(PortableBackup.self, from: Data(contentsOf: url))
        guard backup.formatVersion == 1 else { throw PortableBackupError.unsupportedVersion }
        for item in backup.vehicles {
            for file in item.documents where Data(base64Encoded: file.dataBase64) == nil {
                throw PortableBackupError.invalidDocument(file.filename)
            }
        }

        var customersByCode: [String: Customer] = [:]
        for customer in try context.fetch(FetchDescriptor<Customer>()) {
            let key = customer.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !key.isEmpty, customersByCode[key] == nil { customersByCode[key] = customer }
        }
        for item in backup.customers {
            let key = item.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let customer = (key.isEmpty ? nil : customersByCode[key]) ?? Customer(name: item.name, code: item.code)
            customer.name = item.name
            customer.phone = item.phone
            customer.email = item.email
            customer.city = item.city
            customer.notes = item.notes
            if key.isEmpty || customersByCode[key] == nil {
                context.insert(customer)
                if !key.isEmpty { customersByCode[key] = customer }
            }
        }

        let existingVehicles = try context.fetch(FetchDescriptor<Vehicle>())
        var vehiclesByVIN: [String: Vehicle] = [:]
        var vehiclesByID = Dictionary(uniqueKeysWithValues: existingVehicles.map { ($0.id.uuidString.uppercased(), $0) })
        for vehicle in existingVehicles {
            let key = vehicle.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !key.isEmpty, vehiclesByVIN[key] == nil { vehiclesByVIN[key] = vehicle }
        }
        var importedVehicles = 0
        var importedDocuments = 0
        var skippedDocuments = 0
        for item in backup.vehicles {
            let vin = item.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let backupID = item.id?.uppercased()
            let existing = (!vin.isEmpty ? vehiclesByVIN[vin] : nil) ?? backupID.flatMap { vehiclesByID[$0] }
            let vehicle = existing ?? Vehicle(vin: vin)
            if existing == nil, let id = backupID.flatMap(UUID.init(uuidString:)) { vehicle.id = id }
            vehicle.vin = vin
            vehicle.make = item.make; vehicle.model = item.model; vehicle.generation = item.generation; vehicle.engine = item.engine
            vehicle.year = item.year; vehicle.engineVolumeCc = item.engineVolumeCc; vehicle.enginePowerHp = item.enginePowerHp
            vehicle.engineType = item.engineType; vehicle.engineCylinders = item.engineCylinders; vehicle.bodyType = item.bodyType
            vehicle.driveType = item.driveType; vehicle.transmission = item.transmission; vehicle.vehicleLengthMm = item.vehicleLengthMm
            vehicle.vehicleWidthMm = item.vehicleWidthMm; vehicle.vehicleHeightMm = item.vehicleHeightMm
            vehicle.wheelbaseMm = item.wheelbaseMm; vehicle.curbWeightKg = item.curbWeightKg; vehicle.specSource = item.specSource
            vehicle.originCountry = item.originCountry; vehicle.purchaseDate = parseDay(item.purchaseDate); vehicle.supplierInvoice = item.supplierInvoice
            vehicle.currency = item.currency; vehicle.purchasePrice = item.purchasePrice; vehicle.fxRate = item.fxRate
            vehicle.deliveryCost = item.deliveryCost; vehicle.deliveryCurrency = item.deliveryCurrency; vehicle.deliveryFxRate = item.deliveryFxRate
            vehicle.freightCost = item.freightCost; vehicle.freightCurrency = item.freightCurrency; vehicle.freightFxRate = item.freightFxRate
            vehicle.customsDuty = item.customsDuty
            vehicle.customsFees = item.customsFees; vehicle.recyclingFee = item.recyclingFee; vehicle.certificationCost = item.certificationCost
            vehicle.registrationCost = item.registrationCost; vehicle.otherCosts = item.otherCosts; vehicle.importType = item.importType
            vehicle.customer = item.customerCode.flatMap { customersByCode[$0.uppercased()] }
            vehicle.orderDate = parseDay(item.orderDate); vehicle.clientContract = item.clientContract; vehicle.salePrice = item.salePrice
            vehicle.prepayment = item.prepayment; vehicle.orderStatus = item.orderStatus; vehicle.actualSalePrice = item.actualSalePrice
            vehicle.vehicleStatus = item.vehicleStatus; vehicle.location = item.location; vehicle.documentsStatus = item.documentsStatus
            vehicle.importerType = item.importerType; vehicle.importRoute = item.importRoute; vehicle.notes = item.notes
            vehicle.createdAt = parseTimestamp(item.createdAt) ?? vehicle.createdAt
            vehicle.updatedAt = parseTimestamp(item.updatedAt) ?? .now
            if existing == nil {
                context.insert(vehicle)
                importedVehicles += 1
            }
            vehiclesByID[vehicle.id.uuidString.uppercased()] = vehicle
            if !vin.isEmpty { vehiclesByVIN[vin] = vehicle }

            for file in item.documents {
                if (vehicle.documents ?? []).contains(where: { $0.filename == file.filename && timestamp($0.createdAt) == file.createdAt }) {
                    skippedDocuments += 1
                    continue
                }
                guard let bytes = Data(base64Encoded: file.dataBase64) else { throw PortableBackupError.invalidDocument(file.filename) }
                let document = VehicleDocument(filename: file.filename, contentType: file.contentType, fileData: bytes)
                document.createdAt = parseTimestamp(file.createdAt) ?? .now
                document.vehicle = vehicle
                vehicle.documents = (vehicle.documents ?? []) + [document]
                context.insert(document)
                importedDocuments += 1
            }
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
        return BackupImportResult(customers: backup.customers.count, vehicles: importedVehicles,
                                  documents: importedDocuments, skippedDocuments: skippedDocuments)
    }

    private static func day(_ value: Date?) -> String? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    private static func parseDay(_ value: String?) -> Date? {
        guard let value else { return nil }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return ISO8601DateFormatter().date(from: value) }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func timestamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    private static func parseTimestamp(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}
