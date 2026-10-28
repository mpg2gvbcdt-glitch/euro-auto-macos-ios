import SwiftData
import SwiftUI

struct MaintenanceView: View {
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    private var sortedVehicles: [Vehicle] {
        vehicles.sorted { lhs, rhs in
            (lhs.maintenance?.events.map(\.date).max() ?? "") > (rhs.maintenance?.events.map(\.date).max() ?? "")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ГАРАНТИЙНОЕ ОБСЛУЖИВАНИЕ").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(Color.euroGreen)
                    Text("График ТО").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Следите за датой выдачи, годом гарантии и историей обслуживания каждого авто.")
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                if sortedVehicles.isEmpty {
                    ContentUnavailableView("Автомобилей пока нет", systemImage: "wrench.and.screwdriver", description: Text("Добавьте авто в реестр, чтобы вести историю ТО."))
                } else {
                    ForEach(sortedVehicles) { vehicle in
                        MaintenanceVehicleCard(vehicle: vehicle)
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 940, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.euroCanvas)
        .navigationTitle("График ТО")
    }
}

private struct MaintenanceVehicleCard: View {
    @Bindable var vehicle: Vehicle
    @State private var handoverDate = Date()
    @State private var hasHandoverDate = false
    @State private var serviceDate = Date()
    @State private var mileage = ""
    @State private var location = ""
    @State private var serviceType = "Плановое ТО"
    @State private var work = ""
    @State private var nextServiceDate = Date()
    @State private var hasNextServiceDate = false

    private let serviceTypes = ["Плановое ТО", "Гарантийный ремонт", "Диагностика", "Ремонт", "Другое"]
    private var maintenance: VehicleMaintenanceData { vehicle.maintenance ?? VehicleMaintenanceData() }
    private var warrantyExpiry: Date? { hasHandoverDate ? Calendar.current.date(byAdding: .year, value: 1, to: handoverDate) : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "car.side.fill").foregroundStyle(Color.euroGreen).font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(vehicle.make) \(vehicle.model)").font(.headline)
                    Text([vehicle.year.map(String.init), vehicle.vin].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let expiry = warrantyExpiry {
                    Label(expiry >= .now ? "Гарантия до \(expiry.formatted(date: .numeric, time: .omitted))" : "Гарантия завершена", systemImage: "shield.lefthalf.filled")
                        .font(.caption.weight(.semibold)).foregroundStyle(expiry >= .now ? Color.euroGreen : .secondary)
                } else {
                    Text("Дата выдачи не указана").font(.caption).foregroundStyle(.secondary)
                }
            }

            Toggle("Автомобиль выдан клиенту", isOn: $hasHandoverDate)
                .onChange(of: hasHandoverDate) { _, value in save(handoverDate: value ? Self.day(handoverDate) : nil) }
            if hasHandoverDate {
                DatePicker("Дата выдачи", selection: $handoverDate, displayedComponents: .date)
                    .onChange(of: handoverDate) { _, value in save(handoverDate: Self.day(value)) }
            }

            Divider()
            Text("Добавить обслуживание").font(.subheadline.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack { DatePicker("Дата", selection: $serviceDate, displayedComponents: .date); mileageField }
                VStack(alignment: .leading) { DatePicker("Дата", selection: $serviceDate, displayedComponents: .date); mileageField }
            }
            TextField("Сервис или город", text: $location)
            Picker("Вид работ", selection: $serviceType) {
                ForEach(serviceTypes, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu)
            TextField("Что сделали", text: $work, axis: .vertical).lineLimit(2...4)
            Toggle("Назначить следующее обслуживание", isOn: $hasNextServiceDate)
            if hasNextServiceDate { DatePicker("Следующее ТО", selection: $nextServiceDate, displayedComponents: .date) }
            HStack {
                Spacer()
                Button(action: addService) { Label("Сохранить обслуживание", systemImage: "plus.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(Color.euroGreen)
                    .disabled(location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && work.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            let records = maintenance.events.sorted { $0.date > $1.date }
            if !records.isEmpty {
                Divider()
                Text("История обслуживания").font(.subheadline.weight(.semibold))
                ForEach(records) { record in
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "wrench.fill").foregroundStyle(Color.euroGreen).padding(.top, 3)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.serviceType).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(Self.pretty(record.date)).font(.caption).foregroundStyle(.secondary)
                            }
                            if !record.location.isEmpty { Label(record.location, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary) }
                            if let mileage = record.mileageKm { Text("Пробег: \(mileage.formatted()) км").font(.caption).foregroundStyle(.secondary) }
                            if !record.work.isEmpty { Text(record.work).font(.callout) }
                            if let next = record.nextServiceDate, !next.isEmpty { Text("Следующее ТО: \(Self.pretty(next))").font(.caption.weight(.medium)).foregroundStyle(Color.euroGreen) }
                        }
                        Button(role: .destructive) { delete(record) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).help("Удалить запись")
                    }
                    .padding(12)
                    .background(Color.euroCanvas.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.euroGreen.opacity(0.15), lineWidth: 1))
        .onAppear(perform: loadHandoverDate)
    }

    private var mileageField: some View {
        TextField("Пробег, км", text: $mileage).frame(maxWidth: 180).textFieldStyle(.roundedBorder)
    }

    private func loadHandoverDate() {
        guard let raw = maintenance.handoverDate, let parsed = Self.parse(raw) else { return }
        handoverDate = parsed
        hasHandoverDate = true
    }

    private func save(handoverDate: String?) {
        var data = maintenance
        data.handoverDate = handoverDate
        vehicle.maintenance = data
        vehicle.updatedAt = .now
    }

    private func addService() {
        let km = Int(mileage.filter(\.isNumber))
        let event = MaintenanceRecord(id: UUID().uuidString, date: Self.day(serviceDate), mileageKm: km,
                                      location: location.trimmingCharacters(in: .whitespacesAndNewlines), serviceType: serviceType,
                                      work: work.trimmingCharacters(in: .whitespacesAndNewlines),
                                      nextServiceDate: hasNextServiceDate ? Self.day(nextServiceDate) : nil)
        var data = maintenance
        data.events.append(event)
        vehicle.maintenance = data
        vehicle.updatedAt = .now
        mileage = ""; location = ""; work = ""; hasNextServiceDate = false
    }

    private func delete(_ record: MaintenanceRecord) {
        var data = maintenance
        data.events.removeAll { $0.id == record.id }
        vehicle.maintenance = data
        vehicle.updatedAt = .now
    }

    private static func day(_ date: Date) -> String { date.formatted(.iso8601.year().month().day().dateSeparator(.dash)) }
    private static func parse(_ value: String) -> Date? { ISO8601DateFormatter().date(from: value + "T00:00:00Z") }
    private static func pretty(_ value: String) -> String {
        guard let date = parse(value) else { return value }
        return date.formatted(date: .numeric, time: .omitted)
    }
}
