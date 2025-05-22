import SwiftUI
import CoreLocation
import SwiftData


struct Homepage: View {
    @Environment(\.modelContext) private var modelContext // Untuk dioper ke ViewModel
    
    // Gunakan @StateObject untuk instance ViewModel
    // Ini memastikan ViewModel hidup selama View ini hidup
    @StateObject private var viewModel: HomepageViewModel
    
    // Custom init untuk menginisialisasi ViewModel dengan modelContext saat Homepage dibuat
    init(modelContext: ModelContext, healthKitManager: HealthKitManager, locationManager: LocationManager) {
        // Cara yang benar untuk menginisialisasi @StateObject dengan parameter di init
        _viewModel = StateObject(wrappedValue: HomepageViewModel(modelContext: modelContext, healthKitManager: healthKitManager, locationManager: locationManager))
        print("Homepage: ViewModel diinisialisasi melalui init.")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { WelcomeText(bodyText: viewModel.welcomeMessageBody); Spacer() }
                
                NavigationLink(destination: CoffeeShopListView(title: "Coffee Shops Around You", shops: viewModel.allCoffeeShops, userLocation: viewModel.currentUserLocation)) {
                    SearchButtonsView()
                }
                .buttonStyle(PlainButtonStyle())
                // Menampilkan loading indicator atau konten berdasarkan state ViewModel
                if viewModel.isLoading {
                    ProgressView("Memuat data...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else {
                    // Section: Sip and Save (Diskon Terbesar)
                    if !viewModel.topDiscountShops.isEmpty {
                        SectionView(
                            title: "Sip and Save", // Judul section baru
                            shops: viewModel.topDiscountShops,
                            userLocation: viewModel.currentUserLocation
                        )
                    } else {
                        Text("Belum ada diskon spesial yang menonjol saat ini.")
                            .foregroundColor(.secondary)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    // Section: Digital Wallets & Card Perks
                    // Ambil data dari viewModel.ewalletAndBankShops
                    if !viewModel.ewalletAndBankShops.isEmpty {
                        SectionView(title: "E-Wallets & Card Perks", shops: viewModel.ewalletAndBankShops, userLocation: viewModel.currentUserLocation)
                    } else {
                        Text("Saat ini tidak ada promo e-wallet atau bank.")
                            .foregroundColor(.secondary)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    // Section: Food Selections
                    // Ambil data dari viewModel.foodShops
                    if !viewModel.foodShops.isEmpty {
                        SectionView(title: "Food Selections", shops: viewModel.foodShops, userLocation: viewModel.currentUserLocation)
                    } else {
                        Text("Saat ini tidak ada promo makanan.")
                            .foregroundColor(.secondary)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 20, trailing: 15))
        }
        .onAppear {
            print("Homepage: .onAppear, memanggil viewModel.fetchData() dan locationManager.startUpdatingLocation()")
            viewModel.fetchData() // Untuk data coffee shop
            viewModel.locationManager.startUpdatingLocation() // Mulai update lokasi
        }
        .onDisappear {
            print("Homepage: .onDisappear, memanggil locationManager.stopUpdatingLocation()")
            viewModel.locationManager.stopUpdatingLocation() // Hentikan update lokasi
        }
    }
    
}

// Komponen View baru untuk menampilkan setiap section
struct SectionView: View {
    let title: String
    let shops: [CoffeeShop] // Daftar shop untuk section ini
    let userLocation: CLLocation?
    
    // Padding horizontal standar untuk judul section dan item pertama di kiri
    private let leadingSectionPadding: CGFloat = 20
    // Jarak antar card
    private let cardSpacing: CGFloat = 8
    // Berapa banyak bagian dari card berikutnya yang ingin terlihat "mengintip"
    // Anda bisa sesuaikan nilai ini. Jika card Anda lebar 165, mungkin 30-50pt sudah cukup.
    // Atau, cara yang lebih sederhana adalah membiarkan padding kanan LazyHStack lebih kecil dari layar.
    // Untuk efek seperti di desain Anda, di mana hanya sebagian kecil card berikutnya terlihat,
    // kita bisa atur padding kanan pada LazyHStack agar tidak semua konten termuat penuh di layar awal.
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                //                Spacer()
                // Bungkus "View All" dengan NavigationLink
                NavigationLink(destination: CoffeeShopListView(title: title, shops: shops, userLocation: userLocation)) {
                    Image(systemName: "chevron.forward")
                        .font(.title3) // Sedikit lebih kecil agar tidak terlalu dominan
                        .fontWeight(.bold)
                        .foregroundColor(Color("brownapp")) // Pastikan warna ini ada di assets
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: cardSpacing) {
                    ForEach(shops.prefix(4)) { shop in
                        // Kita perlu membuat ShopCardView bisa dinavigasi juga jika diklik
                        // atau biarkan hanya "View All" yang bisa navigasi ke list.
                        // Untuk sekarang, kita fokus pada "View All".
                        NavigationLink(destination: CoffeeShopDetailView(shop: shop, userLocation: userLocation)){
                            ShopCardView(
                                shop: shop,
                                userLocation: userLocation
                            )
                            .frame(width: 165, height: 250)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 260)
        }
    }
    
    // Pindahkan atau buat ulang fungsi determineDiscountText jika diperlukan
    private func determineDiscountText(for shop: CoffeeShop) -> String {
        if shop.aggregatedPromoTags.contains("bank") {
            return "Bank"
        } else if shop.aggregatedPromoTags.contains("ewallet") {
            return "E-wallet"
        }
        return "Special Offer"
    }
}


// Modifikasi ShopCardView untuk menerima data secara dinamis
struct ShopCardView: View {
    let shop: CoffeeShop // Tambahkan ini
    let userLocation: CLLocation? // Tambahkan ini
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // 1) Shop Image
                Image(shop.logo) // Pastikan gambar ada di Assets.xcassets
                    .resizable()
                    .aspectRatio(contentMode: .fit) // .cover mungkin lebih baik untuk mengisi frame
                    .frame(height: 150) // Beri tinggi agar konsisten
                    .clipped()
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                
                // 2) Discount badge (hanya tampilkan jika ada teks)
                // Tampilkan badge diskon jika bestPromoText ada
                if let promoText = shop.bestPromoText { // Menggunakan computed property baru
                    Text(promoText)
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding([.top, .leading], 5) // Sesuaikan padding badge
                }
            }
            
            // 3) Info area
            VStack(alignment: .leading, spacing: 5) { // Sesuaikan spacing
                Text(shop.name)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true) // Agar teks bisa wrap
                
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.subheadline)
                        .foregroundColor(Color("brownpromo", bundle: nil))
                    Text("\(shop.activePromoCount) Promos")
                        .font(.subheadline)
                        .foregroundColor(Color("brownpromo", bundle: nil))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(shop.displayDistance(userLocation: userLocation))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10) // Padding di dalam area info
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100) // Sesuaikan tinggi area info jika perlu
            .background(Color(UIColor.systemGray6)) // Warna latar yang adaptif
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
        }
        .frame(width: 165) // Lebar total kartu
        .background(Color(UIColor.systemBackground)) // Latar belakang kartu keseluruhan
        .cornerRadius(12) // Corner radius untuk seluruh kartu
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// Helper Views (SearchAndPromoButtonsView, WelcomeText, RoundedCorner)
// tidak perlu diubah dari kode asli Anda, kecuali jika ada penyesuaian lain.

