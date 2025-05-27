// RouteMapView.swift (Menggunakan API Map Baru iOS 17+)
import SwiftUI
import MapKit
import CoreLocation

struct RouteMapView: View {
    @StateObject var viewModel: RouteMapViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingExitConfirmationAlert: Bool = false
    
    init(destinationShop: CoffeeShop, locationManager: LocationManager) {
        _viewModel = StateObject(wrappedValue: RouteMapViewModel(destination: destinationShop, locationManager: locationManager))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Menggunakan initializer Map baru dengan MapContentBuilder
            Map(position: $viewModel.cameraPosition, interactionModes: .all) { // Gunakan MapCameraPosition
                
                // Menampilkan Rute Polyline (lebih mudah di iOS 17+)
                if let route = viewModel.route {
                    MapPolyline(route.polyline)
                        .stroke(Color.blue.opacity(0.8), lineWidth: 6)
                }
                
                // Anotasi untuk Tujuan (Coffee Shop)
                // Asumsi 'annotationItems' sekarang hanya berisi tujuan, atau kita filter
                // Atau lebih baik, ViewModel menyediakan data anotasi yang sudah siap.
                // Untuk sekarang, kita ambil dari annotationItems seperti sebelumnya.
                let destinationItem = viewModel.annotationItems.first(where: { $0.name != "Lokasi Saya" })
                if let item = destinationItem {
                    Annotation(item.name, coordinate: item.coordinate) {
                        VStack(spacing: 2) {
                            Text(item.name)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            Image(systemName: "mappin.and.ellipse.circle.fill")
                                .font(.title2)
                                .foregroundColor(item.tint) // item.tint adalah .red
                                .shadow(radius: 1)
                        }
                    }
                    // Atau gunakan Marker untuk pin standar:
                    // Marker(item.name, systemImage: "mappin.and.ellipse", coordinate: item.coordinate)
                    //    .tint(item.tint)
                }
                
                // Anotasi untuk Lokasi Pengguna dengan Arah Hadap
                // Ambil lokasi pengguna dari viewModel.currentUserLocation
                if let userCoordinate = viewModel.userLocation?.coordinate {
                    Annotation("Lokasi Saya", coordinate: userCoordinate) {
                        UserLocationAnnotation(heading: viewModel.userHeading)
                            .onTapGesture {
                                print("User annotation tapped")
                                // Untuk recenter, kita perlu update cameraPosition di ViewModel
                                // viewModel.recenterMapOnUser()
                            }
                    }
                }
            }
            //            .ignoresSafeArea(edges: .top) // Mengabaikan safe area di bagian bawah untuk Map
            // Akhir dari Map View
            
            // Overlay untuk Info Steps, Calories, dan Tombol Exit
            VStack { // VStack untuk mengatur posisi overlay
                if viewModel.motionManager.isPedometerAvailable {
                    ActivityOverlayView(
                        steps: viewModel.sessionSteps,
                        calories: viewModel.sessionCalories,
                        onExit: {
                            print("RouteMapView: Tombol EXIT di ActivityOverlay ditekan, menampilkan alert konfirmasi.")
                            self.showingExitConfirmationAlert = true // <--- SEKARANG MENAMPILKAN ALERT
                        }
                    )
                    .padding(.top, 8)
                    .padding(.horizontal)
                } else if let motionError = viewModel.motionError {
                    Text("Motion Error: \(motionError)") // Tampilkan error jika pedometer tidak tersedia
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(8)
                        .padding(.top, 8)
                        .padding(.horizontal)
                    
                }
                
                Spacer() // Mendorong ActivityOverlayView ke atas
                
                // ETA Display
                //                if let etaText = viewModel.ETA, !viewModel.hasArrived {
                //                    Text(etaText)
                //                        .font(viewModel.hasArrived ? .headline.bold() : .caption)
                //                        .foregroundColor(viewModel.hasArrived ? .green : .primary)
                //                        .padding(10)
                //                        .background(.ultraThinMaterial)
                //                        .clipShape(Capsule())
                //                        .shadow(radius: 2)
                //                        .padding(.bottom, 20)
                //                }
            }
        }
        //        .navigationTitle("Rute ke \(viewModel.annotationItems.first(where: {$0.name != "Lokasi Saya"})?.name ?? "Tujuan")")
        //        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar) // Sembunyikan toolbar navigasi
        .onAppear {
            print("RouteMapView: onAppear. Memulai pelacakan sesi.")
            viewModel.startSessionTracking() // Memulai semua pelacakan
        }
        .onDisappear {
            print("RouteMapView: onDisappear. Menghentikan pelacakan sesi.")
            viewModel.stopSessionTracking() // Menghentikan semua pelacakan
        }
        .alert("You've Arrived", isPresented: $viewModel.hasArrived) {
            Button("Kembali ke Home", role: .cancel) {
                dismiss()
            }
        } message: {
            // Pesan alert sekarang akan menampilkan steps dan calories sesi ini
                   let stepsFormatted = String(format: "%.0f", Double(viewModel.sessionSteps)) // Pastikan sessionSteps adalah tipe yang benar
                   let caloriesFormatted = String(format: "%.0f", viewModel.sessionCalories)

                   Text("""
                   Congratulations! 🎉
                   You've taken \(stepsFormatted) steps dan burned \(caloriesFormatted) kcal.
                   
                   Enjoy Your Coffee!
                   """)
        }
        .alert("Exit Confirmation", isPresented: $showingExitConfirmationAlert) {
                    Button("No", role: .cancel) {
                        // Tidak melakukan apa-apa, alert akan tertutup
                        print("RouteMapView: Keluar dari peta dibatalkan.")
                    }
                    Button("Yes", role: .destructive) {
                        // Aksi untuk keluar dari peta
                        print("RouteMapView: Pengguna mengkonfirmasi keluar dari peta.")
                        dismiss() // Menutup RouteMapView dan kembali ke CoffeeShopDetailView
                                  // Jika Anda ingin popToRoot dari sini juga, panggil navigationRouter.popToRoot()
                                  // Tapi biasanya tombol "EXIT" di peta hanya kembali satu layar.
                    }
                } message: {
                    Text("Are you sure to cancel this journey?")
                }
    }
}

// Perlu penyesuaian di RouteMapViewModel untuk MapCameraPosition
// dan mungkin cara anotasi dikelola jika ingin lebih optimal.
