//
//  CoffeeShopDetailView.swift
//  ExplorationChallenge
//
//  Created by Hafi on 18/05/25.
//

// CoffeeShopDetailView.swift
import SwiftUI
import CoreLocation

struct CoffeeShopDetailView: View {
    let shop: CoffeeShop // Coffee shop yang detailnya akan ditampilkan
    let userLocation : CLLocation?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @State private var navigationBarIsSolid: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) { // Gunakan ZStack untuk menumpuk ScrollView dan Tombol
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Gambar Header Coffee Shop
                    Image(shop.headerImageName)
                        .resizable()
                        .frame(height: 280)
                        .scaledToFill()
                        .background(Color.primary.opacity(0.3))
                        .clipped()
                    
                    // 2. Info Detail Coffee Shop (Nama, Tag, Jarak, dll.)
                    VStack(alignment: .leading, spacing: 12) { // Atau spacing: 16
                        Text(shop.name)
                            .font(.largeTitle.bold())
                            .padding(.top)
                        
                        if !shop.uniqueActivePromoTagsArray.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "tag")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                Text(shop.uniqueActivePromoTagsArray.map { $0.capitalized }.joined(separator: " | "))
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.top, 4)
                        }
                        
                        HStack(spacing: 20) { // Atau spacing: 15
                            InfoItem(icon: "mappin.and.ellipse", text: shop.displayDistance(userLocation: userLocation))
                            InfoItem(icon: "figure.walk", text: shop.displaySteps(userLocation: userLocation))
                            InfoItem(icon: "flame.fill", text: shop.displayCalories(userLocation: userLocation))
                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                    
                    // 3. Section Promo (Voucher)
                    if !shop.vouchers.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Promo Voucher")
                                .font(.title2.bold())
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(shop.vouchers) { voucher in
                                        PromoCardView(voucher: voucher)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                    
                    // 4. Section Menu
                    if !shop.menuItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Menu")
                                .font(.title2.bold())
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(shop.menuItems) { item in
                                    MenuItemRow(item: item)
                                        .padding(.horizontal)
                                    if item.id != shop.menuItems.last?.id {
                                        Divider().padding(.leading)
                                    }
                                }
                            }
                        }
                        // Padding bawah yang lebih besar untuk memberi ruang bagi tombol fixed
                        // Kita akan mengandalkan padding dari container tombol nanti
                        .padding(.bottom, 120) // Sesuaikan nilai ini jika perlu
                    } else {
                        Text("Menu belum tersedia.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 120) // Sesuaikan nilai ini jika perlu
                    }
                }
            } // Akhir dari ScrollView
            //            .ignoresSafeArea(edges: .top) // Biarkan ScrollView mengabaikan safe area atas
            
            // 5. Tombol "Let's Get Coffee" dan Latar Belakangnya (Fixed di Bawah)
            VStack(spacing: 0) { // VStack untuk menampung tombol dan menghormati safe area
                // Divider tipis di atas area tombol (opsional, sesuai desain)
                Divider()
                NavigationLink(destination: RouteMapView(destinationShop: shop, locationManager: locationManager)) { // <--- TUJUAN NAVIGASI
                    Text("Let's Get Coffee")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.brownapp) // Atau warna solid Anda
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(UIColor.systemGray6)) // Latar belakang putih sedikit abu (seperti .secondarySystemBackground)
            //            .ignoresSafeArea(edges: .bottom)
            
        } // Akhir dari ZStack
        /*.navigationBarBackButtonHidden(false)*/ // Kita tetap sembunyikan tombol default
        .toolbarBackground(.visible, for: .navigationBar) // Make the background visible
        .toolbarColorScheme(.dark, for: .navigationBar) // This tells iOS the bar is dark, so foreground items (like back button) should be light (white)
    }
}

// View kecil untuk InfoItem (jarak, langkah, kalori) - jika belum ada
struct InfoItem: View { // Pastikan ini sudah ada dari implementasi sebelumnya
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
    }
}

