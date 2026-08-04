import SwiftUI
import TazkleAuthentication
import TazkleDesignSystem
import TazkleDomain

struct AccountOrganizationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var destinationID: String {
        appState.selectedDestinationID ?? "settings.profile"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                AccountSettingsHeader(
                    title: appState.selectedDestination?.title ?? "Perfil",
                    subtitle: subtitle,
                    systemImage: appState.selectedDestination?.systemImage ?? "person.crop.circle",
                    accent: accent,
                    state: headerState
                )

                switch destinationID {
                case "settings.availability", "settings.organization",
                     "settings.members", "settings.permissions":
                    ConnectedAccountDomainUnavailableView(
                        destinationID: destinationID
                    )
                case "settings.rates":
                    RoleRatesSettingsView()
                case "settings.notifications":
                    NotificationSettingsView()
                case "settings.appearance":
                    AppearanceSettingsView()
                case "settings.shortcuts":
                    KeyboardSettingsView()
                case "settings.templates":
                    TemplateSettingsView()
                case "settings.ai":
                    AISettingsView()
                case "settings.sync":
                    SyncSettingsView()
                case "settings.security":
                    SecuritySettingsView()
                default:
                    ProfileSettingsView()
                }
            }
            .padding(TazkleSpacing.xLarge)
        }
        .background(
            TazkleColors.canvas(
                for: colorScheme,
                highContrast: highContrast
            )
        )
    }

    private var subtitle: String {
        switch destinationID {
        case "settings.availability": "Capacidad semanal y compromisos visibles para evitar sobrecarga."
        case "settings.notifications": "Avisos relevantes sin convertir cada cambio en una interrupción."
        case "settings.appearance": "Tema, contraste, movimiento y sonido adaptados a macOS."
        case "settings.shortcuts": "Comandos disponibles por teclado y desde los menús de la aplicación."
        case "settings.organization": "Identidad, valores predeterminados y responsabilidad del espacio."
        case "settings.members": "Personas, roles y estado de acceso en un único directorio."
        case "settings.permissions": "Alcance efectivo por rol; el servidor será la autoridad final."
        case "settings.templates": "Base reutilizable para iniciar proyectos con reglas coherentes."
        case "settings.rates": "Costos internos separados del precio y de la información del cliente."
        case "settings.ai": "Privacidad, proveedores y límites de Tazki antes de enviar contexto."
        case "settings.sync": "Estado local, conectividad y conflictos sin ocultar trabajo pendiente."
        case "settings.security": "Sesiones, autenticación y auditoría de cambios sensibles."
        default: "Identidad profesional, preferencias regionales y contexto de trabajo."
        }
    }

    private var accent: Color {
        switch destinationID {
        case "settings.availability", "settings.sync": TazkleColors.success
        case "settings.notifications", "settings.rates": TazkleColors.warning
        case "settings.organization", "settings.members", "settings.permissions":
            TazkleColors.relationship
        case "settings.ai": TazkleColors.assistantProposal
        default: TazkleColors.actionPrimary
        }
    }

    private var headerState: AccountSettingsHeader.State {
        switch destinationID {
        case "settings.appearance", "settings.notifications", "settings.shortcuts":
            .local
        case "settings.security", "settings.profile":
            .implemented
        default:
            .prototype
        }
    }
}

private struct AccountSettingsHeader: View {
    enum State {
        case local
        case implemented
        case prototype
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let state: State

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: TazkleSpacing.large) {
                identity
                Spacer()
                status
            }
            VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
                identity
                status
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

    private var status: some View {
        let presentation: (title: String, systemImage: String, color: Color, hint: String) =
            switch state {
            case .local:
                (
                    "Preferencia local",
                    "internaldrive",
                    TazkleColors.success,
                    "Esta preferencia se conserva en esta Mac."
                )
            case .implemented:
                (
                    "Control implementado",
                    "lock.shield",
                    TazkleColors.actionPrimary,
                    "La superficie refleja el estado efectivo de autenticación de esta Mac."
                )
            case .prototype:
                (
                    "Escenario de prototipo",
                    "hammer",
                    TazkleColors.warning,
                    "Los datos ilustran el flujo y todavía no se guardan en una cuenta remota."
                )
            }
        return Label(
            presentation.title,
            systemImage: presentation.systemImage
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(presentation.color)
        .padding(.horizontal, TazkleSpacing.medium)
        .padding(.vertical, TazkleSpacing.small)
        .background(
            presentation.color.opacity(0.12)
        )
        .clipShape(Capsule())
        .accessibilityHint(presentation.hint)
    }
}

private struct AccountNotice: View {
    let title: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: TazkleSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(TazkleSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TazkleRadius.card)
                .stroke(color.opacity(0.28))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AccountFieldSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, TazkleSpacing.medium)
            .padding(.vertical, TazkleSpacing.small)
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
                        TazkleColors.separator(
                            for: colorScheme,
                            highContrast: highContrast
                        ),
                        lineWidth: highContrast ? 1.5 : 1
                    )
            }
    }
}

private extension View {
    func accountFieldSurface() -> some View {
        modifier(AccountFieldSurface())
    }
}

private struct SettingsValueRow: View {
    let title: String
    let detail: String
    let value: String
    let systemImage: String
    var valueColor: Color? = nil

