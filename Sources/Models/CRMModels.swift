import Foundation

enum UserRole: String, Codable, CaseIterable {
    case superAdmin = "SUPER_ADMIN"
    case admin = "ADMIN"
    case salesperson = "SALES_PERSON"

    var displayName: String {
        switch self {
        case .superAdmin: return "Super Admin (All Roles)"
        case .admin: return "Admin"
        case .salesperson: return "Sales Person"
        }
    }

    static func from(_ raw: String?) -> UserRole {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "SUPER_ADMIN", "SUPERADMIN", "SUPER ADMIN":
            return .superAdmin
        case "ADMIN":
            return .admin
        default:
            return .salesperson
        }
    }
}

struct AuthorizedStaffUser: Identifiable, Codable, Hashable {
    var id: String { email.lowercased() }
    let email: String
    var name: String
    var role: String
    var password: String
    var mobile: String
    var addedBy: String
    var createdAt: Date

    var resolvedRole: UserRole {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == SilverRayConfig.superAdminEmail {
            return .superAdmin
        }
        return UserRole.from(role)
    }
}

struct CRMUser: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let email: String
    let role: UserRole
    let title: String
    var mobile: String = ""
    var addedBy: String = SilverRayConfig.superAdminEmail
    var isGoogleLinked: Bool = false

    var isSuperAdmin: Bool { role == .superAdmin }
    var isAdmin: Bool { role == .admin || role == .superAdmin }
    var canManageAuthorizedEmails: Bool { isAdmin || isSuperAdmin }
    var canViewAllSalesPersonsContacts: Bool { isSuperAdmin }

    var roleBadgeText: String {
        switch role {
        case .superAdmin: return "SUPER ADMIN • ALL ROLES"
        case .admin: return "ADMIN"
        case .salesperson: return "SALES PERSON"
        }
    }
}

struct ClientRecord: Identifiable, Codable, Hashable {
    let id: String
    var sheetId: Int
    var firstName: String
    var lastName: String
    var name: String
    var email: String
    var mobile: String
    var birthdate: String // MM-DD or YYYY-MM-DD
    var company: String
    var address: String
    var suburb: String
    var state: String
    var postcode: String
    var notes: String
    var properties: String
    var status: String // Active, Contacted, Closed
    var classification: String
    var interestedProperty: String
    var budgetRange: String
    var createdBy: String
    var assignedSalespersonId: String
    var assignedSalespersonName: String
    var marketingConsent: Bool
    var updatedAt: Date

    var fullName: String {
        let joined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? name : joined
    }
}

struct CRMTaskRecord: Identifiable, Codable, Hashable {
    let id: String
    var sheetId: Int
    var title: String
    var description: String
    var dueDate: Date
    var priority: String // Low, Medium, High, Urgent
    var assignedToUser: String
    var clientId: String?
    var clientName: String
    var isCompleted: Bool
    var createdAt: Date
}

struct CRMDealRecord: Identifiable, Codable, Hashable {
    let id: String
    var sheetId: Int
    var title: String
    var value: String
    var stage: String // Lead, Qualified, Proposal, Negotiation, Closed Won
    var clientId: String?
    var notes: String
}

struct ContactHistoryRecord: Identifiable, Codable, Hashable {
    let id: String
    var clientId: String
    var contactDate: Date
    var type: String
    var notes: String
}

struct CampaignTemplate: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var category: String
    var subject: String
    var emailBody: String
    var smsBody: String
    var imageUrl: String
    var imageLinkUrl: String
    var imageAlt: String
}

struct SentCampaignRecord: Identifiable, Codable, Hashable {
    let id: String
    let channel: String // "Email" or "SMS"
    let mode: String
    let title: String
    let subjectOrPreview: String
    let recipientCount: Int
    let hasImageAttachment: Bool
    let linkUrl: String
    let sentDateFormatted: String
    let sentTimestamp: TimeInterval
}

enum BulkEmailProvider: String, CaseIterable, Identifiable {
    case sendpaw = "SendPaw SMTP (no-reply@mail.silverray.com.au)"
    case gmail = "Gmail (OAuth / Native)"
    case resend = "Resend Bulk API"
    case sendgrid = "SendGrid Mail v3"
    case mailgun = "Mailgun API"
    case custom = "Custom Email API"
    var id: String { rawValue }
}

