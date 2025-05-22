// CoffeeShopListView.swift
import SwiftUI
import SwiftData
import CoreLocation

struct CoffeeShopListView: View {
    let title: String // Judul halaman, mis: "Digital Wallets & Card Perks"
    let shops: [CoffeeShop] // Daftar coffee shop yang akan ditampilkan
    let userLocation: CLLocation?
    @State private var searchText: String = "" // Untuk search bar
    
    // Filtered shops berdasarkan searchText
    var filteredShops: [CoffeeShop] {
        if searchText.isEmpty {
            return shops
        } else {
            return shops.filter { shop in
                shop.name.localizedCaseInsensitiveContains(searchText) ||
                shop.location.localizedCaseInsensitiveContains(searchText)
                // Anda bisa tambahkan filter berdasarkan tag jika perlu
                // shop.tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Environment untuk tombol kembali kustom jika diperlukan,
    // tapi NavigationStack biasanya menangani ini.
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .center, spacing: 16) { // Atur alignment dan spacing antar item
                ForEach(filteredShops) { shop in
                    // NavigationLink sekarang membungkus CoffeeShopListRow secara langsung
                    // Tanpa styling khusus dari List
                    NavigationLink(destination: CoffeeShopDetailView(shop: shop, userLocation: userLocation)) { // <--- Teruskan userLocation
                        CoffeeShopListRow(shop: shop, userLocation: userLocation) // <--- Teruskan userLocation
                    }
                    // .buttonStyle(PlainButtonStyle()) // Penting agar seluruh area card bisa diklik
                    // dan tidak ada efek highlight biru standar tombol
                }
            }
            .padding(.horizontal) // Padding kiri-kanan untuk keseluruhan LazyVStack
            .padding(.top)        // Padding atas untuk LazyVStack
            // Tambahkan padding bawah jika ada elemen fixed di bawah (seperti search bar yang fixed)
            // tapi karena search bar kita pakai .searchable, ini mungkin tidak perlu.
        }
        // Modifier lainnya tetap sama
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find Your Coffee Shop")
        // Perhatikan: .padding() yang sebelumnya mungkin ada di List, sekarang diatur
        // di dalam ScrollView (pada LazyVStack) atau pada ScrollView itu sendiri jika perlu.
        
    }
}

// View baru untuk setiap baris di daftar
struct CoffeeShopListRow: View {
    let shop: CoffeeShop
    let userLocation: CLLocation?
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image(shop.headerImageName) // Pastikan gambar ada di Assets
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180) // Tinggi gambar bisa disesuaikan
                    .clipped()
                //                    .cornerRadius(10) // Corner radius untuk gambar
                
                if let promoText = shop.bestPromoText { // Menggunakan computed property baru
                    Text(promoText)
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(10)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(shop.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "tag") // Menggunakan ikon tag standar
                        .font(.caption)
                        .foregroundColor(Color("brownpromo", bundle: nil)) // Pastikan warna ini ada
                    Text("\(shop.activePromoCount) Promo For You") // Contoh, bisa diganti dengan data promo aktual
                        .font(.caption)
                        .foregroundColor(Color("brownpromo", bundle: nil))
                    
                    Spacer()
                    
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(shop.displayDistance(userLocation: userLocation)) // <--- GUNAKAN INI
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 10) // Sedikit padding horizontal untuk teks di bawah gambar
        }
        .padding(.bottom, 10) // Padding di bawah setiap item
        .background(Color.white) // Jika ingin latar belakang kartu
        .cornerRadius(12) // Jika ingin kartu dengan corner radius
        .shadow(radius: 2) // Jika ingin bayangan
    }
}

// Preview untuk CoffeeShopListView
//#Preview {
//    // Buat data contoh untuk preview
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    do {
//        let container = try ModelContainer(for: CoffeeShop.self, configurations: config)
//        let sampleShops = [
//            CoffeeShop(name: "Kopi Kenangan Signature", location: "Mall A", tag: "ewallet,food,promo40", distance: 123, steps: 100, calories: 10, latitude: 0, longitude: 0, logo: "kenangan"),
//            CoffeeShop(name: "Starbucks Reserve", location: "Mall B", tag: "bank,food", distance: 456, steps: 100, calories: 10, latitude: 0, longitude: 0, logo: "sbux"),
//            CoffeeShop(name: "Fore Coffee", location: "Mall C", tag: "ewallet", distance: 789, steps: 100, calories: 10, latitude: 0, longitude: 0, logo: "forelogo")
//        ]
//        sampleShops.forEach { container.mainContext.insert($0) }
//
//        // Penting: CoffeeShopListView perlu berada di dalam NavigationStack untuk melihat judul dan tombol kembali
//        return NavigationStack {
//            CoffeeShopListView(title: "Sip and Save", shops: sampleShops)
//        }
//        .modelContainer(container) // Sediakan container agar @Model bisa diakses jika diperlukan
//    } catch {
//        return Text("Gagal membuat preview list: \(error.localizedDescription)")
//    }
//}
//
