import SwiftUI

@main
struct ReverseMusicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 640, height: 720)
        .windowResizability(.contentSize)
    }
}
