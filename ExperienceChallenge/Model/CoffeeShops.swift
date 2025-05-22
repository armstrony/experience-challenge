// CoffeeShop.swift

import SwiftUI
import SwiftData
import CoreLocation // Impor CoreLocation untuk CLLocation dan CLLocationDistance perubahan dikit

// MARK: - Decodable Structs (Untuk Parsing JSON)

struct MenuDiscountJSON: Decodable, Hashable {
    let tag: String
    let discountPercentage: Int
}

struct MenuJSON: Decodable, Hashable {
    let menuName: String
    let price: Int
    let discount: MenuDiscountJSON?
    let img: String
}

struct VoucherJSON: Decodable, Hashable {
    let tag: String
    let maxDisc: String
    let minUsage: String
    let img: String
}

struct CoffeeShopDecodable: Decodable {
    let name: String
    let location: String
    let distance: Int
    let steps: Int
    let calories: Int
    let latitude: Double
    let longitude: Double
    let logo: String
    let img: String
    let menu: [MenuJSON]?
    let voucher: [VoucherJSON]?
}

// MARK: - Swift Structs for Model (Untuk Disimpan di SwiftData @Model)

struct MenuDiscountSwift: Codable, Hashable {
    let tag: String
    let discountPercentage: Int
    
    var isActive: Bool {
        return discountPercentage > 0
    }
}

struct MenuItemSwift: Codable, Identifiable, Hashable {
    var id = UUID()
    let menuName: String
    let price: Int
    let discount: MenuDiscountSwift?
    let img: String
    
    var hasActiveDiscount: Bool {
        return discount?.isActive ?? false
    }
    
    var activeDiscountTag: String? {
        if hasActiveDiscount {
            return discount?.tag
        }
        return nil
    }
}

struct VoucherSwift: Codable, Identifiable, Hashable {
    var id = UUID()
    let tag: String
    let maxDiscountAmount: Int
    let minUsageAmount: Int
    let img: String
}

// MARK: - SwiftData @Model Definition

