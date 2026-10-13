import Foundation
import SwiftData
import Security
import CryptoKit

struct WebsiteSyncReport {
    var uploadedVehicles = 0
    var updatedVehicles = 0
    var downloadedVehicles = 0
    var deletedVehicles = 0
    var uploadedCustomers = 0
    var updatedCustomers = 0
    var downloadedCustomers = 0
    var deletedCustomers = 0
    var uploadedDocuments = 0
    var downloadedDocuments = 0
    var deletedDocuments = 0
    var skippedVehiclesWithoutVIN = 0

    var summary: String {
        "Автомобили: \(uploadedVehicles) новых отправлено, \(updatedVehicles) обновлено, \(downloadedVehicles) получено, \(deletedVehicles) удалено. Заказчики: \(uploadedCustomers) новых отправлено, \(updatedCustomers) обновлено, \(downloadedCustomers) получено, \(deletedCustomers) удалено. Документы: \(uploadedDocuments) отправлено, \(downloadedDocuments) получено, \(deletedDocuments) удалено."
            + (skippedVehiclesWithoutVIN > 0 ? " Пропущено машин без VIN: \(skippedVehiclesWithoutVIN)." : "")
    }
}

enum WebsiteSyncError: LocalizedError {
    case missingPassword
    case invalidServerURL
    case server(String)
    case conflict(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingPassword: "Введите пароль сайта 11/35 для первой синхронизации."
        case .invalidServerURL: "Проверьте адрес сервера синхронизации."
        case .server(let message): message
        case .conflict(let message): message
        case .invalidResponse: "Сервер вернул неожиданный ответ. Повторите синхронизацию."
        }
    }
}

private struct LoginPayload: Encodable { var password: String }
private struct SessionReply: Decodable { var authenticated: Bool? }
private struct ErrorReply: Decodable { var error: String? }
private struct CustomersReply: Decodable { var customers: [RemoteCustomer] }
private struct CarsReply: Decodable { var cars: [RemoteVehicle] }
private struct DocumentsReply: Decodable { var documents: [RemoteDocument] }
private struct CustomerReply: Decodable { var customer: RemoteCustomer }
private struct CarReply: Decodable { var vehicle: RemoteVehicle }
private struct DocumentReply: Decodable { var document: RemoteDocument }
private struct OperationReply: Decodable { var ok: Bool? }

private struct RemoteCustomer: Decodable {
    var id: Int
    var code: String
    var name: String
    var phone: String
    var email: String
    var city: String
    var notes: String
    var createdAt: String?
    var updatedAt: String?
}