    var body: some View {
        ProjectListRow {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
        } trailing: {
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(valueColor ?? .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileSettingsView: View {
    @EnvironmentObject private var authentication: AuthenticationController

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(
                title: authentication.user?.displayName ?? "Perfil local",
                systemImage: identitySystemImage
            ) {
                if let user = authentication.user {
                    SettingsValueRow(
                        title: "Identidad",
                        detail: "Obtenida del proveedor OIDC",
                        value: user.displayName,
                        systemImage: "person.crop.circle.badge.checkmark",
                        valueColor: TazkleColors.success
                    )
                    if let email = user.email {
                        SettingsValueRow(
                            title: "Correo",
                            detail: user.isEmailVerified
                                ? "Verificado por el proveedor"
                                : "Sin confirmación del proveedor",
                            value: email,
                            systemImage: "envelope"
                        )
                    }
                    SettingsValueRow(
                        title: "Organización y rol",
                        detail: "Se mostrarán al conectarse con Project Core",
                        value: "Sin datos",
                        systemImage: "building.2"
                    )
                } else {
                    Label(
                        localIdentityMessage,
                        systemImage: "internaldrive"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    Text("No se asignan nombre, correo, rol ni organización ficticios.")
                        .font(.callout.weight(.semibold))

                    if authentication.configuration != nil {
                        Button("Conectar cuenta") {
                            authentication.returnToSignIn()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            ProjectSectionCard(
                title: "Privacidad de la identidad",
                systemImage: "lock.shield"
            ) {
                Label(
                    "La contraseña permanece en el proveedor de identidad.",
                    systemImage: "checkmark.shield"
                )
                Label(
                    "El token de acceso sólo vive en memoria; la credencial de renovación se guarda en Keychain.",
                    systemImage: "key"
                )
                Text("Tazkle no persiste el correo del formulario de acceso en SQLite ni en preferencias.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var identitySystemImage: String {
        authentication.user == nil
            ? "person.crop.circle"
            : "person.crop.circle.badge.checkmark"
    }

    private var localIdentityMessage: String {
        switch authentication.state {
        case .offline:
            "La sesión validada está sin conexión; los cambios quedan pendientes de sincronización."
        default:
            "Todavía no existe una identidad conectada."
        }
    }
}

private struct ConnectedAccountDomainUnavailableView: View {
    let destinationID: String

    var body: some View {
        ProjectSectionCard(title: title, systemImage: systemImage) {
            Label(
                "Sin datos conectados",
                systemImage: "externaldrive.badge.questionmark"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(TazkleColors.relationship)

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Los datos de ejemplo se retiraron para que el prototipo no parezca contener información real.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 760)
    }

    private var title: String {
        switch destinationID {
        case "settings.availability": "Disponibilidad pendiente"
        case "settings.members": "Directorio pendiente"
        case "settings.permissions": "Permisos pendientes"
        default: "Organización pendiente"
        }
    }

    private var systemImage: String {
        switch destinationID {
        case "settings.availability": "calendar.badge.clock"
        case "settings.members": "person.2.slash"
        case "settings.permissions": "lock.badge.clock"
        default: "building.2"
        }
    }

    private var detail: String {
        switch destinationID {
        case "settings.availability":
            "La capacidad y los compromisos aparecerán cuando exista una identidad y una organización sincronizadas."
        case "settings.members":
            "Los miembros se obtendrán de Project Core; no se mostrarán personas de demostración."
        case "settings.permissions":
            "Los permisos efectivos dependerán de roles reales y de autorización del servidor."
        default:
            "Crea o conecta una organización para definir propiedad, responsables y políticas."
        }
    }
}

private struct AvailabilitySettingsView: View {
    @State private var weeklyCapacity = 40.0
    @State private var workingDays = Set(["Lunes", "Martes", "Miércoles", "Jueves", "Viernes"])
    @State private var focusTime = true

    private let days = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            LazyVGrid(columns: ProjectGridLayout.equalColumns(3), spacing: TazkleSpacing.medium) {
                ProjectMetricCard(title: "Capacidad semanal", value: "\(Int(weeklyCapacity)) h", detail: "Disponible entre proyectos", systemImage: "clock", accent: TazkleColors.actionPrimary)
                ProjectMetricCard(title: "Compromiso actual", value: "32 h", detail: "80% de la capacidad", systemImage: "chart.bar.fill", accent: TazkleColors.success)
                ProjectMetricCard(title: "Capacidad libre", value: "\(max(0, Int(weeklyCapacity) - 32)) h", detail: "Antes de una nueva asignación", systemImage: "plus.circle", accent: TazkleColors.relationship)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Semana laboral", systemImage: "calendar") {
                        Stepper("Capacidad: \(Int(weeklyCapacity)) horas", value: $weeklyCapacity, in: 8...60, step: 4)
                        ForEach(days, id: \.self) { day in
                            Toggle(
                                day,
                                isOn: Binding(
                                    get: { workingDays.contains(day) },
                                    set: { enabled in
                                        if enabled {
                                            workingDays.insert(day)
                                        } else {
                                            workingDays.remove(day)
                                        }
                                    }
                                )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    ProjectSectionCard(title: "Reglas de asignación", systemImage: "person.badge.clock") {
                        Toggle("Reservar bloques de concentración", isOn: $focusTime)
                        Toggle("Advertir antes de superar 90%", isOn: .constant(true))
                            .disabled(true)
                        SettingsValueRow(title: "Proyecto web", detail: "Compromiso principal", value: "20 h", systemImage: "macwindow")
                        SettingsValueRow(title: "Portal interno", detail: "Soporte compartido", value: "12 h", systemImage: "briefcase")
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    Text("Edita la capacidad y los días laborables en esta pantalla.")
                    ProjectSectionCard(title: "Semana laboral", systemImage: "calendar") {
                        Stepper("Capacidad: \(Int(weeklyCapacity)) horas", value: $weeklyCapacity, in: 8...60, step: 4)
                        ForEach(days, id: \.self) { day in
                            Toggle(day, isOn: Binding(
                                get: { workingDays.contains(day) },
                                set: { enabled in
                                    if enabled {
                                        workingDays.insert(day)
                                    } else {
                                        workingDays.remove(day)
                                    }
                                }
                            ))
                        }
                    }
                    ProjectSectionCard(title: "Reglas de asignación", systemImage: "person.badge.clock") {
                        Toggle("Reservar bloques de concentración", isOn: $focusTime)
                        SettingsValueRow(title: "Compromiso actual", detail: "Dos proyectos", value: "32 h", systemImage: "briefcase")
                    }
                }
            }

            AccountNotice(
                title: "No se aplicará una sobreasignación en silencio",
                detail: "Cuando exista sincronización, una asignación que exceda la capacidad requerirá corrección o una excepción documentada.",
                systemImage: "exclamationmark.triangle.fill",
                color: TazkleColors.warning
            )
        }
    }
}

private struct NotificationSettingsView: View {
    @AppStorage("notifyAssignments") private var assignments = true
    @AppStorage("notifyApprovals") private var approvals = true
    @AppStorage("notifyRisks") private var risks = true
    @AppStorage("notifySyncConflicts") private var conflicts = true
    @AppStorage("notifyDailyDigest") private var digest = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(title: "Notificaciones de proyecto", systemImage: "bell.badge") {
                Toggle("Asignaciones y menciones", isOn: $assignments)
                Toggle("Solicitudes de aprobación", isOn: $approvals)
                Toggle("Riesgos y condiciones críticas", isOn: $risks)
                Toggle("Conflictos de sincronización", isOn: $conflicts)
            }

            ProjectSectionCard(title: "Resumen", systemImage: "tray.full") {
                Toggle("Resumen diario", isOn: $digest)
                Text("Los eventos críticos conservan un indicador dentro de la aplicación aunque desactives avisos del sistema.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            AccountNotice(
                title: "El estado nunca depende solo de una notificación",
                detail: "Aprobaciones, conflictos, riesgos y trabajo sin sincronizar también aparecen como texto e icono en su contexto.",
                systemImage: "checkmark.shield.fill",
                color: TazkleColors.success
            )
        }
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage("appearancePreference") private var appearance = AppearancePreference.automatic.rawValue
    @AppStorage("tazkiAnimationsEnabled") private var animations = true
    @AppStorage("interfaceSoundsEnabled") private var sounds = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(title: "Tema", systemImage: "circle.lefthalf.filled") {
                Picker("Tema", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: TazkleSpacing.small) {
                    ForEach([
                        TazkleColors.actionPrimary,
                        TazkleColors.relationship,
                        TazkleColors.assistantProposal,
                        TazkleColors.warning,
                        TazkleColors.success,
                    ], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                    }
                    Text("La paleta conserva su significado en claro, oscuro y mayor contraste.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Movimiento y sonido", systemImage: "waveform") {
                        Toggle("Animaciones de Tazki", isOn: $animations)
                        Toggle("Sonidos de interfaz", isOn: $sounds)
                        Text("El audio es opcional y nunca es el único canal de estado.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    ProjectSectionCard(title: "Preferencias de macOS", systemImage: "accessibility") {
                        SettingsValueRow(title: "Reducir movimiento", detail: "Leído desde el sistema", value: reduceMotion ? "Activo" : "Inactivo", systemImage: "figure.walk.motion")
                        SettingsValueRow(title: "Reducir transparencias", detail: "Leído desde el sistema", value: reduceTransparency ? "Activo" : "Inactivo", systemImage: "circle.dotted")
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Movimiento y sonido", systemImage: "waveform") {
                        Toggle("Animaciones de Tazki", isOn: $animations)
                        Toggle("Sonidos de interfaz", isOn: $sounds)
                    }
                    ProjectSectionCard(title: "Preferencias de macOS", systemImage: "accessibility") {
                        SettingsValueRow(title: "Reducir movimiento", detail: "Leído desde el sistema", value: reduceMotion ? "Activo" : "Inactivo", systemImage: "figure.walk.motion")
                    }
                }
            }
        }
    }
}

private struct KeyboardSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var search = ""

    private var matchingShortcuts: [AccountPrototype.Shortcut] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return AccountPrototype.shortcuts }
        return AccountPrototype.shortcuts.filter {
            $0.action.localizedCaseInsensitiveContains(query)
                || $0.context.localizedCaseInsensitiveContains(query)
                || $0.keys.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(title: "Referencia de comandos", systemImage: "command") {
                TextField("Buscar comando o contexto", text: $search)
                    .accountFieldSurface()
                    .accessibilityLabel("Buscar atajo de teclado")

                ForEach(matchingShortcuts) { shortcut in
                    ProjectListRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortcut.action)
                                .font(.callout.weight(.medium))
                            Text(shortcut.context)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } trailing: {
                        Text(shortcut.keys)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .padding(.horizontal, TazkleSpacing.small)
                            .padding(.vertical, TazkleSpacing.xSmall)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: TazkleRadius.control))
                    }
                }

                if matchingShortcuts.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }

            HStack {
                Text("La primera versión usa atajos predeterminados para evitar conflictos con macOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Abrir referencia rápida") {
                    appState.isPresentingShortcuts = true
                }
            }
        }
    }
}

private struct OrganizationSettingsView: View {
    @State private var name = "Tazkle Studio"
    @State private var identifier = "tazkle-studio"
    @State private var description = "Equipo de producto y tecnología"
    @State private var currency = "MXN — Peso mexicano"
    @State private var timeZone = "GMT−6 Chihuahua"
    @State private var baseTemplate = "Aplicación web"
    @State private var mandatoryPhases = true
    @State private var feasibilityApproval = true
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    organizationCard
                    statusCard
                }
                VStack(spacing: TazkleSpacing.medium) {
                    organizationCard
                    statusCard
                }
            }

            ProjectSectionCard(title: "Valores predeterminados", systemImage: "slider.horizontal.3") {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TazkleSpacing.large) {
                        Picker("Moneda", selection: $currency) {
                            Text("MXN — Peso mexicano").tag("MXN — Peso mexicano")
                            Text("USD — Dólar estadounidense").tag("USD — Dólar estadounidense")
                        }
                        Picker("Zona horaria", selection: $timeZone) {
                            Text("GMT−6 Chihuahua").tag("GMT−6 Chihuahua")
                            Text("GMT−6 Ciudad de México").tag("GMT−6 Ciudad de México")
                        }
                        Picker("Plantilla base", selection: $baseTemplate) {
                            Text("Aplicación web").tag("Aplicación web")
                        }
                    }
                    VStack(alignment: .leading, spacing: TazkleSpacing.medium) {
                        Picker("Moneda", selection: $currency) {
                            Text("MXN — Peso mexicano").tag("MXN — Peso mexicano")
                        }
                        Picker("Zona horaria", selection: $timeZone) {
                            Text("GMT−6 Chihuahua").tag("GMT−6 Chihuahua")
                        }
                        Picker("Plantilla base", selection: $baseTemplate) {
                            Text("Aplicación web").tag("Aplicación web")
                        }
                    }
                }
                Toggle("Crear fases obligatorias de la plantilla", isOn: $mandatoryPhases)
                Toggle("Solicitar aprobación de factibilidad", isOn: $feasibilityApproval)
            }

            HStack {
                if saved {
                    Label("Cambios preparados; no se enviaron a un servidor", systemImage: "internaldrive")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TazkleColors.success)
                }
                Spacer()
                Button("Guardar borrador") { saved = true }
                    .buttonStyle(.borderedProminent)
                    .tint(TazkleColors.relationship)
            }
        }
    }

    private var organizationCard: some View {
        ProjectSectionCard(title: "Identidad del espacio", systemImage: "building.2") {
            HStack(spacing: TazkleSpacing.large) {
                ZStack {
                    Circle().fill(TazkleColors.relationship.opacity(0.2))
                    Text("TS")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(TazkleColors.relationship)
                }
                .frame(width: 68, height: 68)
                VStack(alignment: .leading) {
                    TextField("Nombre del espacio", text: $name)
                        .accountFieldSurface()
                    TextField("Identificador", text: $identifier)
                        .accountFieldSurface()
                }
            }
            TextField("Descripción", text: $description)
                .accountFieldSurface()
            SettingsValueRow(
                title: "Propiedad",
                detail: "Un único propietario; organizaciones externas colaboran por invitación",
                value: "Tazkle Studio",
                systemImage: "building.2.crop.circle"
            )
            SettingsValueRow(
                title: "Responsable final",
                detail: "Resuelve aprobaciones cuando la política lo permite",
                value: "Sin datos conectados",
                systemImage: "person.badge.key"
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var statusCard: some View {
        ProjectSectionCard(title: "Estado y administración", systemImage: "checkmark.shield") {
            SettingsValueRow(title: "Plan", detail: "Escenario conceptual", value: "Equipo", systemImage: "crown")
            SettingsValueRow(title: "Miembros", detail: "Incluye una invitación", value: "6", systemImage: "person.3")
            SettingsValueRow(title: "Proyectos activos", detail: "Un propietario por proyecto", value: "3", systemImage: "folder")
            SettingsValueRow(title: "Responsable", detail: "Puede transferirse con aprobación", value: "Sin datos conectados", systemImage: "person.badge.key")
        }
        .frame(maxWidth: 420, alignment: .top)
    }
}

private struct MembersSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authentication: AuthenticationController
    @State private var search = ""

    private var members: [OrganizationMember] {
        guard !search.isEmpty else { return appState.teamMembers }
        return appState.teamMembers.filter {
            ($0.displayName ?? "").localizedCaseInsensitiveContains(search)
                || $0.role.displayName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            switch appState.teamLoadState {
            case .idle, .loading:
                AccountNotice(
                    title: "Cargando miembros",
                    detail: "Consultando la organización real desde Project Core.",
                    systemImage: "arrow.triangle.2.circlepath",
                    color: TazkleColors.relationship
                )
            case .offline:
                AccountNotice(
                    title: "Sin conexión",
                    detail: "El directorio se actualizará automáticamente al recuperar conexión.",
                    systemImage: "wifi.slash",
                    color: TazkleColors.warning
                )
            case let .error(message):
                AccountNotice(
                    title: "No fue posible cargar el directorio",
                    detail: message,
                    systemImage: "exclamationmark.triangle.fill",
                    color: TazkleColors.warning
                )
            case .loaded:
                ProjectMetricCard(
                    title: "Miembros",
                    value: "\(appState.teamMembers.count)",
                    detail: "Acceso activo en tu organización",
                    systemImage: "person.3.fill",
                    accent: TazkleColors.relationship
                )
                .frame(maxWidth: 320)
            }

            ProjectSectionCard(title: "Directorio", systemImage: "person.3") {
                TextField("Buscar persona o rol", text: $search)
                    .accountFieldSurface()

                Label(
                    "Invitar personas todavía no está conectado a Project Core.",
                    systemImage: "envelope.badge.shield.half.filled"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                if appState.teamLoadState == .loaded, members.isEmpty {
                    Text(
                        search.isEmpty
                            ? "Todavía no hay miembros en tu organización."
                            : "Ninguna persona coincide con “\(search)”."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                ForEach(members) { member in
                    ProjectListRow {
                        HStack(spacing: TazkleSpacing.medium) {
                            ZStack {
                                Circle().fill(TazkleColors.relationship.opacity(0.18))
                                Text(initials(for: member))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(TazkleColors.relationship)
                            }
                            .frame(width: 34, height: 34)
                            Text(member.displayName ?? "Sin nombre")
                                .font(.callout.weight(.semibold))
                        }
                    } trailing: {
                        HStack(spacing: TazkleSpacing.medium) {
                            Text(member.role.displayName)
                                .font(.callout)
                            ProjectStatusPill(
                                title: member.status.displayName,
                                systemImage: member.status == .active ? "checkmark.circle.fill" : "clock.fill",
                                color: member.status == .active ? TazkleColors.success : TazkleColors.warning
                            )
                        }
                    }
                }
            }
        }
        .task {
            guard appState.teamLoadState == .idle else { return }
            await appState.loadTeamMembers(using: authentication)
        }
    }

    private func initials(for member: OrganizationMember) -> String {
        let name = member.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return "?" }
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

private struct PermissionsSettingsView: View {
    @State private var selectedRole = "Responsable del proyecto"

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            AccountNotice(
                title: "La vista no concede autoridad",
                detail: "Esta matriz documenta la intención del producto. Project Core deberá resolver organización, proyecto, objeto, acción y propiedades en cada petición.",
                systemImage: "lock.shield.fill",
                color: TazkleColors.relationship
            )

            ProjectSectionCard(title: "Matriz por responsabilidad", systemImage: "rectangle.grid.3x2") {
                Picker("Rol", selection: $selectedRole) {
                    ForEach(AccountPrototype.permissionRows.map(\.role), id: \.self) { role in
                        Text(role).tag(role)
                    }
                }
                .frame(maxWidth: 360)

                if let row = AccountPrototype.permissionRows.first(where: { $0.role == selectedRole }) {
                    ForEach(row.permissions) { permission in
                        ProjectListRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(permission.area)
                                    .font(.callout.weight(.medium))
                                Text(permission.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } trailing: {
                            ProjectStatusPill(
                                title: permission.level,
                                systemImage: permission.systemImage,
                                color: permission.color
                            )
                        }
                    }
                }
            }

            ProjectSectionCard(title: "Separación de información sensible", systemImage: "eye.slash") {
                SettingsValueRow(title: "Costos internos", detail: "Dirección, finanzas y responsables autorizados", value: "Restringido", systemImage: "banknote", valueColor: TazkleColors.warning)
                SettingsValueRow(title: "Precio al cliente", detail: "Puede compartirse sin exponer tarifas internas", value: "Separado", systemImage: "tag", valueColor: TazkleColors.success)
                SettingsValueRow(title: "Roles del cliente", detail: "Son indicativos hasta validación del servidor", value: "Sin autoridad", systemImage: "person.text.rectangle", valueColor: TazkleColors.warning)
            }
        }
    }
}

private struct TemplateSettingsView: View {
    @State private var selectedTemplate = "Aplicación web"
    @State private var mandatoryPhases = true
    @State private var strictContradictions = true
    @State private var warningRelations = true

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            ProjectSectionCard(title: "Plantilla inicial", systemImage: "doc.on.doc") {
                Picker("Plantilla", selection: $selectedTemplate) {
                    Text("Aplicación web").tag("Aplicación web")
                }
                .pickerStyle(.segmented)

                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    Image(systemName: "macwindow")
                        .font(.largeTitle)
                        .foregroundStyle(TazkleColors.actionPrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aplicación web")
                            .font(.title3.weight(.semibold))
                        Text("Idea, factibilidad, preproducción, diseño, desarrollo, pruebas, producción y seguimiento.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Reglas de estructura", systemImage: "point.3.connected.trianglepath.dotted") {
                        Toggle("Conservar fases obligatorias", isOn: $mandatoryPhases)
                        Toggle("Bloquear contradicciones graves", isOn: $strictContradictions)
                        Toggle("Advertir relaciones discutibles", isOn: $warningRelations)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    ProjectSectionCard(title: "Catálogo inicial", systemImage: "square.grid.2x2") {
                        SettingsValueRow(title: "Familias de bloques", detail: "Estrategia, producto, proceso, tecnología, personas, economía y gobierno", value: "7", systemImage: "square.stack.3d.up")
                        SettingsValueRow(title: "Tipos personalizados", detail: "Fuera de la primera versión", value: "No disponible", systemImage: "hammer", valueColor: TazkleColors.warning)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Reglas de estructura", systemImage: "point.3.connected.trianglepath.dotted") {
                        Toggle("Conservar fases obligatorias", isOn: $mandatoryPhases)
                        Toggle("Bloquear contradicciones graves", isOn: $strictContradictions)
                        Toggle("Advertir relaciones discutibles", isOn: $warningRelations)
                    }
                    ProjectSectionCard(title: "Catálogo inicial", systemImage: "square.grid.2x2") {
                        SettingsValueRow(title: "Familias de bloques", detail: "Catálogo de la plantilla web", value: "7", systemImage: "square.stack.3d.up")
                    }
                }
            }
        }
    }
}

private struct RoleRatesSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authentication: AuthenticationController

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            switch appState.roleRatesLoadState {
            case .idle, .loading:
                AccountNotice(
                    title: "Cargando tarifas",
                    detail: "Consultando la organización real desde Project Core.",
                    systemImage: "arrow.triangle.2.circlepath",
                    color: TazkleColors.relationship
                )
            case .offline:
                AccountNotice(
                    title: "Sin conexión",
                    detail: "Las tarifas se actualizarán automáticamente al recuperar conexión.",
                    systemImage: "wifi.slash",
                    color: TazkleColors.warning
                )
            case let .error(message):
                AccountNotice(
                    title: "No fue posible cargar las tarifas",
                    detail: message,
                    systemImage: "exclamationmark.triangle.fill",
                    color: TazkleColors.warning
                )
            case .loaded:
                ProjectMetricCard(
                    title: "Tarifas capturadas",
                    value: "\(appState.roleRates.count)",
                    detail: "De \(OrganizationRole.allCases.count) roles posibles",
                    systemImage: "banknote",
                    accent: TazkleColors.warning
                )
                .frame(maxWidth: 320)
            }

            ProjectSectionCard(title: "Tarifas por rol", systemImage: "person.2") {
                Text("Tarifa interna en MXN por hora, capturada a mano por un administrador. No es visible para el cliente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if appState.currentOrganizationID == nil, appState.roleRatesLoadState == .loaded {
                    Text("Todavía no se pudo determinar tu organización; agrega primero un miembro del equipo desde Miembros y roles.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                ForEach(OrganizationRole.allCases) { role in
                    RoleRateRow(role: role)
                }

                if case let .error(message) = appState.roleRateSaveState {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TazkleColors.warning)
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .task {
            guard appState.roleRatesLoadState == .idle else { return }
            await appState.loadRoleRates(using: authentication)
        }
    }
}

private struct RoleRateRow: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authentication: AuthenticationController
    let role: OrganizationRole

    @State private var draftValue = ""
    @FocusState private var isFocused: Bool

    private var savedRate: RoleRate? {
        appState.roleRates.first { $0.role == role }
    }

    private var isSaving: Bool {
        appState.roleRateSaveState == .saving
    }

    private var hasChange: Bool {
        guard let value = Int(draftValue), value >= 0 else { return false }
        return value != savedRate?.hourlyRateMXN
    }

    var body: some View {
        ProjectListRow {
            Text(role.displayName)
                .font(.callout.weight(.medium))
        } trailing: {
            HStack(spacing: TazkleSpacing.small) {
                TextField("Sin definir", text: $draftValue)
                    .accountFieldSurface()
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .onSubmit { Task { await save() } }
                    .accessibilityLabel("Tarifa de \(role.displayName) en MXN por hora")
                Text("MXN/h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Guardar") { Task { await save() } }
                    .disabled(isSaving || !hasChange || appState.currentOrganizationID == nil)
            }
        }
        .onAppear { syncDraft() }
        .onChange(of: savedRate) { _, _ in
            if !isFocused { syncDraft() }
        }
    }

    private func syncDraft() {
        draftValue = savedRate.map { String($0.hourlyRateMXN) } ?? ""
    }

    private func save() async {
        guard let value = Int(draftValue), value >= 0 else { return }
        await appState.saveRoleRate(role: role, hourlyRateMXN: value, using: authentication)
    }
}

private struct AISettingsView: View {
    @State private var provider = "Sin proveedor conectado"
    @State private var privacyMode = "Contexto mínimo"
    @State private var humanApproval = true
    @State private var redactCosts = true
    @State private var allowExternalLinks = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            AccountNotice(
                title: "Tazki no tiene autoridad directa",
                detail: "Las propuestas de alcance, arquitectura, costo o acciones externas requieren esquema estricto, validación determinista y revisión humana.",
                systemImage: "sparkles.rectangle.stack",
                color: TazkleColors.assistantProposal
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Proveedor", systemImage: "network") {
                        Picker("Ruta de IA", selection: $provider) {
                            Text("Sin proveedor conectado").tag("Sin proveedor conectado")
                            Text("OmniRoute — candidato por evaluar").tag("OmniRoute — candidato por evaluar")
                            Text("Proveedor propio — futuro").tag("Proveedor propio — futuro")
                        }
                        Text("Las claves vivirán en el almacén de secretos del servicio, nunca en la aplicación macOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    ProjectSectionCard(title: "Privacidad", systemImage: "hand.raised") {
                        Picker("Contexto enviado", selection: $privacyMode) {
                            Text("Contexto mínimo").tag("Contexto mínimo")
                            Text("Proyecto completo con aprobación").tag("Proyecto completo con aprobación")
                        }
                        Toggle("Redactar costos y datos personales", isOn: $redactCosts)
                        Toggle("Permitir enlaces externos", isOn: $allowExternalLinks)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Proveedor", systemImage: "network") {
                        Picker("Ruta de IA", selection: $provider) {
                            Text("Sin proveedor conectado").tag("Sin proveedor conectado")
                            Text("OmniRoute — candidato por evaluar").tag("OmniRoute — candidato por evaluar")
                        }
                    }
                    ProjectSectionCard(title: "Privacidad", systemImage: "hand.raised") {
                        Picker("Contexto enviado", selection: $privacyMode) {
                            Text("Contexto mínimo").tag("Contexto mínimo")
                        }
                        Toggle("Redactar datos sensibles", isOn: $redactCosts)
                    }
                }
            }

            ProjectSectionCard(title: "Límites de operación", systemImage: "shield.lefthalf.filled") {
                Toggle("Exigir aprobación humana para cambios materiales", isOn: $humanApproval)
                    .disabled(true)
                SettingsValueRow(title: "Acceso a base de datos", detail: "El modelo no escribe directamente", value: "Denegado", systemImage: "cylinder.split.1x2", valueColor: TazkleColors.success)
                SettingsValueRow(title: "Secretos en prompts", detail: "Regla permanente", value: "Prohibido", systemImage: "key.slash", valueColor: TazkleColors.success)
                SettingsValueRow(title: "Respuesta del proveedor", detail: "Se trata como entrada no confiable", value: "Validada", systemImage: "checkmark.shield", valueColor: TazkleColors.success)
            }
        }
    }
}

