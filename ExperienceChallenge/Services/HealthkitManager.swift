// HealthKitManager.swift (Versi Koreksi untuk isAuthorized)
import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    @Published var isHealthDataAvailable: Bool
    @Published var isAuthorized: Bool = false // <--- PASTIKAN INI ADA DAN KONSISTEN
    @Published var stepCountToday: Double = 0
    @Published var activeEnergyBurnedToday: Double = 0
    @Published var isLoadingData: Bool = false
    @Published var errorMessage: String? = nil

    private var readDataTypes: Set<HKObjectType> {
        return [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
    }

    init() {
        print("HealthKitManager: init.")
        self.isHealthDataAvailable = HKHealthStore.isHealthDataAvailable()
        if !self.isHealthDataAvailable {
            print("HealthKitManager: Data kesehatan tidak tersedia di perangkat ini.")
            self.errorMessage = "Data kesehatan tidak tersedia di perangkat ini."
            // Set isAuthorized ke false juga jika data tidak tersedia
            self.isAuthorized = false
            return
        }
        requestAuthorization()
    }

    func requestAuthorization() {
        guard isHealthDataAvailable else {
            print("HealthKitManager: Tidak bisa request otorisasi, data kesehatan tidak tersedia.")
            self.isAuthorized = false // Pastikan di-set jika keluar lebih awal
            return
        }

        print("HealthKitManager: Memulai permintaan otorisasi (jika diperlukan)...")
        self.errorMessage = nil
        self.isLoadingData = true // Mulai loading

        healthStore.requestAuthorization(toShare: nil, read: readDataTypes) { [weak self] (success, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    print("HealthKitManager: Gagal meminta otorisasi (callback) - Error: \(error.localizedDescription)")
                    self.errorMessage = "Gagal meminta izin: \(error.localizedDescription)"
                    self.isAuthorized = false // Set false jika error
                    self.isLoadingData = false
                    return
                }

                // 'success' berarti pengguna berinteraksi dengan prompt.
                // Kita akan set isAuthorized berdasarkan hasil fetch nanti.
                // Untuk sekarang, kita bisa set isAuthorizedAttemptedAndResponded (jika ada) atau
                // biarkan isAuthorized di-update setelah fetch.
                // Mari kita coba set isAuthorized berdasarkan success untuk sementara,
                // lalu fetchAllTodayData akan mengkonfirmasi.

                if success {
                    print("HealthKitManager: Pengguna berinteraksi dengan prompt (success=true). Mencoba fetch data...")
                    // Tidak langsung set isAuthorized = true di sini.
                    // Biarkan fetchAllTodayData yang menentukan setelah mencoba mengambil data.
                    self.fetchAllTodayData()
                } else {
                    print("HealthKitManager: Interaksi dengan prompt izin tidak berhasil (success=false).")
                    self.errorMessage = "Izin akses data kesehatan tidak diberikan atau dibatalkan."
                    self.isAuthorized = false // Jelas tidak diotorisasi jika success false
                    self.stepCountToday = 0
                    self.activeEnergyBurnedToday = 0
                    self.isLoadingData = false
                }
            }
        }
    }
    
    func fetchAllTodayData() {
        // Tidak ada guard isAuthorized di awal karena kita akan mengaturnya berdasarkan hasil fetch
        print("HealthKitManager: Memulai fetchAllTodayData...")
        // isLoadingData seharusnya sudah true dari requestAuthorization jika flow-nya dari sana,
        // atau set di sini jika fungsi ini bisa dipanggil terpisah.
        if !self.isLoadingData { self.isLoadingData = true }
        self.errorMessage = nil // Reset error sebelum fetch baru

        let group = DispatchGroup()
        var fetchErrors: [String] = [] // Kumpulkan error fetch

        // Fetch Steps
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            fetchTodaySumStatistics(for: stepType, unit: .count()) { [weak self] steps, fetchError in
                DispatchQueue.main.async {
                    if let fetchError = fetchError {
                        print("HealthKitManager: Error fetching steps: \(fetchError.localizedDescription)")
                        fetchErrors.append("langkah")
                        self?.stepCountToday = 0
                    } else {
                        self?.stepCountToday = steps
                        print("HealthKitManager: Steps hari ini = \(steps)")
                    }
                    group.leave()
                }
            }
        } else {
            fetchErrors.append("tipe data langkah tidak valid")
        }

        // Fetch Active Energy
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            group.enter()
            fetchTodaySumStatistics(for: energyType, unit: .kilocalorie()) { [weak self] calories, fetchError in
                DispatchQueue.main.async {
                    if let fetchError = fetchError {
                        print("HealthKitManager: Error fetching active energy: \(fetchError.localizedDescription)")
                        fetchErrors.append("kalori")
                        self?.activeEnergyBurnedToday = 0
                    } else {
                        self?.activeEnergyBurnedToday = calories
                        print("HealthKitManager: Kalori aktif hari ini = \(calories) kcal")
                    }
                    group.leave()
                }
            }
        } else {
            fetchErrors.append("tipe data kalori tidak valid")
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            print("HealthKitManager: Semua proses fetch data kesehatan selesai.")
            self.isLoadingData = false
            
            if fetchErrors.isEmpty {
                // Jika tidak ada error spesifik dari fetch, kita anggap izin baca ada
                // dan data (meskipun mungkin 0 jika tidak ada aktivitas) berhasil diambil.
                print("HealthKitManager: Fetch data kesehatan berhasil tanpa error spesifik. Mengatur isAuthorized = true.")
                self.isAuthorized = true
            } else {
                print("HealthKitManager: Terjadi error saat fetch data: \(fetchErrors.joined(separator: ", ")). Mengatur isAuthorized = false.")
                self.errorMessage = "Gagal mengambil data untuk: \(fetchErrors.joined(separator: ", ")). Pastikan izin diberikan di Aplikasi Kesehatan."
                self.isAuthorized = false
            }
        }
    }

    // fetchTodaySumStatistics tetap sama seperti sebelumnya (mengembalikan Double dan Error?)
    private func fetchTodaySumStatistics(for quantityType: HKQuantityType, unit: HKUnit, completion: @escaping (Double, Error?) -> Void) {
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
             if let error = error {
                print("HealthKitManager (fetchTodaySumStatistics): HKStatisticsQuery error untuk \(quantityType.identifier): \(error.localizedDescription)")
                completion(0.0, error) // Kembalikan error
                return
            }
            guard let result = result, let sum = result.sumQuantity() else {
                print("HealthKitManager (fetchTodaySumStatistics): Tidak ada data (atau result/sum nil) untuk \(quantityType.identifier)")
                completion(0.0, nil) // Tidak ada data, bukan error
                return
            }
            completion(sum.doubleValue(for: unit), nil) // Sukses, tidak ada error
        }
        healthStore.execute(query)
    }
}