enum BulkSMSProvider: String, CaseIterable, Identifiable {
    case nativeSms = "iPhone Messages / Bulk SMS"
    case crmRelay = "CRM Verified SMS Relay"
    case twilio = "Twilio SMS"
    case messageMedia = "MessageMedia AU"
    case clickSend = "ClickSend AU"
    var id: String { rawValue }
}

enum SilverRayConfig {
    static let spreadsheetId = "1WvNTb1zHc6ltByj_y0v-OPlpGQPlHKae"
    static let spreadsheetUrl = "https://docs.google.com/spreadsheets/d/1WvNTb1zHc6ltByj_y0v-OPlpGQPlHKae/edit"
    static let firestoreDatabaseId = "silverraycrm"
    static let superAdminEmail = "rajanpariyar.com.np@gmail.com"
    static let defaultAdminEmail = "aroon@silverray.com.au"
    static let defaultAdminGmail = "aroon.silverray@gmail.com"
}

enum StaffRoster {
    static let initialAuthorizedUsers: [AuthorizedStaffUser] = [
        AuthorizedStaffUser(email: SilverRayConfig.superAdminEmail, name: "Rajan Pariyar (Super Admin)", role: UserRole.superAdmin.rawValue, password: "", mobile: "+61 400 999 888", addedBy: SilverRayConfig.superAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: SilverRayConfig.defaultAdminEmail, name: "Aroon (Admin)", role: UserRole.admin.rawValue, password: "", mobile: "+61 400 000 001", addedBy: SilverRayConfig.superAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: SilverRayConfig.defaultAdminGmail, name: "Aroon (Admin)", role: UserRole.admin.rawValue, password: "", mobile: "+61 400 000 001", addedBy: SilverRayConfig.superAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "aman@silverray.com.au", name: "Aman", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "salesdirector.silverray@gmail.com", name: "Aman (Sales Director)", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "ash@silverray.com.au", name: "Ash", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "bdm.silverray@gmail.com", name: "Ash (BDM)", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "aviskar@silverray.com.au", name: "Aviskar", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "salesperson2.silverray@gmail.com", name: "Aviskar", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "haider@silverray.com.au", name: "Haider", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "salesperson1.silverray@gmail.com", name: "Haider", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "info@silverray.com.au", name: "Silverray Info", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "silverrayrealty@gmail.com", name: "Silverray Realty", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "jasprincii@silverray.com.au", name: "Jasprincii", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "bdmhead.silverray@gmail.com", name: "Jasprincii (BDM Head)", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "jatinder@silverray.com.au", name: "Jatinder", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "rea.silverray@gmail.com", name: "Jatinder (REA)", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "nabin@silverray.com.au", name: "Nabin", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "rea1.silverray@gmail.com", name: "Nabin (REA 1)", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "robin@silverray.com.au", name: "Robin", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "salesperson.silverray@gmail.com", name: "Robin", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date()),
        AuthorizedStaffUser(email: "rental@silverray.com.au", name: "Silver Ray Rentals", role: UserRole.salesperson.rawValue, password: "", mobile: "", addedBy: SilverRayConfig.defaultAdminEmail, createdAt: Date())
    ]

    static func resolve(_ email: String, from users: [AuthorizedStaffUser] = initialAuthorizedUsers) -> AuthorizedStaffUser? {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return users.first { $0.email.lowercased() == clean }
    }
}

struct SmsSegmentInfo {
    let charCount: Int
    let segmentCount: Int
    let isUnicode: Bool
}

func calculateSmsSegments(_ text: String) -> SmsSegmentInfo {
    let gsm7Basic = Set("@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà")
    let gsm7Extended = Set("^{}\\[~]|€")
    var isUnicode = false
    var gsmLen = 0
    for ch in text {
        if gsm7Basic.contains(ch) {
            gsmLen += 1
        } else if gsm7Extended.contains(ch) {
            gsmLen += 2
        } else {
            isUnicode = true
            break
        }
    }
    let effective = isUnicode ? text.count : gsmLen
    let singleLimit = isUnicode ? 70 : 160
    let multiLimit = isUnicode ? 67 : 153
    let segments: Int
    if effective == 0 {
        segments = 0
    } else if effective <= singleLimit {
        segments = 1
    } else {
        segments = (effective + multiLimit - 1) / multiLimit
    }
    return SmsSegmentInfo(charCount: effective, segmentCount: segments, isUnicode: isUnicode)
}

