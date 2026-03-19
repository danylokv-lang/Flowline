import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            FlowLineTheme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────────
                HStack {
                    Spacer()
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .background(FlowLineTheme.borderHi)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // ── Icon ──────────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(FlowLineTheme.accent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(FlowLineTheme.accent)
                }
                .padding(.bottom, 24)

                // ── Title ─────────────────────────────────────────────────
                Text("You've hit today's limit")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(FlowLineTheme.mainTxt)
                    .multilineTextAlignment(.center)

                Text("Free plan includes \(SubscriptionManager.freeLimit) AI messages per day.\nGo Pro for unlimited planning.")
                    .font(.system(size: 14))
                    .foregroundColor(FlowLineTheme.secondTxt)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 32)

                // ── Features ──────────────────────────────────────────────
                VStack(spacing: 10) {
                    featureRow("Unlimited AI messages")
                    featureRow("Full week planning")
                    featureRow("Menu bar quick chat")
                    featureRow("Priority AI responses")
                }
                .padding(.top, 28)
                .padding(.horizontal, 32)

                Spacer()

                // ── Pricing ───────────────────────────────────────────────
                VStack(spacing: 12) {
                    // Monthly
                    Button {
                        // TODO: trigger RevenueCat purchase for monthly
                        subscriptionManager.activatePro()
                        onDismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Monthly")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(FlowLineTheme.mainBg)
                                Text("Billed monthly, cancel anytime")
                                    .font(.system(size: 11))
                                    .foregroundColor(FlowLineTheme.mainBg.opacity(0.7))
                            }
                            Spacer()
                            Text(SubscriptionManager.monthlyPrice)
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(FlowLineTheme.mainBg)
                            Text("/mo")
                                .font(.system(size: 12))
                                .foregroundColor(FlowLineTheme.mainBg.opacity(0.7))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(FlowLineTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Yearly
                    Button {
                        // TODO: trigger RevenueCat purchase for yearly
                        subscriptionManager.activatePro()
                        onDismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Yearly")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(FlowLineTheme.mainTxt)
                                    Text("SAVE 33%")
                                        .font(.system(size: 9, weight: .heavy))
                                        .tracking(1)
                                        .foregroundColor(FlowLineTheme.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(FlowLineTheme.accent.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                Text("Billed annually")
                                    .font(.system(size: 11))
                                    .foregroundColor(FlowLineTheme.secondTxt)
                            }
                            Spacer()
                            Text(SubscriptionManager.yearlyPrice)
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(FlowLineTheme.mainTxt)
                            Text("/yr")
                                .font(.system(size: 12))
                                .foregroundColor(FlowLineTheme.secondTxt)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(FlowLineTheme.tertiaryBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(FlowLineTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        // TODO: RevenueCat restore purchases
                    } label: {
                        Text("Restore purchases")
                            .font(.system(size: 12))
                            .foregroundColor(FlowLineTheme.secondTxt.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .frame(width: 400, height: 580)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(FlowLineTheme.accent)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(FlowLineTheme.secondTxt)
            Spacer()
        }
    }
}