private struct SyncSettingsView: View {
    @State private var automaticSync = true
    @State private var meteredNetworks = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            LazyVGrid(columns: ProjectGridLayout.equalColumns(3), spacing: TazkleSpacing.medium) {
                ProjectMetricCard(title: "Estado local", value: "Guardado", detail: "SQLite en esta Mac", systemImage: "internaldrive.fill", accent: TazkleColors.success)
                ProjectMetricCard(title: "Nube", value: "No conectada", detail: "Neon y PowerSync son arquitectura prevista", systemImage: "icloud.slash", accent: TazkleColors.warning)
                ProjectMetricCard(title: "Conflictos", value: "0", detail: "No existe sesión remota", systemImage: "arrow.triangle.branch", accent: TazkleColors.relationship)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Comportamiento", systemImage: "arrow.triangle.2.circlepath") {
                        Toggle("Sincronizar automáticamente al recuperar conexión", isOn: $automaticSync)
                        Toggle("Sincronizar en redes de uso medido", isOn: $meteredNetworks)
                        Text("Estos controles son un prototipo; todavía no inician tráfico de red.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    ProjectSectionCard(title: "Estados visibles", systemImage: "list.bullet.rectangle") {
                        ForEach(AccountPrototype.syncStates, id: \.title) { state in
                            SettingsValueRow(title: state.title, detail: state.detail, value: state.value, systemImage: state.icon, valueColor: state.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Comportamiento", systemImage: "arrow.triangle.2.circlepath") {
                        Toggle("Sincronizar al recuperar conexión", isOn: $automaticSync)
                        Text("Prototipo: no inicia tráfico de red.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProjectSectionCard(title: "Estado actual", systemImage: "internaldrive") {
                        SettingsValueRow(title: "Guardado localmente", detail: "SQLite", value: "Disponible", systemImage: "checkmark.circle", valueColor: TazkleColors.success)
                    }
                }
            }

            AccountNotice(
                title: "Los conflictos materiales requieren una decisión",
                detail: "Alcance, costos, arquitectura y aprobaciones nunca se fusionarán silenciosamente. PowerSync no sustituirá la autorización de Project Core.",
                systemImage: "arrow.triangle.branch",
                color: TazkleColors.relationship
            )
        }
    }
}

