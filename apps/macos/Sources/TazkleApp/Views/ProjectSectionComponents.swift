import SwiftUI
import TazkleDesignSystem

enum ProjectGridLayout {
    static func equalColumns(
        _ count: Int,
        minimumWidth: CGFloat = 150
    ) -> [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: minimumWidth),
                spacing: TazkleSpacing.medium,
                alignment: .top
            ),
            count: count
        )
    }
}

struct ProjectSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = TazkleColors.actionPrimary
    var trailingTitle: String?
    var trailingAction: (() -> Void)?
    var contextBadgeTitle = "Escenario de prototipo"
    var contextBadgeSystemImage = "hammer"
    var contextBadgeHelp = "Estos datos ilustran el flujo visual y todavía no se guardan en el modelo del proyecto."

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: TazkleSpacing.large) {
                identity
                Spacer()
                prototypeBadge
                if let trailingTitle, let trailingAction {
                    Button(trailingTitle, action: trailingAction)
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                }
            }

            VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
                identity
                HStack {
                    prototypeBadge
                    Spacer()
                    if let trailingTitle, let trailingAction {
                        Button(trailingTitle, action: trailingAction)
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                    }
                }
            }
        }
    }

    private var identity: some View {
        HStack(spacing: TazkleSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: TazkleRadius.card)
                    .fill(accent.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(
                        TazkleColors.primaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(
                        TazkleColors.secondaryContent(
                            for: colorScheme,
                            highContrast: highContrast
                        )
                    )
            }
        }
    }

    private var prototypeBadge: some View {
        Label(contextBadgeTitle, systemImage: contextBadgeSystemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                TazkleColors.secondaryContent(
                    for: colorScheme,
                    highContrast: highContrast
                )
            )
            .padding(.horizontal, TazkleSpacing.medium)
            .padding(.vertical, TazkleSpacing.small)
            .background(
                TazkleColors.elevated(
                    for: colorScheme,
                    highContrast: highContrast
                )
                .opacity(highContrast ? 1 : 0.72)
            )
            .clipShape(Capsule())
            .help(contextBadgeHelp)
    }
}

struct ProjectSectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let title: String
    let systemImage: String?
    let content: Content

    init(
        title: String,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(.headline)
            } else {
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(
                    TazkleColors.separator(
                        for: colorScheme,
                        highContrast: highContrast
                    ),
                    lineWidth: highContrast ? 1.5 : 1
                )
        }
    }
}

struct ProjectMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(accent)
                Spacer()
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
            }

            Text(title)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(
                    TazkleColors.secondaryContent(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(
            TazkleColors.panel(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(
                    TazkleColors.separator(
                        for: colorScheme,
                        highContrast: highContrast
                    ),
                    lineWidth: highContrast ? 1.5 : 1
                )
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProjectStatusPill: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, TazkleSpacing.small)
            .padding(.vertical, TazkleSpacing.xSmall)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct ProjectProgressRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let title: String
    let detail: String
    let value: Double
    let color: Color
    var trailing: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(
                            TazkleColors.secondaryContent(
                                for: colorScheme,
                                highContrast: highContrast
                            )
                        )
                }
                Spacer()
                Text(trailing ?? "\(Int(value * 100))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(
                        value > 1
                            ? TazkleColors.warning
                            : TazkleColors.secondaryContent(
                                for: colorScheme,
                                highContrast: highContrast
                            )
                    )
            }
            ProgressView(value: min(value, 1))
                .tint(value > 1 ? TazkleColors.warning : color)
                .accessibilityValue("\(Int(value * 100)) por ciento")
        }
    }
}

struct ProjectListRow<Leading: View, Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let leading: Leading
    let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: TazkleSpacing.medium) {
            leading
            Spacer(minLength: TazkleSpacing.large)
            trailing
        }
        .padding(.vertical, TazkleSpacing.small)
        .overlay(alignment: .bottom) {
            Divider()
                .foregroundStyle(
                    TazkleColors.separator(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
        }
    }
}
