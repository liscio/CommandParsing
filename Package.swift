// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommandParsing",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CommandParsing",
            targets: ["CommandParsing"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(name: "Parsing", url: "https://github.com/pointfreeco/swift-parsing", from: "0.8.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CommandParsing",
            dependencies: [.product(name: "Parsing", package: "Parsing")]),
        .testTarget(
            name: "CommandParsingTests",
            dependencies: ["CommandParsing"]),
    ]
)
