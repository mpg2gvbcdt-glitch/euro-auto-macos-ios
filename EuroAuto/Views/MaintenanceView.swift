import SwiftData
import SwiftUI

private struct MaintenanceTaskGroup: Identifiable {
    var title: String
    var tasks: [String]
    var id: String { title }
}

private enum MaintenanceChecklistCatalog {
    static let groups = [
        MaintenanceTaskGroup(title: "Двигатель", tasks: ["Замена масла в ДВС", "Замена масляного фильтра", "Замена воздушного фильтра", "Замена салонного фильтра", "Замена топливного фильтра", "Замена свечей зажигания / накаливания", "Проверка ремня ГРМ / цепи", "Замена охлаждающей жидкости"]),
        MaintenanceTaskGroup(title: "Трансмиссия", tasks: ["Замена масла в АКПП", "Замена фильтра АКПП", "Замена масла в МКПП / редукторе", "Проверка раздаточной коробки"]),
        MaintenanceTaskGroup(title: "Тормозная система", tasks: ["Замена передних колодок", "Замена задних колодок", "Проверка / замена тормозных дисков", "Замена тормозной жидкости"]),
        MaintenanceTaskGroup(title: "Ходовая и другое", tasks: ["Диагностика подвески и рулевого управления", "Проверка аккумулятора", "Проверка шин и давления", "Обслуживание кондиционера", "Проверка световых приборов"])
    ]
}

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
    @Environment(\.modelContext) private var modelContext
    @State private var handoverDate = Date()
    @State private var hasHandoverDate = false
    @State private var serviceDate = Date()
    @State private var mileage = ""
    @State private var location = ""
    @State private var serviceType = "Плановое ТО"
    @State private var selectedTasks = Set<String>()
    @State private var customTasks = [String]()
    @State private var customTask = ""
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
            Text("Отметьте выполненные работы").font(.subheadline.weight(.semibold))
            ForEach(MaintenanceChecklistCatalog.groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title.uppercased()).font(.caption.weight(.bold)).tracking(0.7).foregroundStyle(Color.euroGreen)
                    LazyVGrid(columns: [GridItem(.flexible())], alignment: .leading, spacing: 5) {
                        ForEach(group.tasks, id: \.self) { task in checklistButton(task) }
                    }
                }
                .padding(11)
                .background(Color.euroCanvas.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            }
            HStack(spacing: 8) {
                TextField("Другая работа", text: $customTask)
                Button("Добавить") {
                    let task = customTask.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !task.isEmpty else { return }
                    customTasks.append(task)
                    selectedTasks.insert(task)
                    customTask = ""
                }
                .disabled(customTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          MaintenanceChecklistCatalog.groups.flatMap(\.tasks).contains(customTask.trimmingCharacters(in: .whitespacesAndNewlines)) ||
                          customTasks.contains(customTask.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            ForEach(customTasks, id: \.self) { task in
                HStack {
                    checklistButton(task)
                    Button(role: .destructive) { customTasks.removeAll { $0 == task }; selectedTasks.remove(task) } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless).help("Убрать свой пункт")
                }
            }
            TextField("Комментарий к визиту (необязательно)", text: $work, axis: .vertical).lineLimit(2...4)
            Toggle("Назначить следующее обслуживание", isOn: $hasNextServiceDate)
            if hasNextServiceDate { DatePicker("Следующее ТО", selection: $nextServiceDate, displayedComponents: .date) }
            HStack {
                Spacer()
                Button(action: addService) { Label("Сохранить чек-лист ТО", systemImage: "plus.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(Color.euroGreen)
                    .disabled(location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedTasks.isEmpty)
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
                            if let checklistItems = record.checklistItems, !checklistItems.isEmpty {
                                ForEach(checklistItems, id: \.self) { task in
                                    Label(task, systemImage: "checkmark.circle.fill")
                                        .font(.caption).foregroundStyle(Color.euroGreen)
                                }
                            } else if !record.work.isEmpty {
                                Text(record.work).font(.callout)
                            }
                            if !record.work.isEmpty, record.checklistItems?.isEmpty == false {
                                Text(record.work).font(.caption).foregroundStyle(.secondary)
                            }
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

    private func checklistButton(_ task: String) -> some View {
        let isSelected = selectedTasks.contains(task)
        return Button {
            if isSelected { selectedTasks.remove(task) } else { selectedTasks.insert(task) }
        } label: {
            Label(task, systemImage: isSelected ? "checkmark.square.fill" : "square")
                .font(.callout)
                .foregroundStyle(isSelected ? Color.euroGreen : Color.euroInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        markChanged()
    }

    private func addService() {
        let km = Int(mileage.filter(\.isNumber))
        let order = MaintenanceChecklistCatalog.groups.flatMap(\.tasks)
        let tasks = order.filter(selectedTasks.contains) + customTasks.filter(selectedTasks.contains)
        let event = MaintenanceRecord(id: UUID().uuidString, date: Self.day(serviceDate), mileageKm: km,
                                      location: location.trimmingCharacters(in: .whitespacesAndNewlines), serviceType: serviceType,
                                      work: work.trimmingCharacters(in: .whitespacesAndNewlines),
                                      checklistItems: tasks,
                                      nextServiceDate: hasNextServiceDate ? Self.day(nextServiceDate) : nil)
        var data = maintenance
        data.events.append(event)
        vehicle.maintenance = data
        markChanged()
        mileage = ""; location = ""; work = ""; selectedTasks = []; customTasks = []; customTask = ""; hasNextServiceDate = false
    }

    private func delete(_ record: MaintenanceRecord) {
        var data = maintenance
        data.events.removeAll { $0.id == record.id }
        vehicle.maintenance = data
        markChanged()
    }

    private func markChanged() {
        vehicle.updatedAt = .now
        WebsiteAutoSync.schedule(context: modelContext)
    }

    private static func day(_ date: Date) -> String { date.formatted(.iso8601.year().month().day().dateSeparator(.dash)) }
    private static func parse(_ value: String) -> Date? { ISO8601DateFormatter().date(from: value + "T00:00:00Z") }
    private static func pretty(_ value: String) -> String {
        guard let date = parse(value) else { return value }
        return date.formatted(date: .numeric, time: .omitted)
    }
}
