// HomepageViewModel.swift
import SwiftUI
import SwiftData
import Combine
import CoreLocation
import HealthKit

@MainActor
class HomepageViewModel: ObservableObject {
    @Published var ewalletAndBankShops: [CoffeeShop] = []
    @Published var foodShops: [CoffeeShop] = []
    @Published var allCoffeeShops: [CoffeeShop] = []
    @Published var topDiscountShops: [CoffeeShop] = []
    @Published var isLoading: Bool = false
    
    // loc manager
    @Published var locationManager = LocationManager() // Buat instance LocationManager
    @Published var currentUserLocation: CLLocation? = nil
    
    // healthkit manager
    @Published var healthKitManager: HealthKitManager
    @Published var welcomeMessageBody: String = "Memuat data aktivitas..." // Teks utama untuk langkah & kalori
    @Published var showConnectHealthButton: Bool = false
    @Published var isLoadingHealthData: Bool = false
    
    private var modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>() // Untuk menyimpan subscriber
    
    init(modelContext: ModelContext, healthKitManager: HealthKitManager, locationManager: LocationManager) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager // Simpan instance HealthKitManager
        self.locationManager = locationManager
        print("HomepageViewModel: ViewModel diinisialisasi.")
        
        setupLocationSubscribers()
        setupHealthKitSubscribers() // Buat fungsi baru untuk subscribe ke HealthKitManager
        
        // Minta izin lokasi 
        locationManager.requestLocationPermission()
        
        // Dengarkan notifikasi bahwa data awal telah di-seed
        NotificationCenter.default.publisher(for: .initialDataSeeded)
            .receive(on: DispatchQueue.main) // Pastikan dieksekusi di main thread
            .sink { [weak self] _ in
                print("HomepageViewModel: Menerima notifikasi initialDataSeeded. Memanggil fetchData().")
                self?.fetchData()
            }
            .store(in: &cancellables) // Simpan subscriber
        
