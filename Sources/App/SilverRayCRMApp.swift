import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct SilverRayCRMApp: App {
    @StateObject private var vm = CRMViewModel()
    @State private var showLaunchIntro = true
    @State private var introScale: CGFloat = 0.68
    @State private var introOpacity: Double = 0.0

    init() {
        if let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: plistPath),
           let googleAppId = dict["GOOGLE_APP_ID"] as? String,
           !googleAppId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if vm.isAuthenticated {
                        MainTabView()
                            .environmentObject(vm)
                    } else {
                        LoginView()
                            .environmentObject(vm)
                    }
                }
                .opacity(showLaunchIntro ? 0 : 1)

                if showLaunchIntro {
                    launchOverlay
                        .transition(.opacity)
                }
            }
            .tint(Color(red: 0.06, green: 0.46, blue: 0.43))
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                    introScale = 1.0
                    introOpacity = 1.0
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.easeInOut(duration: 0.28)) {
                    showLaunchIntro = false
                }
            }
        }
    }

    private var launchOverlay: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            SilverRayBrandLogoView(animateOnAppear: true)
                .frame(width: 240, height: 76)
                .scaleEffect(introScale)
                .opacity(introOpacity)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var vm: CRMViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ClientsView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }
                .tag(1)

            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(2)

            BulkCampaignsView()
                .tabItem {
                    Label("Campaigns", systemImage: "envelope.badge.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Admin", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}
