import SwiftUI

enum KoraNavigationRoute: Equatable {
    case rooms
    case room(UUID)
}

@MainActor
final class KoraNavigationState: ObservableObject {
    @Published var route: KoraNavigationRoute?

    func route(to route: KoraNavigationRoute?) {
        self.route = route
    }

    func clearRoute() {
        route = nil
    }
}

@main
struct koraApp: App {
    @StateObject private var navigationState = KoraNavigationState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationState)
        }
        .onOpenURL { url in
            let route = parseRoute(from: url)
            navigationState.route(to: route)
        }
    }

    private func parseRoute(from url: URL) -> KoraNavigationRoute? {
        guard url.scheme?.lowercased() == "kora" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let roomIDValue = components?.queryItems?.first(where: { $0.name == "room" })?.value,
           let parsedRoomID = UUID(uuidString: roomIDValue) {
            return .room(parsedRoomID)
        }

        if url.host == "rooms" {
            return .rooms
        }

        if url.host == "room" {
            if let roomID = url.path
                .split(separator: "/")
                .compactMap({ UUID(uuidString: String($0)) })
                .first {
                return .room(roomID)
            }

            if let roomID = components?.queryItems?.first(where: { $0.name == "id" })?.value,
               let parsedRoomID = UUID(uuidString: roomID) {
                return .room(parsedRoomID)
            }
        }

        return nil
    }
}
