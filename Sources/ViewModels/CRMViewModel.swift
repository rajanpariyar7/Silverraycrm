import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

@MainActor
final class CRMViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: CRMUser? = nil
    @Published var googleAccessToken: String? = nil

    @Published var allClients: [ClientRecord] = []
    @Published var allTasks: [CRMTaskRecord] = []
    @Published var allDeals: [CRMDealRecord] = []
    @Published var contactHistories: [ContactHistoryRecord] = []
    @Published var authorizedUsers: [AuthorizedStaffUser] = StaffRoster.initialAuthorizedUsers
    @Published var sentCampaigns: [SentCampaignRecord] = []

    @Published var campaignTemplates: [CampaignTemplate] = DefaultTemplatesCatalog.templates
    @Published var selectedEmailProvider: BulkEmailProvider = .gmail
    @Published var selectedSMSProvider: BulkSMSProvider = .nativeSms

    @Published var googleSheetUrl: String = SilverRayConfig.spreadsheetUrl
    @Published var sheetTabName: String = "Contacts"
    @Published var googleSheetsApiKey: String = ""
    @Published var appsScriptUrl: String = ""

    @Published var statusMessage: String = ""
    @Published var errorMessage: String? = nil
    @Published var isLoading = false

    private let defaults = UserDefaults.standard
    private let clientsCacheKey = "silverray_ios_clients_v2"
    private let tasksCacheKey = "silverray_ios_tasks_v2"
    private let dealsCacheKey = "silverray_ios_deals_v2"
    private let historyCacheKey = "silverray_ios_history_v2"
    private let usersCacheKey = "silverray_ios_users_v3"
    private let campaignsCacheKey = "silverray_ios_campaigns_v2"
    private let activeUserEmailKey = "silverray_ios_active_user_email"
    private let sheetUrlKey = "silverray_ios_sheet_url"
    private let sheetApiKeyKey = "silverray_ios_sheet_api_key"
    private let appsScriptKey = "silverray_ios_apps_script_url"

    private var firestoreDb: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore(database: SilverRayConfig.firestoreDatabaseId)
    }

    var spreadsheetId: String {
        extractSpreadsheetId(from: googleSheetUrl)
    }

    /// Strict RBAC: ONLY Super Admin sees contacts added by all salespersons.
    var visibleClients: [ClientRecord] {
        guard let user = currentUser else { return [] }
        if user.isSuperAdmin {
            return allClients
        }
        let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myName = user.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allClients.filter { c in
            c.createdBy.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail ||
            c.assignedSalespersonId == user.id ||
            (!myName.isEmpty && c.assignedSalespersonName.lowercased() == myName)
        }
    }

    /// Strict RBAC for Tasks: Super Admin sees all; Admin/Salesperson sees own assigned tasks.
    var visibleTasks: [CRMTaskRecord] {
        guard let user = currentUser else { return [] }
        if user.isSuperAdmin {
            return allTasks
        }
        let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myName = user.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allTasks.filter { t in
            let assigned = t.assignedToUser.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return assigned == myEmail || (!myName.isEmpty && assigned == myName)
        }
    }

    init() {
        loadLocalState()
        restoreSession()
        Task {
            await syncAllWithGoogleSheet()
        }
    }

    // MARK: - Persistence (No Demo Data)

    private func loadLocalState() {
        if let savedUrl = defaults.string(forKey: sheetUrlKey), !savedUrl.isEmpty {
            googleSheetUrl = savedUrl
        }
        googleSheetsApiKey = defaults.string(forKey: sheetApiKeyKey) ?? ""
        appsScriptUrl = defaults.string(forKey: appsScriptKey) ?? ""

        if let data = defaults.data(forKey: usersCacheKey),
           let decoded = try? JSONDecoder().decode([AuthorizedStaffUser].self, from: data),
           !decoded.isEmpty {
            var merged = decoded.map { u -> AuthorizedStaffUser in
                if u.email.lowercased() == SilverRayConfig.superAdminEmail {
                    return AuthorizedStaffUser(email: u.email, name: u.name, role: UserRole.superAdmin.rawValue, password: SilverRayConfig.superAdminPassword, mobile: u.mobile, addedBy: u.addedBy, createdAt: u.createdAt)
                }
                if u.email.lowercased() == SilverRayConfig.defaultAdminEmail || u.email.lowercased() == SilverRayConfig.defaultAdminGmail {
                    return AuthorizedStaffUser(email: u.email, name: u.name, role: UserRole.admin.rawValue, password: SilverRayConfig.defaultAdminPassword, mobile: u.mobile, addedBy: u.addedBy, createdAt: u.createdAt)
                }
                return u
            }
            for defUser in StaffRoster.initialAuthorizedUsers where !merged.contains(where: { $0.email.lowercased() == defUser.email.lowercased() }) {
                merged.append(defUser)
            }
            authorizedUsers = merged
        } else {
            authorizedUsers = StaffRoster.initialAuthorizedUsers
            saveUsersCache()
        }

        if let data = defaults.data(forKey: clientsCacheKey),
           let decoded = try? JSONDecoder().decode([ClientRecord].self, from: data) {
            allClients = decoded
        } else {
            allClients = []
        }

        if let data = defaults.data(forKey: tasksCacheKey),
           let decoded = try? JSONDecoder().decode([CRMTaskRecord].self, from: data) {
            allTasks = decoded
        } else {
            allTasks = []
        }

        if let data = defaults.data(forKey: dealsCacheKey),
           let decoded = try? JSONDecoder().decode([CRMDealRecord].self, from: data) {
            allDeals = decoded
        } else {
            allDeals = []
        }

        if let data = defaults.data(forKey: historyCacheKey),
           let decoded = try? JSONDecoder().decode([ContactHistoryRecord].self, from: data) {
            contactHistories = decoded
        }

        if let data = defaults.data(forKey: campaignsCacheKey),
           let decoded = try? JSONDecoder().decode([SentCampaignRecord].self, from: data) {
            sentCampaigns = decoded
        }
    }

    private func saveClientsCache() {
        if let data = try? JSONEncoder().encode(allClients) {
            defaults.set(data, forKey: clientsCacheKey)
        }
    }

    private func saveTasksCache() {
        if let data = try? JSONEncoder().encode(allTasks) {
            defaults.set(data, forKey: tasksCacheKey)
        }
    }

    private func saveDealsCache() {
        if let data = try? JSONEncoder().encode(allDeals) {
            defaults.set(data, forKey: dealsCacheKey)
        }
    }

    private func saveHistoryCache() {
        if let data = try? JSONEncoder().encode(contactHistories) {
            defaults.set(data, forKey: historyCacheKey)
        }
    }

    private func saveUsersCache() {
        if let data = try? JSONEncoder().encode(authorizedUsers) {
            defaults.set(data, forKey: usersCacheKey)
        }
    }

    private func saveCampaignsCache() {
        if let data = try? JSONEncoder().encode(Array(sentCampaigns.prefix(100))) {
            defaults.set(data, forKey: campaignsCacheKey)
        }
    }

    func saveSheetSettings() {
        defaults.set(googleSheetUrl, forKey: sheetUrlKey)
        defaults.set(googleSheetsApiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: sheetApiKeyKey)
        defaults.set(appsScriptUrl.trimmingCharacters(in: .whitespacesAndNewlines), forKey: appsScriptKey)
    }

    // MARK: - Authentication & RBAC

    func restoreSession() {
        if let fbUser = Auth.auth().currentUser, let email = fbUser.email {
            if let staff = StaffRoster.resolve(email, from: authorizedUsers) {
                currentUser = buildUser(from: staff, id: fbUser.uid, googleLinked: true)
                isAuthenticated = true
                Task { await syncFromFirestore() }
                return
            }
        }
        if let savedEmail = defaults.string(forKey: activeUserEmailKey),
           let staff = StaffRoster.resolve(savedEmail, from: authorizedUsers) {
            currentUser = buildUser(from: staff, id: "sheet_user_\(staff.email)", googleLinked: savedEmail.hasSuffix("@gmail.com"))
            isAuthenticated = true
        }
    }

    private func buildUser(from staff: AuthorizedStaffUser, id: String, googleLinked: Bool) -> CRMUser {
        CRMUser(
            id: id,
            name: staff.name,
            email: staff.email,
            role: staff.resolvedRole,
            title: staff.resolvedRole.displayName,
            mobile: staff.mobile,
            addedBy: staff.addedBy,
            isGoogleLinked: googleLinked
        )
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        await syncUsersFromRemoteSheet()

        guard let staff = StaffRoster.resolve(cleanEmail, from: authorizedUsers) else {
            errorMessage = "Access Denied: '\(cleanEmail)' is not authorized to log in."
            return
        }
        guard !cleanPass.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }

        // Verify either against Firebase Auth OR synced Google Sheet authorized roster password
        var firebaseUid: String? = nil
        if FirebaseApp.app() != nil {
            if let authRes = try? await Auth.auth().signIn(withEmail: cleanEmail, password: cleanPass) {
                firebaseUid = authRes.user.uid
            }
        }

        if firebaseUid == nil && cleanPass != staff.password.trimmingCharacters(in: .whitespacesAndNewlines) {
            errorMessage = "Invalid email address or password."
            return
        }

        let resolvedUser = buildUser(
            from: staff,
            id: firebaseUid ?? "sheet_user_\(cleanEmail)",
            googleLinked: cleanEmail.hasSuffix("@gmail.com")
        )
        currentUser = resolvedUser
        defaults.set(cleanEmail, forKey: activeUserEmailKey)
        isAuthenticated = true
        await syncAllWithGoogleSheet()
        if firebaseUid != nil {
            await syncFromFirestore()
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let clientId = FirebaseApp.app()?.options.clientID, !clientId.isEmpty else {
            errorMessage = "iOS Google Sign-In CLIENT_ID is missing in GoogleService-Info.plist. Add the iOS app in Firebase Console and update GoogleService-Info.plist."
            return
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to present Google Sign-In screen."
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        let scopes = [
            "https://www.googleapis.com/auth/gmail.send",
            "https://www.googleapis.com/auth/spreadsheets",
            "https://www.googleapis.com/auth/calendar"
        ]

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: nil,
                additionalScopes: scopes
            )
            let gmail = (result.user.profile?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            await syncUsersFromRemoteSheet()

            guard let staff = StaffRoster.resolve(gmail, from: authorizedUsers) else {
                GIDSignIn.sharedInstance.signOut()
                errorMessage = "Access Denied: '\(gmail)' has not been added by Admin."
                return
            }

            googleAccessToken = result.user.accessToken.tokenString
            var uid = "gmail_user_\(gmail)"
            if let idToken = result.user.idToken?.tokenString {
                let cred = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                if let fbRes = try? await Auth.auth().signIn(with: cred) {
                    uid = fbRes.user.uid
                }
            }

            currentUser = buildUser(from: staff, id: uid, googleLinked: true)
            defaults.set(gmail, forKey: activeUserEmailKey)
            isAuthenticated = true
            statusMessage = "Signed in with Google Workspace (\(gmail))"
            await syncAllWithGoogleSheet()
            await syncFromFirestore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
            statusMessage = "Password reset link sent to \(email)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        googleAccessToken = nil
        currentUser = nil
        defaults.removeObject(forKey: activeUserEmailKey)
        isAuthenticated = false
        statusMessage = "Logged out of Silver Ray CRM"
    }

    // MARK: - Admin Role & User Management

    func addAuthorizedUser(email: String, name: String, role: UserRole, password: String, mobile: String) async -> String? {
        guard let actor = currentUser, actor.canManageAuthorizedEmails else {
            return "Only Admin or Super Admin can authorize users."
        }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanEmail.contains("@") else {
            return "Enter a valid email address."
        }
        let allowedRole = actor.isSuperAdmin ? role : (role == .superAdmin ? .admin : role)
        let newUser = AuthorizedStaffUser(
            email: cleanEmail,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(cleanEmail.split(separator: "@").first ?? "Staff") : name.trimmingCharacters(in: .whitespacesAndNewlines),
            role: allowedRole.rawValue,
            password: password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "silverray" : password.trimmingCharacters(in: .whitespacesAndNewlines),
            mobile: mobile.trimmingCharacters(in: .whitespacesAndNewlines),
            addedBy: actor.email,
            createdAt: Date()
        )
        if let idx = authorizedUsers.firstIndex(where: { $0.email.lowercased() == cleanEmail }) {
            authorizedUsers[idx] = newUser
        } else {
            authorizedUsers.append(newUser)
        }
        saveUsersCache()
        await appendRowToGoogleSheet(
            tabName: "Users",
            values: [newUser.email, newUser.name, newUser.role, newUser.password, newUser.mobile, newUser.addedBy, formatTimestamp(newUser.createdAt)]
        )
        statusMessage = "Saved \(newUser.email) as \(allowedRole.displayName)"
        return nil
    }

    func updateAuthorizedUserRole(email: String, newRole: UserRole) {
        guard let actor = currentUser, actor.canManageAuthorizedEmails else { return }
        let clean = email.lowercased()
        guard clean != SilverRayConfig.superAdminEmail else { return }
        let allowed = (!actor.isSuperAdmin && newRole == .superAdmin) ? .salesperson : newRole
        authorizedUsers = authorizedUsers.map { u in
            guard u.email.lowercased() == clean else { return u }
            var copy = u
            copy.role = allowed.rawValue
            return copy
        }
        saveUsersCache()
        statusMessage = "Updated \(clean) role to \(allowed.displayName)"
    }

    func removeAuthorizedUser(email: String) {
        guard let actor = currentUser, actor.canManageAuthorizedEmails else { return }
        let clean = email.lowercased()
        guard clean != SilverRayConfig.superAdminEmail else { return }
        if !actor.isSuperAdmin && clean == SilverRayConfig.defaultAdminEmail { return }
        authorizedUsers.removeAll { $0.email.lowercased() == clean }
        saveUsersCache()
        statusMessage = "Removed \(clean)"
    }

    // MARK: - Client CRUD

    func addClient(_ client: ClientRecord) async {
        let nextSheetId = (allClients.map { $0.sheetId }.max() ?? 0) + 1
        let creator = client.createdBy.isEmpty ? (currentUser?.email ?? SilverRayConfig.superAdminEmail) : client.createdBy
        var saved = client
        saved.sheetId = client.sheetId > 0 ? client.sheetId : nextSheetId
        saved.name = client.fullName
        saved.createdBy = creator
        saved.assignedSalespersonId = currentUser?.id ?? creator
        saved.assignedSalespersonName = currentUser?.name ?? creator
        saved.updatedAt = Date()

        allClients.insert(saved, at: 0)
        saveClientsCache()

        await appendRowToGoogleSheet(
            tabName: "Contacts",
            values: contactToRow(saved)
        )
        await syncContactToFirestore(saved)
        statusMessage = "Added \(saved.fullName) to Google Sheet & CRM"
    }

    func updateClient(_ client: ClientRecord) async {
        var updated = client
        updated.name = client.fullName
        updated.updatedAt = Date()
        if let idx = allClients.firstIndex(where: { $0.id == client.id }) {
            allClients[idx] = updated
            saveClientsCache()
            await updateRowInGoogleSheet(tabName: "Contacts", rowNumber: idx + 2, lastCol: "K", values: contactToRow(updated))
        }
        await syncContactToFirestore(updated)
        statusMessage = "Updated \(updated.fullName)"
    }

    func deleteClient(_ client: ClientRecord) async {
        allClients.removeAll { $0.id == client.id }
        saveClientsCache()
        if let db = firestoreDb, let uid = Auth.auth().currentUser?.uid {
            try? await db.collection("users").document(uid).collection("contacts").document(client.id).delete()
        }
        statusMessage = "Deleted \(client.fullName)"
    }

    func addHistory(for clientId: String, type: String, notes: String) {
        let entry = ContactHistoryRecord(
            id: UUID().uuidString,
            clientId: clientId,
            contactDate: Date(),
            type: type,
            notes: notes
        )
        contactHistories.insert(entry, at: 0)
        saveHistoryCache()
    }

    // MARK: - Tasks CRUD

    func addTask(_ task: CRMTaskRecord) async {
        let nextSheetId = (allTasks.map { $0.sheetId }.max() ?? 0) + 1
        var saved = task
        saved.sheetId = task.sheetId > 0 ? task.sheetId : nextSheetId
        if saved.assignedToUser.isEmpty {
            saved.assignedToUser = currentUser?.email ?? SilverRayConfig.superAdminEmail
        }
        allTasks.insert(saved, at: 0)
        saveTasksCache()

        await appendRowToGoogleSheet(tabName: "Tasks", values: taskToRow(saved))
        await syncTaskToFirestore(saved)
        statusMessage = "Added task: \(saved.title)"
    }

    func toggleTaskCompletion(_ task: CRMTaskRecord) async {
        guard let idx = allTasks.firstIndex(where: { $0.id == task.id }) else { return }
        allTasks[idx].isCompleted.toggle()
        let updated = allTasks[idx]
        saveTasksCache()
        await updateRowInGoogleSheet(tabName: "Tasks", rowNumber: idx + 2, lastCol: "I", values: taskToRow(updated))
        await syncTaskToFirestore(updated)
    }

    func deleteTask(_ task: CRMTaskRecord) async {
        allTasks.removeAll { $0.id == task.id }
        saveTasksCache()
        if let db = firestoreDb, let uid = Auth.auth().currentUser?.uid {
            try? await db.collection("users").document(uid).collection("tasks").document(task.id).delete()
        }
    }

    // MARK: - Deals CRUD

    func addDeal(_ deal: CRMDealRecord) async {
        let nextSheetId = (allDeals.map { $0.sheetId }.max() ?? 0) + 1
        var saved = deal
        saved.sheetId = deal.sheetId > 0 ? deal.sheetId : nextSheetId
        allDeals.insert(saved, at: 0)
        saveDealsCache()
        await appendRowToGoogleSheet(
            tabName: "Deals",
            values: [String(saved.sheetId), saved.title, saved.value, saved.stage, saved.clientId ?? "", saved.notes]
        )
    }

    func deleteDeal(_ deal: CRMDealRecord) {
        allDeals.removeAll { $0.id == deal.id }
        saveDealsCache()
    }

    // MARK: - Firestore Sync (/users/{uid}/contacts & /users/{uid}/tasks)

    func syncFromFirestore() async {
        guard let db = firestoreDb, let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let contactSnap = try await db.collection("users").document(uid).collection("contacts")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            let fetchedClients: [ClientRecord] = contactSnap.documents.map { doc in
                let d = doc.data()
                let fullName = d["name"] as? String ?? "Contact"
                let parts = fullName.split(separator: " ", maxSplits: 1).map(String.init)
                return ClientRecord(
                    id: doc.documentID,
                    sheetId: d["sheetContactId"] as? Int ?? 0,
                    firstName: parts.first ?? fullName,
                    lastName: parts.count > 1 ? parts[1] : "",
                    name: fullName,
                    email: d["email"] as? String ?? "",
                    mobile: d["mobile"] as? String ?? "",
                    birthdate: d["birthdate"] as? String ?? "",
                    company: d["company"] as? String ?? "",
                    address: d["address"] as? String ?? "",
                    suburb: "",
                    state: "QLD",
                    postcode: "",
                    notes: d["notes"] as? String ?? "",
                    properties: d["properties"] as? String ?? "",
                    status: d["status"] as? String ?? "Active",
                    classification: "Client",
                    interestedProperty: d["properties"] as? String ?? "",
                    budgetRange: "",
                    createdBy: d["createdBy"] as? String ?? (currentUser?.email ?? ""),
                    assignedSalespersonId: uid,
                    assignedSalespersonName: currentUser?.name ?? "",
                    marketingConsent: true,
                    updatedAt: Date()
                )
            }
            if !fetchedClients.isEmpty {
                mergeClients(fetchedClients)
            }

            let taskSnap = try await db.collection("users").document(uid).collection("tasks")
                .whereField("userId", isEqualTo: uid)
                .getDocuments()
            let fetchedTasks: [CRMTaskRecord] = taskSnap.documents.map { doc in
                let d = doc.data()
                let dueMs = (d["dueDate"] as? NSNumber)?.doubleValue ?? (Date().timeIntervalSince1970 * 1000.0)
                return CRMTaskRecord(
                    id: doc.documentID,
                    sheetId: d["sheetTaskId"] as? Int ?? 0,
                    title: d["title"] as? String ?? "Task",
                    description: d["description"] as? String ?? "",
                    dueDate: Date(timeIntervalSince1970: dueMs / 1000.0),
                    priority: d["priority"] as? String ?? "Medium",
                    assignedToUser: d["assignedToUser"] as? String ?? "",
                    clientId: nil,
                    clientName: d["clientName"] as? String ?? "",
                    isCompleted: d["isCompleted"] as? Bool ?? false,
                    createdAt: Date()
                )
            }
            if !fetchedTasks.isEmpty {
                mergeTasks(fetchedTasks)
            }
        } catch {
            // Keep Google Sheet synced records if Firestore query lacks index/rules permission
        }
    }

    private func syncContactToFirestore(_ c: ClientRecord) async {
        guard let db = firestoreDb, let uid = Auth.auth().currentUser?.uid else { return }
        let payload: [String: Any] = [
            "userId": uid,
            "sheetContactId": c.sheetId,
            "name": c.fullName,
            "email": c.email,
            "mobile": c.mobile,
            "birthdate": c.birthdate,
            "company": c.company,
            "address": c.address,
            "notes": c.notes,
            "properties": c.properties,
            "status": c.status,
            "createdBy": c.createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection("users").document(uid).collection("contacts").document(c.id).setData(payload, merge: true)
    }

    private func syncTaskToFirestore(_ t: CRMTaskRecord) async {
        guard let db = firestoreDb, let uid = Auth.auth().currentUser?.uid else { return }
        let payload: [String: Any] = [
            "userId": uid,
            "sheetTaskId": t.sheetId,
            "title": t.title,
            "description": t.description,
            "dueDate": Int64(t.dueDate.timeIntervalSince1970 * 1000.0),
            "priority": t.priority,
            "assignedToUser": t.assignedToUser,
            "clientName": t.clientName,
            "isCompleted": t.isCompleted,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection("users").document(uid).collection("tasks").document(t.id).setData(payload, merge: true)
    }

    // MARK: - Google Sheets Sync Engine (Spreadsheet 1WvNTb1zHc6ltByj_y0v-OPlpGQPlHKae)

    func syncAllWithGoogleSheet() async {
        isLoading = true
        defer { isLoading = false }
        await syncUsersFromRemoteSheet()
        let cCount = await syncContactsFromRemoteSheet()
        let tCount = await syncTasksFromRemoteSheet()
        statusMessage = "Synced \(cCount) contacts & \(tCount) tasks with Google Sheet (\(spreadsheetId))"
    }

    @discardableResult
    private func syncContactsFromRemoteSheet() async -> Int {
        // 1. Try Sheets REST API v4 if API Key or OAuth token present
        if !googleSheetsApiKey.isEmpty || !(googleAccessToken ?? "").isEmpty {
            for range in ["Contacts!A1:Z2000", "A1:Z2000"] {
                if let rows = await fetchSheetsApiValues(range: range), rows.count > 1 {
                    let parsed = parseContactsFromSheetRows(rows)
                    if !parsed.isEmpty {
                        mergeClients(parsed)
                        return allClients.count
                    }
                }
            }
        }

        // 2. Try GViz / Export CSV endpoints
        let endpoints = [
            "https://docs.google.com/spreadsheets/d/\(spreadsheetId)/gviz/tq?tqx=out:csv&sheet=Contacts",
            "https://docs.google.com/spreadsheets/d/\(spreadsheetId)/gviz/tq?tqx=out:csv",
            "https://docs.google.com/spreadsheets/d/\(spreadsheetId)/export?format=csv"
        ]
        for urlStr in endpoints {
            guard let url = URL(string: urlStr) else { continue }
            if let (data, resp) = try? await URLSession.shared.data(from: url),
               (resp as? HTTPURLResponse)?.statusCode == 200,
               let text = String(data: data, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<!doctype"),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<html") {
                let rows = parseCsvToRows(text)
                let parsed = parseContactsFromSheetRows(rows)
                if !parsed.isEmpty {
                    mergeClients(parsed)
                    return allClients.count
                }
            }
        }
        return allClients.count
    }

    @discardableResult
    private func syncTasksFromRemoteSheet() async -> Int {
        if let rows = await fetchSheetsApiValues(range: "Tasks!A1:I500"), rows.count > 1 {
            let parsed = parseTasksFromSheetRows(rows)
            if !parsed.isEmpty {
                mergeTasks(parsed)
                return allTasks.count
            }
        }
        let csvUrl = "https://docs.google.com/spreadsheets/d/\(spreadsheetId)/gviz/tq?tqx=out:csv&sheet=Tasks"
        if let url = URL(string: csvUrl),
           let (data, resp) = try? await URLSession.shared.data(from: url),
           (resp as? HTTPURLResponse)?.statusCode == 200,
           let text = String(data: data, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<!doctype") {
            let parsed = parseTasksFromSheetRows(parseCsvToRows(text))
            if !parsed.isEmpty {
                mergeTasks(parsed)
            }
        }
        return allTasks.count
    }

    private func syncUsersFromRemoteSheet() async {
        guard let rows = await fetchSheetsApiValues(range: "Users!A1:G200"), rows.count > 1 else { return }
        let hasHeader = rows[0].contains { $0.trimmingCharacters(in: .whitespaces).lowercased() == "email" }
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        for r in dataRows {
            let email = (r.count > 0 ? r[0] : "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard email.contains("@") else { continue }
            let u = AuthorizedStaffUser(
                email: email,
                name: r.count > 1 ? r[1].trimmingCharacters(in: .whitespaces) : String(email.split(separator: "@").first ?? "Staff"),
                role: email == SilverRayConfig.superAdminEmail ? UserRole.superAdmin.rawValue : UserRole.from(r.count > 2 ? r[2] : nil).rawValue,
                password: (r.count > 3 && !r[3].trimmingCharacters(in: .whitespaces).isEmpty) ? r[3].trimmingCharacters(in: .whitespaces) : "silverray",
                mobile: r.count > 4 ? r[4].trimmingCharacters(in: .whitespaces) : "",
                addedBy: (r.count > 5 && !r[5].isEmpty) ? r[5] : SilverRayConfig.superAdminEmail,
                createdAt: Date()
            )
            if let idx = authorizedUsers.firstIndex(where: { $0.email.lowercased() == email }) {
                authorizedUsers[idx] = u
            } else {
                authorizedUsers.append(u)
            }
        }
        saveUsersCache()
    }

    func pushToGoogleSheets() async {
        saveSheetSettings()
        if let token = googleAccessToken, !token.isEmpty {
            let header = ["ID", "Name", "Email", "Mobile", "Birthdate", "Company", "Address", "Notes", "Properties", "Status", "CreatedBy"]
            let rows = [header] + visibleClients.map { contactToRow($0) }
            await updateRangeInGoogleSheet(range: "\(sheetTabName)!A1:K\(rows.count)", values: rows)
            statusMessage = "Pushed \(visibleClients.count) rows to Google Sheet tab '\(sheetTabName)'"
        } else if appsScriptUrl.starts(with: "https://script.google.com") {
            for c in visibleClients {
                await appendRowToGoogleSheet(tabName: sheetTabName, values: contactToRow(c))
            }
            statusMessage = "Synced \(visibleClients.count) rows via Apps Script bridge"
        } else {
            await syncAllWithGoogleSheet()
        }
    }

    func importClientsFromCsvFile(url: URL) -> Int {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        let parsed = parseContactsFromSheetRows(parseCsvToRows(text))
        guard !parsed.isEmpty else { return 0 }
        let owner = currentUser?.email ?? SilverRayConfig.superAdminEmail
        let owned = parsed.map { item -> ClientRecord in
            var c = item
            if c.createdBy.isEmpty { c.createdBy = owner }
            return c
        }
        mergeClients(owned)
        statusMessage = "Imported \(owned.count) contacts from CSV"
        return owned.count
    }

    func exportVisibleClientsCsv() -> URL? {
        let header = "ID,Name,Email,Mobile,Birthdate,Company,Address,Notes,Properties,Status,CreatedBy\n"
        let body = visibleClients.map { c in
            contactToRow(c).map { escapeCsv($0) }.joined(separator: ",")
        }.joined(separator: "\n")
        let full = header + body
        let outUrl = FileManager.default.temporaryDirectory.appendingPathComponent("SilverRay_Contacts_Export.csv")
        try? full.write(to: outUrl, atomically: true, encoding: .utf8)
        return outUrl
    }

    // MARK: - Campaigns (Gmail OAuth MIME + Attachment + Sent History)

    func recordDispatchedCampaign(_ record: SentCampaignRecord) {
        sentCampaigns.insert(record, at: 0)
        saveCampaignsCache()
    }

    func sendBulkGmailViaApi(
        recipients: [ClientRecord],
        subject: String,
        body: String,
        linkUrl: String,
        imageData: Data?
    ) async -> Int {
        guard let token = googleAccessToken, !token.isEmpty else { return 0 }
        var sentCount = 0
        let trimmedLink = linkUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        for client in recipients where !client.email.isEmpty {
            let first = client.firstName.isEmpty ? (client.fullName.split(separator: " ").first.map(String.init) ?? "Client") : client.firstName
            let resolvedSubject = subject
                .replacingOccurrences(of: "[FirstName]", with: first)
                .replacingOccurrences(of: "[FullName]", with: client.fullName)
                .replacingOccurrences(of: "{{firstName}}", with: first)
            var resolvedBody = body
                .replacingOccurrences(of: "[FirstName]", with: first)
                .replacingOccurrences(of: "[FullName]", with: client.fullName)
                .replacingOccurrences(of: "{{firstName}}", with: first)
                .replacingOccurrences(of: "{{salespersonName}}", with: currentUser?.name ?? "Silver Ray Realty")
            if !trimmedLink.isEmpty {
                resolvedBody += "\n\nView Details: \(trimmedLink)"
            }

            let rawMime = buildMimeEmail(
                to: client.email,
                subject: resolvedSubject,
                plainBody: resolvedBody,
                linkUrl: trimmedLink,
                imageData: imageData
            )
            let encoded = Data(rawMime.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")

            guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["raw": encoded])

            if let (_, resp) = try? await URLSession.shared.data(for: req),
               let code = (resp as? HTTPURLResponse)?.statusCode, code < 300 {
                sentCount += 1
            }
        }
        statusMessage = "Dispatched \(sentCount)/\(recipients.count) emails directly via Gmail API."
        return sentCount
    }

    private func buildMimeEmail(
        to: String,
        subject: String,
        plainBody: String,
        linkUrl: String,
        imageData: Data?
    ) -> String {
        let htmlEscaped = plainBody
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br/>")
        var html = "<div style='font-family:sans-serif;line-height:1.5;'>\(htmlEscaped)"
        if !linkUrl.isEmpty {
            html += "<p><a href='\(linkUrl)'>View Offer / Property Link</a></p>"
        }
        html += "<hr/><p style='font-size:12px;color:#666;'>Silver Ray Realty Pty Ltd &bull; Geebung QLD 4034 &bull; <a href='https://silverray.com.au'>silverray.com.au</a></p></div>"

        guard let img = imageData else {
            return "To: \(to)\r\nSubject: \(subject)\r\nContent-Type: text/html; charset=utf-8\r\n\r\n\(html)"
        }

        let boundary = "SilverRayCRM_\(UUID().uuidString)"
        let b64Img = img.base64EncodedString(options: .lineLength76Characters)
        return """
        To: \(to)\r
        Subject: \(subject)\r
        MIME-Version: 1.0\r
        Content-Type: multipart/mixed; boundary="\(boundary)"\r
        \r
        --\(boundary)\r
        Content-Type: text/html; charset="utf-8"\r
        \r
        \(html)\r
        \r
        --\(boundary)\r
        Content-Type: image/jpeg; name="campaign_banner.jpg"\r
        Content-Transfer-Encoding: base64\r
        Content-Disposition: attachment; filename="campaign_banner.jpg"\r
        \r
        \(b64Img)\r
        \r
        --\(boundary)--
        """
    }

    // MARK: - Google Sheets REST v4 Helpers & CSV Parsing

    private func extractSpreadsheetId(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return SilverRayConfig.spreadsheetId }
        if let regex = try? NSRegularExpression(pattern: "/spreadsheets/d/([a-zA-Z0-9-_]+)"),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let range = Range(match.range(at: 1), in: trimmed) {
            return String(trimmed[range])
        }
        return !trimmed.contains("/") && trimmed.count >= 15 ? trimmed : SilverRayConfig.spreadsheetId
    }

    private func fetchSheetsApiValues(range: String) async -> [[String]]? {
        let apiKey = googleSheetsApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = (googleAccessToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty || !token.isEmpty else { return nil }
        let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? range
        var urlStr = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(encodedRange)"
        if !apiKey.isEmpty { urlStr += "?key=\(apiKey)" }
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["values"] as? [[String]] else {
            return nil
        }
        return values
    }

    private func appendRowToGoogleSheet(tabName: String, values: [String]) async {
        let apiKey = googleSheetsApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = (googleAccessToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty || !token.isEmpty {
            let encodedRange = "\(tabName)!A1".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tabName
            var urlStr = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(encodedRange):append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS"
            if !apiKey.isEmpty { urlStr += "&key=\(apiKey)" }
            if let url = URL(string: urlStr) {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: ["majorDimension": "ROWS", "values": [values]])
                _ = try? await URLSession.shared.data(for: req)
            }
        }
        let script = appsScriptUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if script.hasPrefix("https://script.google.com"), let url = URL(string: script) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "action": "append",
                "spreadsheetId": spreadsheetId,
                "sheet": tabName,
                "values": values
            ])
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    private func updateRowInGoogleSheet(tabName: String, rowNumber: Int, lastCol: String, values: [String]) async {
        await updateRangeInGoogleSheet(range: "\(tabName)!A\(rowNumber):\(lastCol)\(rowNumber)", values: [values])
    }

    private func updateRangeInGoogleSheet(range: String, values: [[String]]) async {
        let apiKey = googleSheetsApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = (googleAccessToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty || !token.isEmpty else { return }
        let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? range
        var urlStr = "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(encodedRange)?valueInputOption=USER_ENTERED"
        if !apiKey.isEmpty { urlStr += "&key=\(apiKey)" }
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["range": range, "majorDimension": "ROWS", "values": values])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func mergeClients(_ incoming: [ClientRecord]) {
        var current = allClients
        for item in incoming {
            if let idx = current.firstIndex(where: {
                (item.sheetId > 0 && $0.sheetId == item.sheetId) ||
                (!item.email.isEmpty && $0.email.lowercased() == item.email.lowercased()) ||
                (!item.fullName.isEmpty && $0.fullName.lowercased() == item.fullName.lowercased())
            }) {
                var merged = item
                merged.sheetId = current[idx].sheetId > 0 ? current[idx].sheetId : item.sheetId
                current[idx] = merged
            } else {
                current.append(item)
            }
        }
        allClients = current.sorted { $0.fullName.lowercased() < $1.fullName.lowercased() }
        saveClientsCache()
    }

    private func mergeTasks(_ incoming: [CRMTaskRecord]) {
        var current = allTasks
        for item in incoming {
            if let idx = current.firstIndex(where: {
                (item.sheetId > 0 && $0.sheetId == item.sheetId) ||
                ($0.title.lowercased() == item.title.lowercased() && $0.clientName.lowercased() == item.clientName.lowercased())
            }) {
                current[idx] = item
            } else {
                current.append(item)
            }
        }
        allTasks = current.sorted { $0.dueDate < $1.dueDate }
        saveTasksCache()
    }

    private func parseContactsFromSheetRows(_ rows: [[String]]) -> [ClientRecord] {
        guard !rows.isEmpty else { return [] }
        let headers = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let hasHeader = headers.contains {
            $0.contains("name") || $0.contains("email") || $0.contains("mobile") ||
            $0.contains("account") || $0.contains("surname") || $0.contains("phone")
        }
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows

        func findCol(_ keys: String...) -> Int {
            guard hasHeader else { return -1 }
            for k in keys {
                if let exact = headers.firstIndex(of: k) { return exact }
            }
            for k in keys {
                if let partial = headers.firstIndex(where: { $0.contains(k) }) { return partial }
            }
            return -1
        }

        let idCol = findCol("id")
        let accountCol = findCol("account")
        let fullNameCol = findCol("full name", "fullname", "name", "client")
        let reversedCol = findCol("reversed name")
        let firstCol = findCol("firstname", "first name", "christiannames", "christian names")
        let lastCol = findCol("lastname", "last name", "surname")
        let emailCol = findCol("email", "e-mail")
        let mobileCol = findCol("mobile", "phone 1 excel", "phone 1", "phone")
        let phoneAltCol = findCol("phone 1 excel", "phone 1", "phone")
        let birthCol = findCol("birth", "dob")
        let companyCol = findCol("company", "host")
        let addressCol = findCol("address")
        let cityStateCol = findCol("city state", "suburb", "city")
        let postCodeCol = findCol("post code", "postcode")
        let countryCol = findCol("country")
        let notesCol = findCol("notes", "note")
        let eventCol = findCol("event")
        let soldDateCol = findCol("sold date")
        let cameFromCol = findCol("came from", "channel source", "source")
        let canContactCol = findCol("can contact")
        let propCol = findCol("properties", "propert", "asset")
        let statusCol = findCol("status")
        let createdByCol = findCol("createdby", "created_by", "created", "sales", "owner", "added")

        var results: [ClientRecord] = []
        var seen = Set<String>()

        for r in dataRows {
            func cell(_ col: Int, fallback: Int = -1) -> String {
                let idx = col >= 0 ? col : (!hasHeader && fallback >= 0 ? fallback : -1)
                guard idx >= 0 && idx < r.count else { return "" }
                return r[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var first = cell(firstCol)
            var last = cell(lastCol)
            var name = cell(fullNameCol, fallback: 1)

            if name.isEmpty && (!first.isEmpty || !last.isEmpty) {
                name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            }
            if name.isEmpty {
                let rev = cell(reversedCol)
                if !rev.isEmpty {
                    let parts = rev.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count == 2 {
                        if last.isEmpty { last = parts[0] }
                        if first.isEmpty { first = parts[1] }
                        name = "\(parts[1]) \(parts[0])".trimmingCharacters(in: .whitespaces)
                    } else {
                        name = rev
                    }
                }
            }
            if first.isEmpty && last.isEmpty && !name.isEmpty {
                let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
                first = parts.first ?? name
                last = parts.count > 1 ? parts[1] : ""
            }

            let email = cell(emailCol, fallback: 2)
            let m1 = cell(mobileCol, fallback: 3)
            let mobile = m1.isEmpty ? cell(phoneAltCol) : m1
            if name.isEmpty && email.isEmpty && mobile.isEmpty { continue }

            let account = cell(accountCol)
            let dedupKey = !email.isEmpty ? "e:\(email.lowercased())"
                : !account.isEmpty ? "a:\(account.lowercased())"
                : "n:\(name.lowercased())|\(mobile.lowercased())"
            if !seen.insert(dedupKey).inserted { continue }

            let street = cell(addressCol, fallback: 6)
            let suburb = cell(cityStateCol)
            let postcode = cell(postCodeCol)
            let country = cell(countryCol)
            let fullAddress = [street, suburb, postcode, country].filter { !$0.isEmpty }.joined(separator: ", ")

            let baseNotes = cell(notesCol, fallback: 7)
            let meta = [
                account.isEmpty ? nil : "Account: \(account)",
                cell(eventCol).isEmpty ? nil : "Event: \(cell(eventCol))",
                cell(soldDateCol).isEmpty ? nil : "Sold: \(cell(soldDateCol))",
                cell(cameFromCol).isEmpty ? nil : "Source: \(cell(cameFromCol))",
                cell(canContactCol).isEmpty ? nil : "Can Contact: \(cell(canContactCol))"
            ].compactMap { $0 }.joined(separator: " • ")
            let combinedNotes = [baseNotes, meta].filter { !$0.isEmpty }.joined(separator: "\n")

            let parsedId = Int(cell(idCol, fallback: 0)) ?? (results.count + 1)
            let createdBy = cell(createdByCol, fallback: 10).isEmpty ? SilverRayConfig.superAdminEmail : cell(createdByCol, fallback: 10)
            let canContactRaw = cell(canContactCol).lowercased()
            let consent = !(canContactRaw == "no" || canContactRaw == "false" || canContactRaw == "0")

            results.append(
                ClientRecord(
                    id: "sheet_contact_\(parsedId)_\(dedupKey.hashValue)",
                    sheetId: parsedId,
                    firstName: first,
                    lastName: last,
                    name: name.isEmpty ? String(email.split(separator: "@").first ?? "Client") : name,
                    email: email,
                    mobile: mobile,
                    birthdate: cell(birthCol, fallback: 4),
                    company: cell(companyCol, fallback: 5),
                    address: fullAddress,
                    suburb: suburb,
                    state: "QLD",
                    postcode: postcode,
                    notes: combinedNotes,
                    properties: cell(propCol, fallback: 8),
                    status: cell(statusCol, fallback: 9).isEmpty ? "Active" : cell(statusCol, fallback: 9),
                    classification: "Client",
                    interestedProperty: cell(propCol, fallback: 8),
                    budgetRange: "",
                    createdBy: createdBy,
                    assignedSalespersonId: createdBy,
                    assignedSalespersonName: createdBy,
                    marketingConsent: consent,
                    updatedAt: Date()
                )
            )
        }
        return results
    }

    private func parseTasksFromSheetRows(_ rows: [[String]]) -> [CRMTaskRecord] {
        guard !rows.isEmpty else { return [] }
        let headers = rows[0].map { $0.lowercased() }
        let hasHeader = headers.contains { $0.contains("title") || $0.contains("due") || $0.contains("priority") }
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows
        var list: [CRMTaskRecord] = []
        for (idx, r) in dataRows.enumerated() {
            let title = (r.count > 1 && !r[1].trimmingCharacters(in: .whitespaces).isEmpty) ? r[1].trimmingCharacters(in: .whitespaces) : (r.first?.trimmingCharacters(in: .whitespaces) ?? "")
            guard !title.isEmpty else { continue }
            let idVal = Int(r.first?.trimmingCharacters(in: .whitespaces) ?? "") ?? (idx + 1)
            let desc = r.count > 2 ? r[2].trimmingCharacters(in: .whitespaces) : ""
            let dueDate = parseTimestamp(r.count > 3 ? r[3] : "")
            let priority = (r.count > 4 && !r[4].trimmingCharacters(in: .whitespaces).isEmpty) ? r[4].trimmingCharacters(in: .whitespaces) : "Medium"
            let assigned = (r.count > 5 && !r[5].trimmingCharacters(in: .whitespaces).isEmpty) ? r[5].trimmingCharacters(in: .whitespaces) : SilverRayConfig.superAdminEmail
            let clientId = r.count > 6 ? r[6].trimmingCharacters(in: .whitespaces) : nil
            let clientName = r.count > 7 ? r[7].trimmingCharacters(in: .whitespaces) : ""
            let completed = r.count > 8 && r[8].trimmingCharacters(in: .whitespaces).lowercased() == "true"
            list.append(
                CRMTaskRecord(
                    id: "sheet_task_\(idVal)",
                    sheetId: idVal,
                    title: title,
                    description: desc,
                    dueDate: dueDate,
                    priority: priority,
                    assignedToUser: assigned,
                    clientId: clientId,
                    clientName: clientName,
                    isCompleted: completed,
                    createdAt: Date()
                )
            )
        }
        return list
    }

    private func parseCsvToRows(_ csvText: String) -> [[String]] {
        var rows: [[String]] = []
        let lines = csvText.components(separatedBy: .newlines)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            var tokens: [String] = []
            var current = ""
            var inQuotes = false
            let chars = Array(line)
            var i = 0
            while i < chars.count {
                let c = chars[i]
                if c == "\"" {
                    if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                        current.append("\"")
                        i += 1
                    } else {
                        inQuotes.toggle()
                    }
                } else if c == "," && !inQuotes {
                    tokens.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
                i += 1
            }
            tokens.append(current)
            rows.append(tokens)
        }
        return rows
    }

    private func contactToRow(_ c: ClientRecord) -> [String] {
        [String(c.sheetId), c.fullName, c.email, c.mobile, c.birthdate, c.company, c.address, c.notes, c.properties, c.status, c.createdBy]
    }

    private func taskToRow(_ t: CRMTaskRecord) -> [String] {
        [String(t.sheetId), t.title, t.description, formatTimestamp(t.dueDate), t.priority, t.assignedToUser, t.clientId ?? "", t.clientName, t.isCompleted ? "true" : "false"]
    }

    private func escapeCsv(_ value: String) -> String {
        let clean = value.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(clean)\""
    }

    private func formatTimestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }

    private func parseTimestamp(_ input: String) -> Date {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ms = Double(clean), ms > 1_000_000_000 {
            return Date(timeIntervalSince1970: ms > 10_000_000_000 ? ms / 1000.0 : ms)
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = fmt.date(from: clean) { return d }
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: clean) { return d }
        return Date().addingTimeInterval(86400)
    }
}
