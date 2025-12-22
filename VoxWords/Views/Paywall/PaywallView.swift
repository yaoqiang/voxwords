import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchase: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selected: PurchaseManager.Tier = .yearly

    var body: some View {
        ZStack {
            LiquidGlassBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    featureList

                    planPicker

                    cta

                    footerLinks
                }
                .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                .padding(.top, 14)
                .padding(.bottom, 22)
            }
        }
        .task {
            purchase.start()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    HapticManager.shared.selectionChanged()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.75))
                        .padding(10)
                        .glassIconCircle(size: 40)
                }
                .buttonStyle(.plain)

                Spacer()

                if purchase.isPremium {
                    Text(String(localized: "paywall.status.active"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                } else {
                    Text(String(localized: "paywall.badge.launch"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                }
            }

            Text(String(localized: "paywall.title"))
                .font(.system(size: 38, weight: .regular, design: .serif))
                .foregroundStyle(.primary.opacity(0.92))

            Text(String(localized: "paywall.subtitle"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaywallFeatureRow(icon: "sparkles", text: String(localized: "paywall.feature.unlimited_cards"))
            PaywallFeatureRow(icon: "speaker.wave.2.fill", text: String(localized: "paywall.feature.pronunciation"))
            PaywallFeatureRow(icon: "globe", text: String(localized: "paywall.feature.more_languages"))
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "paywall.choose_plan"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                planRow(.yearly, badge: yearlyBadge)
                planRow(.monthly, badge: nil)
            }
        }
    }

    private var yearlyBadge: String? {
        if let pct = yearlySavingsPercent, pct >= 10 {
            return String(format: String(localized: "paywall.badge.save_percent"), pct)
        }
        return String(localized: "paywall.badge.best_value")
    }

    private var yearlySavingsPercent: Int? {
        guard let monthly = purchase.productsByTier[.monthly],
              let yearly = purchase.productsByTier[.yearly] else { return nil }
        let annualViaMonthly = NSDecimalNumber(decimal: monthly.price)
            .multiplying(by: NSDecimalNumber(value: 12))
        let annual = NSDecimalNumber(decimal: yearly.price)
        guard annualViaMonthly.doubleValue > 0 else { return nil }
        let savings = 1.0 - (annual.doubleValue / annualViaMonthly.doubleValue)
        let pct = Int((savings * 100.0).rounded())
        return max(0, min(90, pct))
    }

    private var yearlyPerMonthText: String? {
        guard let yearly = purchase.productsByTier[.yearly] else { return nil }
        let perMonth = NSDecimalNumber(decimal: yearly.price)
            .dividing(by: NSDecimalNumber(value: 12))
            .decimalValue
        return perMonth.formatted(yearly.priceFormatStyle)
    }

    private func planRow(_ tier: PurchaseManager.Tier, badge: String?) -> some View {
        let isSelected = (selected == tier)
        let p = purchase.productsByTier[tier]

        return Button {
            HapticManager.shared.selectionChanged()
            selected = tier
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(planTitle(tier))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                        }
                    }

                    Text(planSubtitle(tier))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    if tier == .yearly, let perMonth = yearlyPerMonthText {
                        Text(String(format: String(localized: "paywall.yearly.per_month"), perMonth))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.82))
                    }
                }

                Spacer()

                Text(p?.displayPrice ?? "—")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? VoxTheme.Colors.softPink : .secondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .glassCard(cornerRadius: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(VoxTheme.Colors.softPink.opacity(isSelected ? 0.70 : 0.0), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                HapticManager.shared.mediumImpact()
                Task { await purchase.purchase(selected) }
            } label: {
                HStack(spacing: 8) {
                    if purchase.isLoadingProducts {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(ctaTitle(selected))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .dark ? [
                                    VoxTheme.Colors.softPink.opacity(0.75),
                                    VoxTheme.Colors.softPink.opacity(0.60)
                                ] : [
                                    VoxTheme.Colors.softPink.opacity(0.85),
                                    VoxTheme.Colors.softPink.opacity(0.70)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(purchase.isLoadingProducts)

            Button {
                HapticManager.shared.selectionChanged()
                Task { await purchase.restorePurchases() }
            } label: {
                Text(String(localized: "paywall.restore"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if let msg = purchase.lastPurchaseErrorMessage, msg.isEmpty == false {
                Text(msg)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 6)
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Text(String(localized: "paywall.disclaimer"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.75))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://thin-tuba-90a.notion.site/2cfa939e504780129e73df8ff650892e") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "paywall.privacy"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                }
                
                Text("•")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
                
                Button {
                    if let url = URL(string: "https://thin-tuba-90a.notion.site/2cfa939e504780909350eff2f5c76e77") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "paywall.terms"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func planTitle(_ tier: PurchaseManager.Tier) -> String {
        switch tier {
        case .monthly: return String(localized: "paywall.plan.monthly")
        case .yearly: return String(localized: "paywall.plan.yearly")
        }
    }

    private func planSubtitle(_ tier: PurchaseManager.Tier) -> String {
        switch tier {
        case .monthly: return String(localized: "paywall.plan.monthly.subtitle")
        case .yearly: return String(localized: "paywall.plan.yearly.subtitle")
        }
    }

    private func ctaTitle(_ tier: PurchaseManager.Tier) -> String {
        String(localized: "paywall.cta.subscribe")
    }
}

private struct PaywallFeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

