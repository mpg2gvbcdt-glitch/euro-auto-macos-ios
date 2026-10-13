import Foundation
import SwiftData

@Model
final class Customer {
    var id: UUID
    var code: String
    var name: String
    var phone: String
    var email: String
    var city: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \Vehicle.customer)
    var vehicles: [Vehicle]? = []

    init(name: String, code: String = "", phone: String = "", email: String = "", city: String = "", notes: String = "") {
        self.id = UUID()
        self.code = code.isEmpty ? "C-\(UUID().uuidString.prefix(8))" : code
        self.name = name
        self.phone = phone
        self.email = email
        self.city = city
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
final class Vehicle {
    var id: UUID
    var vin: String
    var make: String
    var model: String
    var generation: String
    var engine: String
    var year: Int?
    var engineVolumeCc: Int?
    var enginePowerHp: Int?
    var engineType: String
    var bodyType: String
    var driveType: String
    var transmission: String
    var vehicleLengthMm: Int?
    var vehicleWidthMm: Int?
    var vehicleHeightMm: Int?
    var wheelbaseMm: Int?
    var curbWeightKg: Int?
    var engineCylinders: Int?
    var specSource: String
    var importType: String
    var customer: Customer?
    var originCountry: String
    var vehicleStatus: String
    var location: String
    var supplierInvoice: String
    var orderDate: Date?
    var clientContract: String
    var prepayment: Double
    var orderStatus: String
    var actualSalePrice: Double
    var documentsStatus: String
    var importerType: String
    var importRoute: String
    var purchaseDate: Date?
    var purchasePrice: Double
    var currency: String
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
    var salePrice: Double
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \VehicleDocument.vehicle)
    var documents: [VehicleDocument]? = []

    init(vin: String = "", make: String = "", model: String = "") {
        self.id = UUID()
        self.vin = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.make = make
        self.model = model
        self.generation = ""
        self.engine = ""
        self.year = nil
        self.engineVolumeCc = nil
        self.enginePowerHp = nil
        self.engineType = "Бензин"
        self.bodyType = ""
        self.driveType = ""
        self.transmission = ""
        self.vehicleLengthMm = nil
        self.vehicleWidthMm = nil
        self.vehicleHeightMm = nil
        self.wheelbaseMm = nil
        self.curbWeightKg = nil
        self.engineCylinders = nil
        self.specSource = ""
        self.importType = "На склад"
        self.customer = nil
        self.originCountry = ""
        self.vehicleStatus = "В пути"
        self.location = ""
        self.supplierInvoice = ""
        self.orderDate = nil
        self.clientContract = ""
        self.prepayment = 0
        self.orderStatus = "Новая заявка"
        self.actualSalePrice = 0
        self.documentsStatus = "Не проверены"
        self.importerType = "Юрлицо / ИП"
        self.importRoute = "Напрямую в Россию"
        self.purchaseDate = nil
        self.purchasePrice = 0
        self.currency = "EUR"
        self.fxRate = 1
        self.deliveryCost = 0
        self.deliveryCurrency = "EUR"
        self.deliveryFxRate = 1
        self.freightCost = 0
        self.freightCurrency = "EUR"
        self.freightFxRate = 1
        self.customsDuty = 0
        self.customsFees = 0
        self.recyclingFee = 0
        self.certificationCost = 0
        self.registrationCost = 0
        self.otherCosts = 0
        self.salePrice = 0
        self.notes = ""
        self.createdAt = .now
        self.updatedAt = .now
    }

    var deliveryCostRUB: Double { deliveryCost * (deliveryFxRate ?? 1) }
    var freightCostRUB: Double { freightCost * (freightFxRate ?? 1) }

    var totalCost: Double {
        purchasePrice * fxRate + deliveryCostRUB + freightCostRUB
            + customsDuty + customsFees
            + recyclingFee + certificationCost + registrationCost + otherCosts
    }

    var expectedProfit: Double { salePrice - totalCost }
}

@Model
final class VehicleDocument {
    var id: UUID
    var filename: String
    var contentType: String
    @Attribute(.externalStorage) var fileData: Data
    var createdAt: Date
    var remoteID: Int?
    var vehicle: Vehicle?

    init(filename: String, contentType: String, fileData: Data) {
        self.id = UUID()
        self.filename = filename
        self.contentType = contentType
        self.fileData = fileData
        self.createdAt = .now
        self.remoteID = nil
    }
}
