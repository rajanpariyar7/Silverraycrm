import SwiftUI

enum SilverRayTheme {
    static let logoAqua = Color(red: 0.635, green: 0.929, blue: 0.922)       // #A2EDEB
    static let emeraldTeal = Color(red: 0.051, green: 0.478, blue: 0.459)    // #0D7A75
    static let skyBlue = Color(red: 0.008, green: 0.518, blue: 0.780)        // #0284C7
    static let slateNavy = Color(red: 0.059, green: 0.090, blue: 0.165)      // #0F172A
    static let mutedSlate = Color(red: 0.278, green: 0.333, blue: 0.412)     // #475569
    static let appBackground = Color(red: 0.953, green: 0.980, blue: 0.980)  // #F3FAFA
    static let cardSurface = Color.white
    static let cardBorder = Color(red: 0.733, green: 0.890, blue: 0.882)     // #BBE3E1

    static let authBackdropGradient = LinearGradient(
        colors: [
            Color.white,
            Color(red: 0.953, green: 0.980, blue: 0.980), // #F3FAFA
            Color(red: 0.867, green: 0.957, blue: 0.953)  // #DDF4F3
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct LoginView: View {
    @EnvironmentObject private var vm: CRMViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showResetAlert = false
    @State private var resetEmail = ""

    private var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !vm.isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image("SilverRayBrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 76)
                        .padding(.top, 44)

                    Text("Silverray CRM")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(SilverRayTheme.slateNavy)

                    Text("Login")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(SilverRayTheme.emeraldTeal)

                    VStack(spacing: 12) {
                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !vm.statusMessage.isEmpty && vm.errorMessage == nil {
                            Text(vm.statusMessage)
                                .font(.caption)
                                .foregroundStyle(SilverRayTheme.emeraldTeal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TextField("Email Address", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(SilverRayTheme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(SilverRayTheme.cardBorder, lineWidth: 1)
                            )

                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Password", text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(SilverRayTheme.mutedSlate)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(SilverRayTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(SilverRayTheme.cardBorder, lineWidth: 1)
                        )

                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                resetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                showResetAlert = true
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SilverRayTheme.emeraldTeal)
                            .disabled(vm.isLoading)
                        }

                        Button {
                            Task { await vm.signIn(email: email, password: password) }
                        } label: {
                            HStack {
                                if vm.isLoading { ProgressView().tint(.white) }
                                Text("Login")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                canLogin
                                ? SilverRayTheme.emeraldTeal
                                : SilverRayTheme.emeraldTeal.opacity(0.45)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(!canLogin)

                        HStack(spacing: 12) {
                            Rectangle().frame(height: 1).foregroundStyle(SilverRayTheme.cardBorder)
                            Text("or")
                                .font(.subheadline)
                                .foregroundStyle(SilverRayTheme.mutedSlate)
                            Rectangle().frame(height: 1).foregroundStyle(SilverRayTheme.cardBorder)
                        }
                        .padding(.vertical, 4)

                        Button {
                            Task { await vm.signInWithGoogle() }
                        } label: {
                            Label("Sign in with Google", systemImage: "g.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SilverRayTheme.slateNavy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(SilverRayTheme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(SilverRayTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .disabled(vm.isLoading)
                    }
                    .padding(18)
                    .background(SilverRayTheme.cardSurface.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(SilverRayTheme.cardBorder.opacity(0.85), lineWidth: 1)
                    )
                    .shadow(color: SilverRayTheme.slateNavy.opacity(0.06), radius: 14, y: 6)

                    Text("Authorized Silver Ray Realty staff account required.")
                        .font(.caption)
                        .foregroundStyle(SilverRayTheme.mutedSlate)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(SilverRayTheme.authBackdropGradient.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .alert("Reset Password", isPresented: $showResetAlert) {
                TextField("Email Address", text: $resetEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Send Reset Link") {
                    Task { await vm.sendPasswordReset(email: resetEmail) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your registered email address to receive a password reset link.")
            }
        }
    }
}
