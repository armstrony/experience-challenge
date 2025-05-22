// LocationManager.swift
import Foundation
import CoreLocation // Impor CoreLocation
import Combine     // Untuk @Published

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentLocation: CLLocation?
    @Published var heading: CLHeading? // Properti untuk menyimpan data heading
    @Published var locationError: Error?

    override init() {
        // Inisialisasi status otorisasi dengan status saat ini dari locationManager
        // sebelum memanggil super.init()
        self.authorizationStatus = locationManager.authorizationStatus
        super.init() // Panggil super.init() setelah semua properti kelas ini diinisialisasi

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // Lebih baik untuk navigasi
        locationManager.distanceFilter = 10 // Hanya update jika bergerak minimal 10 meter
                                           // Sesuaikan nilai ini sesuai kebutuhan Anda
        print("LocationManager: init selesai. Status otorisasi awal: \(self.authorizationStatus.rawValue)")
        
        // Anda bisa langsung meminta izin di sini jika statusnya .notDetermined
        // atau biarkan View/ViewModel yang memicunya.
        // Untuk konsistensi dengan HealthKitManager, mari kita coba panggil request saat init.
        if self.authorizationStatus == .notDetermined {
            requestLocationPermission()
        } else if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
            // Jika sudah diotorisasi, kita bisa mulai update jika diperlukan oleh logika aplikasi awal
            // locationManager.startUpdatingLocation() // Mungkin tidak selalu ingin langsung start
        }
    }

    // MARK: - Kontrol Publik

    func requestLocationPermission() {
        print("LocationManager: Meminta izin lokasi...")
        locationManager.requestWhenInUseAuthorization()
        // Atau requestAlwaysAuthorization() jika Anda benar-benar membutuhkannya
    }
    
    func startUpdatingLocation() {
        // Cek status otorisasi sebelum memulai
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            print("LocationManager: Mulai update lokasi.")
            locationManager.startUpdatingLocation()
        } else if authorizationStatus == .notDetermined {
            print("LocationManager: Izin lokasi belum ditentukan. Meminta izin dulu...")
            requestLocationPermission()
        } else {
            print("LocationManager: Izin lokasi tidak diberikan (\(authorizationStatus.rawValue)). Tidak dapat memulai update lokasi.")
            // Mungkin set error atau notifikasi ke pengguna
            self.locationError = NSError(domain: "LocationManagerError", code: 101, userInfo: [NSLocalizedDescriptionKey: "Izin lokasi diperlukan untuk fitur ini."])
        }
    }

    func stopUpdatingLocation() {
        print("LocationManager: Berhenti update lokasi.")
        locationManager.stopUpdatingLocation()
    }

    func startUpdatingHeading() {
        if CLLocationManager.headingAvailable() {
            print("LocationManager: Mulai update heading.")
            locationManager.headingFilter = 5 // Update jika arah berubah 5 derajat
            locationManager.startUpdatingHeading()
        } else {
            print("LocationManager: Heading tidak tersedia pada perangkat ini.")
            // Mungkin set error atau state tertentu
        }
    }
    
    func stopUpdatingHeading() {
        print("LocationManager: Berhenti update heading.")
        locationManager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate Methods

    // Dipanggil ketika status otorisasi berubah
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { // Pastikan update UI properties di main thread
            self.authorizationStatus = manager.authorizationStatus // Update status lokal kita
            print("LocationManager: Status otorisasi berubah menjadi: \(self.authorizationStatus.rawValue) (0=notDet, 1=denied, 2=restricted, 3=whenInUse, 4=always)")
            
            switch self.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("LocationManager: Izin lokasi diberikan. Memulai update lokasi jika belum berjalan.")
                // Anda bisa memilih untuk otomatis memulai update di sini,
                // atau membiarkan pemanggil (ViewModel/View) yang memutuskan kapan start.
                // Untuk sekarang, kita biarkan pemanggil yang memutuskan untuk start.
                // self.locationManager.startUpdatingLocation() // Hapus ini jika start dikontrol dari luar
                self.locationError = nil // Hapus error sebelumnya jika ada
            case .denied, .restricted:
                print("LocationManager: Izin lokasi ditolak atau dibatasi.")
                self.currentLocation = nil // Hapus lokasi terakhir
                self.heading = nil // Hapus heading terakhir
                self.stopUpdatingLocation() // Pastikan berhenti jika sedang berjalan
                self.stopUpdatingHeading()
                self.locationError = NSError(domain: "LocationManagerError", code: 102, userInfo: [NSLocalizedDescriptionKey: "Izin lokasi ditolak atau dibatasi oleh pengguna."])
            case .notDetermined:
                print("LocationManager: Status otorisasi lokasi belum ditentukan.")
                // Tidak melakukan apa-apa di sini, tunggu pengguna memicu requestLocationPermission()
            @unknown default:
                print("LocationManager: Status otorisasi lokasi tidak diketahui.")
                self.stopUpdatingLocation()
                self.stopUpdatingHeading()
            }
        }
    }

    // Dipanggil ketika lokasi baru diterima
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            guard let latestLocation = locations.last else {
                print("LocationManager: Tidak ada lokasi terbaru dalam array.")
                return
            }
            // Filter update yang tidak signifikan jika perlu (meskipun distanceFilter sudah ada)
            // if let current = self.currentLocation, latestLocation.distance(from: current) < 5 { return }
            
            self.currentLocation = latestLocation
            self.locationError = nil // Hapus error jika lokasi berhasil didapat
            print("LocationManager: Lokasi diperbarui: Lat \(latestLocation.coordinate.latitude), Lon \(latestLocation.coordinate.longitude), Acc \(latestLocation.horizontalAccuracy)m")
        }
    }

    // Dipanggil ketika gagal mendapatkan lokasi
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error
            print("LocationManager: GAGAL mendapatkan lokasi: \(error.localizedDescription)")
            // Anda bisa menghentikan update jika terjadi error terus menerus untuk hemat baterai
            // self.stopUpdatingLocation()
        }
    }
    
    // Delegate method BARU untuk heading
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            // Kita hanya tertarik pada true heading jika akurasinya bagus (positif)
            if newHeading.headingAccuracy >= 0 {
                print("LocationManager: Heading diperbarui: \(newHeading.trueHeading)° (Akurasi: \(newHeading.headingAccuracy)°)")
                self.heading = newHeading
            } else {
                // Akurasi negatif berarti heading tidak valid atau sedang kalibrasi
                print("LocationManager: Menerima update heading, tapi akurasi tidak valid (\(newHeading.headingAccuracy)°)")
                // Anda bisa set self.heading = nil jika ingin UI tahu heading tidak valid
            }
        }
    }

    // Delegate method untuk memberi tahu jika UI kalibrasi kompas perlu ditampilkan
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // Jika heading sangat tidak akurat, sistem mungkin ingin menampilkan UI kalibrasi.
        // Mengembalikan true akan mengizinkan sistem menampilkannya.
        if let currentHeading = heading, currentHeading.headingAccuracy < 0 || currentHeading.headingAccuracy > 30 { // Contoh threshold akurasi
            print("LocationManager: Menyarankan kalibrasi kompas (akurasi saat ini: \(currentHeading.headingAccuracy)°).")
            return true
        }
        return false // Jangan tampilkan jika akurasi sudah cukup baik
    }
}
