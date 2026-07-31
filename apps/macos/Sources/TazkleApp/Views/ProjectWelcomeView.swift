import SwiftUI
import TazkleAuthentication
import TazkleDesignSystem

struct ProjectWelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authentication: AuthenticationController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    var body: some View {
        ZStack {
            TazkleColors.canvas(for: colorScheme, highContrast: highContrast)
                .ignoresSafeArea()

            ambientBackground

            ScrollView {
                VStack(spacing: TazkleSpacing.xxLarge) {
                    BrandWordmarkView()
                        .frame(width: 164, height: 46)
                        .accessibilityLabel("Tazkle")

                    welcomeMessage
                    primaryActions
                    tourPreview
                    storageNotice
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 48)
                .padding(.vertical, 56)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
    }

    private var welcomeMessage: some View {
        VStack(spacing: TazkleSpacing.medium) {
            Text("Bienvenido a Tazkle")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(
                "Convierte una idea en un proyecto estructurado, viable y cotizable "
                    + "sin perder la relación entre decisiones."
            )
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 660)

            if authentication.state == .offline {
                Label(
                    "Estás sin conexión. Puedes crear el proyecto en esta Mac y sincronizarlo posteriormente.",
                    systemImage: "wifi.slash"
                )
                .font(.callout)
                .foregroundStyle(TazkleColors.warning)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var primaryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: TazkleSpacing.medium) {
                createProjectButton
                tourButton
            }

            VStack(spacing: TazkleSpacing.medium) {
                createProjectButton
                tourButton
            }
        }
        .frame(maxWidth: 560)
    }

    private var createProjectButton: some View {
        Button {
            appState.presentNewProject()
        } label: {
            Label("Crear nuevo proyecto", systemImage: "plus")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, TazkleSpacing.medium)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .accessibilityHint(
            "Abre el asistente para nombrar el proyecto, elegir una plantilla y configurar sus tecnologías."
        )
    }

    private var tourButton: some View {
        Button {
            appState.presentProductTour()
        } label: {
            Label("Ver recorrido", systemImage: "play.circle")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, TazkleSpacing.medium)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint(
            "Muestra un recorrido breve por el mapa, la arquitectura, la factibilidad y la cotización."
        )
    }

    private var tourPreview: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.large) {
            Text("De la idea a un plan con pies y cabeza")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    welcomeFeature(
                        title: "Estructura",
                        detail: "Organiza módulos y relaciones en un mismo mapa.",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        accent: TazkleColors.relationship
                    )
                    welcomeFeature(
                        title: "Evalúa",
                        detail: "Revisa factibilidad, supuestos y riesgos antes de construir.",
                        systemImage: "checkmark.seal",
                        accent: TazkleColors.success
                    )
                    welcomeFeature(
                        title: "Cotiza",
                        detail: "Relaciona horas, roles, servicios y precio propuesto.",
                        systemImage: "dollarsign.circle",
                        accent: TazkleColors.warning
                    )
                }

                VStack(spacing: TazkleSpacing.medium) {
                    welcomeFeature(
                        title: "Estructura",
                        detail: "Organiza módulos y relaciones en un mismo mapa.",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        accent: TazkleColors.relationship
                    )
                    welcomeFeature(
                        title: "Evalúa",
                        detail: "Revisa factibilidad, supuestos y riesgos antes de construir.",
                        systemImage: "checkmark.seal",
                        accent: TazkleColors.success
                    )
                    welcomeFeature(
                        title: "Cotiza",
                        detail: "Relaciona horas, roles, servicios y precio propuesto.",
                        systemImage: "dollarsign.circle",
                        accent: TazkleColors.warning
                    )
                }
            }
        }
        .padding(TazkleSpacing.xLarge)
        .background(
            TazkleColors.panel(for: colorScheme, highContrast: highContrast)
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.panel)
                .stroke(
                    TazkleColors.separator(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
        }
    }

    private func welcomeFeature(
        title: String,
        detail: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        HStack(alignment: .top, spacing: TazkleSpacing.medium) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TazkleSpacing.xSmall) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var storageNotice: some View {
        Label(
            "El primer proyecto se crea sólo cuando confirmas el asistente. "
                + "No generamos contenido ni enviamos tu idea automáticamente.",
            systemImage: "lock.shield"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(TazkleColors.relationship.opacity(highContrast ? 0.05 : 0.12))
                .frame(width: 520, height: 520)
                .blur(radius: highContrast ? 0 : 120)
                .offset(x: 420, y: -260)
            Circle()
                .fill(TazkleColors.assistantProposal.opacity(highContrast ? 0.04 : 0.08))
                .frame(width: 420, height: 420)
                .blur(radius: highContrast ? 0 : 110)
                .offset(x: -460, y: 300)
        }
        .accessibilityHidden(true)
    }
}

