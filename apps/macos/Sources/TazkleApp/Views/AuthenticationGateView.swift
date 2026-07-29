import SwiftUI
import TazkleAuthentication
import TazkleDesignSystem

struct AuthenticationGateView: View {
    @EnvironmentObject private var authentication: AuthenticationController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appearancePreference") private var appearance =
        AppearancePreference.automatic.rawValue
    @State private var emailAddress = ""
    @State private var emailValidationAttempted = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
    }

    private var highContrast: Bool {
        AppearancePreference(rawValue: appearance)?.usesHighContrastTokens == true
            || colorSchemeContrast == .increased
    }

    var body: some View {
        ZStack {
            TazkleColors.canvas(for: colorScheme, highContrast: highContrast)
                .ignoresSafeArea()
            ambientColor

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 72) {
                    ConceptPreview()
                        .frame(maxWidth: 520)
                    accessCard
                        .frame(width: 430)
                }
                VStack(spacing: TazkleSpacing.xLarge) {
                    BrandWordmarkView()
                        .frame(width: 136, height: 38)
                    accessCard
                        .frame(maxWidth: 430)
                }
            }
            .padding(48)
        }
        .environment(\.tazkleHighContrast, highContrast)
        .task {
            switch authentication.state {
            case .signedOut, .configurationRequired:
                await authentication.restore()
            default:
                break
            }
        }
    }

    private var ambientColor: some View {
        ZStack {
            Circle()
                .fill(TazkleColors.relationship.opacity(highContrast ? 0.06 : 0.12))
                .frame(width: 520, height: 520)
                .blur(radius: highContrast ? 0 : 110)
                .offset(x: 340, y: -230)
            Circle()
                .fill(TazkleColors.actionPrimary.opacity(highContrast ? 0.05 : 0.09))
                .frame(width: 440, height: 440)
                .blur(radius: highContrast ? 0 : 120)
                .offset(x: -430, y: 290)
        }
        .accessibilityHidden(true)
    }

    private var accessCard: some View {
        VStack(spacing: TazkleSpacing.xLarge) {
            VStack(spacing: TazkleSpacing.large) {
                BrandWordmarkView()
                    .frame(width: 148, height: 42)
                VStack(spacing: TazkleSpacing.small) {
                    Text("Haz que el proyecto encaje")
                        .font(.title2.weight(.semibold))
                    Text(accessSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            stateNotice

            VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                Text("Correo electrónico")
                    .font(.callout.weight(.medium))

                HStack(spacing: TazkleSpacing.small) {
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("nombre@empresa.com", text: $emailAddress)
                        .textFieldStyle(.plain)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .onSubmit(beginEmailSignIn)
                        .accessibilityLabel("Correo electrónico")
                }
                .padding(.horizontal, TazkleSpacing.medium)
                .padding(.vertical, TazkleSpacing.medium)
                .background(
                    TazkleColors.elevated(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: TazkleRadius.control)
                        .stroke(
                            emailHasError
                                ? TazkleColors.warning
                                : TazkleColors.separator(
                                    for: colorScheme,
                                    highContrast: highContrast
                                ),
                            lineWidth: emailHasError ? 2 : 1
                        )
                }
                .disabled(isBusy)

                if emailHasError {
                    Label(
                        "Escribe un correo válido para continuar.",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(TazkleColors.warning)
                    .accessibilityLabel(
                        "Error en correo electrónico. Escribe un correo válido para continuar."
                    )
                } else {
                    Text("No se guarda en preferencias ni en SQLite.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: TazkleSpacing.medium) {
                Button(action: beginEmailSignIn) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .accessibilityHidden(true)
                        Text(primaryActionTitle)
                        Spacer()
                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                                .accessibilityLabel("Acceso en curso")
                        } else {
                            Image(systemName: "arrow.up.right")
                                .accessibilityHidden(true)
                        }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, TazkleSpacing.large)
                    .padding(.vertical, TazkleSpacing.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(TazkleColors.actionPrimary)
                .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: TazkleRadius.control)
                        .stroke(Color.white.opacity(highContrast ? 0.65 : 0.18))
                }
                .disabled(authentication.configuration == nil || isBusy)
                .keyboardShortcut(.defaultAction)
                .accessibilityHint(
                    "Abre el proveedor de identidad en el navegador seguro de macOS."
                )

                if authentication.state == .authorizing {
                    Button {
                        authentication.returnToSignIn()
                    } label: {
                        Label(
                            "Cancelar y volver a intentarlo",
                            systemImage: "arrow.counterclockwise"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TazkleSpacing.small)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(
                        "Cierra el acceso actual y habilita nuevamente el correo."
                    )
                }

                Button {
                    authentication.continueLocally()
                } label: {
                    Label("Continuar sólo en esta Mac", systemImage: "internaldrive")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TazkleSpacing.small)
                }
                .buttonStyle(.bordered)
                .disabled(authentication.state == .restoring)
                .accessibilityHint(
                    "Cancela cualquier acceso pendiente y abre los proyectos locales sin sincronización ni colaboración."
                )
            }

            Label(
                "Tu contraseña permanece en el proveedor de identidad",
                systemImage: "lock.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
        .padding(TazkleSpacing.xxLarge)
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
        .shadow(
            color: Color.black.opacity(highContrast ? 0 : 0.24),
            radius: reduceMotion ? 0 : 32,
            y: reduceMotion ? 0 : 14
        )
    }

    @ViewBuilder
    private var stateNotice: some View {
        switch authentication.state {
        case .configurationRequired:
            AccessNotice(
                title: "Proveedor pendiente de configurar",
                detail: "Puedes trabajar localmente. El acceso remoto se habilitará al registrar el cliente OIDC de Tazkle.",
                systemImage: "wrench.and.screwdriver",
                color: TazkleColors.warning
            )
        case .failed(let failure):
            AccessNotice(
                title: "No se completó el acceso",
                detail: failure.userMessage,
                systemImage: "exclamationmark.triangle",
                color: TazkleColors.warning
            )
        case .restoring:
            AccessNotice(
                title: "Restaurando sesión",
                detail: "Validando la credencial guardada de forma segura en esta Mac.",
                systemImage: "arrow.triangle.2.circlepath",
                color: TazkleColors.assistantProposal
            )
        case .authorizing:
            AccessNotice(
                title: "Completa el acceso en el navegador",
                detail: "Ahí puedes iniciar sesión o crear una cuenta. Si cerraste la ventana, cancela este intento para comenzar otro.",
                systemImage: "safari",
                color: TazkleColors.assistantProposal
            )
        default:
            EmptyView()
        }
    }

    private var accessSubtitle: String {
        authentication.configuration == nil
            ? "Conecta tu identidad para colaborar o entra en modo local."
            : "Inicia sesión o crea una cuenta para sincronizar proyectos y colaborar con tu equipo."
    }

    private var primaryActionTitle: String {
        switch authentication.state {
        case .authorizing: "Esperando al navegador…"
        case .restoring: "Restaurando sesión…"
        default: "Iniciar sesión o crear cuenta"
        }
    }

    private var isBusy: Bool {
        authentication.state == .authorizing || authentication.state == .restoring
    }

    private var emailHint: EmailLoginHint? {
        EmailLoginHint(emailAddress)
    }

    private var emailHasError: Bool {
        emailValidationAttempted && emailHint == nil
    }

    private func beginEmailSignIn() {
        emailValidationAttempted = true
        guard let emailHint else {
            focusedField = .email
            return
        }
        focusedField = nil
        Task {
            await authentication.signIn(email: emailHint)
        }
    }
}

private struct AccessNotice: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 20)
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
        .padding(TazkleSpacing.medium)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.control)
                .stroke(color.opacity(0.34))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ConceptPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xxLarge) {
            BrandWordmarkView()
                .frame(width: 160, height: 46)

            ZStack {
                ConceptConnections()
                    .stroke(
                        TazkleColors.relationship.opacity(highContrast ? 0.85 : 0.48),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .accessibilityHidden(true)
                ConceptBlock(title: "Idea", systemImage: "lightbulb", accent: TazkleColors.actionPrimary)
                    .offset(x: -122, y: -102)
                ConceptBlock(title: "Producto", systemImage: "square.3.layers.3d", accent: TazkleColors.relationship)
                    .offset(x: 72, y: -34)
                ConceptBlock(title: "Equipo", systemImage: "person.2", accent: TazkleColors.assistantProposal)
                    .offset(x: -96, y: 96)
                ConceptBlock(title: "Factibilidad", systemImage: "checkmark.seal", accent: TazkleColors.success)
                    .offset(x: 128, y: 116)
            }
            .frame(height: 390)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Un mapa de proyecto conecta la idea con producto, equipo y factibilidad."
            )

            VStack(alignment: .leading, spacing: TazkleSpacing.small) {
                Text("De la idea a un plan viable.")
                    .font(.largeTitle.weight(.semibold))
                Text(
                    "Estructura módulos, arquitectura, responsables y costos sin perder la relación entre decisiones."
                )
                .font(.title3)
                .foregroundStyle(
                    TazkleColors.secondaryContent(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ConceptBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: TazkleSpacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(accent)
            Text(title)
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, TazkleSpacing.large)
        .padding(.vertical, TazkleSpacing.medium)
        .frame(width: 154, alignment: .leading)
        .background(
            TazkleColors.panel(for: colorScheme, highContrast: highContrast)
        )
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(accent.opacity(highContrast ? 0.9 : 0.42))
        }
    }
}

private struct ConceptConnections: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: center.x - 115, y: center.y - 92))
        path.addCurve(
            to: CGPoint(x: center.x + 40, y: center.y - 30),
            control1: CGPoint(x: center.x - 40, y: center.y - 92),
            control2: CGPoint(x: center.x - 35, y: center.y - 30)
        )
        path.addCurve(
            to: CGPoint(x: center.x - 70, y: center.y + 90),
            control1: CGPoint(x: center.x + 10, y: center.y + 28),
            control2: CGPoint(x: center.x - 70, y: center.y + 20)
        )
        path.move(to: CGPoint(x: center.x + 90, y: center.y - 22))
        path.addCurve(
            to: CGPoint(x: center.x + 122, y: center.y + 102),
            control1: CGPoint(x: center.x + 140, y: center.y + 10),
            control2: CGPoint(x: center.x + 122, y: center.y + 42)
        )
        return path
    }
}