enum DefaultTemplatesCatalog {
    static let templates: [CampaignTemplate] = [
        CampaignTemplate(
            id: "blank",
            name: "Blank",
            category: "Custom",
            subject: "",
            emailBody: "Hi [FirstName],\n\n",
            smsBody: "Hi [FirstName], ",
            imageUrl: "",
            imageLinkUrl: "",
            imageAlt: "Silver Ray Realty"
        ),
        CampaignTemplate(
            id: "buy_offers",
            name: "Buy Offers & Discounts",
            category: "Buy Offer",
            subject: "Exclusive Buyer Offers & Off-Market Deals | Silver Ray Realty",
            emailBody: "Hi [FirstName],\n\nLooking to buy your next home or investment property? Silver Ray Realty currently has priority buyer offers and off-market listings available with exclusive buyer incentives.\n\nReply to this email or call us today to arrange a private viewing tailored to your budget and preferred suburbs.\n\nWarm regards,\nSilver Ray Realty Pty Ltd\nGeebung, QLD 4034\nhttps://silverray.com.au",
            smsBody: "Hi [FirstName], exclusive buyer offers & off-market homes are now available at Silver Ray Realty! Reply YES or visit https://silverray.com.au for details. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Silver Ray Realty Buyer Offers"
        ),
        CampaignTemplate(
            id: "sell_offers",
            name: "Sell Offers & Discounts",
            category: "Sell Offer",
            subject: "Special Seller Offer: Reduced Commission & Free Appraisal",
            emailBody: "Hi [FirstName],\n\nThinking of selling? Silver Ray Realty is offering qualified homeowners a complimentary market appraisal plus special discounted marketing & commission packages this month.\n\nLet our experienced team help you achieve the best possible sale price.\n\nWarm regards,\nSilver Ray Realty Pty Ltd\nGeebung, QLD 4034\nhttps://silverray.com.au",
            smsBody: "Hi [FirstName], thinking of selling? Book a FREE appraisal with Silver Ray Realty & unlock special discounted seller packages. Visit https://silverray.com.au. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Silver Ray Realty Seller Packages"
        ),
        CampaignTemplate(
            id: "rental_offers",
            name: "Rental Offers & Discounts",
            category: "Rent Offer",
            subject: "Rental Specials & Property Management Offers | Silver Ray Realty",
            emailBody: "Hi [FirstName],\n\nWhether you are searching for a quality rental home or looking for stress-free property management with discounted onboarding fees, Silver Ray Realty is here to help.\n\nReach out today to view our latest rental listings or request a rental yield assessment.\n\nWarm regards,\nSilver Ray Realty Pty Ltd\nGeebung, QLD 4034\nhttps://silverray.com.au",
            smsBody: "Hi [FirstName], check out Silver Ray Realty's latest rental listings & landlord management fee discounts! Contact us or visit https://silverray.com.au. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Silver Ray Realty Rentals"
        ),
        CampaignTemplate(
            id: "birthday",
            name: "Birthday Wishes",
            category: "Birthday",
            subject: "Happy Birthday [FirstName] from Silver Ray Realty!",
            emailBody: "Dear [FirstName],\n\nWishing you a wonderful Happy Birthday filled with joy, good health, and success!\n\nThank you for being a valued part of the Silver Ray Realty community. Please let us know if we can ever assist with your property plans.\n\nWarmest wishes,\nSilver Ray Realty Pty Ltd\nhttps://silverray.com.au",
            smsBody: "Happy Birthday [FirstName]! Wishing you joy, health & prosperity from the team at Silver Ray Realty (https://silverray.com.au). Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Happy Birthday from Silver Ray Realty"
        ),
        CampaignTemplate(
            id: "dashain_tihar",
            name: "Dashain & Tihar",
            category: "Festival",
            subject: "Happy Dashain & Tihar! Festive Wishes from Silver Ray Realty",
            emailBody: "Namaste [FirstName],\n\nWishing you and your family a joyful Dashain and a bright, prosperous Tihar!\n\nTo celebrate this auspicious festive season, Silver Ray Realty is pleased to offer special festive discounts on property appraisals, buyer consultations, and listing packages.\n\nWarm festive regards,\nSilver Ray Realty Pty Ltd\nGeebung, QLD 4034\nhttps://silverray.com.au",
            smsBody: "Namaste [FirstName]! Wishing you & your family a Happy Dashain & Tihar from Silver Ray Realty! Enjoy special festive property offers at https://silverray.com.au. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Dashain and Tihar Wishes"
        ),
        CampaignTemplate(
            id: "christmas",
            name: "Christmas",
            category: "Festival",
            subject: "Merry Christmas & Season's Greetings | Silver Ray Realty",
            emailBody: "Hi [FirstName],\n\nWishing you and your loved ones a Merry Christmas and a joyful holiday season!\n\nThank you for your trust and support throughout the year. Keep an eye out for our holiday property specials.\n\nWarm regards,\nSilver Ray Realty Pty Ltd\nGeebung, QLD 4034\nhttps://silverray.com.au",
            smsBody: "Merry Christmas [FirstName]! Warm wishes to you & your family from Silver Ray Realty. Visit https://silverray.com.au for holiday property updates. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Merry Christmas from Silver Ray Realty"
        ),
        CampaignTemplate(
            id: "international_new_year",
            name: "International New Year",
            category: "New Year",
            subject: "Happy New Year! Fresh Property Opportunities | Silver Ray Realty",
            emailBody: "Hi [FirstName],\n\nHappy New Year from all of us at Silver Ray Realty! May this year bring new milestones, happiness, and prosperity to you and your family.\n\nIf buying, selling, or investing is on your goals for the year ahead, we'd love to help.\n\nBest regards,\nSilver Ray Realty Pty Ltd\nhttps://silverray.com.au",
            smsBody: "Happy New Year [FirstName]! Wishing you a prosperous year ahead from Silver Ray Realty. Explore new property opportunities at https://silverray.com.au. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Happy New Year from Silver Ray Realty"
        ),
        CampaignTemplate(
            id: "nepali_new_year",
            name: "Nepali New Year",
            category: "New Year",
            subject: "Naya Barsha ko Shubhakamana! | Silver Ray Realty",
            emailBody: "Namaste [FirstName],\n\nNaya Barsha ko hardik mangalmaya shubhakamana! Wishing you and your family happiness, good health, and prosperity in the Nepali New Year.\n\nReach out to Silver Ray Realty anytime for special community property offers.\n\nWarm regards,\nSilver Ray Realty Pty Ltd\nhttps://silverray.com.au",
            smsBody: "Namaste [FirstName]! Naya Barsha ko hardik shubhakamana from Silver Ray Realty! Contact us for special community property offers: https://silverray.com.au. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Naya Barsha Wishes"
        ),
        CampaignTemplate(
            id: "property_offer",
            name: "Property Offer",
            category: "Listing",
            subject: "Featured Property Listing Just For You | Silver Ray Realty",
            emailBody: "Hi [FirstName],\n\nWe have a newly listed property that matches what our buyers have been searching for.\n\nCheck the link below to explore property photos, pricing, and open home times.\n\nBest regards,\nSilver Ray Realty Pty Ltd\nhttps://silverray.com.au",
            smsBody: "Hi [FirstName], a featured property just hit the market with Silver Ray Realty! Check details or book an inspection at https://silverray.com.au. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Featured Property Listing"
        ),
        CampaignTemplate(
            id: "sales_update",
            name: "Sales Update",
            category: "Market Update",
            subject: "Latest Real Estate Market & Sales Update | Silver Ray Realty",
            emailBody: "Hi [FirstName],\n\nHere is your latest Brisbane & Queensland property market update from Silver Ray Realty.\n\nBuyer demand remains strong across our local suburbs. Contact us anytime for an updated valuation on your property.\n\nBest regards,\nSilver Ray Realty Pty Ltd\nhttps://silverray.com.au",
            smsBody: "Hi [FirstName], local buyer demand is strong! Request an updated property appraisal from Silver Ray Realty at https://silverray.com.au. Opt out: reply STOP",
            imageUrl: "",
            imageLinkUrl: "https://silverray.com.au",
            imageAlt: "Sales & Market Update"
        )
    ]
}
