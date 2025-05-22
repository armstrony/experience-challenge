// RouteMapViewModel.swift
import SwiftUI
import MapKit
import CoreLocation
import Combine // Diperlukan untuk @Published dan cancellables

@MainActor
class RouteMapViewModel: ObservableObject {
    
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var route: MKRoute?
    @Published var annotationItems: [MapAnnotationItem] = []
    @Published var userHeading: CLLocationDirection? = nil
    @Published var hasArrived: Bool = false
    @Published var ETA: String? = nil

    @Published var userLocation: CLLocation?
    private var destinationLocation: CLLocationCoordinate2D
    private var destinationName: String
    private var locationManager: LocationManager // Diinjeksi

    private var arrivalThreshold: CLLocationDistance = 50 // Meter
    private var cancellables = Set<AnyCancellable>()

    init(destination: CoffeeShop, locationManager: LocationManager) {
        self.destinationName = destination.name
        self.destinationLocation = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        self.locationManager = locationManager
        
        print("RouteMapViewModel: Tujuan - \(destination.name) di \(destination.latitude), \(destination.longitude)")

        self.cameraPosition = .region(MKCoordinateRegion(
            center: self.destinationLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
        
        setupBindings()
        updateUserAndDestinationAnnotations() // Panggil sekali untuk anotasi tujuan awal
        // calculateRoute() akan dipanggil setelah lokasi pengguna pertama diterima
    }

    private func setupBindings() {
        locationManager.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.userLocationChanged(newLocation: location)
            }
            .store(in: &cancellables)

        // Pastikan LocationManager Anda mem-publish 'heading'
        // dan Anda sudah menambahkan start/stopUpdatingHeading di LocationManager
        locationManager.$heading
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newHeading in
                self?.userHeading = newHeading.trueHeading
            }
            .store(in: &cancellables)
    }
    
