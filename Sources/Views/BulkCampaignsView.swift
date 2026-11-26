import SwiftUI
import PhotosUI
import MessageUI

struct BulkCampaignsView: View {
    @EnvironmentObject private var vm: CRMViewModel

    @State private var selectedChannel = 0 // 0 = Email, 1 = SMS
    @State private var isComposing = false
    @State private var preselectedTemplate: CampaignTemplate? = nil
    @State private var inspectedRecord: SentCampaignRecord? = nil

    private var activeChannelName: String { selectedChannel == 0 ? "Email" : "SMS" }

    private var eligibleCount: Int {
        if selectedChannel == 0 {
            return vm.visibleClients.filter { !$0.email.trimmingCharacters(in: .whitespaces).isEmpty }.count
        } else {
            return vm.visibleClients.filter { !$0.mobile.trimmingCharacters(in: .whitespaces).isEmpty }.count
        }
    }

    private var filteredHistory: [SentCampaignRecord] {
        vm.sentCampaigns.filter { $0.channel == activeChannelName }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(eligibleCount) synced contacts eligible for \(activeChannelName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Channel", selection: $selectedChannel) {
                        Text("Bulk Email (Gmail)").tag(0)
                        Text("Bulk SMS").tag(1)
                    }
                    .pickerStyle(.segmented)

                    Text("Quick Templates (\(vm.campaignTemplates.count - 1))")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.campaignTemplates.filter { $0.id != "blank" }) { tpl in
                                Button {
                                    preselectedTemplate = tpl
                                    isComposing = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(tpl.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(selectedChannel == 0 ? tpl.subject : tpl.smsBody)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Text("Use Template ->")
                                            .font(.caption2.bold())
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .frame(width: 205, alignment: .leading)
                                    .padding(12)
                                    .background(SilverRayTheme.cardSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Sent \(activeChannelName) History (\(filteredHistory.count))")
                        .font(.headline)

                    if filteredHistory.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "megaphone.fill")
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                            Text("No \(activeChannelName) campaigns sent yet")
                                .font(.subheadline.bold())
                            Text(selectedChannel == 0
                                 ? "Select synced contacts, upload a banner image, and send directly via Gmail."
                                 : "Select synced contacts and send bulk or personalized SMS offers.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(SilverRayTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        ForEach(filteredHistory) { rec in
                            Button {
                                inspectedRecord = rec
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(rec.title).font(.headline).foregroundStyle(.primary)
                                        Spacer()
                                        Text(rec.mode).font(.caption2.bold()).foregroundStyle(Color.accentColor)
                                    }
                                    Text(rec.subjectOrPreview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("\(rec.recipientCount) Recipients • \(rec.sentDateFormatted)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(SilverRayTheme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        preselectedTemplate = nil
                        isComposing = true
                    } label: {
                        Label(
                            selectedChannel == 0 ? "Compose Bulk Gmail Campaign" : "Compose Bulk SMS Campaign",
                            systemImage: "paperplane.fill"
                        )
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .background(SilverRayTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Campaigns")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        preselectedTemplate = nil
                        isComposing = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $isComposing) {
                CampaignComposerSheet(
                    initialMode: selectedChannel == 0 ? "BulkEmail" : "BulkSMS",
                    preselectedTemplate: preselectedTemplate
                )
            }
            .alert("Campaign Details", isPresented: Binding(
                get: { inspectedRecord != nil },
                set: { if !$0 { inspectedRecord = nil } }
            )) {
                Button("Close", role: .cancel) { inspectedRecord = nil }
            } message: {
                if let r = inspectedRecord {
                    Text("Mode: \(r.mode)\nRecipients: \(r.recipientCount)\nSent: \(r.sentDateFormatted)\nImage Attached: \(r.hasImageAttachment ? "Yes" : "No")\n\n\(r.subjectOrPreview)")
                }
            }
        }
    }
}

private struct CampaignComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: CRMViewModel

    let initialMode: String
    let preselectedTemplate: CampaignTemplate?

    @State private var mode: String = "BulkEmail" // BulkEmail, Email, BulkSMS, SMS
    @State private var activeTemplateId: String = "blank"
    @State private var subject: String = ""
    @State private var bodyText: String = "Hi [FirstName],\n\n"
    @State private var linkUrl: String = ""

    @State private var pickedPhotoItem: PhotosPickerItem? = nil
    @State private var attachedImageData: Data? = nil
    @State private var attachedUIImage: UIImage? = nil

    @State private var searchQuery: String = ""
    @State private var selectedIds: Set<String> = []
    @State private var showConfirmDispatch = false
    @State private var sendingIndex: Int = -1
    @State private var dispatchMessage: String? = nil

    @State private var mailComposeData: NativeMailPayload? = nil
    @State private var smsComposeData: NativeSMSPayload? = nil

    private var isEmailMode: Bool { mode == "BulkEmail" || mode == "Email" }

    private var eligibleClients: [ClientRecord] {
        vm.visibleClients.filter { c in
            isEmailMode
                ? !c.email.trimmingCharacters(in: .whitespaces).isEmpty
                : !c.mobile.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var filteredClients: [ClientRecord] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return eligibleClients }
        return eligibleClients.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q) ||
            $0.mobile.lowercased().contains(q)
        }
    }

    private var selectedRecipients: [ClientRecord] {
        eligibleClients.filter { selectedIds.contains($0.id) }
    }

    private var smsStats: SmsSegmentInfo {
        calculateSmsSegments(bodyText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Delivery Mode") {
                    Picker("Mode", selection: $mode) {
                        Text("Bulk Gmail (BCC)").tag("BulkEmail")
                        Text("Gmail (1-by-1)").tag("Email")
                        Text("Bulk SMS").tag("BulkSMS")
                        Text("SMS (1-by-1)").tag("SMS")
                    }
                    .onChange(of: mode) { newVal in
                        let nowEmail = newVal == "BulkEmail" || newVal == "Email"
                        selectedIds.removeAll()
                        if let tpl = vm.campaignTemplates.first(where: { $0.id == activeTemplateId }) {
                            subject = tpl.subject
                            bodyText = nowEmail ? tpl.emailBody : tpl.smsBody
                        }
                    }
                }

                Section("Select Recipients (\(selectedRecipients.count)/\(eligibleClients.count))") {
                    TextField("Search name, email, or mobile...", text: $searchQuery)
                    if !filteredClients.isEmpty {
                        let allSelected = filteredClients.allSatisfy { selectedIds.contains($0.id) }
                        Button(allSelected ? "Deselect All" : "Select All (\(filteredClients.count))") {
                            if allSelected {
                                filteredClients.forEach { selectedIds.remove($0.id) }
                            } else {
                                filteredClients.forEach { selectedIds.insert($0.id) }
                            }
                        }
                    }
                    if filteredClients.isEmpty {
                        Text("No eligible synced contacts found. Sync Google Sheet or import CSV in Contacts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredClients) { client in
                            Button {
                                if selectedIds.contains(client.id) {
                                    selectedIds.remove(client.id)
                                } else {
                                    selectedIds.insert(client.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedIds.contains(client.id) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selectedIds.contains(client.id) ? Color.accentColor : .secondary)
                                    VStack(alignment: .leading) {
                                        Text(client.fullName).foregroundStyle(.primary).font(.subheadline.weight(.medium))
                                        Text(isEmailMode ? client.email : client.mobile)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Templates") {
                    Picker("Template", selection: $activeTemplateId) {
                        ForEach(vm.campaignTemplates) { tpl in
                            Text(tpl.name).tag(tpl.id)
                        }
                    }
                    .onChange(of: activeTemplateId) { newId in
                        if let tpl = vm.campaignTemplates.first(where: { $0.id == newId }) {
                            if isEmailMode {
                                subject = tpl.subject
                                bodyText = tpl.emailBody
                                if linkUrl.isEmpty { linkUrl = tpl.imageLinkUrl }
                            } else {
                                bodyText = tpl.smsBody
                            }
                        }
                    }
                }

                Section(isEmailMode ? "Email Content & Image Banner" : "SMS Message") {
                    if isEmailMode {
                        TextField("Email Subject", text: $subject)
                    }

                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)

                    if isEmailMode {
                        Text("Merge tags (1-by-1 mode): [FirstName], [FullName]")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("Destination Link URL (optional)", text: $linkUrl)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)

                        PhotosPicker(selection: $pickedPhotoItem, matching: .images) {
                            Label(attachedUIImage == nil ? "Upload Image Banner" : "Change Image Banner", systemImage: "photo.on.rectangle.angled")
                        }
                        .onChange(of: pickedPhotoItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImg = UIImage(data: data),
                                   let jpeg = uiImg.jpegData(compressionQuality: 0.85) {
                                    attachedImageData = jpeg
                                    attachedUIImage = uiImg
                                }
                            }
                        }

                        if let uiImg = attachedUIImage {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Button("Remove Image", role: .destructive) {
                                    pickedPhotoItem = nil
                                    attachedImageData = nil
                                    attachedUIImage = nil
                                }
                                .font(.caption)
                            }
                        }
                    } else {
                        Text("\(smsStats.charCount) chars • \(smsStats.segmentCount) SMS segment(s) (\(smsStats.isUnicode ? "Unicode" : "GSM-7"))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if sendingIndex >= 0 && sendingIndex < selectedRecipients.count {
                    let client = selectedRecipients[sendingIndex]
                    Section("1-by-1 Progress (\(sendingIndex + 1)/\(selectedRecipients.count))") {
                        Text("Current Recipient: \(client.fullName)")
                        Button(sendingIndex + 1 < selectedRecipients.count ? "Send Next Client" : "Finish") {
                            if sendingIndex + 1 < selectedRecipients.count {
                                sendingIndex += 1
                                launchCurrentOneByOne()
                            } else {
                                sendingIndex = -1
                                dispatchMessage = "Completed sending to \(selectedRecipients.count) contacts!"
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let msg = dispatchMessage {
                    Section {
                        Text(msg).foregroundStyle(.green).font(.subheadline.bold())
                    }
                }

                Section {
                    Button {
                        showConfirmDispatch = true
                    } label: {
                        Text("Start Sending (\(selectedRecipients.count))")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRecipients.isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (isEmailMode && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
            .navigationTitle("New Campaign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                mode = initialMode
                if let tpl = preselectedTemplate {
                    activeTemplateId = tpl.id
                    subject = tpl.subject
                    bodyText = isEmailMode ? tpl.emailBody : tpl.smsBody
                    linkUrl = tpl.imageLinkUrl
                }
            }
            .alert("Confirm Campaign Dispatch", isPresented: $showConfirmDispatch) {
                Button("Cancel", role: .cancel) {}
                Button("Send Now") {
                    Task { await executeDispatch() }
                }
            } message: {
                Text("Send \(mode) to \(selectedRecipients.count) selected contact(s)?")
            }
            .sheet(item: $mailComposeData) { payload in
                MailComposeSheet(payload: payload)
            }
            .sheet(item: $smsComposeData) { payload in
                MessageComposeSheet(payload: payload)
            }
        }
    }

    private func executeDispatch() async {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yyyy, hh:mm a"
        let tplName = vm.campaignTemplates.first(where: { $0.id == activeTemplateId })?.name ?? "Custom"
        let modeLabel: String
        switch mode {
        case "BulkEmail": modeLabel = "Bulk BCC (Gmail)"
        case "Email": modeLabel = "Individual Gmail"
        case "BulkSMS": modeLabel = "Bulk SMS"
        default: modeLabel = "Personalized SMS"
        }

        vm.recordDispatchedCampaign(
            SentCampaignRecord(
                id: "cmp_\(Int(Date().timeIntervalSince1970))",
                channel: isEmailMode ? "Email" : "SMS",
                mode: modeLabel,
                title: tplName == "Blank" ? modeLabel : tplName,
                subjectOrPreview: isEmailMode ? subject : String(bodyText.prefix(120)),
                recipientCount: selectedRecipients.count,
                hasImageAttachment: attachedImageData != nil,
                linkUrl: linkUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                sentDateFormatted: fmt.string(from: Date()),
                sentTimestamp: Date().timeIntervalSince1970
            )
        )

        if mode == "BulkEmail" {
            if let token = vm.googleAccessToken, !token.isEmpty {
                let sent = await vm.sendBulkGmailViaApi(
                    recipients: selectedRecipients,
                    subject: subject,
                    body: bodyText,
                    linkUrl: linkUrl,
                    imageData: attachedImageData
                )
                dispatchMessage = "Sent \(sent)/\(selectedRecipients.count) emails directly via Gmail API!"
            } else if MFMailComposeViewController.canSendMail() {
                let bcc = selectedRecipients.map { $0.email }
                var finalBody = bodyText.replacingOccurrences(of: "[FirstName]", with: "Valued Client").replacingOccurrences(of: "[FullName]", with: "Valued Client")
                if !linkUrl.trimmingCharacters(in: .whitespaces).isEmpty {
                    finalBody += "\n\nView Details: \(linkUrl)"
                }
                mailComposeData = NativeMailPayload(to: [], bcc: bcc, subject: subject, body: finalBody, imageData: attachedImageData)
                dispatchMessage = "Prepared email with \(bcc.count) BCC recipients."
            } else {
                let bccStr = selectedRecipients.map { $0.email }.joined(separator: ",")
                var finalBody = bodyText.replacingOccurrences(of: "[FirstName]", with: "Valued Client")
                if !linkUrl.trimmingCharacters(in: .whitespaces).isEmpty { finalBody += "\n\n\(linkUrl)" }
                let subEnc = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let bodyEnc = finalBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "googlegmail:///co?bcc=\(bccStr)&subject=\(subEnc)&body=\(bodyEnc)"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let mailto = URL(string: "mailto:?bcc=\(bccStr)&subject=\(subEnc)&body=\(bodyEnc)") {
                    UIApplication.shared.open(mailto)
                }
                dispatchMessage = "Opened email composer for \(selectedRecipients.count) recipients."
            }
        } else if mode == "BulkSMS" {
            let nums = selectedRecipients.map { $0.mobile.replacingOccurrences(of: " ", with: "") }
            let cleanBody = bodyText.replacingOccurrences(of: "[FirstName]", with: "Valued Client").replacingOccurrences(of: "[FullName]", with: "Valued Client")
            if MFMessageComposeViewController.canSendText() {
                smsComposeData = NativeSMSPayload(recipients: nums, body: cleanBody)
            } else if let bodyEnc = cleanBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "sms:/open?addresses=\(nums.joined(separator: ","))&body=\(bodyEnc)") {
                UIApplication.shared.open(url)
            }
            dispatchMessage = "Opened SMS composer for \(nums.count) recipients."
        } else {
            sendingIndex = 0
            launchCurrentOneByOne()
        }
    }

    private func launchCurrentOneByOne() {
        guard sendingIndex >= 0 && sendingIndex < selectedRecipients.count else { return }
        let client = selectedRecipients[sendingIndex]
        let first = client.firstName.isEmpty ? (client.fullName.split(separator: " ").first.map(String.init) ?? "") : client.firstName
        let personalized = bodyText.replacingOccurrences(of: "[FirstName]", with: first).replacingOccurrences(of: "[FullName]", with: client.fullName)
        if mode == "Email" {
            var finalBody = personalized
            if !linkUrl.trimmingCharacters(in: .whitespaces).isEmpty { finalBody += "\n\nView Details: \(linkUrl)" }
            if MFMailComposeViewController.canSendMail() {
                mailComposeData = NativeMailPayload(to: [client.email], bcc: [], subject: subject, body: finalBody, imageData: attachedImageData)
            } else {
                let subEnc = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let bodyEnc = finalBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "mailto:\(client.email)?subject=\(subEnc)&body=\(bodyEnc)") {
                    UIApplication.shared.open(url)
                }
            }
        } else {
            let cleanNum = client.mobile.replacingOccurrences(of: " ", with: "")
            if MFMessageComposeViewController.canSendText() {
                smsComposeData = NativeSMSPayload(recipients: [cleanNum], body: personalized)
            } else if let bodyEnc = personalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "sms:\(cleanNum)&body=\(bodyEnc)") {
                UIApplication.shared.open(url)
            }
        }
    }
}

private struct NativeMailPayload: Identifiable {
    let id = UUID()
    let to: [String]
    let bcc: [String]
    let subject: String
    let body: String
    let imageData: Data?
}

private struct NativeSMSPayload: Identifiable {
    let id = UUID()
    let recipients: [String]
    let body: String
}

private struct MailComposeSheet: UIViewControllerRepresentable {
    let payload: NativeMailPayload
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        if !payload.to.isEmpty { vc.setToRecipients(payload.to) }
        if !payload.bcc.isEmpty { vc.setBccRecipients(payload.bcc) }
        vc.setSubject(payload.subject)
        vc.setMessageBody(payload.body, isHTML: false)
        if let data = payload.imageData {
            vc.addAttachmentData(data, mimeType: "image/jpeg", fileName: "campaign_banner.jpg")
        }
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

private struct MessageComposeSheet: UIViewControllerRepresentable {
    let payload: NativeSMSPayload
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = payload.recipients
        vc.body = payload.body
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func messageComposeController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}
