import SwiftData
import SwiftUI

private enum CatalogField: String, Identifiable {
    case make, model, generation, engine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .make: "Марка"
        case .model: "Модель"
        case .generation: "Поколение"
        case .engine: "Двигатель"
        }
    }
}

struct VehicleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.name) private var customers: [Customer]
    @Bindable var vehicle: Vehicle
    let isNew: Bool
    @State private var catalogField: CatalogField?
    @State private var saveError: String?

    private let catalog = VehicleCatalogStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Автомобиль") {
                    #if os(iOS)
                    TextField("VIN", text: $vehicle.vin)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    #else
                    TextField("VIN", text: $vehicle.vin)
                        .autocorrectionDisabled()
                    #endif
                    catalogButton(.make, value: vehicle.make, enabled: true)
                    catalogButton(.model, value: vehicle.model, enabled: !vehicle.make.isEmpty)
                    catalogButton(.generation, value: vehicle.generation, enabled: !vehicle.model.isEmpty)
                    catalogButton(.engine, value: vehicle.engine, enabled: !vehicle.generation.isEmpty)
                    Picker("Тип ввоза", selection: $vehicle.importType) {
                        Text("На склад").tag("На склад")
                        Text("Под заказ").tag("Под заказ")
                    }
                    if vehicle.importType == "Под заказ" {
                        Picker("Заказчик", selection: customerSelection) {
                            Text("Не выбран").tag("")
                            ForEach(customers) { customer in Text("\(customer.code) · \(customer.name)").tag(customer.id.uuidString) }
                        }
                    }
                    Picker("Статус", selection: $vehicle.vehicleStatus) {
                        ForEach(["В пути", "На складе", "Оформление", "Готов к выдаче", "Продан"], id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Страна отправления", text: $vehicle.originCountry)
                    TextField("Местонахождение", text: $vehicle.location)
                    Picker("Импортер", selection: $vehicle.importerType) {
                        ForEach(["Юрлицо / ИП", "Физическое лицо"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Маршрут", selection: $vehicle.importRoute) {
                        ForEach(["Напрямую в Россию", "Через третью страну"], id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Характеристики из каталога") {
                    LabeledContent("Год", value: vehicle.year.map(String.init) ?? "—")
                    LabeledContent("Двигатель", value: vehicle.engineVolumeCc.map { "\($0) см³" } ?? "—")
                    LabeledContent("Мощность", value: vehicle.enginePowerHp.map { "\($0) л.с." } ?? "—")
                    LabeledContent("Цилиндры", value: vehicle.engineCylinders.map(String.init) ?? "—")
                    LabeledContent("Топливо", value: vehicle.engineType.isEmpty ? "—" : vehicle.engineType)
                    LabeledContent("Привод", value: vehicle.driveType.isEmpty ? "—" : vehicle.driveType)
                    LabeledContent("Коробка", value: vehicle.transmission.isEmpty ? "—" : vehicle.transmission)
                    LabeledContent("Габариты", value: dimensions)
                    LabeledContent("Масса", value: vehicle.curbWeightKg.map { "\($0) кг" } ?? "—")
                }

                Section("Покупка и расходы") {
                    DatePicker("Дата покупки", selection: purchaseDateBinding, displayedComponents: .date)
                    TextField("Счёт / договор поставщика", text: $vehicle.supplierInvoice)
                    Picker("Валюта покупки", selection: $vehicle.currency) {
                        ForEach(["EUR", "USD", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN"], id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    moneyField("Цена покупки, \(vehicle.currency)", value: $vehicle.purchasePrice)
                    moneyField("Курс, ₽ за 1 \(vehicle.currency)", value: $vehicle.fxRate)
                    moneyField("Доставка до порта, ₽", value: $vehicle.deliveryCost)
                    moneyField("Фрахт, ₽", value: $vehicle.freightCost)
                    Text("Таможенные и прочие расходы ниже указываются в рублях. Себестоимость считается в ₽ по формуле: цена покупки × курс + расходы.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Таможня и оформление · ₽") {
                    moneyField("Пошлина, ₽", value: $vehicle.customsDuty)
                    moneyField("Сборы / НДС / акциз, ₽", value: $vehicle.customsFees)
                    moneyField("Утилизационный сбор, ₽", value: $vehicle.recyclingFee)
                    moneyField("Сертификация, ₽", value: $vehicle.certificationCost)
                    moneyField("Регистрация, ₽", value: $vehicle.registrationCost)
                    moneyField("Прочие расходы, ₽", value: $vehicle.otherCosts)
                }

                Section("Продажа") {
                    moneyField("Плановая цена продажи", value: $vehicle.salePrice)
                    moneyField("Предоплата", value: $vehicle.prepayment)
                    Picker("Статус заказа", selection: $vehicle.orderStatus) {
                        ForEach(["Новая заявка", "Подтвержден", "Ожидает оплату", "Ожидает автомобиль", "Автомобиль доставлен", "Закрыт", "Отменен"], id: \.self) { Text($0).tag($0) }
                    }
                    if vehicle.importType == "Под заказ" {
                        DatePicker("Дата заказа", selection: orderDateBinding, displayedComponents: .date)
                        TextField("Договор с клиентом", text: $vehicle.clientContract)
                    }
                    LabeledContent("Себестоимость", value: vehicle.totalCost.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                    LabeledContent("Плановая прибыль", value: vehicle.expectedProfit.formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                    moneyField("Фактическая цена продажи, ₽", value: $vehicle.actualSalePrice)
                    if vehicle.actualSalePrice > 0 {
                        LabeledContent("Фактическая прибыль", value: (vehicle.actualSalePrice - vehicle.totalCost).formatted(.currency(code: "RUB").locale(Locale(identifier: "ru_RU"))))
                    }
                }

                Section("Документы") {
                    Picker("Статус документов", selection: $vehicle.documentsStatus) {
                        ForEach(["Не проверены", "Неполный комплект", "Полный комплект", "Есть замечания"], id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Заметки") {
                    TextEditor(text: $vehicle.notes).frame(minHeight: 90)
                }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Новый автомобиль" : "Изменить автомобиль")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.fontWeight(.semibold)
                }
            }
            .sheet(item: $catalogField) { field in
                CatalogChoiceSheet(field: field, choices: choices(for: field)) { choice in
                    apply(choice, to: field)
                }
            }
        }
    }

    private var customerSelection: Binding<String> {
        Binding(
            get: { vehicle.customer?.id.uuidString ?? "" },
            set: { id in vehicle.customer = customers.first(where: { $0.id.uuidString == id }) }
        )
    }

    private var purchaseDateBinding: Binding<Date> {
        Binding(get: { vehicle.purchaseDate ?? .now }, set: { vehicle.purchaseDate = $0 })
    }

    private var orderDateBinding: Binding<Date> {
        Binding(get: { vehicle.orderDate ?? .now }, set: { vehicle.orderDate = $0 })
    }

    private var dimensions: String {
        let values = [vehicle.vehicleLengthMm, vehicle.vehicleWidthMm, vehicle.vehicleHeightMm]
        guard values.contains(where: { $0 != nil }) else { return "—" }
        return values.map { $0.map(String.init) ?? "—" }.joined(separator: " × ") + " мм"
    }

    private func moneyField(_ title: String, value: Binding<Double>) -> some View {
        TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
    }

    private func catalogButton(_ field: CatalogField, value: String, enabled: Bool) -> some View {
        Button { catalogField = field } label: {
            HStack {
                Text(field.title).foregroundStyle(.primary)
                Spacer()
                Text(value.isEmpty ? "Выбрать" : value).foregroundStyle(value.isEmpty ? .secondary : Color.euroGreen).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .disabled(!enabled)
    }

    private func choices(for field: CatalogField) -> [String] {
        switch field {
        case .make: catalog.makes.map(\.make)
        case .model: catalog.models(for: vehicle.make).map(\.n)
        case .generation: catalog.generations(for: vehicle.make, model: vehicle.model).map(\.n)
        case .engine: catalog.engines(for: vehicle.make, model: vehicle.model, generation: vehicle.generation).map(\.n)
        }
    }

    private func apply(_ choice: String, to field: CatalogField) {
        switch field {
        case .make:
            vehicle.make = choice
            vehicle.model = ""
            vehicle.generation = ""
            vehicle.engine = ""
            clearSpecs()
        case .model:
            vehicle.model = choice
            vehicle.generation = ""
            vehicle.engine = ""
            clearSpecs()
        case .generation:
            vehicle.generation = choice
            vehicle.engine = ""
            clearSpecs()
            if let generation = catalog.generations(for: vehicle.make, model: vehicle.model).first(where: { $0.n == choice }) {
                vehicle.year = generation.from
                vehicle.bodyType = generation.body ?? ""
            }
        case .engine:
            vehicle.engine = choice
            if let engine = catalog.engines(for: vehicle.make, model: vehicle.model, generation: vehicle.generation).first(where: { $0.n == choice }) {
                vehicle.engineVolumeCc = engine.cc
                vehicle.enginePowerHp = engine.hp
                vehicle.engineType = engine.localizedFuel
                vehicle.driveType = engine.localizedDrive
                vehicle.transmission = engine.tr ?? ""
                vehicle.vehicleLengthMm = engine.l
                vehicle.vehicleWidthMm = engine.w
                vehicle.vehicleHeightMm = engine.h
                vehicle.wheelbaseMm = engine.wb
                vehicle.curbWeightKg = engine.kg
            }
        }
    }

    private func clearSpecs() {
        vehicle.engineVolumeCc = nil
        vehicle.enginePowerHp = nil
        vehicle.engineType = ""
        vehicle.driveType = ""
        vehicle.transmission = ""
        vehicle.vehicleLengthMm = nil
        vehicle.vehicleWidthMm = nil
        vehicle.vehicleHeightMm = nil
        vehicle.wheelbaseMm = nil
        vehicle.curbWeightKg = nil
    }

    private func save() {
        vehicle.vin = vehicle.vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        vehicle.updatedAt = .now
        if isNew { modelContext.insert(vehicle) }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Не удалось сохранить автомобиль: \(error.localizedDescription)"
        }
    }
}

private struct CatalogChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let field: CatalogField
    let choices: [String]
    let onChoose: (String) -> Void

    private var filteredChoices: [String] {
        guard !search.isEmpty else { return choices }
        return choices.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filteredChoices, id: \.self) { choice in
                Button {
                    onChoose(choice)
                    dismiss()
                } label: {
                    Text(choice).foregroundStyle(.primary)
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Поиск")
            .navigationTitle(field.title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 430, minHeight: 500)
        #endif
    }
}