    private func userLocationChanged(newLocation: CLLocation) {
        let firstLocationUpdate = (self.userLocation == nil)
        self.userLocation = newLocation
        print("RouteMapViewModel: Lokasi pengguna berubah - \(newLocation.coordinate)")

        updateUserAndDestinationAnnotations() // Update posisi pin pengguna

        if firstLocationUpdate {
            // Jika ini update lokasi pertama, pusatkan peta dan hitung rute
            self.cameraPosition = .region(MKCoordinateRegion(
                center: newLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            calculateRoute() // Hitung rute saat lokasi pengguna pertama kali didapat
        } else if route != nil {
            // Jika rute sudah ada, mungkin hanya cek status kedatangan atau sedikit sesuaikan region
            // Untuk rute yang dinamis memendek, kita akan menggambar ulang rute
            // atau cukup andalkan pin pengguna yang bergerak.
            // Jika ingin rute selalu update dari posisi pengguna:
            // calculateRoute() // Ini bisa boros, pertimbangkan frekuensinya
        }
        
        checkArrivalStatus(userLocation: newLocation)
    }

    func updateUserAndDestinationAnnotations() {
        var items: [MapAnnotationItem] = []
        items.append(MapAnnotationItem(name: destinationName, coordinate: destinationLocation, tint: .red))

        if let userCoord = userLocation?.coordinate {
            items.append(MapAnnotationItem(name: "Lokasi Saya", coordinate: userCoord, tint: .blue))
        }
        self.annotationItems = items
    }

    func calculateRoute() {
        guard let userLoc = userLocation else {
            print("RouteMapViewModel: Lokasi pengguna belum tersedia untuk menghitung rute.")
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationLocation))
        request.transportType = .walking // Atau .automobile

        let directions = MKDirections(request: request)
        print("RouteMapViewModel: Meminta rute...")
        self.ETA = "Menghitung rute..." // Pesan loading untuk ETA

        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    print("RouteMapViewModel: Gagal menghitung rute: \(error.localizedDescription)")
                    self.route = nil
                    self.ETA = "Gagal memuat rute"
                    return
                }
                
                guard let route = response?.routes.first else {
                    print("RouteMapViewModel: Tidak ada rute yang ditemukan.")
                    self.route = nil
                    self.ETA = "Rute tidak ditemukan"
                    return
                }
                
                self.route = route
                self.ETA = self.formatETA(route.expectedTravelTime)
                print("RouteMapViewModel: Rute berhasil dihitung. Jarak: \(route.distance)m, Waktu: \(route.expectedTravelTime)s")

                // Sesuaikan region untuk menampilkan seluruh rute, HANYA JIKA INI FETCH RUTE PERTAMA
                // Jika rute di-recalculate terus menerus, baris ini mungkin tidak diinginkan
                // agar peta tidak selalu zoom out.
                // Sesuaikan region agar menampilkan seluruh rute (dengan sedikit padding)
                // Pastikan route dan polyline tidak nil sebelum mengakses boundingMapRect
                if route.polyline.pointCount > 0 { // Cek apakah polyline punya point, cara aman
                    let routeRect: MKMapRect = route.polyline.boundingMapRect

                    // Tentukan padding. 20% dari lebar/tinggi rute mungkin terlalu besar jika rute sangat panjang.
                    // Mari kita gunakan padding absolut atau persentase yang lebih kecil.
                    // Atau, cara yang lebih umum adalah menggunakan region yang pas dengan rute,
                    // dan MapKit biasanya sudah memberi sedikit margin.
                    // Jika ingin padding eksplisit:
                    let paddingFactor: Double = 0.10 // 10% padding di setiap sisi
                    var paddedRect = routeRect
                    
                    // Perbesar rect sedikit agar rute tidak terlalu mepet
                    // (dx dan dy negatif akan memperluas rect)
                    let dw = routeRect.size.width * paddingFactor
                    let dh = routeRect.size.height * paddingFactor
                    paddedRect = paddedRect.insetBy(dx: -dw, dy: -dh)
                    
                    // Pastikan paddedRect valid sebelum membuat region
                    if paddedRect.origin.x.isFinite && paddedRect.origin.y.isFinite &&
                       paddedRect.size.width.isFinite && paddedRect.size.height.isFinite &&
                       paddedRect.size.width > 0 && paddedRect.size.height > 0 {
                        
                        self.cameraPosition = .region(MKCoordinateRegion(paddedRect))
                        print("RouteMapViewModel: Region disesuaikan untuk menampilkan rute.")
                    } else {
                        print("RouteMapViewModel: Gagal membuat paddedRect yang valid untuk rute.")
                        // Fallback: Mungkin pusatkan ke tengah rute dengan span tertentu
                        let routeMidPoint = route.polyline.coordinate // Ambil titik tengah polyline (koordinat pertama sbg contoh)
                        self.cameraPosition = .region(MKCoordinateRegion(center: routeMidPoint, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                    }
                } else {
                    print("RouteMapViewModel: Polyline rute kosong, tidak bisa menyesuaikan region berdasarkan rute.")
                    // Fallback jika polyline kosong: Pusatkan ke lokasi pengguna atau tujuan
                    if let userLoc = self.userLocation {
                        self.cameraPosition = .region(MKCoordinateRegion(center: userLoc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                    } else {
                        self.cameraPosition = .region(MKCoordinateRegion(center: self.destinationLocation, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                    }
                }
            }
        }
    }
    
    private func formatETA(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second] // Tambah detik jika perlu
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2 // Tampilkan maksimal 2 unit (misal: 1h 10m, bukan 1h 10m 5s)
        return formatter.string(from: time) ?? "N/A"
    }

    private func checkArrivalStatus(userLocation: CLLocation) {
        let destinationCLLocation = CLLocation(latitude: destinationLocation.latitude, longitude: destinationLocation.longitude)
        let distanceToDestination = userLocation.distance(from: destinationCLLocation)
        print("RouteMapViewModel: Jarak ke tujuan: \(String(format: "%.0f", distanceToDestination)) meter")

        if distanceToDestination <= arrivalThreshold {
            if !hasArrived {
                print("RouteMapViewModel: Pengguna telah sampai di tujuan!")
                self.hasArrived = true
                self.ETA = "Telah Sampai!"
                locationManager.stopUpdatingLocation() // Hentikan update lokasi
                stopUpdatingUserHeading()            // Hentikan update heading
            }
        }
    }
    
    func startUpdatingUserHeading() {
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingUserHeading() {
        locationManager.stopUpdatingHeading()
    }
}
