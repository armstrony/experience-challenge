// RouteMapView.swift (Menggunakan API Map Baru iOS 17+)
import SwiftUI
import MapKit
import CoreLocation

struct RouteMapView: View {
    @StateObject var viewModel: RouteMapViewModel
    @Environment(\.dismiss) var dismiss
    // @State private var showingArrivalAlert = false // Tidak perlu lagi, dikontrol oleh viewModel.hasArrived

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

            } // Akhir dari Map View

            // Tampilkan ETA di atas peta
            if let etaText = viewModel.ETA {
                Text(etaText)
                    .font(viewModel.hasArrived ? .headline.bold() : .caption)
                    .foregroundColor(viewModel.hasArrived ? .green : .primary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .shadow(radius: 2)
            }
        }
        .navigationTitle("Rute ke \(viewModel.annotationItems.first(where: {$0.name != "Lokasi Saya"})?.name ?? "Tujuan")")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("RouteMapView: onAppear")
            viewModel.startUpdatingUserHeading()
        }
        .onDisappear {
            print("RouteMapView: onDisappear")
            viewModel.stopUpdatingUserHeading()
        }
        .alert("Telah Sampai!", isPresented: $viewModel.hasArrived) {
            Button("Kembali ke Home", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Anda telah tiba di sekitar \(viewModel.annotationItems.first(where: {$0.name != "Lokasi Saya"})?.name ?? "tujuan"). Selamat menikmati!")
        }
    }
}

// Perlu penyesuaian di RouteMapViewModel untuk MapCameraPosition
// dan mungkin cara anotasi dikelola jika ingin lebih optimal.
