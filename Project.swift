import ProjectDescription

// Velia iOS app — project as code. See docs/architecture.md §2 for the module graph + dependency rules.
// Generate with: `tuist install && tuist generate`  (Tuist 4.x).
//
// Dependency direction (enforced by which targets list which):
//   Velia(app) → VeliaFeatures → {DesignSystem, Data, Security, Health} ; Data → Security ; Health → VeliaCore
//   VeliaCore (the pure engine) is a LOCAL SwiftPM package with NO dependencies.

private let iOS: DeploymentTargets = .iOS("17.0")
private let bundlePrefix = "app.velia"
/// Development signing: automatic profile managed by Xcode for the Apple ID already added to Xcode
/// (hi.minhuy@gmail.com → personal team "Giang Ngo"). This is a DEVELOPMENT team — Xcode provisions
/// an "Apple Development" profile, never an App Store / distribution one. Override with the
/// TUIST_DEVELOPMENT_TEAM env var if you sign with a different account.
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
        )
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
        .local(path: "VeliaCore")
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
        "DEVELOPMENT_TEAM": .string(developmentTeam)
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
                "NSFaceIDUsageDescription":
                    "Velia uses Face ID to lock the app so only you can open it.",
                // Only standard crypto (CryptoKit/CommonCrypto) for local data protection → exempt.
                // Declaring this skips the export-compliance prompt on every upload.
                "ITSAppUsesNonExemptEncryption": false,
                // Discretion suite: a neutral alternate icon switchable at runtime. The primary icon
                // is the asset-catalog AppIcon; the alternate is loose PNGs (AltNeutral@2x/@3x).
                "CFBundleIcons": [
                    "CFBundleAlternateIcons": [
                        "Neutral": [
                            "CFBundleIconFiles": ["AltNeutral"],
                            "UIPrerenderedIcon": false
                        ]
                    ]
                ]
            ]),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            entitlements: .dictionary([
                "com.apple.developer.applesignin": ["Default"]
            ]),
            dependencies: [.target(name: "VeliaFeatures")],
            settings: .settings(base: [
                // Automatic signing picks the right identity per configuration: Apple Development for
                // Debug/run, Apple Distribution when archiving for the App Store.
                "CODE_SIGN_STYLE": "Automatic",
                "DEVELOPMENT_TEAM": .string(developmentTeam),
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                // Release builds are fully standalone (no dev server) — native app embeds everything.
                "PRODUCT_BUNDLE_IDENTIFIER": "\(bundlePrefix).ios"
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
        )
    ]
        // Buildable graph today: app → VeliaFeatures → (VeliaDesignSystem, VeliaCore).
        + module("VeliaFeatures", dependencies: [
            .target(name: "VeliaDesignSystem"),
            .package(product: "VeliaCore")
        ])
        + module("VeliaDesignSystem"),
    // Deferred (scaffolds present under Modules/, re-add once SQLCipher GRDB is configured):
    //   module("VeliaData", deps: [VeliaSecurity, VeliaCore, GRDB])
    //   module("VeliaSecurity")
    //   module("VeliaHealth", deps: [VeliaCore])
    schemes: [
        // Custom app scheme so local StoreKit testing uses the bundled config (simulator).
        // On a real device with a sandbox tester this is ignored.
        .scheme(
            name: "Velia",
            shared: true,
            buildAction: .buildAction(targets: ["Velia"]),
            testAction: .targets(["VeliaUITests"]),
            runAction: .runAction(
                configuration: .debug,
                options: .options(storeKitConfigurationPath: "Velia.storekit")
            )
        )
    ]
)