struct MenuItemRow: View {
    let item: MenuItemSwift // Sekarang menerima MenuItemSwift
    
    // Fungsi helper untuk format harga ke Rupiah (opsional, tapi bagus)
    private func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "id_ID") // Untuk format Rupiah "Rp"
        formatter.maximumFractionDigits = 0 // Tidak ada desimal untuk harga ini
        return formatter.string(from: NSNumber(value: price)) ?? "Rp\(price)"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(item.img) // Nama field di MenuItemSwift adalah 'img'
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70) // Ukuran gambar menu
                .cornerRadius(8)
                .clipped()
                .overlay(Color.black.opacity(0.3))
            
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.menuName)
                    .font(.headline)
                    .lineLimit(2) // Izinkan dua baris jika nama panjang
                
                // Logika untuk menampilkan harga
                if item.hasActiveDiscount, let discountInfo = item.discount {
                    let discountedPrice = item.price - Int(Double(item.price) * (Double(discountInfo.discountPercentage) / 100.0))
                    HStack(spacing: 8) {
                        Text(formatPrice(item.price)) // Harga asli
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .strikethrough() // Coret harga asli
                        
                        Text(formatPrice(discountedPrice)) // Harga setelah diskon
                            .font(.subheadline.bold()) // Buat harga diskon lebih menonjol
                            .foregroundColor(.primary) // Warna untuk harga diskon
                    }
                } else {
                    Text(formatPrice(item.price)) // Harga normal
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
            }
            
            Spacer() // Mendorong konten ke kiri
            
            // Tampilkan label diskon jika ada diskon aktif
            if item.hasActiveDiscount, let discountInfo = item.discount {
                Text("\(discountInfo.discountPercentage)% OFF")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8) // Padding atas bawah untuk setiap baris
    }
}


// Preview untuk CoffeeShopDetailView
//#Preview {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    do {
//        let container = try ModelContainer(for: CoffeeShop.self, configurations: config)
//
//        // Buat data contoh MenuItemSwift dan VoucherSwift
//        let sampleMenuDiscount = MenuDiscountSwift(tag: "drink", discountPercentage: 25)
//        let sampleMenuItems = [
//            MenuItemSwift(menuName: "Espresso Mantap", price: 22000, discount: sampleMenuDiscount, img: "coffeeimg"),
//            MenuItemSwift(menuName: "Roti Bakar Keju", price: 18000, discount: MenuDiscountSwift(tag: "food", discountPercentage: 10), img: "breadimg"),
//            MenuItemSwift(menuName: "Teh Tarik", price: 15000, discount: nil, img: "coffeeimg")
//        ]
//        let sampleVouchers = [
//            VoucherSwift(tag: "bank abc", maxDiscountAmount: 50000, minUsageAmount: 100000, img: "logovoucher"),
//            VoucherSwift(tag: "ewallet xyz", maxDiscountAmount: 20000, minUsageAmount: 50000, img: "logovoucher")
//        ]
//
//        let sampleShop = CoffeeShop(
//            name: "Kafe Detail Preview",
//            location: "Jalan Contoh No. 123",
//            distance: 350,
//            steps: 600,
//            calories: 70,
//            latitude: -6.200000,
//            longitude: 106.816666,
//            logo: "starbuckslogo", // Ganti dengan logo yang relevan jika ada
//            headerImageName: "starbucksimg", // Ganti dengan gambar header yang relevan
//            menuItems: sampleMenuItems,
//            vouchers: sampleVouchers
//        )
//        container.mainContext.insert(sampleShop)
//
//        return NavigationStack { // Penting untuk preview navigasi
//            CoffeeShopDetailView(shop: sampleShop)
//        }
//        .modelContainer(container)
//    } catch {
//        return Text("Gagal membuat preview DetailView: \(error.localizedDescription)")
//    }
//}