        // Anda mungkin masih ingin melakukan fetch awal di sini atau mengandalkan .onAppear sepenuhnya
        // untuk kasus ketika data sudah ada (bukan peluncuran pertama setelah install).
        // Pemanggilan fetchData() di .onAppear pada View sudah cukup untuk kasus tersebut.
    }
    
    private func setupHealthKitSubscribers() {
            healthKitManager.$isAuthorized
                .combineLatest(healthKitManager.$stepCountToday, healthKitManager.$activeEnergyBurnedToday, healthKitManager.$isLoadingData) // Gunakan isLoading dari HealthKitManager
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isAuthorized, steps, calories, isLoadingHealth in
                    guard let self = self else { return }
                    
                    self.isLoadingHealthData = isLoadingHealth // Update status loading data kesehatan
                    
                    if isLoadingHealth {
                        self.welcomeMessageBody = "Memuat data aktivitas..."
                        self.showConnectHealthButton = false
                    } else if isAuthorized {
                        let stepsFormatted = String(format: "%.0f", steps)
                        let caloriesFormatted = String(format: "%.0f", calories)
//                        print("HomepageViewModel: Menerima data kesehatan - Langkah: \(stepsFormatted), Kalori: \(caloriesFormatted)")
                        self.welcomeMessageBody = "You've burned **\(caloriesFormatted) calories** in **\(stepsFormatted) steps**.\nLet’s burn more calories—but not your wallet."
                        self.showConnectHealthButton = false
                    } else {
                        self.welcomeMessageBody = "Hubungkan ke Aplikasi Kesehatan untuk melihat aktivitas harianmu di sini."
                        self.showConnectHealthButton = true
//                        print("HomepageViewModel: Tidak ada izin untuk membaca data kesehatan.")
                        if let message = self.healthKitManager.errorMessage, !message.isEmpty {
                            print("HomepageViewModel: HealthKit Error dari Manager - \(message)")
                            // Anda bisa tambahkan @Published var healthErrorMessage: String? jika ingin menampilkan di UI
                            // self.welcomeMessageBody = "Gagal memuat data kesehatan. \(error.localizedDescription)" // Contoh
                        }
                    }
                }
                .store(in: &cancellables)
        }

    
    private func setupLocationSubscribers() {
        // Subscribe ke perubahan currentLocation dari LocationManager
        locationManager.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLocation in
                if let location = newLocation {
                    print("HomepageViewModel: Menerima update lokasi pengguna: \(location.coordinate)")
                    self?.currentUserLocation = location
                    // Anda bisa memicu fetchData() lagi di sini jika ingin jarak di-refresh otomatis
                    // saat lokasi berubah signifikan, atau biarkan View yang menghitung ulang.
                    // self?.fetchData() // Hati-hati, ini bisa sering terpicu jika lokasi sering update.
                }
            }
            .store(in: &cancellables)
        
        // Subscribe ke perubahan status otorisasi
        locationManager.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                print("HomepageViewModel: Menerima update status otorisasi lokasi: \(status.rawValue)")
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self?.locationManager.startUpdatingLocation() // Mulai update jika diizinkan
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchData() {
        print("HomepageViewModel: fetchData() dipanggil.")
        self.isLoading = true
        
        // 1. Descriptor untuk section "Digital Wallets & Card Perks"
        // Sekarang filter berdasarkan aggregatedPromoTags
        let ewalletPredicate = #Predicate<CoffeeShop> { shop in
            // aggregatedPromoTags akan berisi string seperti "ewallet,bank,drink" (sudah lowercase)
            shop.aggregatedPromoTags.contains("ewallet") ||
            shop.aggregatedPromoTags.contains("bank")
        }
        let ewalletSortDescriptor = [SortDescriptor(\CoffeeShop.name, order: .forward)]
        let ewalletDescriptor = FetchDescriptor<CoffeeShop>(predicate: ewalletPredicate, sortBy: ewalletSortDescriptor)
        
        // 2. Descriptor untuk section "Food Selections"
        // Filter berdasarkan aggregatedPromoTags
        let foodPredicate = #Predicate<CoffeeShop> { shop in
            shop.aggregatedPromoTags.contains("food")
        }
        let foodSortDescriptor = [SortDescriptor(\CoffeeShop.name, order: .forward)]
        let foodDescriptor = FetchDescriptor<CoffeeShop>(predicate: foodPredicate, sortBy: foodSortDescriptor)
        
        // 3. Descriptor untuk SEMUA coffee shops (untuk "View All" dari Search Bar)
        let allShopsSortDescriptor = [SortDescriptor(\CoffeeShop.name, order: .forward)]
        let allShopsDescriptor = FetchDescriptor<CoffeeShop>(sortBy: allShopsSortDescriptor)
        
        // 4. Descriptor BARU untuk "Sip and Save" (Diskon Tertinggi)
        // Filter: hanya coffee shop yang memiliki diskon efektif > 0
        // Urutkan: dari maxEffectiveDiscountValue tertinggi ke terendah
        let topDiscountPredicate = #Predicate<CoffeeShop> { shop in
            shop.maxEffectiveDiscountValue > 0 // Hanya yang punya diskon
        }
        let topDiscountSortDescriptor = [SortDescriptor(\CoffeeShop.maxEffectiveDiscountValue, order: .reverse), // Urutan utama: diskon terbesar
                                         SortDescriptor(\CoffeeShop.name, order: .forward)] // Urutan sekunder: nama A-Z jika diskon sama
        let topDiscountDescriptor = FetchDescriptor<CoffeeShop>(predicate: topDiscountPredicate, sortBy: topDiscountSortDescriptor)
        
        
        do {
            // Fetch data untuk ewallet/bank
            let ewalletResults = try modelContext.fetch(ewalletDescriptor)
            self.ewalletAndBankShops = ewalletResults
            print("HomepageViewModel: Hasil fetch ewalletAndBankShops - Jumlah: \(ewalletResults.count)")
            if ewalletResults.isEmpty { print("HomepageViewModel: Tidak ada data ewallet/bank yang cocok (berdasarkan aggregatedPromoTags).") }
            else { ewalletResults.forEach { print("   - Ewallet/Bank: \($0.name) (AggregatedTags: '\($0.aggregatedPromoTags)')") } }
            
            // Fetch data untuk food
            let foodResults = try modelContext.fetch(foodDescriptor)
            self.foodShops = foodResults
            print("HomepageViewModel: Hasil fetch foodShops - Jumlah: \(foodResults.count)")
            if foodResults.isEmpty { print("HomepageViewModel: Tidak ada data food yang cocok (berdasarkan aggregatedPromoTags).") }
            else { foodResults.forEach { print("   - Food: \($0.name) (AggregatedTags: '\($0.aggregatedPromoTags)')") } }
            
            // Fetch Top Discount
            self.topDiscountShops = try modelContext.fetch(topDiscountDescriptor)
            print("HomepageViewModel: Hasil fetch topDiscountShops - Jumlah: \(self.topDiscountShops.count)")
            self.topDiscountShops.forEach { shop in
                print("   - Top Discount: \(shop.name) (Value: \(shop.maxEffectiveDiscountValue), PromoText: \(shop.bestPromoText ?? "N/A"))")
            }
            
            // Fetch SEMUA coffee shops
            let allResults = try modelContext.fetch(allShopsDescriptor)
            self.allCoffeeShops = allResults
            print("HomepageViewModel: Hasil fetch allCoffeeShops - Jumlah: \(allResults.count)")
            
            // (AKAN DIIMPLEMENTASIKAN NANTI) Fetch data untuk diskon terbesar
            // Untuk sekarang, biarkan kosong atau isi dengan beberapa item untuk testing UI section baru
            // self.topDiscountShops = try modelContext.fetch(topDiscountDescriptor).prefix(5).map { $0 } // Ambil 5 teratas misalnya
            // print("HomepageViewModel: Hasil fetch topDiscountShops (sementara) - Jumlah: \(self.topDiscountShops.count)")
            
            
            print("HomepageViewModel: Semua data fetched successfully.")
        } catch {
            print("HomepageViewModel: GAGAL mengambil data untuk ViewModel: \(error)")
        }
        self.isLoading = false
    }
}
