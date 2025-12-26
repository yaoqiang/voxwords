import SwiftUI

/// Lightweight premium status sheet shown from Settings when the user is already subscribed.
/// Intentionally minimal (not a "membership center").
struct PremiumStatusSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onManage: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule(style: .continuous)
                .fill(.secondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text(String(localized: "settings.plus.title"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(String(localized: "settings.upgrade.active"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            VStack(spacing: 10) {
                Button {
                    HapticManager.shared.selectionChanged()
                    onManage()
                } label: {
                    Text(String(localized: "settings.plus.manage"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    HapticManager.shared.selectionChanged()
                    onRestore()
                } label: {
                    Text(String(localized: "settings.plus.restore"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    HapticManager.shared.selectionChanged()
                    dismiss()
                } label: {
                    Text(String(localized: "common.close"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }
}
