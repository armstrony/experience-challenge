import SwiftUI
import SwiftData

// Di file App utama Anda (misalnya, CofficeApp.swift)
@main
struct CofficeApp: App {
    let modelContainer: ModelContainer
    @StateObject private var locationManager = LocationManager() // Jika Anda init di sini
    @StateObject private var healthKitManager = HealthKitManager() // Inisialisasi HealthKitManager

    init() {
        print("App.init: Memulai inisialisasi ModelContainer...")
        do {
            let schema = Schema([
                CoffeeShop.self // Pastikan hanya model yang valid
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("App.init: ModelContainer BERHASIL dibuat.")

        } catch {
            print("App.init: KRITIKAL - GAGAL membuat ModelContainer.")
            print("App.init: Error: \(error)")
            print("App.init: Error Localized Description: \(error.localizedDescription)")
            if let swiftDataError = error as? SwiftData.SwiftDataError {
                print("App.init: SwiftData Error Detail: \(swiftDataError)")
            }
            // Baris ini yang menyebabkan aplikasi Anda crash
            fatalError("Tidak dapat membuat ModelContainer: \(error.localizedDescription). Detail Lengkap: \(error)")
        }

        // ... (Kode DataSeeder Task) ...
        let containerForTask = self.modelContainer
        Task { @MainActor in
            print("App.init: Task untuk DataSeeder dimulai.")
            DataSeeder.loadInitialDataIfNeeded(modelContext: containerForTask.mainContext, jsonFileName: "coffee_shop") // Pastikan nama file JSON benar
            print("App.init: Task untuk DataSeeder selesai.")
            NotificationCenter.default.post(name: .initialDataSeeded, object: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Homepage(
                    modelContext: modelContainer.mainContext,
                    healthKitManager: healthKitManager,
                    locationManager: locationManager)

            }
            .environmentObject(locationManager) // Sediakan locationManager
            .environmentObject(healthKitManager) // Sediakan HealthKitManager
            .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}

// Tambahkan ini di mana saja dalam proyek Anda, misalnya di file App atau file terpisah
extension Notification.Name {
    static let initialDataSeeded = Notification.Name("initialDataSeededNotification")
}