struct ProductTourView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pageIndex = 0

    private let pages = ProductTourPage.pages

    var body: some View {
        VStack(spacing: 0) {
            tourHeader
            Divider()

            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            tourFooter
        }
        .frame(width: 860, height: 620)
        .background(
            TazkleColors.canvas(for: colorScheme, highContrast: highContrast)
        )
    }

    private var tourHeader: some View {
        HStack {
            BrandWordmarkView()
                .frame(width: 124, height: 36)
                .accessibilityLabel("Tazkle")

            Spacer()

            Text("Paso \(pageIndex + 1) de \(pages.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    "Paso \(pageIndex + 1) de \(pages.count), \(pages[pageIndex].title)"
                )
        }
        .padding(.horizontal, TazkleSpacing.xLarge)
        .padding(.vertical, TazkleSpacing.large)
        .background(
            TazkleColors.panel(for: colorScheme, highContrast: highContrast)
        )
    }

    private var page: some View {
        let currentPage = pages[pageIndex]
        return VStack(spacing: TazkleSpacing.xxLarge) {
            Image(systemName: currentPage.systemImage)
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(currentPage.accent)
                .frame(width: 112, height: 112)
                .background(currentPage.accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: TazkleSpacing.medium) {
                Text(currentPage.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(currentPage.detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }

            HStack(spacing: TazkleSpacing.small) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(
                            index == pageIndex
                                ? TazkleColors.relationship
                                : TazkleColors.separator(
                                    for: colorScheme,
                                    highContrast: highContrast
                                )
                        )
                        .frame(width: index == pageIndex ? 34 : 22, height: 5)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(TazkleSpacing.xxLarge)
        .id(pageIndex)
        .transition(reduceMotion ? .identity : .opacity)
        .accessibilityElement(children: .contain)
    }

    private var tourFooter: some View {
        HStack {
            Button("Cerrar recorrido") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if pageIndex > 0 {
                Button("Atrás") {
                    move(to: pageIndex - 1)
                }
            }

            Button(pageIndex == pages.count - 1 ? "Crear mi primer proyecto" : "Continuar") {
                if pageIndex == pages.count - 1 {
                    dismiss()
                    DispatchQueue.main.async {
                        appState.presentNewProject()
                    }
                } else {
                    move(to: pageIndex + 1)
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(TazkleSpacing.xLarge)
        .background(
            TazkleColors.panel(for: colorScheme, highContrast: highContrast)
        )
    }

    private func move(to index: Int) {
        if reduceMotion {
            pageIndex = index
        } else {
            withAnimation(.easeOut(duration: 0.16)) {
                pageIndex = index
            }
        }
    }
}

private struct ProductTourPage {
    let title: String
    let detail: String
    let systemImage: String
    let accent: Color

    static let pages = [
        ProductTourPage(
            title: "Plasma la idea",
            detail: "Comienza escribiendo libremente, con una plantilla o desde un lienzo vacío. Tazkle convierte cada decisión en información estructurada.",
            systemImage: "lightbulb.max",
            accent: TazkleColors.relationship
        ),
        ProductTourPage(
            title: "Conecta el proyecto",
            detail: "Los módulos, tecnologías, responsables y costos comparten un mismo modelo. Las relaciones explican qué contiene, requiere, produce o valida cada bloque.",
            systemImage: "point.3.connected.trianglepath.dotted",
            accent: TazkleColors.actionPrimary
        ),
        ProductTourPage(
            title: "Evalúa antes de construir",
            detail: "Factibilidad muestra condiciones, supuestos y riesgos. La cotización deriva horas, tarifas, servicios y reserva sin presentar estimaciones como garantías.",
            systemImage: "checkmark.seal",
            accent: TazkleColors.success
        ),
        ProductTourPage(
            title: "Mantén el control",
            detail: "El equipo trabaja sobre el mismo proyecto, con vistas por rol, historial y aprobaciones. Tazki propone alternativas, pero nunca aprueba ni modifica el plan por sí sola.",
            systemImage: "person.2.badge.gearshape",
            accent: TazkleColors.assistantProposal
        ),
    ]
}

struct WorkspaceLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    var body: some View {
        VStack(spacing: TazkleSpacing.large) {
            BrandWordmarkView()
                .frame(width: 148, height: 42)
                .accessibilityLabel("Tazkle")
            ProgressView()
                .controlSize(.small)
            Text("Preparando tu espacio")
                .font(.headline)
            Text("Buscando proyectos guardados para esta cuenta.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            TazkleColors.canvas(for: colorScheme, highContrast: highContrast)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparando tu espacio. Buscando proyectos guardados.")
    }
}
