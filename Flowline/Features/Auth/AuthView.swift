import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var mode: Mode = .login
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case login, register }

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo ────────────────────────────────────────────────
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(FlowLineTheme.accent.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "sparkles")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(FlowLineTheme.accent)
                    }
                    Text("Flowline")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("Your AI-powered daily planner")
                        .font(.system(size: 13))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
                .padding(.bottom, 36)

                // ── Mode switcher ───────────────────────────────────────
                HStack(spacing: 0) {
                    modeTab("Sign In", tab: .login)
                    modeTab("Create Account", tab: .register)
                }
                .background(FlowLineTheme.tertiaryBg)
                .clipShape(Capsule())
                .padding(.horizontal, 48)
                .padding(.bottom, 28)

                // ── Form ────────────────────────────────────────────────
                VStack(spacing: 12) {
                    if mode == .register {
                        authField("Name", text: $name, icon: "person")
                    }
                    authField("Email", text: $email, icon: "envelope")
                    authField("Password", text: $password, icon: "lock", isSecure: true)
                }
                .padding(.horizontal, 48)

                // ── Error ───────────────────────────────────────────────
                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                        .padding(.top, 10)
                }

                // ── Submit button ───────────────────────────────────────
                Button(action: submit) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(FlowLineTheme.accent)
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.75)
                                .tint(.white)
                        } else {
                            HStack(spacing: 6) {
                                Text(mode == .login ? "Sign In" : "Create Account")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !isFormValid)
                .opacity(isFormValid ? 1 : 0.5)
                .padding(.horizontal, 48)
                .padding(.top, 20)

                Spacer()

                // ── Footer ──────────────────────────────────────────────
                HStack(spacing: 4) {
                    Text("By continuing you agree to our")
                    Link("Terms of Use", destination: URL(string: "https://flowline.ink/terms")!)
                    Text("and")
                    Link("Privacy Policy", destination: URL(string: "https://flowline.ink/privacy")!)
                }
                .font(.system(size: 10))
                .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 420)
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.15), value: errorMessage)
    }

    // MARK: - Sub-views

    private func modeTab(_ label: String, tab: Mode) -> some View {
        Button { withAnimation { mode = tab; errorMessage = nil } } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(mode == tab ? .white : FlowLineTheme.secondTxt)
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
                .background(
                    mode == tab
                        ? FlowLineTheme.accent.clipShape(Capsule())
                        : nil
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func authField(_ placeholder: String, text: Binding<String>,
                           icon: String, isSecure: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(FlowLineTheme.secondTxt)
                .frame(width: 16)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.mainTxt)
            } else {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.mainTxt)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FlowLineTheme.tertiaryBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(FlowLineTheme.borderHi, lineWidth: 1)
                )
        )
    }

    // MARK: - Logic

    private var isFormValid: Bool {
        let base = !email.isEmpty && password.count >= 6
        return mode == .register ? base && !name.isEmpty : base
    }

    private func submit() {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true

        Task {
            do {
                if mode == .login {
                    try await authService.login(email: email, password: password)
                } else {
                    try await authService.register(name: name, email: email, password: password)
                }
            } catch let err as AuthError {
                errorMessage = err.errorDescription
            } catch {
                errorMessage = "Something went wrong. Try again."
            }
            isLoading = false
        }
    }
}
