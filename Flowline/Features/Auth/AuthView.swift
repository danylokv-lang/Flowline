import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var mode: Mode = .login
    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var emailError: String?
    @State private var showForgotPassword = false
    @State private var showPassword = false
    @State private var showPasswordConfirm = false
    @State private var passwordMatchError: String?

    enum Mode { case login, register }

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // ── Logo ────────────────────────────────────────────────
                VStack(spacing: 12) {
                    Text("Flowline")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(FlowLineTheme.mainTxt)
                    Text("AI-powered daily planning")
                        .font(.system(size: 14))
                        .foregroundColor(FlowLineTheme.secondTxt)
                }
                .padding(.bottom, 40)

                // ── Mode switcher ───────────────────────────────────────
                HStack(spacing: 0) {
                    modeTab("Sign In", tab: .login)
                    modeTab("Create Account", tab: .register)
                }
                .background(FlowLineTheme.secondBg)
                .clipShape(Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 32)

                // ── Form ────────────────────────────────────────────────
                VStack(spacing: 14) {
                    if mode == .register {
                        authField("Full name", text: $name, icon: "person")
                    }
                    #if os(iOS)
                    authField("Email address", text: $email, icon: "envelope", keyboardType: .emailAddress) {
                        if !email.isEmpty {
                            emailError = EmailValidator.isValid(email) ? nil : EmailValidator.errorMessage(for: email)
                        } else {
                            emailError = nil
                        }
                    }
                    #else
                    authField("Email address", text: $email, icon: "envelope") {
                        if !email.isEmpty {
                            emailError = EmailValidator.isValid(email) ? nil : EmailValidator.errorMessage(for: email)
                        } else {
                            emailError = nil
                        }
                    }
                    #endif
                    if let err = emailError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.top, -6)
                    }

                    if mode == .register && !password.isEmpty && !passwordConfirm.isEmpty && password != passwordConfirm {
                        Text("Passwords don't match")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.top, -6)
                    }
                    passwordField("Password", text: $password, isVisible: $showPassword, icon: "lock")

                    if mode == .register {
                        passwordField("Confirm password", text: $passwordConfirm, isVisible: $showPasswordConfirm, icon: "lock")
                    }
                }
                .padding(.horizontal, 20)

                // ── Error ───────────────────────────────────────────────
                if let err = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red.opacity(0.8))
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // ── Submit button ───────────────────────────────────────
                Button(action: submit) {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.75)
                                .tint(.white)
                        } else {
                            HStack(spacing: 6) {
                                Text(mode == .login ? "Sign In" : "Create Account")
                                    .font(.system(size: 15, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(FlowLineTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !isFormValid)
                .opacity(isFormValid ? 1 : 0.5)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // ── Forgot Password link (login only) ────────────────────
                if mode == .login {
                    Button(action: { showForgotPassword = true }) {
                        Text("Forgot password?")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FlowLineTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }

                Spacer()

                // ── Footer ──────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 11))
                        .foregroundColor(FlowLineTheme.secondTxt)
                    HStack(spacing: 8) {
                        Link("Terms of Use", destination: URL(string: "https://flowline.ink/terms")!)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(FlowLineTheme.accent)
                        Text("•")
                            .foregroundColor(FlowLineTheme.secondTxt)
                        Link("Privacy Policy", destination: URL(string: "https://flowline.ink/privacy")!)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(FlowLineTheme.accent)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
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
        Button {
            withAnimation {
                mode = tab
                errorMessage = nil
                emailError = nil
                passwordMatchError = nil
                password = ""
                passwordConfirm = ""
                showPassword = false
                showPasswordConfirm = false
            }
        } label: {
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

    #if os(iOS)
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
    #else
    private func authField(_ placeholder: String, text: Binding<String>,
                           icon: String, isSecure: Bool = false,
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
    #endif

    // MARK: - Password field with visibility toggle

    #if os(iOS)
    private func passwordField(_ placeholder: String, text: Binding<String>,
                              isVisible: Binding<Bool>, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(FlowLineTheme.secondTxt)
                .frame(width: 16)

            if isVisible.wrappedValue {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.mainTxt)
            } else {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.mainTxt)
            }

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isVisible.wrappedValue.toggle() } }) {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
            .buttonStyle(.plain)
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
    #else
    private func passwordField(_ placeholder: String, text: Binding<String>,
                              isVisible: Binding<Bool>, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(FlowLineTheme.secondTxt)
                .frame(width: 16)

            if isVisible.wrappedValue {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.mainTxt)
            } else {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.mainTxt)
            }

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isVisible.wrappedValue.toggle() } }) {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 13))
                    .foregroundColor(FlowLineTheme.secondTxt)
            }
            .buttonStyle(.plain)
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
    #endif

    // MARK: - Logic

    private var isFormValid: Bool {
        let emailValid = EmailValidator.isValid(email)
        let passwordValid = password.count >= 6
        let base = emailValid && passwordValid

        if mode == .register {
            let nameValid = !name.isEmpty
            let passwordsMatch = password == passwordConfirm && passwordConfirm.count >= 6
            return base && nameValid && passwordsMatch
        }
        return base
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
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        #endif
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

