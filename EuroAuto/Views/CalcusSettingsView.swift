import SwiftUI

struct CalcusSettingsView: View {
    @State private var clientID = ""
    @State private var key = ""
    @State private var hasSavedKey = CalcusKeyStore.hasCredentials
    @State private var statusMessage: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section {
                Label("Calcus", systemImage: "function")
                    .font(.title3.weight(.semibold))
                Text("ID клиента и API-ключ хранятся только в Связке ключей этого устройства. Они не записываются в базу автомобилей, резервные копии или исходный код.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("ID клиента Calcus", text: $clientID)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                SecureField("API-ключ Calcus", text: $key)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                HStack {
                    Button("Сохранить доступ") { saveKey() }
                        .buttonStyle(.borderedProminent)
                        .tint(.euroGreen)
                        .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasSavedKey {
                        Button("Удалить ключ", role: .destructive) { removeKey() }
                            .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("Доступ к API")
            } footer: {
                Text(hasSavedKey ? "Доступ сохранён на этом устройстве. Для расчёта потребуется интернет." : "ID клиента и API-ключ ещё не сохранены на этом устройстве.")
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(isError ? Color.euroAmber : Color.euroGreen)
                        .font(.footnote)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Настройки Calcus")
    }

    private func saveKey() {
        do {
            try CalcusKeyStore.save(clientID: clientID, apiKey: key)
            clientID = ""
            key = ""
            hasSavedKey = true
            isError = false
            statusMessage = "Доступ сохранён в Связке ключей этого устройства."
        } catch {
            isError = true
            statusMessage = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try CalcusKeyStore.delete()
            hasSavedKey = false
            isError = false
            statusMessage = "Данные доступа удалены с этого устройства."
        } catch {
            isError = true
            statusMessage = error.localizedDescription
        }
    }
}