private struct RemoteVehicle: Decodable {
    var id: Int
    var vin: String
    var make: String
    var model: String
    var year: Int?
    var originCountry: String
    var purchaseDate: String
    var supplierInvoice: String
    var currency: String
    var purchasePrice: Double
    var fxRate: Double
    var deliveryCost: Double
    var freightCost: Double
    var customsDuty: Double
    var customsFees: Double
    var recyclingFee: Double
    var certificationCost: Double
    var registrationCost: Double
    var otherCosts: Double
    var importType: String
    var customerId: Int?
    var orderDate: String
    var clientContract: String
    var salePrice: Double
    var prepayment: Double
    var orderStatus: String
    var actualSalePrice: Double
    var vehicleStatus: String
    var location: String
    var documentsStatus: String
    var notes: String
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
    var importerType: String
    var importRoute: String
    var nativeMetadata: NativeVehicleMetadata?
    var createdAt: String?
    var updatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, vin, make, model, year, originCountry, purchaseDate, supplierInvoice, currency, purchasePrice, fxRate
        case deliveryCost, freightCost, customsDuty, customsFees, recyclingFee, certificationCost, registrationCost, otherCosts
        case importType, customerId, orderDate, clientContract, salePrice, prepayment, orderStatus, actualSalePrice
        case vehicleStatus, location, documentsStatus, notes, engineVolumeCc, enginePowerHp, engineType, engineCylinders
        case bodyType, driveType, transmission, vehicleLengthMm, vehicleWidthMm, vehicleHeightMm, wheelbaseMm, curbWeightKg
        case specSource, importerType, importRoute, nativeMetadata, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        vin = try c.decodeIfPresent(String.self, forKey: .vin) ?? ""
        make = try c.decodeIfPresent(String.self, forKey: .make) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        originCountry = try c.decodeIfPresent(String.self, forKey: .originCountry) ?? ""
        purchaseDate = try c.decodeIfPresent(String.self, forKey: .purchaseDate) ?? ""
        supplierInvoice = try c.decodeIfPresent(String.self, forKey: .supplierInvoice) ?? ""
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "EUR"
        purchasePrice = try c.decodeIfPresent(Double.self, forKey: .purchasePrice) ?? 0
        fxRate = try c.decodeIfPresent(Double.self, forKey: .fxRate) ?? 1
        deliveryCost = try c.decodeIfPresent(Double.self, forKey: .deliveryCost) ?? 0
        freightCost = try c.decodeIfPresent(Double.self, forKey: .freightCost) ?? 0
        customsDuty = try c.decodeIfPresent(Double.self, forKey: .customsDuty) ?? 0
        customsFees = try c.decodeIfPresent(Double.self, forKey: .customsFees) ?? 0
        recyclingFee = try c.decodeIfPresent(Double.self, forKey: .recyclingFee) ?? 0
        certificationCost = try c.decodeIfPresent(Double.self, forKey: .certificationCost) ?? 0
        registrationCost = try c.decodeIfPresent(Double.self, forKey: .registrationCost) ?? 0
        otherCosts = try c.decodeIfPresent(Double.self, forKey: .otherCosts) ?? 0
        importType = try c.decodeIfPresent(String.self, forKey: .importType) ?? "На склад"
        customerId = try c.decodeIfPresent(Int.self, forKey: .customerId)
        orderDate = try c.decodeIfPresent(String.self, forKey: .orderDate) ?? ""
        clientContract = try c.decodeIfPresent(String.self, forKey: .clientContract) ?? ""
        salePrice = try c.decodeIfPresent(Double.self, forKey: .salePrice) ?? 0
        prepayment = try c.decodeIfPresent(Double.self, forKey: .prepayment) ?? 0
        orderStatus = try c.decodeIfPresent(String.self, forKey: .orderStatus) ?? "Новая заявка"
        actualSalePrice = try c.decodeIfPresent(Double.self, forKey: .actualSalePrice) ?? 0
        vehicleStatus = try c.decodeIfPresent(String.self, forKey: .vehicleStatus) ?? "В пути"
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        documentsStatus = try c.decodeIfPresent(String.self, forKey: .documentsStatus) ?? "Не проверены"
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        engineVolumeCc = try c.decodeIfPresent(Int.self, forKey: .engineVolumeCc)
        enginePowerHp = try c.decodeIfPresent(Int.self, forKey: .enginePowerHp)
        engineType = try c.decodeIfPresent(String.self, forKey: .engineType) ?? "Бензин"
        engineCylinders = try c.decodeIfPresent(Int.self, forKey: .engineCylinders)
        bodyType = try c.decodeIfPresent(String.self, forKey: .bodyType) ?? ""
        driveType = try c.decodeIfPresent(String.self, forKey: .driveType) ?? ""
        transmission = try c.decodeIfPresent(String.self, forKey: .transmission) ?? ""
        vehicleLengthMm = try c.decodeIfPresent(Int.self, forKey: .vehicleLengthMm)
        vehicleWidthMm = try c.decodeIfPresent(Int.self, forKey: .vehicleWidthMm)
        vehicleHeightMm = try c.decodeIfPresent(Int.self, forKey: .vehicleHeightMm)
        wheelbaseMm = try c.decodeIfPresent(Int.self, forKey: .wheelbaseMm)
        curbWeightKg = try c.decodeIfPresent(Int.self, forKey: .curbWeightKg)
        specSource = try c.decodeIfPresent(String.self, forKey: .specSource) ?? ""
        importerType = try c.decodeIfPresent(String.self, forKey: .importerType) ?? "Юрлицо / ИП"
        importRoute = try c.decodeIfPresent(String.self, forKey: .importRoute) ?? "Напрямую в Россию"
        nativeMetadata = try? c.decodeIfPresent(NativeVehicleMetadata.self, forKey: .nativeMetadata)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

private struct RemoteDocument: Decodable {
    var id: Int
    var filename: String
    var contentType: String
    var fileSize: Int
    var createdAt: String?
}

private struct NativeVehicleMetadata: Codable {
    var generation: String
    var engine: String
    var deliveryCurrency: String?
    var deliveryFxRate: Double?
    var freightCurrency: String?
    var freightFxRate: Double?
}

private struct CustomerPayload: Encodable {
    var code: String; var name: String; var phone: String; var email: String; var city: String; var notes: String
    var expectedUpdatedAt: String?
}

private struct VehiclePayload: Encodable {
    var vin: String; var make: String; var model: String; var year: Int?
    var originCountry: String; var purchaseDate: String; var supplierInvoice: String
    var currency: String; var purchasePrice: Double; var fxRate: Double
    var deliveryCost: Double; var freightCost: Double; var customsDuty: Double; var customsFees: Double
    var recyclingFee: Double; var certificationCost: Double; var registrationCost: Double; var otherCosts: Double
    var importType: String; var customerId: Int?; var orderDate: String; var clientContract: String
    var salePrice: Double; var prepayment: Double; var orderStatus: String; var actualSalePrice: Double
    var vehicleStatus: String; var location: String; var documentsStatus: String; var notes: String
    var engineVolumeCc: Int?; var enginePowerHp: Int?; var engineType: String; var engineCylinders: Int?
    var bodyType: String; var driveType: String; var transmission: String
    var vehicleLengthMm: Int?; var vehicleWidthMm: Int?; var vehicleHeightMm: Int?; var wheelbaseMm: Int?
    var curbWeightKg: Int?; var specSource: String; var importerType: String; var importRoute: String
    var nativeMetadata: NativeVehicleMetadata
    var expectedUpdatedAt: String?
}

@MainActor
enum WebsiteSyncService {
    static let defaultServer = "https://euro-auto-office.primecabin8.chatgpt.site"
    private static let serverKey = "11-35.sync.server"

