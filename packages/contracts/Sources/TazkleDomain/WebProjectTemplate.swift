import Foundation

public protocol WebTechnologyOption: CaseIterable, Hashable, Identifiable, Sendable {
    var displayName: String { get }
    var summary: String { get }
}

public enum WebFrontend: String, Codable, WebTechnologyOption {
    case nextJS = "next-js"
    case reactVite = "react-vite"
    case nuxt
    case svelteKit = "svelte-kit"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .nextJS: "Next.js"
        case .reactVite: "React + Vite"
        case .nuxt: "Nuxt"
        case .svelteKit: "SvelteKit"
        }
    }

    public var summary: String {
        switch self {
        case .nextJS: "Aplicación React con renderizado híbrido."
        case .reactVite: "Cliente React desacoplado y ligero."
        case .nuxt: "Aplicación Vue con renderizado híbrido."
        case .svelteKit: "Interfaz Svelte orientada a rendimiento."
        }
    }
}

public enum BackendLanguage: String, Codable, WebTechnologyOption {
    case typescript
    case python
    case go

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .typescript: "TypeScript"
        case .python: "Python"
        case .go: "Go"
        }
    }

    public var summary: String {
        switch self {
        case .typescript: "Runtime Node.js con tipos compartidos."
        case .python: "Backend Python preparado para FastAPI."
        case .go: "Servicio compilado, concurrente y contenido."
        }
    }
}

public enum APIStyle: String, Codable, WebTechnologyOption {
    case rest
    case graphql
    case trpc

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .rest: "REST"
        case .graphql: "GraphQL"
        case .trpc: "tRPC"
        }
    }

    public var summary: String {
        switch self {
        case .rest: "Recursos y operaciones mediante HTTP."
        case .graphql: "Contrato tipado orientado a consultas."
        case .trpc: "Contrato TypeScript de extremo a extremo."
        }
    }
}

public enum AuthenticationProvider: String, Codable, WebTechnologyOption {
    case authJS = "auth-js"
    case keycloak
    case clerk

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .authJS: "Auth.js"
        case .keycloak: "Keycloak"
        case .clerk: "Clerk"
        }
    }

    public var summary: String {
        switch self {
        case .authJS: "Autenticación abierta integrada a la aplicación."
        case .keycloak: "Identidad autogestionada con roles y sesiones."
        case .clerk: "Identidad administrada con plan gratuito inicial."
        }
    }
}

public enum DatabaseTechnology: String, Codable, WebTechnologyOption {
    case postgresql
    case mysql
    case mongodb

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .postgresql: "PostgreSQL"
        case .mysql: "MySQL"
        case .mongodb: "MongoDB"
        }
    }

    public var summary: String {
        switch self {
        case .postgresql: "Datos relacionales y consultas avanzadas."
        case .mysql: "Persistencia relacional ampliamente soportada."
        case .mongodb: "Documentos flexibles y agregaciones."
        }
    }
}

public enum DeploymentTechnology: String, Codable, WebTechnologyOption {
    case docker
    case cloudflare
    case vercel

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .docker: "Docker"
        case .cloudflare: "Cloudflare"
        case .vercel: "Vercel"
        }
    }

    public var summary: String {
        switch self {
        case .docker: "Despliegue portable en contenedores."
        case .cloudflare: "Entrega perimetral y funciones distribuidas."
        case .vercel: "Despliegue administrado orientado al frontend."
        }
    }
}

public struct WebTechnologySelection: Codable, Equatable, Sendable {
    public var frontend: WebFrontend
    public var language: BackendLanguage
    public var api: APIStyle
    public var authentication: AuthenticationProvider
    public var database: DatabaseTechnology
    public var deployment: DeploymentTechnology

