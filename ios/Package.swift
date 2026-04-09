// swift-tools-version: 6.0
// Package.swift — allows building LangBrew as a Swift package for validation.
// The real build uses LangBrew.xcodeproj (created via xcodegen).

import PackageDescription

let package = Package(
    name: "LangBrew",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "LangBrew",
            targets: ["LangBrew"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "LangBrew",
            dependencies: [
                .product(name: "Auth", package: "supabase-swift"),
            ],
            path: "LangBrew",
            exclude: ["Info.plist", "LangBrew.entitlements"]
        )
    ]
)
