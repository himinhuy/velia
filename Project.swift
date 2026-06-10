import ProjectDescription

// Velia iOS app — project as code. See docs/architecture.md §2 for the module graph + dependency rules.
// Generate with: `tuist install && tuist generate`  (Tuist 4.x).
//
// Dependency direction (enforced by which targets list which):
//   Velia(app) → VeliaFeatures → {DesignSystem, Data, Security, Health} ; Data → Security ; Health → VeliaCore
//   VeliaCore (the pure engine) is a LOCAL SwiftPM package with NO dependencies.

private let iOS: DeploymentTargets = .iOS("17.0")
private let bundlePrefix = "app.velia"
// Development signing: automatic profile managed by Xcode for the Apple ID already added to Xcode
// (hi.minhuy@gmail.com → personal team "Giang Ngo"). This is a DEVELOPMENT team — Xcode provisions
// an "Apple Development" profile, never an App Store / distribution one. Override with the
// TUIST_DEVELOPMENT_TEAM env var if you sign with a different account.
private let developmentTeam = Environment.developmentTeam.getString(default: "42C434U7BU")

private func module(
    _ name: String,
    dependencies: [TargetDependency] = [],
    hasTests: Bool = true
) -> [Target] {
    var targets: [Target] = [
        .target(
            name: name,
            destinations: .iOS,
            product: .framework,
            bundleId: "\(bundlePrefix).\(name.lowercased())",
            deploymentTargets: iOS,
            sources: ["Modules/\(name)/Sources/**"],
            dependencies: dependencies
        ),
    ]
    if hasTests {
        targets.append(
            .target(
                name: "\(name)Tests",
                destinations: .iOS,
                product: .unitTests,
                bundleId: "\(bundlePrefix).\(name.lowercased()).tests",
                deploymentTargets: iOS,
                sources: ["Modules/\(name)/Tests/**"],
                dependencies: [.target(name: name)]
            )
        )
    }
    return targets
}

let project = Project(
    name: "Velia",
    packages: [
        .local(path: "VeliaCore"),
        // NOTE: GRDB/SQLCipher is intentionally NOT wired yet. Vanilla GRDB lacks `usePassphrase`
        // (needs a SQLCipher-enabled build), and the VeliaData/VeliaSecurity scaffolds are unverified.
        // They are excluded from the build graph so the app COMPILES & RUNS today on the engine + UI.
        // Re-add the package + the modules below once SQLCipher GRDB is configured (Phase 1 finish).
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        "SWIFT_STRICT_CONCURRENCY": "complete",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
        "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
        // Apply the dev team to every target so embedded frameworks sign with the same identity.
        "CODE_SIGN_STYLE": "Automatic",
        "DEVELOPMENT_TEAM": .string(developmentTeam),
    ]),
    targets: [
        .target(
            name: "Velia",
            destinations: .iOS,
            product: .app,
            bundleId: "\(bundlePrefix).ios",
            deploymentTargets: iOS,
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": ["UIColorName": "LaunchBackground"],
                "CFBundleDisplayName": "Velia",
                // Privacy usage strings (HealthKit read for temperature/HR — fertility signals).
                "NSHealthShareUsageDescription":
                    "Velia reads body temperature, heart rate and sleep from Health to improve cycle predictions. This data stays on your device.",
                "NSFaceIDUsageDescription":
                    "Velia uses Face ID to lock the app so only you can open it.",
            ]),
            sources: ["App/Sources/**"],
            dependencies: [.target(name: "VeliaFeatures")],
            settings: .settings(base: [
                // Device builds: automatic dev signing with the team resolved above.
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": .string(developmentTeam),
                "CODE_SIGN_IDENTITY": "Apple Development",
                // Release builds are fully standalone (no dev server) — native app embeds everything.
                "PRODUCT_BUNDLE_IDENTIFIER": "\(bundlePrefix).ios",
            ])
        ),
        .target(
            name: "VeliaUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "\(bundlePrefix).uitests",
            deploymentTargets: iOS,
            sources: ["App/UITests/**"],
            dependencies: [.target(name: "Velia")]
        ),
    ]
    // Buildable graph today: app → VeliaFeatures → (VeliaDesignSystem, VeliaCore).
    + module("VeliaFeatures", dependencies: [
        .target(name: "VeliaDesignSystem"),
        .package(product: "VeliaCore"),
    ])
    + module("VeliaDesignSystem")
    // Deferred (scaffolds present under Modules/, re-add once SQLCipher GRDB is configured):
    //   module("VeliaData", deps: [VeliaSecurity, VeliaCore, GRDB])
    //   module("VeliaSecurity")
    //   module("VeliaHealth", deps: [VeliaCore])
)