private struct SecuritySettingsView: View {
    @EnvironmentObject private var authentication: AuthenticationController
    @EnvironmentObject private var appState: AppState
    @State private var isConfirmingAccountDeletion = false

    var body: some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
            AccountNotice(
                title: noticeTitle,
                detail: noticeDetail,
                systemImage: noticeSystemImage,
                color: noticeColor
            )

            LazyVGrid(columns: ProjectGridLayout.equalColumns(3), spacing: TazkleSpacing.medium) {
                ProjectMetricCard(title: "Acceso", value: accessValue, detail: accessDetail, systemImage: "person.badge.key", accent: accessAccent)
                ProjectMetricCard(title: "Credencial", value: credentialValue, detail: credentialDetail, systemImage: "key.horizontal", accent: TazkleColors.actionPrimary)
                ProjectMetricCard(title: "Auditoría", value: "Servidor", detail: "Project Core registra operaciones remotas", systemImage: "checkmark.shield", accent: TazkleColors.relationship)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Autenticación", systemImage: "person.badge.key") {
                        SettingsValueRow(title: "Contraseña", detail: "Gestionada por el proveedor de identidad", value: "Fuera de Tazkle", systemImage: "key", valueColor: TazkleColors.success)
                        SettingsValueRow(title: "Segundo factor", detail: "Aplicado por las políticas del proveedor", value: "Según política", systemImage: "lock.rotation", valueColor: TazkleColors.relationship)
                        SettingsValueRow(title: "Credencial macOS", detail: "Refresh token no sincronizable", value: credentialValue, systemImage: "key.horizontal", valueColor: accessAccent)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    ProjectSectionCard(title: "Sesión en esta Mac", systemImage: "desktopcomputer") {
                        SettingsValueRow(title: "Estado", detail: accessDetail, value: accessValue, systemImage: "desktopcomputer", valueColor: accessAccent)
                        if case .authenticated(let remoteSession) = authentication.state {
                            SettingsValueRow(
                                title: "Renovación",
                                detail: "El access token permanece únicamente en memoria",
                                value: remoteSession.expiresAt.formatted(date: .omitted, time: .shortened),
                                systemImage: "clock",
                                valueColor: TazkleColors.success
                            )
                        }
                        sessionAction
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                VStack(spacing: TazkleSpacing.medium) {
                    ProjectSectionCard(title: "Autenticación", systemImage: "person.badge.key") {
                        SettingsValueRow(title: "Proveedor OIDC", detail: "Authorization Code con PKCE S256", value: authentication.configuration == nil ? "Pendiente" : "Configurado", systemImage: "lock.rotation", valueColor: authentication.configuration == nil ? TazkleColors.warning : TazkleColors.success)
                    }
                    ProjectSectionCard(title: "Sesión local", systemImage: "desktopcomputer") {
                        SettingsValueRow(title: "Esta Mac", detail: accessDetail, value: accessValue, systemImage: "checkmark.circle", valueColor: accessAccent)
                        sessionAction
                    }
                }
            }

            ProjectSectionCard(title: "Auditoría y privacidad", systemImage: "doc.text.magnifyingglass") {
                SettingsValueRow(title: "Cambios de rol y permiso", detail: "Actor, organización, acción y resultado", value: "Evento requerido", systemImage: "person.2.badge.gearshape", valueColor: TazkleColors.relationship)
                SettingsValueRow(title: "Exportaciones sensibles", detail: "Se registran por referencia, no por copia de contenido", value: "Evento requerido", systemImage: "square.and.arrow.up", valueColor: TazkleColors.relationship)
                SettingsValueRow(title: "Secretos y prompts completos", detail: "Nunca deben aparecer en logs", value: "Excluidos", systemImage: "eye.slash", valueColor: TazkleColors.success)
            }

            ProjectSectionCard(
                title: "Zona de riesgo",
                systemImage: "exclamationmark.triangle"
            ) {
                Text(
                    "Eliminar la cuenta borra la identidad, revoca sus sesiones y elimina de esta Mac el espacio local asociado. No se puede deshacer."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if let failure = authentication.accountDeletionFailure {
                    Label(
                        failure.userMessage,
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.callout)
                    .foregroundStyle(TazkleColors.warning)
                    .accessibilityElement(children: .combine)
                }

                Button("Eliminar cuenta…", role: .destructive) {
                    isConfirmingAccountDeletion = true
                }
                .disabled(
                    authentication.isDeletingAccount
                        || !isAuthenticatedOnline
                )
                .accessibilityHint(
                    "Solicita nuevamente tus credenciales y el segundo factor antes de pedirte escribir ELIMINAR."
                )

                if authentication.state == .offline {
                    Text("Conéctate a internet para eliminar la cuenta.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "¿Eliminar permanentemente tu cuenta?",
            isPresented: $isConfirmingAccountDeletion,
            titleVisibility: .visible
        ) {
            Button("Continuar con la eliminación", role: .destructive) {
                Task {
                    await authentication.deleteAccount {
                        workspaceAccountID in
                        try appState.deleteWorkspace(
                            for: workspaceAccountID
                        )
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                "Identity te pedirá autenticar de nuevo la misma cuenta. Después deberás escribir ELIMINAR para confirmar."
            )
        }
    }

    private var isAuthenticatedOnline: Bool {
        if case .authenticated = authentication.state {
            return true
        }
        return false
    }

    @ViewBuilder
    private var sessionAction: some View {
        switch authentication.state {
        case .authenticated, .offline:
            Button("Cerrar sesión en esta Mac", role: .destructive) {
                Task { await authentication.signOut() }
            }
        default:
            Button("Volver al acceso") {
                authentication.returnToSignIn()
            }
        }
    }

    private var noticeTitle: String {
        switch authentication.state {
        case .authenticated: "Sesión remota protegida"
        case .offline: "Sesión conocida, conexión no disponible"
        default: "Identidad pendiente"
        }
    }

    private var noticeDetail: String {
        switch authentication.state {
        case .authenticated:
            "El navegador gestiona el acceso; Keychain conserva sólo la credencial de renovación y Project Core decide los permisos efectivos."
        case .offline:
            "Puedes consultar y editar el espacio de esta cuenta. Los cambios quedan pendientes hasta renovar la sesión al recuperar conexión."
        default:
            "Configura o inicia una sesión OIDC antes de abrir proyectos."
        }
    }

    private var noticeSystemImage: String {
        switch authentication.state {
        case .authenticated: "lock.shield.fill"
        case .offline: "wifi.slash"
        default: "person.badge.key"
        }
    }

    private var noticeColor: Color {
        switch authentication.state {
        case .authenticated: TazkleColors.success
        default: TazkleColors.warning
        }
    }

    private var accessValue: String {
        switch authentication.state {
        case .authenticated: "Conectado"
        case .offline: "Sin conexión"
        default: "Pendiente"
        }
    }

    private var accessDetail: String {
        switch authentication.state {
        case .authenticated: "Identidad remota disponible"
        case .offline: "Sesión validada; sincronización pausada"
        default: "Requiere inicio de sesión"
        }
    }

    private var credentialValue: String {
        switch authentication.state {
        case .authenticated, .offline: "Keychain"
        default: "Pendiente"
        }
    }

    private var credentialDetail: String {
        switch authentication.state {
        case .authenticated, .offline: "Refresh token ligado a esta Mac"
        default: "No se conserva una credencial remota"
        }
    }

    private var accessAccent: Color {
        switch authentication.state {
        case .authenticated: TazkleColors.success
        default: TazkleColors.warning
        }
    }
}

private enum AccountPrototype {
    struct Shortcut: Identifiable {
        let id = UUID()
        let action: String
        let context: String
        let keys: String
    }

    struct Permission: Identifiable {
        let id = UUID()
        let area: String
        let detail: String
        let level: String
        let systemImage: String
        let color: Color
    }

    struct PermissionRow {
        let role: String
        let permissions: [Permission]
    }

    struct SyncState {
        let title: String
        let detail: String
        let value: String
        let icon: String
        let color: Color
    }

    static let shortcuts = [
        Shortcut(action: "Paleta de comandos", context: "Global", keys: "⌘K"),
        Shortcut(action: "Buscar", context: "Listas y documentos", keys: "⌘F"),
        Shortcut(action: "Nuevo bloque", context: "Mapa y arquitectura", keys: "⌘N"),
        Shortcut(action: "Conectar bloques", context: "Mapa y arquitectura", keys: "⌘L"),
        Shortcut(action: "Duplicar", context: "Selección", keys: "⌘D"),
        Shortcut(action: "Eliminar selección", context: "Selección con confirmación", keys: "⌫"),
        Shortcut(action: "Deshacer", context: "Global", keys: "⌘Z"),
        Shortcut(action: "Rehacer", context: "Global", keys: "⇧⌘Z"),
        Shortcut(action: "Mostrar u ocultar sidebar", context: "Ventana", keys: "⌃⌘S"),
        Shortcut(action: "Mostrar inspector", context: "Mapa y arquitectura", keys: "⌥⌘I"),
        Shortcut(action: "Volver al origen", context: "Lienzo", keys: "⌘0"),
        Shortcut(action: "Ajustar mapa a ventana", context: "Lienzo", keys: "⇧⌘F"),
        Shortcut(action: "Referencia de atajos", context: "Global", keys: "⌘/"),
    ]

    static let permissionRows = [
        PermissionRow(role: "Responsable del proyecto", permissions: [
            Permission(area: "Proyecto y alcance", detail: "Edita propuestas y solicita aprobaciones.", level: "Administrar", systemImage: "checkmark.shield.fill", color: TazkleColors.success),
            Permission(area: "Arquitectura", detail: "Puede proponer y aprobar según la política.", level: "Administrar", systemImage: "checkmark.shield.fill", color: TazkleColors.success),
            Permission(area: "Costos internos", detail: "Visible si la organización lo autoriza.", level: "Condicionado", systemImage: "exclamationmark.triangle.fill", color: TazkleColors.warning),
            Permission(area: "Miembros", detail: "Invita; los cambios de rol se auditan.", level: "Administrar", systemImage: "checkmark.shield.fill", color: TazkleColors.success),
        ]),
        PermissionRow(role: "Responsable técnico", permissions: [
            Permission(area: "Arquitectura", detail: "Edita tecnologías y dependencias.", level: "Editar", systemImage: "pencil.circle.fill", color: TazkleColors.actionPrimary),
            Permission(area: "Factibilidad técnica", detail: "Emite revisión y evidencia.", level: "Revisar", systemImage: "checkmark.circle.fill", color: TazkleColors.success),
            Permission(area: "Costos internos", detail: "Solo costo técnico agregado.", level: "Lectura parcial", systemImage: "eye.fill", color: TazkleColors.relationship),
            Permission(area: "Miembros", detail: "No altera roles de organización.", level: "Sin acceso", systemImage: "lock.fill", color: TazkleColors.warning),
        ]),
        PermissionRow(role: "Finanzas", permissions: [
            Permission(area: "Tarifas internas", detail: "Edita valores autorizados.", level: "Administrar", systemImage: "checkmark.shield.fill", color: TazkleColors.success),
            Permission(area: "Precio al cliente", detail: "Prepara propuesta comercial.", level: "Administrar", systemImage: "checkmark.shield.fill", color: TazkleColors.success),
            Permission(area: "Arquitectura", detail: "Consulta impacto económico.", level: "Lectura", systemImage: "eye.fill", color: TazkleColors.relationship),
            Permission(area: "Miembros", detail: "Consulta rol y capacidad, no salarios.", level: "Lectura parcial", systemImage: "eye.fill", color: TazkleColors.relationship),
        ]),
        PermissionRow(role: "Cliente u observador", permissions: [
            Permission(area: "Alcance aprobado", detail: "Consulta versiones compartidas.", level: "Lectura", systemImage: "eye.fill", color: TazkleColors.relationship),
            Permission(area: "Solicitudes de cambio", detail: "Puede proponer nuevas implementaciones.", level: "Proponer", systemImage: "plus.bubble.fill", color: TazkleColors.actionPrimary),
            Permission(area: "Costos internos", detail: "Nunca se exponen.", level: "Sin acceso", systemImage: "lock.fill", color: TazkleColors.warning),
            Permission(area: "Precio aprobado", detail: "Visible cuando se comparte.", level: "Lectura", systemImage: "eye.fill", color: TazkleColors.relationship),
        ]),
    ]

    static let syncStates = [
        SyncState(title: "Guardado localmente", detail: "El cambio existe en SQLite", value: "Visible", icon: "internaldrive", color: TazkleColors.success),
        SyncState(title: "Sincronizando", detail: "Envío y validación pendientes", value: "Futuro", icon: "arrow.triangle.2.circlepath", color: TazkleColors.actionPrimary),
        SyncState(title: "Conflicto", detail: "Requiere decisión explícita", value: "Futuro", icon: "arrow.triangle.branch", color: TazkleColors.warning),
        SyncState(title: "Rechazado", detail: "Permiso o regla de negocio", value: "Futuro", icon: "xmark.shield", color: TazkleColors.warning),
    ]
}
