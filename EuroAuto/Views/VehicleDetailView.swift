import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var vehicle: Vehicle
    @State private var showingEditor = false
    @State private var showingImporter = false
    @State private var previewURL: URL?
    @State private var message: String?
    @State private var messageTitle = "Документы"
    @State private var showingDeleteConfirmation = false

    private var title: String {
        [vehicle.make, vehicle.model].filter { !$0.isEmpty }.joined(separator: " ").isEmpty
            ? "Автомобиль"
            : [vehicle.make, vehicle.model].filter { !$0.isEmpty }.joined(separator: " ")
    }
    private var documents: [VehicleDocument] { vehicle.documents ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
                        HStack(spacing: 8) {
                            if let year = vehicle.year { Text(String(year)) }
                            if !vehicle.vin.isEmpty { Text(vehicle.vin).font(.system(.caption, design: .monospaced)) }
                        }.foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Изменить") { showingEditor = true }.buttonStyle(.bordered)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 10) {
                    DetailMetric(title: "Статус", value: vehicle.vehicleStatus, symbol: "shippingbox")
                    DetailMetric(title: "Себестоимость", value: vehicle.totalCost.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))), symbol: "rublesign.circle")
                    DetailMetric(title: "Плановая прибыль", value: vehicle.expectedProfit.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))), symbol: "chart.line.uptrend.xyaxis")
                }

                GroupBox("Характеристики") {
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow("Поколение", vehicle.generation)
                        detailRow("Двигатель", [vehicle.engine, vehicle.engineVolumeCc.map { "\($0) см³" }, vehicle.enginePowerHp.map { "\($0) л.с." }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        detailRow("Топливо / привод", [vehicle.engineType, vehicle.driveType].filter { !$0.isEmpty }.joined(separator: " · "))
                        detailRow("Коробка", vehicle.transmission)
                        detailRow("Габариты", [vehicle.vehicleLengthMm, vehicle.vehicleWidthMm, vehicle.vehicleHeightMm].contains(where: { $0 != nil }) ? [vehicle.vehicleLengthMm, vehicle.vehicleWidthMm, vehicle.vehicleHeightMm].map { $0.map(String.init) ?? "—" }.joined(separator: " × ") + " мм" : "")
                        detailRow("Заказчик", vehicle.customer?.name ?? "—")
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Документы автомобиля", systemImage: "doc.text")
                                .font(.headline)
                            Spacer()
                            Button { showingImporter = true } label: { Label("Добавить файл", systemImage: "plus") }
                                .buttonStyle(.bordered)
                        }
                        Text("PDF или изображение · до 20 МБ на файл · доступно офлайн после сохранения")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if documents.isEmpty {
                            ContentUnavailableView("Документов пока нет", systemImage: "doc.badge.plus", description: Text("Добавьте договор, счет или транспортные документы."))
                                .frame(minHeight: 130)
                        } else {
                            ForEach(documents.sorted { $0.createdAt > $1.createdAt }) { document in
                                HStack(spacing: 12) {
                                    Image(systemName: document.contentType == "application/pdf" ? "doc.richtext" : "photo")
                                        .foregroundStyle(Color.euroGreen)
                                        .frame(width: 35, height: 38)
                                        .background(Color.euroGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(document.filename).lineLimit(1).font(.subheadline.weight(.medium))
                                        Text(document.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button { previewURL = VehicleDocumentStore.url(for: document) } label: { Image(systemName: "arrow.up.right.square") }
                                        .buttonStyle(.borderless)
                                        .help("Открыть документ")
                                    Button(role: .destructive) { remove(document) } label: { Image(systemName: "trash") }
                                        .buttonStyle(.borderless)
                                        .help("Удалить документ")
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }

                GroupBox("Расходы") {
                    VStack(spacing: 0) {
                        costRow("Покупка · \(vehicle.currency)", value: vehicle.purchasePrice * vehicle.fxRate)
                        costRow("Доставка до порта · \(vehicle.deliveryCurrency ?? "RUB")", value: vehicle.deliveryCostRUB)
                        costRow("Фрахт · \(vehicle.freightCurrency ?? "RUB")", value: vehicle.freightCostRUB)
                        costRow("Таможня", value: vehicle.customsDuty + vehicle.customsFees + vehicle.recyclingFee)
                        costRow("Оформление и прочее", value: vehicle.certificationCost + vehicle.registrationCost + vehicle.otherCosts)
                        if vehicle.prepayment > 0 { costRow("Предоплата", value: vehicle.prepayment) }
                        if vehicle.actualSalePrice > 0 {
                            costRow("Фактическая цена продажи", value: vehicle.actualSalePrice)
                            costRow("Фактическая прибыль", value: vehicle.actualSalePrice - vehicle.totalCost)
                        }
                        Divider().padding(.vertical, 8)
                        HStack { Text("Итого").fontWeight(.bold); Spacer(); Text(vehicle.totalCost.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU")))).fontWeight(.bold) }
                    }
                    .padding(.top, 8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Калькулятор ТКС", systemImage: "function")
                            .font(.headline)
                        Text("Подключим внешний расчёт после получения API-ключа. Ручные расходы и себестоимость уже считаются на устройстве без интернета.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !vehicle.notes.isEmpty {
                    GroupBox("Заметки") { Text(vehicle.notes).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6) }
                }
            }
            .padding(22)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.euroCanvas)
        .groupBoxStyle(EuroAutoGroupBoxStyle())
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup {
                Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                    Label("Удалить", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .tint(.red)
                .help("Удалить автомобиль из реестра")
                Button { showingEditor = true } label: {
                    Label("Изменить", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .help("Изменить автомобиль")
            }
        }
        .confirmationDialog("Удалить автомобиль?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить автомобиль", role: .destructive, action: deleteVehicle)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Автомобиль и прикреплённые к нему документы будут удалены из реестра.")
        }
        .sheet(isPresented: $showingEditor) {
            #if os(macOS)
            VehicleEditorView(vehicle: vehicle, isNew: false).frame(minWidth: 560, minHeight: 620)
            #else
            VehicleEditorView(vehicle: vehicle, isNew: false)
            #endif
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf, .jpeg, .png, .webP], allowsMultipleSelection: true, onCompletion: importDocuments)
        .quickLookPreview($previewURL)
        .alert(messageTitle, isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("ОК") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 125, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func costRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
        }
        .padding(.vertical, 6)
    }

    private func importDocuments(_ result: Result<[URL], Error>) {
        messageTitle = "Документы"
        do {
            for url in try result.get() {
                let document = try VehicleDocumentStore.importFile(at: url)
                document.vehicle = vehicle
                var current = vehicle.documents ?? []
                current.append(document)
                vehicle.documents = current
                modelContext.insert(document)
            }
            vehicle.updatedAt = .now
            try modelContext.save()
        } catch {
            message = error.localizedDescription
        }
    }

    private func remove(_ document: VehicleDocument) {
        VehicleDocumentStore.delete(document)
        vehicle.documents = (vehicle.documents ?? []).filter { $0.id != document.id }
        modelContext.delete(document)
        try? modelContext.save()
    }

    private func deleteVehicle() {
        modelContext.delete(vehicle)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            messageTitle = "Не удалось удалить автомобиль"
            message = error.localizedDescription
        }
    }
}

private struct DetailMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol).foregroundStyle(Color.euroGreen)
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(minHeight: 98, alignment: .leading)
        .background(Color.euroPanel, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.euroLine.opacity(0.75), lineWidth: 1))
    }
}
