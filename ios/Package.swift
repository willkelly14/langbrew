// swift-tools-version: 6.0
// Package.swift — allows building LangBrew as a Swift package for validation.
// The real build uses LangBrew.xcodeproj (created via Xcode).

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
    targets: [
        .target(
            name: "LangBrew",
            path: "LangBrew",
            exclude: ["Info.plist"]
        )
    ]
)
