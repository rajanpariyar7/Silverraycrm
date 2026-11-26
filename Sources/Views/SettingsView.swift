import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: CRMViewModel

    @State private var newUserEmail = ""
    @State private var newUserName = ""
    @State private var newUserPassword = ""
    @State private var newUserMobile = ""
    @State private var selectedRole: UserRole = .salesperson
    @State private var rbacMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                if let user = vm.currentUser {
                    Section("Role & Access Level") {
                        LabeledContent("Staff", value: user.name)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Role", value: user.roleBadgeText)
                        Text(user.isSuperAdmin
                             ? "Super Admin Privilege: All roles granted. You can view all contacts added by all salespersons."
                             : (user.isAdmin
                                ? "Admin Privilege: You can authorize login emails and manage salesperson roles."
                                : "Sales Person Access: Scoped strictly to your own contacts and tasks."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if user.canManageAuthorizedEmails {
                        Section("Add Authorized User (Admin Only)") {
                            TextField("Email Address *", text: $newUserEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            TextField("Full Name", text: $newUserName)
                            TextField("Initial Password", text: $newUserPassword)
                                .textInputAutocapitalization(.never)
                            TextField("Mobile (optional)", text: $newUserMobile)
                                .keyboardType(.phonePad)

                            Picker("Assign Role", selection: $selectedRole) {
                                Text("Sales Person").tag(UserRole.salesperson)
                                Text("Admin").tag(UserRole.admin)
                                if user.isSuperAdmin {
                                    Text("Super Admin").tag(UserRole.superAdmin)
                                }
                            }

                            Button("Add User & Assign Role") {
                                Task {
                                    let err = await vm.addAuthorizedUser(
                                        email: newUserEmail,
                                        name: newUserName,
                                        role: selectedRole,
                                        password: newUserPassword,
                                        mobile: newUserMobile
                                    )
                                    if let err = err {
                                        rbacMessage = err
                                    } else {
                                        rbacMessage = "Saved \(newUserEmail)!"
                                        newUserEmail = ""; newUserName = ""; newUserPassword = ""; newUserMobile = ""
                                    }
                                }
                            }
                            .disabled(newUserEmail.trimmingCharacters(in: .whitespaces).isEmpty)

                            if let msg = rbacMessage {
                                Text(msg).font(.caption).foregroundStyle(.blue)
                            }
                        }

                        Section("Authorized Staff & Roles (\(vm.authorizedUsers.count))") {
                            ForEach(vm.authorizedUsers) { staff in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(staff.name).font(.subheadline.bold())
                                            Text(staff.email).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if staff.email.lowercased() != SilverRayConfig.superAdminEmail {
                                            Button(role: .destructive) {
                                                vm.removeAuthorizedUser(email: staff.email)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }

                                    if staff.email.lowercased() == SilverRayConfig.superAdminEmail {
                                        Text("Role: Super Admin (All Roles)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.green)
                                    } else {
                                        HStack {
                                            Text("Role:").font(.caption2).foregroundStyle(.secondary)
                                            Button("Salesperson") {
                                                vm.updateAuthorizedUserRole(email: staff.email, newRole: .salesperson)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(staff.resolvedRole == .salesperson ? .blue : .gray)
                                            .font(.caption2)

                                            Button("Admin") {
                                                vm.updateAuthorizedUserRole(email: staff.email, newRole: .admin)
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(staff.resolvedRole == .admin ? .blue : .gray)
                                            .font(.caption2)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                Section("Google Sheets API Service Layer") {
                    TextField("Google Sheet File URL", text: $vm.googleSheetUrl)
                        .textInputAutocapitalization(.never)
                    TextField("Tab Name (default: Contacts)", text: $vm.sheetTabName)
                    TextField("Google Sheets API Key (optional)", text: $vm.googleSheetsApiKey)
                        .textInputAutocapitalization(.never)
                    TextField("Apps Script Bridge URL (optional)", text: $vm.appsScriptUrl)
                        .textInputAutocapitalization(.never)

                    Button("Sync Contacts & Tasks Now") {
                        vm.saveSheetSettings()
                        Task { await vm.syncAllWithGoogleSheet() }
                    }
                    Button("Push CRM → Google Sheet") {
                        Task { await vm.pushToGoogleSheets() }
                    }
                    if let url = URL(string: vm.googleSheetUrl) {
                        Link("Open Connected Google Sheet", destination: url)
                    }
                }

                Section("Google Workspace OAuth (Gmail & Sheets)") {
                    LabeledContent("OAuth Status", value: (vm.googleAccessToken ?? "").isEmpty ? "Not Linked" : "Connected")
                    Button("Connect / Re-Authorize Google Workspace") {
                        Task { await vm.signInWithGoogle() }
                    }
                }

                Section("Session") {
                    Button(role: .destructive) {
                        vm.signOut()
                    } label: {
                        Label("Logout of Silver Ray CRM", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SilverRayTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Admin & Settings")
        }
    }
}
