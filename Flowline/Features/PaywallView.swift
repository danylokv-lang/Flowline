import SwiftUI
import RevenueCat

// MARK: - FlowlinePaywallView — Custom native paywall

struct FlowlinePaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    var onDismiss: () -> Void

    @State private var isRestoring  = false
    @State private var pickYearly   = true   // default = yearly (better value)

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

                        Text("Unlimited AI planning, every day.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#9999bb"))
                    }
                    .padding(.bottom, 28)

                    // ── Features ──────────────────────────────────
                    VStack(spacing: 10) {
                        featureRow(icon: "sparkles",                 color: "#6d4cfa", text: "Unlimited AI day planning")
                        featureRow(icon: "arrow.trianglehead.2.counterclockwise.rotate.90",
                                                                     color: "#3b9eff", text: "Unlimited replanning & smart reschedule")
                        featureRow(icon: "chart.bar.fill",           color: "#f59e0b", text: "Full stats, streaks & insights")
                        featureRow(icon: "timer",                    color: "#2ecc71", text: "Focus timer & session tracking")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // ── Plan picker ───────────────────────────────
                    VStack(spacing: 10) {
                        planCard(
                            title: "Yearly",
                            subtitle: "Best value · billed once a year",
                            price: "$34.99",
                            badge: "Save 42%",
                            selected: pickYearly
                        ) { pickYearly = true }

                        planCard(
                            title: "Monthly",
                            subtitle: "Flexible · cancel anytime",
                            price: "$4.99",
                            badge: nil,
                            selected: !pickYearly
                        ) { pickYearly = false }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // ── Trial note ────────────────────────────────
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(hex: "#2ecc71"))
                            .font(.system(size: 12))
                        Text("3-day free trial · No charge until trial ends")
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
                                Text(pickYearly
                                     ? "Start Free Trial — $34.99/yr"
                                     : "Start Free Trial — $4.99/mo")
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
        #if os(macOS)
        .frame(width: 420, height: 720)
        #endif
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

    private func planCard(
        title: String,
        subtitle: String,
        price: String,
        badge: String?,
        selected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio dot
                ZStack {
                    Circle()
                        .stroke(selected ? Color(hex: "#6d4cfa") : Color(hex: "#444466"), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if selected {
                        Circle()
                            .fill(Color(hex: "#6d4cfa"))
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#2ecc71"))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#2ecc71").opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#7a7a9a"))
                }

                Spacer()

                Text(price)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                selected
                    ? Color(hex: "#6d4cfa").opacity(0.12)
                    : Color.white.opacity(0.03)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        selected ? Color(hex: "#6d4cfa").opacity(0.6) : Color.white.opacity(0.06),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func purchase() async {
        await subscriptionManager.fetchOfferings()
        let pkgOpt = pickYearly
            ? (subscriptionManager.yearlyPackage ?? subscriptionManager.monthlyPackage)
            : subscriptionManager.monthlyPackage
        guard let pkg = pkgOpt else { return }
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
                    #if os(macOS)
                    if let url = URL(string: "macappstore://showManageSubscriptions") {
                        NSWorkspace.shared.open(url)
                    }
                    #else
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                    #endif
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
