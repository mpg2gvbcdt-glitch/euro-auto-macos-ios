import SwiftData
import SwiftUI

struct VehiclesView: View {
    @Binding var showingNewVehicle: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]
    @State private var searchText = ""
    @State private var importFilter = "Все"
    @State private var vehicleToDelete: Vehicle?
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?

    private let filters = ["Все", "На склад", "Под заказ"]
    private var filtered: [Vehicle] {
        vehicles.filter { vehicle in
            let matchesFilter = importFilter == "Все" || vehicle.importType == importFilter
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || [vehicle.vin, vehicle.make, vehicle.model, vehicle.customer?.name ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("АВТОПАРК").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Color.euroGreen)
                    Text("Автомобили").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Карточки, расходы и документы по каждой машине").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingNewVehicle = true } label: {
                    Label("Добавить", systemImage: "plus").fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.euroGreen)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)

            Picker("Тип", selection: $importFilter) {
                ForEach(filters, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            if filtered.isEmpty {
                ContentUnavailableView(searchText.isEmpty ? "Список пока пуст" : "Ничего не найдено", systemImage: "car.side", description: Text(searchText.isEmpty ? "Добавьте автомобиль, чтобы начать учет." : "Измените запрос или фильтр."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { vehicle in
                        HStack(spacing: 8) {
                            NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
                                VehicleRow(vehicle: vehicle)
                                    .padding(.vertical, 5)
                            }
                            Menu {
                                Button(role: .destructive) {
                                    vehicleToDelete = vehicle
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Удалить автомобиль", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .help("Действия с автомобилем")
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(role: .destructive) {
                                vehicleToDelete = vehicle
                                showingDeleteConfirmation = true
                            } label: { Label("Удалить", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Марка, модель, VIN или клиент")
            }
        }
        .background(Color.euroCanvas)
        .navigationTitle("Автомобили")
        .confirmationDialog("Удалить автомобиль?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive, action: deleteSelectedVehicle)
            Button("Отмена", role: .cancel) { vehicleToDelete = nil }
        } message: {
            Text("Автомобиль и прикреплённые к нему документы будут удалены из реестра.")
        }
        .alert("Не удалось удалить автомобиль", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("ОК") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showingNewVehicle) {
            #if os(macOS)
            VehicleEditorView(vehicle: Vehicle(), isNew: true)
                .frame(minWidth: 560, minHeight: 620)
            #else
            VehicleEditorView(vehicle: Vehicle(), isNew: true)
            #endif
        }
    }

    private func deleteSelectedVehicle() {
        guard let vehicle = vehicleToDelete else { return }
        modelContext.delete(vehicle)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deleteError = error.localizedDescription
        }
        vehicleToDelete = nil
    }
}

struct VehicleRow: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "car.side.fill")
                .font(.title3)
                .foregroundStyle(Color.euroGreen)
                .frame(width: 44, height: 44)
                .background(Color.euroGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text([vehicle.make, vehicle.model].filter { !$0.isEmpty }.joined(separator: " ").isEmpty ? "Новый автомобиль" : [vehicle.make, vehicle.model].filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.headline)
                    .foregroundStyle(Color.euroInk)
                HStack(spacing: 7) {
                    if let year = vehicle.year { Text(String(year)) }
                    if !vehicle.vin.isEmpty { Text(vehicle.vin).font(.system(.caption, design: .monospaced)) }
                    if let customer = vehicle.customer { Text("· \(customer.name)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                Text(vehicle.vehicleStatus).font(.caption.weight(.semibold)).foregroundStyle(vehicle.vehicleStatus == "В пути" ? Color.euroAmber : Color.euroGreen)
                Text(vehicle.totalCost.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(13)
        .background(Color.euroPanel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.euroLine.opacity(0.75), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
