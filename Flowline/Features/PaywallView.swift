import SwiftUI
import RevenueCat

// MARK: - FlowlinePaywallView — Custom native paywall

struct FlowlinePaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    var onDismiss: () -> Void

    @State private var isRestoring = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            Color(hex: "#080810").ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [Color(hex: "#6d4cfa").opacity(0.18), .clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Close button
            Button {
                onDismiss()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#7a7a9a"))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(20)
            .zIndex(10)

            // Main content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Hero ──────────────────────────────────────
                    VStack(spacing: 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#6d4cfa").opacity(0.15))
                                .frame(width: 80, height: 80)
                            Text("✦")
                                .font(.system(size: 38))
                        }
                        .padding(.top, 56)

                        Text("Flowline Pro")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.white)

                        // Sale badge
                        HStack(spacing: 6) {
                            Text("LIMITED OFFER")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#ff7b45"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#ff7b45").opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 28)

                    // ── Features ──────────────────────────────────
                    VStack(spacing: 10) {
                        featureRow(icon: "sparkles",                  color: "#6d4cfa", text: "10 AI planning messages per day")
                        featureRow(icon: "calendar.badge.checkmark",  color: "#3b9eff", text: "Smart calendar & replanning")
                        featureRow(icon: "timer",                     color: "#2ecc71", text: "Focus timer with session tracking")
                        featureRow(icon: "bell.badge.fill",           color: "#a78bfa", text: "Smart reminders & notifications")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                    // ── Plan card ─────────────────────────────────
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Monthly")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Text("SALE 55% OFF")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color(hex: "#ff7b45"))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(hex: "#ff7b45").opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            Text("per month · cancel anytime")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#7a7a9a"))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$4.99")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                            Text("$10.99")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#44445a"))
                                .strikethrough(true, color: Color(hex: "#44445a"))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color(hex: "#6d4cfa").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#6d4cfa").opacity(0.45), lineWidth: 1.5))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // ── Trial note ────────────────────────────────
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(hex: "#2ecc71"))
                            .font(.system(size: 12))
                        Text("3-day free trial included · No charge until trial ends")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#7a7a9a"))
                    }
                    .padding(.bottom, 20)

                    // ── CTA Button ────────────────────────────────
                    Button {
                        Task { await purchase() }
                    } label: {
                        ZStack {
                            if subscriptionManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Text("Start Free Trial — $4.99/mo")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#8b6dff"), Color(hex: "#6d4cfa")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(hex: "#6d4cfa").opacity(0.4), radius: 16, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(subscriptionManager.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // ── Restore ───────────────────────────────────
                    Button {
                        Task { await restore() }
                    } label: {
                        HStack(spacing: 4) {
                            if isRestoring {
                                ProgressView().scaleEffect(0.7).tint(Color(hex: "#7a7a9a"))
                            }
                            Text("Restore purchases")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#7a7a9a"))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)

                    // Error
                    if let err = subscriptionManager.errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#ff5f5f"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    }

                    // Legal
                    Text("Subscriptions auto-renew unless cancelled 24h before renewal.\nManage in App Store settings.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#44445a"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                }
            }
        }
        .frame(width: 420, height: 680)
    }

    // MARK: - Sub-views

    private func featureRow(icon: String, color: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: color))
                .frame(width: 28, height: 28)
                .background(Color(hex: color).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#eeeef5"))

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#2ecc71"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Logic

    private func purchase() async {
        await subscriptionManager.fetchOfferings()
        guard let pkg = subscriptionManager.monthlyPackage else { return }
        let success = await subscriptionManager.purchase(package: pkg)
        if success { onDismiss(); dismiss() }
    }

    private func restore() async {
        isRestoring = true
        await subscriptionManager.restorePurchases()
        isRestoring = false
        if subscriptionManager.isPro { onDismiss(); dismiss() }
    }
}

// MARK: - FlowlineCustomerCenter

struct FlowlineCustomerCenter: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#080810").ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "#6d4cfa"))

                Text("Manage Subscription")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("To manage, cancel, or restore your subscription, visit the App Store settings.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#7a7a9a"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Open App Store Subscriptions") {
                    if let url = URL(string: "macappstore://showManageSubscriptions") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#6d4cfa"))

                Button("Restore Purchases") {
                    Task {
                        _ = try? await Purchases.shared.restorePurchases()
                        dismiss()
                    }
                }
                .foregroundColor(Color(hex: "#7a7a9a"))
                .font(.system(size: 14))
            }
            .padding(32)
        }
        .frame(width: 380, height: 320)
    }
}

// MARK: - View Modifier

extension View {
    func flowlinePaywall(
        isPresented: Binding<Bool>,
        subscriptionManager: SubscriptionManager,
        onSuccess: @escaping () -> Void = {}
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            FlowlinePaywallView {
                isPresented.wrappedValue = false
                if subscriptionManager.isPro { onSuccess() }
            }
            .environmentObject(subscriptionManager)
        }
    }
}

