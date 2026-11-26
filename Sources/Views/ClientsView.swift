import SwiftUI
import UniformTypeIdentifiers

struct ClientsView: View {
    @EnvironmentObject private var vm: CRMViewModel
    @State private var searchText = ""
    @State private var statusFilter = "All"
    @State private var salespersonFilter = "All Sales Persons"
    @State private var showAddClient = false
    @State private var clientToEdit: ClientRecord? = nil
    @State private var showCsvImporter = false
    @State private var exportFileUrl: URL? = nil
    @State private var showShareExport = false
    @State private var importAlertMessage: String? = nil

    private var salespersonOptions: [String] {
        let creators = Set(vm.visibleClients.map { $0.createdBy.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        return ["All Sales Persons"] + creators.sorted()
    }

    private var filtered: [ClientRecord] {
        vm.visibleClients.filter { client in
            let matchesStatus = statusFilter == "All" || client.status.caseInsensitiveCompare(statusFilter) == .orderedSame
            let matchesSalesperson = !(vm.currentUser?.isSuperAdmin == true) ||
                salespersonFilter == "All Sales Persons" ||
                client.createdBy.caseInsensitiveCompare(salespersonFilter) == .orderedSame
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = q.isEmpty ||
                client.fullName.lowercased().contains(q) ||
                client.suburb.lowercased().contains(q) ||
                client.email.lowercased().contains(q) ||
                client.mobile.lowercased().contains(q) ||
                client.company.lowercased().contains(q) ||
                client.notes.lowercased().contains(q)
            return matchesStatus && matchesSalesperson && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["All", "Active", "Contacted", "Closed"], id: \.self) { status in
                            Button {
                                statusFilter = status
                            } label: {
                                Text(status)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(statusFilter == status ? Color.accentColor : Color.white)
                                    .foregroundStyle(statusFilter == status ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                            }
                        }

                        if vm.currentUser?.isSuperAdmin == true && salespersonOptions.count > 1 {
                            Menu {
                                ForEach(salespersonOptions, id: \.self) { sp in
                                    Button(sp) { salespersonFilter = sp }
                                }
                            } label: {
                                Label(salespersonFilter == "All Sales Persons" ? "Filter Staff" : salespersonFilter, systemImage: "line.3.horizontal.decrease.circle")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if filtered.isEmpty {
                    ContentUnavailableViewCompat(
                        title: vm.visibleClients.isEmpty ? "No Synced Contacts Yet" : "No Matching Contacts",
                        subtitle: vm.visibleClients.isEmpty
                            ? "Pull down to sync with Google Sheet or tap ••• to Import CSV."
                            : "Try clearing your search or status filter."
                    )
                } else {
                    List {
                        ForEach(filtered) { client in
                            NavigationLink {
                                ClientDetailView(client: client) {
                                    clientToEdit = client
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(client.fullName)
                                            .font(.headline)
                                        Spacer()
                                        Text(client.status)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(statusColor(client.status).opacity(0.14))
                                            .foregroundStyle(statusColor(client.status))
                                            .clipShape(Capsule())
                                    }
                                    if !client.email.isEmpty || !client.mobile.isEmpty {
                                        Text([client.mobile, client.email].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !client.properties.isEmpty || !client.address.isEmpty {
                                        Text([client.properties, client.address].filter { !$0.isEmpty }.joined(separator: " • "))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.deleteClient(client) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    clientToEdit = client
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .refreshable {
                        await vm.syncAllWithGoogleSheet()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SilverRayTheme.appBackground.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search name, email, mobile, suburb")
            .navigationTitle("Clients (\(filtered.count))")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await vm.syncAllWithGoogleSheet() }
                        } label: {
                            Label("Sync with Google Sheet", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button {
                            showCsvImporter = true
                        } label: {
                            Label("Import CSV File", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            if let url = vm.exportVisibleClientsCsv() {
                                exportFileUrl = url
                                showShareExport = true
                            }
                        } label: {
                            Label("Export Contacts CSV", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button {
                        showAddClient = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .fileImporter(
                isPresented: $showCsvImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let first = urls.first {
                    let count = vm.importClientsFromCsvFile(url: first)
                    importAlertMessage = count > 0
                        ? "Imported \(count) contacts and synced them with your CRM."
                        : "Could not find valid contact rows in that CSV file."
                }
            }
            .sheet(isPresented: $showAddClient) {
                ClientFormSheet(existing: nil) { newClient in
                    Task { await vm.addClient(newClient) }
                }
            }
            .sheet(item: $clientToEdit) { editing in
                ClientFormSheet(existing: editing) { updated in
                    Task { await vm.updateClient(updated) }
                }
            }
            .sheet(isPresented: $showShareExport) {
                if let url = exportFileUrl {
                    ActivityShareSheet(items: [url])
                }
            }
            .alert("CSV Import", isPresented: Binding(
                get: { importAlertMessage != nil },
                set: { if !$0 { importAlertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { importAlertMessage = nil }
            } message: {
                Text(importAlertMessage ?? "")
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active": return .green
        case "contacted": return .blue
        case "closed": return .gray
        default: return .teal
        }
    }
}

struct ClientDetailView: View {
    @EnvironmentObject private var vm: CRMViewModel
    let client: ClientRecord
    let onEdit: () -> Void

    @State private var newHistoryNote = ""
    @State private var historyType = "Call"

    private var histories: [ContactHistoryRecord] {
        vm.contactHistories.filter { $0.clientId == client.id }
    }

    var body: some View {
        List {
            Section("Quick Actions") {
                HStack(spacing: 12) {
                    if !client.mobile.isEmpty {
                        Button {
                            if let url = URL(string: "tel:\(client.mobile.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Call", systemImage: "phone.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button {
                            if let url = URL(string: "sms:\(client.mobile.replacingOccurrences(of: " ", with: ""))") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("SMS", systemImage: "message.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    }

                    if !client.email.isEmpty {
                        Button {
                            if let url = URL(string: "mailto:\(client.email)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Email", systemImage: "envelope.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            }

            Section("Contact Information") {
                LabeledContent("Name", value: client.fullName)
                LabeledContent("Status", value: client.status)
                if !client.mobile.isEmpty { LabeledContent("Mobile", value: client.mobile) }
                if !client.email.isEmpty { LabeledContent("Email", value: client.email) }
                if !client.birthdate.isEmpty { LabeledContent("Birthdate", value: client.birthdate) }
                if !client.company.isEmpty { LabeledContent("Company", value: client.company) }
                if !client.address.isEmpty { LabeledContent("Address", value: client.address) }
                LabeledContent("Added By", value: client.createdBy)
            }

            if !client.properties.isEmpty || !client.notes.isEmpty {
                Section("Properties & Notes") {
                    if !client.properties.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Properties / Interests").font(.caption).foregroundStyle(.secondary)
                            Text(client.properties)
                        }
                    }
                    if !client.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes").font(.caption).foregroundStyle(.secondary)
                            Text(client.notes)
                        }
                    }
                }
            }

            Section("Log Interaction") {
                Picker("Type", selection: $historyType) {
                    ForEach(["Call", "Email", "SMS", "Meeting", "Inspection"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                TextField("Interaction summary...", text: $newHistoryNote)
                Button("Add Log Entry") {
                    vm.addHistory(for: client.id, type: historyType, notes: newHistoryNote)
                    newHistoryNote = ""
                }
                .disabled(newHistoryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ForEach(histories) { h in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(h.type).font(.caption.bold()).foregroundStyle(.blue)
                            Spacer()
                            Text(h.contactDate, style: .date).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(h.notes).font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(client.fullName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", action: onEdit)
            }
        }
    }
}

struct ClientFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existing: ClientRecord?
    let onSave: (ClientRecord) -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var mobile = ""
    @State private var birthdate = ""
    @State private var company = ""
    @State private var address = ""
    @State private var properties = ""
    @State private var notes = ""
    @State private var status = "Active"

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("First Name *", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Mobile", text: $mobile)
                        .keyboardType(.phonePad)
                    TextField("Birthdate (MM-DD or YYYY-MM-DD)", text: $birthdate)
                }

                Section("Property & CRM Details") {
                    TextField("Company / Organization", text: $company)
                    TextField("Street / Suburb / Postcode", text: $address)
                    TextField("Interested Properties", text: $properties)
                    Picker("Status", selection: $status) {
                        ForEach(["Active", "Contacted", "Closed"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "Add Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                        let record = ClientRecord(
                            id: existing?.id ?? UUID().uuidString,
                            sheetId: existing?.sheetId ?? 0,
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName: lastName.trimmingCharacters(in: .whitespaces),
                            name: full,
                            email: email.trimmingCharacters(in: .whitespaces),
                            mobile: mobile.trimmingCharacters(in: .whitespaces),
                            birthdate: birthdate.trimmingCharacters(in: .whitespaces),
                            company: company.trimmingCharacters(in: .whitespaces),
                            address: address.trimmingCharacters(in: .whitespaces),
                            suburb: existing?.suburb ?? "",
                            state: existing?.state ?? "QLD",
                            postcode: existing?.postcode ?? "",
                            notes: notes.trimmingCharacters(in: .whitespaces),
                            properties: properties.trimmingCharacters(in: .whitespaces),
                            status: status,
                            classification: existing?.classification ?? "Client",
                            interestedProperty: properties.trimmingCharacters(in: .whitespaces),
                            budgetRange: existing?.budgetRange ?? "",
                            createdBy: existing?.createdBy ?? "",
                            assignedSalespersonId: existing?.assignedSalespersonId ?? "",
                            assignedSalespersonName: existing?.assignedSalespersonName ?? "",
                            marketingConsent: existing?.marketingConsent ?? true,
                            updatedAt: Date()
                        )
                        onSave(record)
                        dismiss()
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty && email.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let c = existing {
                    firstName = c.firstName.isEmpty ? c.name : c.firstName
                    lastName = c.lastName
                    email = c.email
                    mobile = c.mobile
                    birthdate = c.birthdate
                    company = c.company
                    address = c.address
                    properties = c.properties
                    notes = c.notes
                    status = c.status
                }
            }
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
