import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var mode: Mode = .login
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var emailError: String?
    @State private var showForgotPassword = false

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
                    authField("Email", text: $email, icon: "envelope", keyboardType: .emailAddress) {
                        if !email.isEmpty {
                            emailError = EmailValidator.isValid(email) ? nil : EmailValidator.errorMessage(for: email)
                        } else {
                            emailError = nil
                        }
                    }
                    if let err = emailError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.top, -8)
                    }
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

                // ── Forgot Password link (login only) ────────────────────
                if mode == .login {
                    Button(action: { showForgotPassword = true }) {
                        Text("Forgot password?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FlowLineTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }

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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(isPresented: $showForgotPassword)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
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
                           icon: String, isSecure: Bool = false,
                           keyboardType: UIKeyboardType = .default,
                           onChange: @escaping () -> Void = {}) -> some View {
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
                    .keyboardType(keyboardType)
                    .onChange(of: text.wrappedValue) { _, _ in onChange() }
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
        let emailValid = EmailValidator.isValid(email)
        let passwordValid = password.count >= 6
        let base = emailValid && passwordValid
        return mode == .register ? base && !name.isEmpty : base
    }

    private func submit() {
        guard !isLoading else { return }

        // Validate email format first
        guard EmailValidator.isValid(email) else {
            errorMessage = EmailValidator.errorMessage(for: email)
            return
        }

        errorMessage = nil
        emailError = nil
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

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @EnvironmentObject private var authService: AuthService
    @Binding var isPresented: Bool

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var emailError: String?

    var isFormValid: Bool {
        EmailValidator.isValid(email)
    }

    var body: some View {
        VStack(spacing: 16) {
            // ── Header ──────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reset your password")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("We'll send you a reset link via email")
                        .font(.system(size: 12))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ── Email field ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .font(.system(size: 13))
                        .foregroundColor(FlowLineTheme.secondTxt)
                        .frame(width: 16)

                    TextField("Your email", text: $email)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(FlowLineTheme.mainTxt)
                        .keyboardType(.emailAddress)
                        .onChange(of: email) { _, _ in
                            if !email.isEmpty {
                                emailError = EmailValidator.isValid(email) ? nil : EmailValidator.errorMessage(for: email)
                            } else {
                                emailError = nil
                            }
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

                if let err = emailError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 14)
                }
            }
            .padding(.horizontal, 16)

            // ── Status messages ─────────────────────────────────────
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            if let success = successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            }

            Spacer()

            // ── Send button ─────────────────────────────────────────
            Button(action: sendReset) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(FlowLineTheme.accent)
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Text("Send reset link")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || !isFormValid)
            .opacity(isFormValid ? 1 : 0.5)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(FlowLineTheme.mainBg)
    }

    private func sendReset() {
        guard !isLoading else { return }
        guard EmailValidator.isValid(email) else {
            errorMessage = EmailValidator.errorMessage(for: email)
            return
        }

        errorMessage = nil
        emailError = nil
        isLoading = true

        Task {
            do {
                try await authService.forgotPassword(email: email)
                successMessage = "Check your email for a reset link"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    isPresented = false
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

