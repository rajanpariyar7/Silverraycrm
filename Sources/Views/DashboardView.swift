import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var vm: CRMViewModel
    @Binding var selectedTab: Int
    @State private var showDealsSheet = false
    @State private var showAddDealSheet = false
    @State private var dealTitle = ""
    @State private var dealValue = ""
    @State private var dealStage = "Lead"
    @State private var dealNotes = ""

    private var activeClientsCount: Int {
        vm.visibleClients.filter { $0.status.caseInsensitiveCompare("Active") == .orderedSame }.count
    }

    private var linkedPropertiesCount: Int {
        vm.visibleClients.filter { !$0.properties.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var overdueTasks: [CRMTaskRecord] {
        vm.visibleTasks.filter { !$0.isCompleted && $0.dueDate < startOfToday }
    }

    private var upcomingTasks: [CRMTaskRecord] {
        vm.visibleTasks.filter { !$0.isCompleted && $0.dueDate >= startOfToday }
    }

    private var todayMonthDay: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM-dd"
        return fmt.string(from: Date())
    }

    private var birthdayClients: [ClientRecord] {
        vm.visibleClients.filter { !$0.birthdate.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var birthdaysToday: [ClientRecord] {
        birthdayClients.filter { $0.birthdate.hasSuffix(todayMonthDay) }
    }

    private var upcomingBirthdays: [ClientRecord] {
        Array(birthdayClients.filter { !$0.birthdate.hasSuffix(todayMonthDay) }.prefix(3))
    }

    private var pipelineTotalFormatted: String {
        let total = vm.allDeals.reduce(0.0) { acc, deal in
            let cleaned = deal.value.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            return acc + (Double(cleaned) ?? 0.0)
        }
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 0
        fmt.locale = Locale(identifier: "en_AU")
        return fmt.string(from: NSNumber(value: total)) ?? "$0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // User & Role Header Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome, \(vm.currentUser?.name ?? "Staff")")
                                .font(.headline)
                            Text(vm.currentUser?.roleBadgeText ?? "CRM PORTAL")
                                .font(.caption.bold())
                                .foregroundStyle(vm.currentUser?.isSuperAdmin == true ? .green : .blue)
                        }
                        Spacer()
                        Button {
                            vm.signOut()
                        } label: {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Birthdays Today Card
                    if !birthdaysToday.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Birthdays Today!", systemImage: "birthday.cake.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            ForEach(birthdaysToday) { client in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(client.fullName).fontWeight(.semibold)
                                        Text(client.mobile.isEmpty ? client.email : client.mobile)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Send Wishes") {
                                        let first = client.firstName.isEmpty ? client.fullName : client.firstName
                                        let body = "Happy Birthday \(first)! Wishing you a fantastic day from Silver Ray Realty."
                                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                        if !client.mobile.isEmpty,
                                           let url = URL(string: "sms:\(client.mobile)&body=\(body)") {
                                            UIApplication.shared.open(url)
                                        } else if !client.email.isEmpty,
                                                  let url = URL(string: "mailto:\(client.email)?subject=Happy%20Birthday!&body=\(body)") {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Upcoming Birthdays
                    if !upcomingBirthdays.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Upcoming Birthdays", systemImage: "calendar")
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                            ForEach(upcomingBirthdays) { client in
                                HStack {
                                    Text(client.fullName).font(.subheadline)
                                    Spacer()
                                    Text(client.birthdate).font(.subheadline.bold()).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Tasks & Deadlines Widget
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tasks & Deadlines").font(.headline)
                                Text("\(overdueTasks.count) overdue • \(upcomingTasks.count) upcoming")
                                    .font(.caption)
                                    .foregroundStyle(overdueTasks.isEmpty ? Color.secondary : Color.red)
                            }
                            Spacer()
                            Button("View All") {
                                selectedTab = 2
                            }
                            .font(.caption.bold())
                        }

                        let topTasks = Array((overdueTasks.prefix(2) + upcomingTasks.prefix(2)).prefix(2))
                        if topTasks.isEmpty {
                            Text("No pending tasks.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(topTasks) { task in
                                HStack {
                                    Circle()
                                        .fill(task.dueDate < startOfToday ? Color.red : Color.blue)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading) {
                                        Text(task.title).font(.subheadline.weight(.medium)).lineLimit(1)
                                        if !task.clientName.isEmpty {
                                            Text(task.clientName).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(task.dueDate < startOfToday ? "Overdue" : task.priority)
                                        .font(.caption2.bold())
                                        .foregroundStyle(task.dueDate < startOfToday ? .red : .blue)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // KPI Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        KPICard(title: "Total Contacts", value: "\(vm.visibleClients.count)", subtitle: vm.visibleClients.isEmpty ? "Sync Sheet or Import CSV" : "Google Sheet Synced", color: .blue)
                        KPICard(title: "Active Clients", value: "\(activeClientsCount)", subtitle: "In Directory", color: .green)
                        KPICard(title: "Open Deals", value: "\(vm.allDeals.count)", subtitle: "Pipeline", color: .purple)
                        KPICard(title: "Properties", value: "\(linkedPropertiesCount)", subtitle: "Linked Assets", color: .orange)
                    }

                    // Sales Pipeline Card
                    Button {
                        showDealsSheet = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sales Pipeline Value")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(pipelineTotalFormatted)
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                Text(vm.allDeals.isEmpty ? "Tap to add your first deal" : "Across \(vm.allDeals.count) active deals · Tap to manage")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    if !vm.statusMessage.isEmpty {
                        Text(vm.statusMessage)
                            .font(.footnote)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .refreshable {
                await vm.syncAllWithGoogleSheet()
            }
            .navigationTitle("Silver Ray CRM")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.syncAllWithGoogleSheet() }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .sheet(isPresented: $showDealsSheet) {
                NavigationStack {
                    List {
                        if vm.allDeals.isEmpty {
                            Text("No deals recorded yet. Tap + to add one.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.allDeals) { deal in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(deal.title).font(.headline)
                                        Spacer()
                                        Text(deal.value).font(.subheadline.bold()).foregroundStyle(.green)
                                    }
                                    Text("Stage: \(deal.stage)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !deal.notes.isEmpty {
                                        Text(deal.notes).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        vm.deleteDeal(deal)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Sales Pipeline")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showDealsSheet = false }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showAddDealSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                    .sheet(isPresented: $showAddDealSheet) {
                        NavigationStack {
                            Form {
                                TextField("Deal Title", text: $dealTitle)
                                TextField("Estimated Value (e.g. $950,000)", text: $dealValue)
                                Picker("Stage", selection: $dealStage) {
                                    ForEach(["Lead", "Qualified", "Proposal", "Negotiation", "Closed Won"], id: \.self) {
                                        Text($0).tag($0)
                                    }
                                }
                                TextField("Notes", text: $dealNotes)
                            }
                            .navigationTitle("New Deal")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") { showAddDealSheet = false }
                                }
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Save") {
                                        let d = CRMDealRecord(
                                            id: UUID().uuidString,
                                            sheetId: 0,
                                            title: dealTitle,
                                            value: dealValue,
                                            stage: dealStage,
                                            clientId: nil,
                                            notes: dealNotes
                                        )
                                        Task { await vm.addDeal(d) }
                                        dealTitle = ""; dealValue = ""; dealNotes = ""
                                        showAddDealSheet = false
                                    }
                                    .disabled(dealTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct KPICard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
