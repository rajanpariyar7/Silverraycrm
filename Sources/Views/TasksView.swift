import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var vm: CRMViewModel
    @State private var statusFilter = "All"
    @State private var searchText = ""
    @State private var showAddTask = false

    @State private var titleInput = ""
    @State private var descInput = ""
    @State private var dueDateInput = Date().addingTimeInterval(86400)
    @State private var priorityInput = "Medium"
    @State private var selectedClientName = ""

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var filteredTasks: [CRMTaskRecord] {
        vm.visibleTasks.filter { task in
            let matchesStatus: Bool
            switch statusFilter {
            case "Upcoming": matchesStatus = !task.isCompleted && task.dueDate >= startOfToday
            case "Overdue": matchesStatus = !task.isCompleted && task.dueDate < startOfToday
            case "Completed": matchesStatus = task.isCompleted
            default: matchesStatus = true
            }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = q.isEmpty ||
                task.title.lowercased().contains(q) ||
                task.description.lowercased().contains(q) ||
                task.clientName.lowercased().contains(q) ||
                task.assignedToUser.lowercased().contains(q)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["All", "Upcoming", "Overdue", "Completed"], id: \.self) { filter in
                            Button {
                                statusFilter = filter
                            } label: {
                                Text(filter)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(statusFilter == filter ? Color.accentColor : SilverRayTheme.cardSurface)
                                    .foregroundStyle(statusFilter == filter ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if filteredTasks.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "No Tasks",
                        subtitle: "Tap + to schedule a follow-up task synced with Google Sheets."
                    )
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            HStack(spacing: 12) {
                                Button {
                                    Task { await vm.toggleTaskCompletion(task) }
                                } label: {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.headline)
                                        .strikethrough(task.isCompleted)
                                    if !task.description.isEmpty {
                                        Text(task.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    HStack(spacing: 8) {
                                        Text(task.priority)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(priorityColor(task.priority).opacity(0.15))
                                            .foregroundStyle(priorityColor(task.priority))
                                            .clipShape(Capsule())

                                        Text(task.dueDate, style: .date)
                                            .font(.caption2)
                                            .foregroundStyle(!task.isCompleted && task.dueDate < startOfToday ? .red : .secondary)

                                        if !task.clientName.isEmpty {
                                            Text("• \(task.clientName)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.deleteTask(task) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SilverRayTheme.appBackground.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search tasks, clients, assignees")
            .navigationTitle("Tasks (\(filteredTasks.count))")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                NavigationStack {
                    Form {
                        Section("Task Details") {
                            TextField("Title (e.g. Call buyer about inspection)", text: $titleInput)
                            TextField("Description / Notes", text: $descInput)
                            DatePicker("Due Date", selection: $dueDateInput, displayedComponents: [.date, .hourAndMinute])
                            Picker("Priority", selection: $priorityInput) {
                                ForEach(["Low", "Medium", "High", "Urgent"], id: \.self) {
                                    Text($0).tag($0)
                                }
                            }
                        }

                        if !vm.visibleClients.isEmpty {
                            Section("Link Client (Optional)") {
                                Picker("Client", selection: $selectedClientName) {
                                    Text("None").tag("")
                                    ForEach(vm.visibleClients) { c in
                                        Text(c.fullName).tag(c.fullName)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("New Task")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddTask = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let newTask = CRMTaskRecord(
                                    id: UUID().uuidString,
                                    sheetId: 0,
                                    title: titleInput.trimmingCharacters(in: .whitespacesAndNewlines),
                                    description: descInput.trimmingCharacters(in: .whitespacesAndNewlines),
                                    dueDate: dueDateInput,
                                    priority: priorityInput,
                                    assignedToUser: vm.currentUser?.email ?? SilverRayConfig.superAdminEmail,
                                    clientId: nil,
                                    clientName: selectedClientName,
                                    isCompleted: false,
                                    createdAt: Date()
                                )
                                Task { await vm.addTask(newTask) }
                                titleInput = ""; descInput = ""; selectedClientName = ""
                                showAddTask = false
                            }
                            .disabled(titleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "urgent": return .red
        case "high": return .orange
        case "low": return .gray
        default: return .blue
        }
    }
}

struct ContentUnavailableViewCompat: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