@Model
final class CoffeeShop: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var location: String
    
    // Properti ini adalah nilai default/statis dari JSON
    var staticDistance: Int
    var staticSteps: Int
    var staticCalories: Int
    
    var latitude: Double
    var longitude: Double
    var logo: String
    var headerImageName: String
    
    var menuItems: [MenuItemSwift] = []
    var vouchers: [VoucherSwift] = []
    var aggregatedPromoTags: String = ""
    
    var maxEffectiveDiscountValue: Double = 0.0
    // MARK: - Initializer
    init(
        name: String, // ID akan diambil dari nama
        location: String,
        distance: Int, // Ini akan menjadi staticDistance
        steps: Int,    // Ini akan menjadi staticSteps
        calories: Int, // Ini akan menjadi staticCalories
        latitude: Double,
        longitude: Double,
        logo: String,
        headerImageName: String,
        menuItems: [MenuItemSwift] = [],
        vouchers: [VoucherSwift] = []
    ) {
        self.id = name // Menggunakan nama sebagai ID unik
        self.name = name
        self.location = location
        self.staticDistance = distance
        self.staticSteps = steps
        self.staticCalories = calories
        self.latitude = latitude
        self.longitude = longitude
        self.logo = logo
        self.headerImageName = headerImageName
        self.menuItems = menuItems
        self.vouchers = vouchers
        
        // Mengisi aggregatedPromoTags berdasarkan menuItems dan vouchers
        var activeTagsSetForStorage = Set<String>()
        vouchers.forEach { voucher in
            // Asumsi tag di VoucherSwift sudah lowercase dari DataSeeder
            voucher.tag
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .forEach { activeTagsSetForStorage.insert($0) }
        }
        menuItems.forEach { menuItem in
            if let discount = menuItem.discount, discount.isActive {
                // Asumsi tag di MenuDiscountSwift sudah lowercase dari DataSeeder
                discount.tag
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .forEach { activeTagsSetForStorage.insert($0) }
            }
        }
        self.aggregatedPromoTags = activeTagsSetForStorage.sorted().joined(separator: ",")
        
        // --- MENGHITUNG maxEffectiveDiscountValue (LOGIKA BARU) ---
        var currentMaxSaving: Double = 0.0
        
        // Evaluasi diskon dari item menu
        for menuItem in self.menuItems {
            if let discount = menuItem.discount, discount.isActive {
                let absoluteSavingFromMenu = Double(menuItem.price) * (Double(discount.discountPercentage) / 100.0)
                if absoluteSavingFromMenu > currentMaxSaving {
                    currentMaxSaving = absoluteSavingFromMenu
                }
            }
        }
        
        // Evaluasi diskon dari voucher
        for voucher in self.vouchers {
            // voucher.maxDiscountAmount sudah merupakan nilai absolut Rupiah
            let absoluteSavingFromVoucher = Double(voucher.maxDiscountAmount)
            if absoluteSavingFromVoucher > currentMaxSaving {
                currentMaxSaving = absoluteSavingFromVoucher
            }
        }
        self.maxEffectiveDiscountValue = currentMaxSaving
        // --- AKHIR MENGHITUNG maxEffectiveDiscountValue ---
    }
    
    
    
    // MARK: - Computed Properties & Methods for Promo Display
    
    var activePromoCount: Int {
        var count = 0
        count += self.vouchers.count
        for menuItem in self.menuItems {
            if menuItem.hasActiveDiscount {
                count += 1
            }
        }
        return count
    }
    
    
    var uniqueActivePromoTagsArray: [String] {
        var activeTagsSet = Set<String>()
        vouchers.forEach { voucher in
            voucher.tag // Asumsi sudah lowercase
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .forEach { activeTagsSet.insert($0) }
        }
        menuItems.forEach { menuItem in
            if let discount = menuItem.discount, discount.isActive {
                discount.tag // Asumsi sudah lowercase
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .forEach { activeTagsSet.insert($0) }
            }
        }
        return Array(activeTagsSet).sorted()
    }
    // Computed property BARU untuk mendapatkan teks promo terbaik
    var bestPromoText: String? {
        var maxAbsoluteSaving: Double = 0.0
        var currentBestPromoDescription: String? = nil
        
        // 1. Evaluasi diskon dari item menu
        for menuItem in self.menuItems {
            if let discount = menuItem.discount, discount.isActive { // isActive memeriksa discountPercentage > 0
                // Hitung nilai potongan absolut dari diskon menu
                let absoluteSavingFromMenu = Double(menuItem.price) * (Double(discount.discountPercentage) / 100.0)
                
                if absoluteSavingFromMenu > maxAbsoluteSaving {
                    maxAbsoluteSaving = absoluteSavingFromMenu
                    let savingInK = Int(round(absoluteSavingFromMenu / 1000.0)) // Bulatkan ke ribuan terdekat
                    if savingInK > 0 {
                        currentBestPromoDescription = "\(savingInK)rb Off" // Format seperti "50rb Off"
                    } else if discount.discountPercentage > 0 {
                        // Jika potongannya kecil tapi ada persentase, tampilkan persentase
                        currentBestPromoDescription = "\(discount.discountPercentage)% Off"
                    }
                }
            }
        }
        
        // 2. Evaluasi diskon dari voucher
        for voucher in self.vouchers {
            // voucher.maxDiscountAmount sudah merupakan nilai absolut (misal 25000 untuk 25rb)
            let absoluteSavingFromVoucher = Double(voucher.maxDiscountAmount)
            
            if absoluteSavingFromVoucher > maxAbsoluteSaving {
                maxAbsoluteSaving = absoluteSavingFromVoucher
                let savingInK = Int(round(absoluteSavingFromVoucher / 1000.0))
                if savingInK > 0 {
                    currentBestPromoDescription = "\(savingInK)rb Off" // Format "Xrb Off"
                }
            }
        }
        
        // Jika tidak ada diskon sama sekali yang menghasilkan nilai > 0,
        // kita bisa kembalikan nil atau string default.
        // Untuk label merah, kita hanya ingin tampilkan jika ada promo signifikan.
        if maxAbsoluteSaving > 0 {
            return currentBestPromoDescription
        } else {
            return nil // Tidak ada promo yang menonjol untuk ditampilkan di label utama
        }
    }
    // MARK: - Methods for Dynamic Location-Based Data
    
    // Menghitung jarak mentah dalam meter dari lokasi pengguna
    func distanceFrom(userLocation: CLLocation?) -> CLLocationDistance? {
        guard let userLoc = userLocation else { return nil }
        // Pastikan latitude dan longitude CoffeeShop valid
        guard self.latitude != 0 && self.longitude != 0 else { return nil } // Hindari lokasi (0,0) jika data tidak valid
        let shopLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        return userLoc.distance(from: shopLocation)
    }
    
    // Menampilkan jarak yang sudah diformat (dinamis atau statis)
    func displayDistance(userLocation: CLLocation?) -> String {
        if let dynamicDistance = distanceFrom(userLocation: userLocation) {
            if dynamicDistance < 1000 {
                return String(format: "%.0f m", dynamicDistance)
            } else {
                return String(format: "%.1f km", dynamicDistance / 1000)
            }
        } else {
            // Fallback ke data statis jika lokasi pengguna tidak tersedia
            if self.staticDistance < 1000 {
                return "\(self.staticDistance) m" // Hapus "(perkiraan)" jika tidak perlu
            } else {
                // Perhatikan pembagian integer jika staticDistance adalah Int
                return String(format: "%.1f km", Double(self.staticDistance) / 1000.0)
            }
        }
    }
    
    // Menghitung perkiraan langkah (dinamis atau statis)
    func displaySteps(userLocation: CLLocation?) -> String {
        if let dynamicDistance = distanceFrom(userLocation: userLocation) {
            // Asumsi sederhana: 1 meter = 1.3 langkah (sesuaikan faktor ini)
            let dynamicSteps = Int(dynamicDistance * 1.3)
            return "\(dynamicSteps) steps"
        } else {
            // Fallback ke data statis
            return "\(self.staticSteps) steps"
        }
    }
    
    // Menghitung perkiraan kalori (dinamis atau statis)
    func displayCalories(userLocation: CLLocation?) -> String {
        if let dynamicDistance = distanceFrom(userLocation: userLocation) {
            // Asumsi sederhana: 1km (1000m) = 70 kalori (sesuaikan faktor ini)
            // Atau bisa berdasarkan langkah: 20 langkah = 1 kalori
            let dynamicSteps = Int(dynamicDistance * 1.3) // Faktor langkah sama seperti di atas
            let dynamicCalories = dynamicSteps / 20 // Faktor kalori per langkah
            return "\(dynamicCalories) kcal"
        } else {
            // Fallback ke data statis
            return "\(self.staticCalories) kcal"
        }
    }
}
