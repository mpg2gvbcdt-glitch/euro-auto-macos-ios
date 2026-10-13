import SwiftData
import SwiftUI

struct CustomersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Customer.createdAt, order: .reverse) private var customers: [Customer]
    @State private var search = ""
    @State private var showingNew = false

    private var filtered: [Customer] {
        guard !search.isEmpty else { return customers }
        return customers.filter { [$0.code, $0.name, $0.phone, $0.email, $0.city].contains { $0.localizedCaseInsensitiveContains(search) } }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("КЛИЕНТСКАЯ БАЗА").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Color.euroGreen)
                    Text("Заказчики").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Контакты клиентов и привязанные автомобили").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingNew = true } label: { Label("Добавить", systemImage: "plus").fontWeight(.semibold) }
                    .buttonStyle(.borderedProminent)
                    .tint(.euroGreen)
            }
            .padding(22)

            if filtered.isEmpty {
                ContentUnavailableView("Заказчиков пока нет", systemImage: "person.crop.circle.badge.plus", description: Text("Добавьте клиента, чтобы привязать к нему автомобиль под заказ."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { customer in
                        CustomerRow(customer: customer)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions {
                                Button(role: .destructive) { modelContext.delete(customer) } label: { Label("Удалить", systemImage: "trash") }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .searchable(text: $search, prompt: "Имя, телефон или email")
            }
        }
        .background(Color.euroCanvas)
        .navigationTitle("Заказчики")
        .sheet(isPresented: $showingNew) {
            #if os(macOS)
            CustomerEditorView(customer: Customer(name: ""), isNew: true).frame(minWidth: 430, minHeight: 500)
            #else
            CustomerEditorView(customer: Customer(name: ""), isNew: true)
            #endif
        }
    }
}

private struct CustomerRow: View {
    @Bindable var customer: Customer
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: {
            HStack(spacing: 13) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.euroGreen)
                    .frame(width: 45, height: 45)
                    .background(Color.euroGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name).font(.headline).foregroundStyle(Color.euroInk)
                    Text(([customer.code] + [customer.phone, customer.email, customer.city].filter { !$0.isEmpty }).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text("\(customer.vehicles?.count ?? 0) авто").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(13)
            .background(Color.euroPanel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.euroLine.opacity(0.75), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $editing) {
            #if os(macOS)
            CustomerEditorView(customer: customer, isNew: false).frame(minWidth: 430, minHeight: 500)
            #else
            CustomerEditorView(customer: customer, isNew: false)
            #endif
        }
    }
}

private struct CustomerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var customer: Customer
    let isNew: Bool
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Контакт") {
                    #if os(iOS)
                    TextField("ID клиента", text: $customer.code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    #else
                    TextField("ID клиента", text: $customer.code)
                        .autocorrectionDisabled()
                    #endif
                    TextField("Имя и фамилия", text: $customer.name)
                    TextField("Телефон", text: $customer.phone)
                    TextField("Email", text: $customer.email)
                    TextField("Город", text: $customer.city)
                }
                Section("Заметки") { TextEditor(text: $customer.notes).frame(minHeight: 110) }
                if !isNew && !(customer.vehicles ?? []).isEmpty {
                    Section("Автомобили") {
                        ForEach(customer.vehicles ?? []) { vehicle in
                            Label([vehicle.make, vehicle.model].filter { !$0.isEmpty }.joined(separator: " ").isEmpty ? "Автомобиль" : [vehicle.make, vehicle.model].filter { !$0.isEmpty }.joined(separator: " "), systemImage: "car.side")
                        }
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Новый заказчик" : "Заказчик")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).fontWeight(.semibold) }
            }
        }
    }

    private func save() {
        guard !customer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Укажите имя заказчика."
            return
        }
        customer.code = customer.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !customer.code.isEmpty else {
            errorMessage = "Укажите ID заказчика."
            return
        }
        if isNew { modelContext.insert(customer) }
        customer.updatedAt = .now
        do { try modelContext.save(); dismiss() }
        catch { errorMessage = "Не удалось сохранить заказчика: \(error.localizedDescription)" }
    }
}
