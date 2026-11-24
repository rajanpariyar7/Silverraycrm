import SwiftUI

struct SilverRayBrandLogoView: View {
    var animateOnAppear: Bool = true
    @State private var shimmerOffset: CGFloat = -0.35

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let slate = Color(red: 0.06, green: 0.09, blue: 0.16)
            let mint = Color(red: 0.48, green: 0.88, blue: 0.83)
            let strokeWidth = max(2.2, h * 0.025)

            ZStack {
                Canvas { context, _ in
                    let blockRect = CGRect(
                        x: w * 0.625,
                        y: h * 0.08,
                        width: w * 0.21,
                        height: h * 0.65
                    )
                    context.fill(Path(blockRect), with: .color(mint))

                    var housePath = Path()
                    housePath.move(to: CGPoint(x: w * 0.575, y: h * 0.24))
                    housePath.addLine(to: CGPoint(x: w * 0.575, y: h * 0.21))
                    housePath.addLine(to: CGPoint(x: w * 0.685, y: h * 0.12))
                    housePath.addLine(to: CGPoint(x: w * 0.755, y: h * 0.19))
                    housePath.addLine(to: CGPoint(x: w * 0.755, y: h * 0.24))
                    housePath.addLine(to: CGPoint(x: w * 0.725, y: h * 0.215))
                    housePath.addLine(to: CGPoint(x: w * 0.685, y: h * 0.17))
                    housePath.addLine(to: CGPoint(x: w * 0.612, y: h * 0.235))
                    housePath.addLine(to: CGPoint(x: w * 0.612, y: h * 0.52))
                    housePath.move(to: CGPoint(x: w * 0.725, y: h * 0.22))
                    housePath.addLine(to: CGPoint(x: w * 0.725, y: h * 0.38))
                    housePath.move(to: CGPoint(x: w * 0.65, y: h * 0.67))
                    housePath.addLine(to: CGPoint(x: w * 0.80, y: h * 0.67))
                    housePath.move(to: CGPoint(x: w * 0.27, y: h * 0.495))
                    housePath.addLine(to: CGPoint(x: w * 0.45, y: h * 0.495))

                    context.stroke(
                        housePath,
                        with: .color(slate),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                    )

                    var rayPath = Path()
                    rayPath.move(to: CGPoint(x: w * 0.395, y: h * 0.94))
                    rayPath.addCurve(
                        to: CGPoint(x: w * 0.465, y: h * 0.52),
                        control1: CGPoint(x: w * 0.425, y: h * 0.86),
                        control2: CGPoint(x: w * 0.455, y: h * 0.68)
                    )
                    rayPath.addCurve(
                        to: CGPoint(x: w * 0.54, y: h * 0.57),
                        control1: CGPoint(x: w * 0.485, y: h * 0.46),
                        control2: CGPoint(x: w * 0.545, y: h * 0.47)
                    )
                    rayPath.addCurve(
                        to: CGPoint(x: w * 0.565, y: h * 0.81),
                        control1: CGPoint(x: w * 0.50, y: h * 0.69),
                        control2: CGPoint(x: w * 0.525, y: h * 0.82)
                    )
                    context.stroke(
                        rayPath,
                        with: .color(slate),
                        style: StrokeStyle(lineWidth: strokeWidth * 1.35, lineCap: .round, lineJoin: .round)
                    )
                }

                Text("SILVER")
                    .font(.system(size: max(12, h * 0.24), weight: .regular))
                    .tracking(4)
                    .foregroundStyle(slate)
                    .position(x: w * 0.33, y: h * 0.31)

                Text("REALTY")
                    .font(.system(size: max(9, h * 0.13), weight: .regular))
                    .tracking(3)
                    .foregroundStyle(slate)
                    .position(x: w * 0.73, y: h * 0.84)
            }
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.6), .white.opacity(0.9), .white.opacity(0.6), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: w * 0.38)
                .offset(x: w * shimmerOffset)
                .mask(Rectangle())
                .allowsHitTesting(false)
            )
        }
        .aspectRatio(3.2, contentMode: .fit)
        .onAppear {
            if animateOnAppear {
                shimmerOffset = -0.35
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.4
                }
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var vm: CRMViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SilverRayBrandLogoView(animateOnAppear: true)
                        .frame(width: 210)
                        .padding(.top, 56)

                    Text("Silverray CRM")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(red: 0.15, green: 0.23, blue: 0.30))

                    Text("Login")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.23))
                        .padding(.top, 4)

                    VStack(spacing: 14) {
                        TextField("Email Address", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.80, green: 0.84, blue: 0.88), lineWidth: 1)
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
                                    .foregroundStyle(Color(red: 0.28, green: 0.33, blue: 0.41))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.20, green: 0.25, blue: 0.33), lineWidth: 1)
                        )

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !vm.statusMessage.isEmpty && vm.errorMessage == nil {
                            Text(vm.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                                (email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || vm.isLoading)
                                ? Color(red: 0.56, green: 0.69, blue: 0.72)
                                : Color(red: 0.06, green: 0.46, blue: 0.43)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || vm.isLoading)

                        HStack(spacing: 12) {
                            Rectangle().frame(height: 1).foregroundStyle(Color(red: 0.89, green: 0.91, blue: 0.94))
                            Text("or")
                                .font(.subheadline)
                                .foregroundStyle(Color(red: 0.39, green: 0.45, blue: 0.55))
                            Rectangle().frame(height: 1).foregroundStyle(Color(red: 0.89, green: 0.91, blue: 0.94))
                        }
                        .padding(.vertical, 4)

                        Button {
                            Task { await vm.signInWithGoogle() }
                        } label: {
                            Label("Login with Google", systemImage: "g.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.80, green: 0.84, blue: 0.88), lineWidth: 1)
                                )
                        }
                        .disabled(vm.isLoading)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 28)
            }
            .background(Color.white.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
