// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppStoreCommerceKit",
    platforms: [.iOS(.v17)],
    products: [.library(name: "AppStoreCommerceKit", targets: ["AppStoreCommerceKit"])],
    targets: [
        .target(name: "AppStoreCommerceKit"),
        .testTarget(name: "AppStoreCommerceKitTests", dependencies: ["AppStoreCommerceKit"])
    ]
)