    static var savedServer: String {
        UserDefaults.standard.string(forKey: serverKey) ?? defaultServer
    }

    static var hasPassword: Bool { (try? WebsiteSyncKeyStore.read()) != nil }

    static func forgetPassword() throws { try WebsiteSyncKeyStore.delete() }

    static func markVehicleDeleted(vin: String) {
        SyncTombstones.add(vin: vin)
    }

    static func markCustomerDeleted(code: String) {
        SyncTombstones.add(customerCode: code)
    }

    static func markDocumentDeleted(remoteID: Int?) {
        guard let remoteID else { return }
        SyncTombstones.add(documentID: remoteID)
    }

    static func synchronize(server: String, password: String, context: ModelContext) async throws -> WebsiteSyncReport {
        let base = try normalizedServer(server)
        UserDefaults.standard.set(base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")), forKey: serverKey)
        let entered = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let credential = !entered.isEmpty ? entered : try WebsiteSyncKeyStore.read()
        try await ensureSession(base: base, password: credential, forceLogin: !entered.isEmpty)
        try WebsiteSyncKeyStore.save(credential)

        var report = WebsiteSyncReport()
        var remoteCustomers = try await request(CustomersReply.self, base: base, path: "/api/customers")
        var remoteCars = try await request(CarsReply.self, base: base, path: "/api/cars")
        try await applyPendingDeletions(base: base, remoteCustomers: &remoteCustomers, remoteCars: &remoteCars, report: &report)
        var localCustomers = try context.fetch(FetchDescriptor<Customer>())
        var localCustomersByCode = Dictionary(localCustomers.map { ($0.code.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        var remoteCustomersByCode = Dictionary(remoteCustomers.customers.map { ($0.code.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })

        for local in localCustomers {
            guard !local.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let key = local.code.uppercased()
            let localPayload = customerPayload(local)
            if let remote = remoteCustomersByCode[key] {
                if (local.updatedAt ?? local.createdAt) > (parseDate(remote.updatedAt) ?? .distantPast) {
                    var payload = localPayload
                    payload.expectedUpdatedAt = remote.updatedAt
                    let updated = try await request(CustomerReply.self, base: base, path: "/api/customers?id=\(remote.id)", method: "PATCH", body: JSONEncoder().encode(payload))
                    local.updatedAt = parseDate(updated.customer.updatedAt) ?? .now
                    report.updatedCustomers += 1
                } else {
                    apply(remote, to: local)
                }
            } else {
                let created = try await request(CustomerReply.self, base: base, path: "/api/customers", method: "POST", body: JSONEncoder().encode(localPayload))
                local.updatedAt = parseDate(created.customer.updatedAt) ?? .now
                report.uploadedCustomers += 1
            }
        }

        remoteCustomers = try await request(CustomersReply.self, base: base, path: "/api/customers")
        remoteCustomersByCode = Dictionary(remoteCustomers.customers.map { ($0.code.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        localCustomers = try context.fetch(FetchDescriptor<Customer>())
        localCustomersByCode = Dictionary(localCustomers.map { ($0.code.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        for remote in remoteCustomers.customers where localCustomersByCode[remote.code.uppercased()] == nil {
            let customer = Customer(name: remote.name, code: remote.code)
            apply(remote, to: customer)
            context.insert(customer)
            localCustomersByCode[remote.code.uppercased()] = customer
            report.downloadedCustomers += 1
        }

        remoteCars = try await request(CarsReply.self, base: base, path: "/api/cars")
        var localCars = try context.fetch(FetchDescriptor<Vehicle>())
        var localCarsByVIN = Dictionary(localCars.filter { !$0.vin.isEmpty }.map { ($0.vin.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        var remoteCarsByVIN = Dictionary(remoteCars.cars.map { ($0.vin.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })

        report.skippedVehiclesWithoutVIN = localCars.filter { $0.vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        for local in localCars where !local.vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = local.vin.uppercased()
            let customerID = local.customer.flatMap { remoteCustomersByCode[$0.code.uppercased()]?.id }
            if let remote = remoteCarsByVIN[key] {
                if local.updatedAt > (parseDate(remote.updatedAt) ?? .distantPast) {
                    let payload = vehiclePayload(local, customerID: customerID, expectedUpdatedAt: remote.updatedAt)
                    let updated = try await request(CarReply.self, base: base, path: "/api/cars?id=\(remote.id)", method: "PATCH", body: JSONEncoder().encode(payload))
                    local.updatedAt = parseDate(updated.vehicle.updatedAt) ?? .now
                    report.updatedVehicles += 1
                } else {
                    apply(remote, to: local, customersByID: Dictionary(uniqueKeysWithValues: remoteCustomers.customers.map { ($0.id, $0) }), localCustomers: localCustomersByCode)
                }
            } else {
                let payload = vehiclePayload(local, customerID: customerID, expectedUpdatedAt: nil)
                let created = try await request(CarReply.self, base: base, path: "/api/cars", method: "POST", body: JSONEncoder().encode(payload))
                local.updatedAt = parseDate(created.vehicle.updatedAt) ?? .now
                report.uploadedVehicles += 1
            }
        }

        remoteCars = try await request(CarsReply.self, base: base, path: "/api/cars")
        remoteCarsByVIN = Dictionary(remoteCars.cars.map { ($0.vin.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        localCars = try context.fetch(FetchDescriptor<Vehicle>())
        localCarsByVIN = Dictionary(localCars.filter { !$0.vin.isEmpty }.map { ($0.vin.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let customersByID = Dictionary(uniqueKeysWithValues: remoteCustomers.customers.map { ($0.id, $0) })
        for remote in remoteCars.cars where localCarsByVIN[remote.vin.uppercased()] == nil {
            let vehicle = Vehicle(vin: remote.vin, make: remote.make, model: remote.model)
            apply(remote, to: vehicle, customersByID: customersByID, localCustomers: localCustomersByCode)
            context.insert(vehicle)
            localCarsByVIN[remote.vin.uppercased()] = vehicle
            report.downloadedVehicles += 1
        }

        try await synchronizeDocuments(base: base, context: context, localVehiclesByVIN: localCarsByVIN, remoteCarsByVIN: remoteCarsByVIN, report: &report)
        do { try context.save() }
        catch { context.rollback(); throw error }
        return report
    }

    private static func applyPendingDeletions(base: URL, remoteCustomers: inout CustomersReply, remoteCars: inout CarsReply, report: inout WebsiteSyncReport) async throws {
        for id in SyncTombstones.documentIDs {
            _ = try await request(OperationReply.self, base: base, path: "/api/car-documents?id=\(id)", method: "DELETE")
            SyncTombstones.remove(documentID: id)
            report.deletedDocuments += 1
        }

        for vin in SyncTombstones.vehicleVINs {
            guard let index = remoteCars.cars.firstIndex(where: { $0.vin.uppercased() == vin }) else {
                SyncTombstones.remove(vin: vin)
                continue
            }
            let remote = remoteCars.cars[index]
            _ = try await request(OperationReply.self, base: base, path: "/api/cars?id=\(remote.id)", method: "DELETE")
            remoteCars.cars.remove(at: index)
            SyncTombstones.remove(vin: vin)
            report.deletedVehicles += 1
        }

        for code in SyncTombstones.customerCodes {
            guard let index = remoteCustomers.customers.firstIndex(where: { $0.code.uppercased() == code }) else {
                SyncTombstones.remove(customerCode: code)
                continue
            }
            let remote = remoteCustomers.customers[index]
            for car in remoteCars.cars where car.customerId == remote.id {
                let payload = vehiclePayload(from: car, customerID: nil, expectedUpdatedAt: car.updatedAt)
                _ = try await request(CarReply.self, base: base, path: "/api/cars?id=\(car.id)", method: "PATCH", body: JSONEncoder().encode(payload))
                report.updatedVehicles += 1
            }
            _ = try await request(OperationReply.self, base: base, path: "/api/customers?id=\(remote.id)", method: "DELETE")
            remoteCustomers.customers.remove(at: index)
            SyncTombstones.remove(customerCode: code)
            report.deletedCustomers += 1
        }
    }

    private static func ensureSession(base: URL, password: String, forceLogin: Bool) async throws {
        if !forceLogin {
            let sessionURL = endpoint(base: base, path: "/api/auth/session")
            var sessionRequest = URLRequest(url: sessionURL)
            sessionRequest.httpMethod = "GET"
            let (data, response) = try await URLSession.shared.data(for: sessionRequest)
            if (response as? HTTPURLResponse)?.statusCode == 200,
               (try? JSONDecoder().decode(SessionReply.self, from: data).authenticated) == true { return }
        }
        guard !password.isEmpty else { throw WebsiteSyncError.missingPassword }
        var login = URLRequest(url: endpoint(base: base, path: "/api/auth/login"))
        login.httpMethod = "POST"
        login.setValue("application/json", forHTTPHeaderField: "Content-Type")
        login.httpBody = try JSONEncoder().encode(LoginPayload(password: password))
        let (loginData, loginResponse) = try await URLSession.shared.data(for: login)
        guard let status = loginResponse as? HTTPURLResponse else { throw WebsiteSyncError.invalidResponse }
        guard (200..<300).contains(status.statusCode) else { throw apiError(data: loginData, status: status.statusCode) }
    }

    private static func normalizedServer(_ value: String) throws -> URL {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: text), url.scheme == "https", url.host != nil, url.user == nil else { throw WebsiteSyncError.invalidServerURL }
        return url
    }

    private static func endpoint(base: URL, path: String) -> URL {
        URL(string: path, relativeTo: base)!.absoluteURL
    }

    private static func request<T: Decodable>(_ type: T.Type, base: URL, path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        var request = URLRequest(url: endpoint(base: base, path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WebsiteSyncError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw apiError(data: data, status: http.statusCode) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw WebsiteSyncError.server("Ответ сервера не подходит для версии приложения. Обновите сайт и повторите синхронизацию.") }
    }

    private static func apiError(data: Data, status: Int) -> Error {
        let message = (try? JSONDecoder().decode(ErrorReply.self, from: data).error) ?? "HTTP \(status)"
        if status == 409 { return WebsiteSyncError.conflict(message) }
        if status == 401 { return WebsiteSyncError.server("Сессия сайта истекла. Повторите синхронизацию и введите пароль.") }
        return WebsiteSyncError.server(message)
    }

    private static func customerPayload(_ customer: Customer) -> CustomerPayload {
        CustomerPayload(code: customer.code, name: customer.name, phone: customer.phone, email: customer.email, city: customer.city, notes: customer.notes, expectedUpdatedAt: nil)
    }

    private static func vehiclePayload(_ car: Vehicle, customerID: Int?, expectedUpdatedAt: String?) -> VehiclePayload {
        VehiclePayload(vin: car.vin, make: car.make, model: car.model, year: car.year,
                       originCountry: car.originCountry, purchaseDate: day(car.purchaseDate), supplierInvoice: car.supplierInvoice,
                       currency: car.currency, purchasePrice: car.purchasePrice, fxRate: car.fxRate,
                       deliveryCost: car.deliveryCost, freightCost: car.freightCost, customsDuty: car.customsDuty,
                       customsFees: car.customsFees, recyclingFee: car.recyclingFee, certificationCost: car.certificationCost,
                       registrationCost: car.registrationCost, otherCosts: car.otherCosts, importType: car.importType,
                       customerId: customerID, orderDate: day(car.orderDate), clientContract: car.clientContract,
                       salePrice: car.salePrice, prepayment: car.prepayment, orderStatus: car.orderStatus,
                       actualSalePrice: car.actualSalePrice, vehicleStatus: car.vehicleStatus, location: car.location,
                       documentsStatus: car.documentsStatus, notes: car.notes, engineVolumeCc: car.engineVolumeCc,
                       enginePowerHp: car.enginePowerHp, engineType: car.engineType, engineCylinders: car.engineCylinders,
                       bodyType: car.bodyType, driveType: car.driveType, transmission: car.transmission,
                       vehicleLengthMm: car.vehicleLengthMm, vehicleWidthMm: car.vehicleWidthMm, vehicleHeightMm: car.vehicleHeightMm,
                       wheelbaseMm: car.wheelbaseMm, curbWeightKg: car.curbWeightKg, specSource: car.specSource,
                       importerType: car.importerType, importRoute: car.importRoute,
                       nativeMetadata: NativeVehicleMetadata(generation: car.generation, engine: car.engine,
                                                             deliveryCurrency: car.deliveryCurrency, deliveryFxRate: car.deliveryFxRate,
                                                             freightCurrency: car.freightCurrency, freightFxRate: car.freightFxRate),
                       expectedUpdatedAt: expectedUpdatedAt)
    }

    private static func vehiclePayload(from car: RemoteVehicle, customerID: Int?, expectedUpdatedAt: String?) -> VehiclePayload {
        VehiclePayload(vin: car.vin, make: car.make, model: car.model, year: car.year,
                       originCountry: car.originCountry, purchaseDate: car.purchaseDate, supplierInvoice: car.supplierInvoice,
                       currency: car.currency, purchasePrice: car.purchasePrice, fxRate: car.fxRate,
                       deliveryCost: car.deliveryCost, freightCost: car.freightCost, customsDuty: car.customsDuty,
                       customsFees: car.customsFees, recyclingFee: car.recyclingFee, certificationCost: car.certificationCost,
                       registrationCost: car.registrationCost, otherCosts: car.otherCosts, importType: car.importType,
                       customerId: customerID, orderDate: car.orderDate, clientContract: car.clientContract,
                       salePrice: car.salePrice, prepayment: car.prepayment, orderStatus: car.orderStatus,
                       actualSalePrice: car.actualSalePrice, vehicleStatus: car.vehicleStatus, location: car.location,
                       documentsStatus: car.documentsStatus, notes: car.notes, engineVolumeCc: car.engineVolumeCc,
                       enginePowerHp: car.enginePowerHp, engineType: car.engineType, engineCylinders: car.engineCylinders,
                       bodyType: car.bodyType, driveType: car.driveType, transmission: car.transmission,
                       vehicleLengthMm: car.vehicleLengthMm, vehicleWidthMm: car.vehicleWidthMm, vehicleHeightMm: car.vehicleHeightMm,
                       wheelbaseMm: car.wheelbaseMm, curbWeightKg: car.curbWeightKg, specSource: car.specSource,
                       importerType: car.importerType, importRoute: car.importRoute,
                       nativeMetadata: car.nativeMetadata ?? NativeVehicleMetadata(generation: "", engine: ""),
                       expectedUpdatedAt: expectedUpdatedAt)
    }

    private static func apply(_ remote: RemoteCustomer, to local: Customer) {
        local.code = remote.code; local.name = remote.name; local.phone = remote.phone
        local.email = remote.email; local.city = remote.city; local.notes = remote.notes
        local.createdAt = parseDate(remote.createdAt) ?? local.createdAt
        local.updatedAt = parseDate(remote.updatedAt) ?? .now
    }

    private static func apply(_ remote: RemoteVehicle, to local: Vehicle, customersByID: [Int: RemoteCustomer], localCustomers: [String: Customer]) {
        local.vin = remote.vin; local.make = remote.make; local.model = remote.model; local.year = remote.year
        local.originCountry = remote.originCountry; local.purchaseDate = parseDay(remote.purchaseDate)
        local.supplierInvoice = remote.supplierInvoice; local.currency = remote.currency
        local.purchasePrice = remote.purchasePrice; local.fxRate = remote.fxRate
        local.deliveryCost = remote.deliveryCost; local.freightCost = remote.freightCost
        local.customsDuty = remote.customsDuty; local.customsFees = remote.customsFees
        local.recyclingFee = remote.recyclingFee; local.certificationCost = remote.certificationCost
        local.registrationCost = remote.registrationCost; local.otherCosts = remote.otherCosts
        local.importType = remote.importType
        local.customer = remote.customerId.flatMap { customersByID[$0] }.flatMap { localCustomers[$0.code.uppercased()] }
        local.orderDate = parseDay(remote.orderDate); local.clientContract = remote.clientContract
        local.salePrice = remote.salePrice; local.prepayment = remote.prepayment; local.orderStatus = remote.orderStatus
        local.actualSalePrice = remote.actualSalePrice; local.vehicleStatus = remote.vehicleStatus
        local.location = remote.location; local.documentsStatus = remote.documentsStatus; local.notes = remote.notes
        local.engineVolumeCc = remote.engineVolumeCc; local.enginePowerHp = remote.enginePowerHp
        local.engineType = remote.engineType; local.engineCylinders = remote.engineCylinders
        local.bodyType = remote.bodyType; local.driveType = remote.driveType; local.transmission = remote.transmission
        local.vehicleLengthMm = remote.vehicleLengthMm; local.vehicleWidthMm = remote.vehicleWidthMm
        local.vehicleHeightMm = remote.vehicleHeightMm; local.wheelbaseMm = remote.wheelbaseMm
        local.curbWeightKg = remote.curbWeightKg; local.specSource = remote.specSource
        local.importerType = remote.importerType; local.importRoute = remote.importRoute
        if let metadata = remote.nativeMetadata {
            local.generation = metadata.generation; local.engine = metadata.engine
            local.deliveryCurrency = metadata.deliveryCurrency; local.deliveryFxRate = metadata.deliveryFxRate
            local.freightCurrency = metadata.freightCurrency; local.freightFxRate = metadata.freightFxRate
        }
        local.createdAt = parseDate(remote.createdAt) ?? local.createdAt
        local.updatedAt = parseDate(remote.updatedAt) ?? .now
    }

    private static func synchronizeDocuments(base: URL, context: ModelContext, localVehiclesByVIN: [String: Vehicle], remoteCarsByVIN: [String: RemoteVehicle], report: inout WebsiteSyncReport) async throws {
        for (vin, vehicle) in localVehiclesByVIN {
            guard let remoteCar = remoteCarsByVIN[vin] else { continue }
            let reply = try await request(DocumentsReply.self, base: base, path: "/api/car-documents?carId=\(remoteCar.id)")
            var localDocs = vehicle.documents ?? []
            for remote in reply.documents {
                if localDocs.contains(where: { $0.remoteID == remote.id }) { continue }
                let bytes = try await requestData(base: base, path: "/api/car-documents?id=\(remote.id)")
                if let local = localDocs.first(where: {
                    $0.filename == remote.filename && $0.contentType == remote.contentType &&
                    $0.fileData.count == remote.fileSize && SHA256.hash(data: $0.fileData) == SHA256.hash(data: bytes)
                }) {
                    local.remoteID = remote.id
                    continue
                }
                let document = VehicleDocument(filename: remote.filename, contentType: remote.contentType, fileData: bytes)
                document.remoteID = remote.id
                document.createdAt = parseDate(remote.createdAt) ?? .now
                document.vehicle = vehicle
                vehicle.documents = (vehicle.documents ?? []) + [document]
                context.insert(document)
                localDocs.append(document)
                report.downloadedDocuments += 1
            }
            for document in localDocs where document.remoteID == nil {
                let remote = try await upload(document, vehicleID: remoteCar.id, base: base)
                document.remoteID = remote.id
                report.uploadedDocuments += 1
            }
        }
    }

    private static func upload(_ document: VehicleDocument, vehicleID: Int, base: URL) async throws -> RemoteDocument {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint(base: base, path: "/api/car-documents"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.appendUTF8("--\(boundary)\r\nContent-Disposition: form-data; name=\"vehicleId\"\r\n\r\n\(vehicleID)\r\n")
        body.appendUTF8("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(document.filename.replacingOccurrences(of: "\"", with: "_"))\"\r\nContent-Type: \(document.contentType)\r\n\r\n")
        body.append(document.fileData)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WebsiteSyncError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw apiError(data: data, status: http.statusCode) }
        return try JSONDecoder().decode(DocumentReply.self, from: data).document
    }

    private static func requestData(base: URL, path: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: endpoint(base: base, path: path))
        guard let http = response as? HTTPURLResponse else { throw WebsiteSyncError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw apiError(data: data, status: http.statusCode) }
        return data
    }

    private static func day(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDay(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(value.prefix(10)))
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) { append(Data(string.utf8)) }
}

private enum WebsiteSyncKeyStore {
    private static let service = "com.nordauto.euroauto.website-sync"
    private static let account = "app-password"

    static func save(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query; add[kSecValueData as String] = data; add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let result = SecItemAdd(add as CFDictionary, nil)
            guard result == errSecSuccess else { throw WebsiteSyncError.server("Не удалось безопасно сохранить пароль в Связке ключей.") }
        } else if status != errSecSuccess { throw WebsiteSyncError.server("Не удалось обновить пароль в Связке ключей.") }
    }

    static func read() throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw WebsiteSyncError.missingPassword }
        return value
    }

    static func delete() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw WebsiteSyncError.server("Не удалось удалить сохранённый пароль.") }
    }
}

private enum SyncTombstones {
    private static let vehiclesKey = "11-35.sync.deletedVehicles"
    private static let customersKey = "11-35.sync.deletedCustomers"
    private static let documentsKey = "11-35.sync.deletedDocuments"

    static var vehicleVINs: [String] { values(for: vehiclesKey) }
    static var customerCodes: [String] { values(for: customersKey) }
    static var documentIDs: [Int] { UserDefaults.standard.array(forKey: documentsKey) as? [Int] ?? [] }

    static func add(vin: String) {
        add(vin, for: vehiclesKey)
    }

    static func add(customerCode: String) {
        add(customerCode, for: customersKey)
    }

    static func remove(vin: String) {
        remove(vin, for: vehiclesKey)
    }

    static func remove(customerCode: String) {
        remove(customerCode, for: customersKey)
    }

    static func add(documentID: Int) {
        var current = Set(documentIDs)
        current.insert(documentID)
        UserDefaults.standard.set(current.sorted(), forKey: documentsKey)
    }

    static func remove(documentID: Int) {
        var current = Set(documentIDs)
        current.remove(documentID)
        UserDefaults.standard.set(current.sorted(), forKey: documentsKey)
    }

    private static func values(for key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    private static func add(_ value: String, for key: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return }
        var current = Set(values(for: key))
        current.insert(normalized)
        UserDefaults.standard.set(current.sorted(), forKey: key)
    }

    private static func remove(_ value: String, for key: String) {
        var current = Set(values(for: key))
        current.remove(value.uppercased())
        UserDefaults.standard.set(current.sorted(), forKey: key)
    }
}