struct SearchButtonsView: View {
    @State private var searchText = ""
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.primary)
                TextField("Looking For Nearby Coffee Shops?", text: $searchText)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(15)
            .disabled(true)
        }
    }
}

struct WelcomeText: View {
    let bodyText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Great coffee offers await!")
                .foregroundColor(.primary)
                .fontWeight(.bold)
                .font(.title2)
            Text(LocalizedStringKey(bodyText))
                .font(.subheadline)
                .fontWeight(.light)
        }
    }
}

fileprivate extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

fileprivate struct RoundedCorner: Shape {
    var radius: CGFloat = 0
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Preview Provider untuk Homepage
//#Preview {
//    // Buat model container in-memory untuk preview
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    do {
//        let container = try ModelContainer(for: CoffeeShop.self, configurations: config)
//
//        // (WAJIB untuk preview yang baik) Isi data contoh atau panggil DataSeeder
//        // Contoh:
//        let sampleShop1 = CoffeeShop(name: "Preview Starbucks", location: "Preview Location", tag: "ewallet,food,bank", distance: 100, steps: 150, calories: 20, latitude: 0, longitude: 0, logo: "sbux")
//        let sampleShop2 = CoffeeShop(name: "Preview Kenangan", location: "The Breeze", tag: "ewallet", distance: 350, steps: 580, calories: 50, latitude: -6.301535, longitude: 106.653458, logo: "kenangan")
//        let sampleShop3 = CoffeeShop(name: "Preview Lawson", location: "GOP 6", tag: "ewallet,drink,food", distance: 490, steps: 780, calories: 68, latitude: -6.302592, longitude: 106.65338, logo: "lawsonlogo")
//
//        container.mainContext.insert(sampleShop1)
//        container.mainContext.insert(sampleShop2)
//        container.mainContext.insert(sampleShop3)
//
//        // Atau jika ingin data JSON lengkap di preview:
//        // DataSeeder.loadInitialDataIfNeeded(modelContext: container.mainContext, jsonFileName: "coffee_shop") // Ganti nama file jika perlu
//
//        // Inisialisasi Homepage dengan modelContext dari container preview
//        return Homepage(modelContext: container.mainContext)
//            .modelContainer(container) // Sediakan container untuk environment
//
//    } catch {
//        return Text("Gagal membuat preview: \(error.localizedDescription)")
//    }
//}