    public init(
        frontend: WebFrontend = .nextJS,
        language: BackendLanguage = .typescript,
        api: APIStyle = .rest,
        authentication: AuthenticationProvider = .authJS,
        database: DatabaseTechnology = .postgresql,
        deployment: DeploymentTechnology = .docker
    ) {
        self.frontend = frontend
        self.language = language
        self.api = api
        self.authentication = authentication
        self.database = database
        self.deployment = deployment
    }

    public static let defaultSelection = WebTechnologySelection()

    public var compatibilityWarnings: [String] {
        var warnings: [String] = []
        if api == .trpc, language != .typescript {
            warnings.append(
                "tRPC presupone TypeScript de extremo a extremo; el backend "
                    + "\(language.displayName) requiere un adaptador o un contrato alternativo."
            )
        }
        return warnings
    }
}

public enum WebProjectTemplateFactory {
    public static func make(
        name: String,
        technologies: WebTechnologySelection = .defaultSelection
    ) -> ProjectGraph {
        let hasCompatibilityWarnings = !technologies.compatibilityWarnings.isEmpty

        let frontend = ProjectBlock(
            title: "Frontend · \(technologies.frontend.displayName)",
            summary: technologies.frontend.summary,
            family: .technology,
            architectureLayer: .experience,
            position: BlockPosition(x: 180, y: 180)
        )
        let api = ProjectBlock(
            title: "API · \(technologies.api.displayName)",
            summary: technologies.api.summary,
            family: .technology,
            state: hasCompatibilityWarnings ? .warning : .draft,
            architectureLayer: .services,
            position: BlockPosition(x: 500, y: 150)
        )
        let authentication = ProjectBlock(
            title: "Autenticación · \(technologies.authentication.displayName)",
            summary: technologies.authentication.summary,
            family: .technology,
            architectureLayer: .services,
            position: BlockPosition(x: 500, y: 410)
        )
        let backend = ProjectBlock(
            title: "Backend · \(technologies.language.displayName)",
            summary: technologies.language.summary,
            family: .technology,
            architectureLayer: .services,
            position: BlockPosition(x: 820, y: 180)
        )
        let database = ProjectBlock(
            title: "Base de datos · \(technologies.database.displayName)",
            summary: technologies.database.summary,
            family: .technology,
            architectureLayer: .data,
            position: BlockPosition(x: 1_120, y: 220)
        )
        let infrastructure = ProjectBlock(
            title: "Infraestructura · \(technologies.deployment.displayName)",
            summary: technologies.deployment.summary,
            family: .technology,
            architectureLayer: .infrastructure,
            position: BlockPosition(x: 820, y: 480)
        )

        return ProjectGraph(
            name: name,
            blocks: [frontend, api, authentication, backend, database, infrastructure],
            relations: [
                BlockRelation(
                    sourceID: frontend.id,
                    targetID: api.id,
                    sourcePort: .right,
                    targetPort: .left,
                    type: .requires
                ),
                BlockRelation(
                    sourceID: frontend.id,
                    targetID: authentication.id,
                    sourcePort: .bottom,
                    targetPort: .left,
                    type: .requires
                ),
                BlockRelation(
                    sourceID: api.id,
                    targetID: backend.id,
                    sourcePort: .right,
                    targetPort: .left,
                    type: .dependsOn,
                    isCritical: hasCompatibilityWarnings
                ),
                BlockRelation(
                    sourceID: authentication.id,
                    targetID: backend.id,
                    sourcePort: .right,
                    targetPort: .bottom,
                    type: .validates
                ),
                BlockRelation(
                    sourceID: backend.id,
                    targetID: database.id,
                    sourcePort: .right,
                    targetPort: .left,
                    type: .requires
                ),
                BlockRelation(
                    sourceID: backend.id,
                    targetID: infrastructure.id,
                    sourcePort: .bottom,
                    targetPort: .top,
                    type: .dependsOn
                ),
                BlockRelation(
                    sourceID: database.id,
                    targetID: infrastructure.id,
                    sourcePort: .bottom,
                    targetPort: .right,
                    type: .dependsOn
                ),
            ]
        )
    }
}
