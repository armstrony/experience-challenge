// DataSeeder.swift
import SwiftUI
import SwiftData

struct DataSeeder {

    static func loadInitialDataIfNeeded(modelContext: ModelContext, jsonFileName: String) {
        print("DataSeeder: Memulai loadInitialDataIfNeeded untuk file: \(jsonFileName).json")
        
        let descriptor = FetchDescriptor<CoffeeShop>()
        var existingShopsCount = 0
        do {
            existingShopsCount = try modelContext.fetchCount(descriptor)
            print("DataSeeder: Jumlah CoffeeShop yang sudah ada di database: \(existingShopsCount)")
        } catch {
            print("DataSeeder: GAGAL memeriksa data yang ada: \(error). Melanjutkan seolah-olah kosong.")
        }

        if existingShopsCount > 0 {
            print("DataSeeder: Data sudah ada (\(existingShopsCount) item). Tidak melakukan load ulang dari JSON.")
            return
        }
        
        print("DataSeeder: Database kosong, melanjutkan untuk memuat data dari JSON...")

        guard let url = Bundle.main.url(forResource: jsonFileName, withExtension: "json") else {
            print("DataSeeder: KRITIKAL - Tidak dapat menemukan file JSON bernama '\(jsonFileName).json' di bundle aplikasi.")
            return
        }
        print("DataSeeder: File JSON ditemukan di URL: \(url)")

        guard let jsonData = try? Data(contentsOf: url) else {
            print("DataSeeder: KRITIKAL - Tidak dapat memuat data dari file JSON di URL: \(url).")
            return
        }
        print("DataSeeder: Berhasil memuat konten data dari file JSON.")

        let decoder = JSONDecoder()
        do {
            let decodedCoffeeShopsData = try decoder.decode([CoffeeShopDecodable].self, from: jsonData)
            print("DataSeeder: Berhasil mem-parse \(decodedCoffeeShopsData.count) item CoffeeShopDecodable dari JSON.")

            if decodedCoffeeShopsData.isEmpty {
                print("DataSeeder: File JSON berhasil di-parse tetapi tidak berisi data. Tidak ada yang dimasukkan.")
                return
            }

            for shopDataDecodable in decodedCoffeeShopsData {
                // 1. Konversi Menu dari [MenuJSON]? ke [MenuItemSwift]
                var swiftMenuItems: [MenuItemSwift] = []
                if let menuJSONArray = shopDataDecodable.menu {
                    swiftMenuItems = menuJSONArray.compactMap { menuJSON -> MenuItemSwift? in
                        var swiftMenuDiscount: MenuDiscountSwift? = nil
                        if let discountJSON = menuJSON.discount {
                            swiftMenuDiscount = MenuDiscountSwift(
                                tag: discountJSON.tag.lowercased(), // Langsung lowercase di sini
                                discountPercentage: discountJSON.discountPercentage
                            )
                        }
                        
                        return MenuItemSwift(
                            // id akan digenerate otomatis oleh UUID() di struct MenuItemSwift
                            menuName: menuJSON.menuName,
                            price: menuJSON.price,
                            discount: swiftMenuDiscount,
                            img: menuJSON.img
                        )
                    }
                }

                // 2. Konversi Voucher dari [VoucherJSON]? ke [VoucherSwift]
                var swiftVouchers: [VoucherSwift] = []
                if let voucherJSONArray = shopDataDecodable.voucher {
                    swiftVouchers = voucherJSONArray.compactMap { voucherJSON -> VoucherSwift? in
                        // Konversi maxDisc dan minUsage ke Int.
                        // Asumsi "30" berarti 30,000 (nilai dalam ribuan). Sesuaikan jika berbeda.
                        let maxDiscountAmountInt = (Int(voucherJSON.maxDisc) ?? 0) * 1000
                        let minUsageAmountInt = (Int(voucherJSON.minUsage) ?? 0) * 1000
                        
                        return VoucherSwift(
                            // id akan digenerate otomatis
                            tag: voucherJSON.tag.lowercased(), // Langsung lowercase
                            maxDiscountAmount: maxDiscountAmountInt,
                            minUsageAmount: minUsageAmountInt,
                            img: voucherJSON.img
                        )
                    }
                }

                // 3. Buat objek @Model CoffeeShop
                // 'id' akan otomatis di-set dari 'name' di dalam init CoffeeShop.
                // 'aggregatedPromoTags' juga akan otomatis dihitung di dalam init CoffeeShop.
                let newShop = CoffeeShop(
                    name: shopDataDecodable.name,
                    location: shopDataDecodable.location,
                    distance: shopDataDecodable.distance,
                    steps: shopDataDecodable.steps,
                    calories: shopDataDecodable.calories,
                    latitude: shopDataDecodable.latitude,
                    longitude: shopDataDecodable.longitude,
                    logo: shopDataDecodable.logo,
                    headerImageName: shopDataDecodable.img, // Dari field 'img' di JSON
                    menuItems: swiftMenuItems,
                    vouchers: swiftVouchers
                )
                
                modelContext.insert(newShop)
                print("DataSeeder: Memasukkan ke context: \(newShop.name) - Menu: \(newShop.menuItems.count) item, Voucher: \(newShop.vouchers.count) item. AggregatedTags: '\(newShop.aggregatedPromoTags)'")
            }

            try modelContext.save()
            print("DataSeeder: SUKSES - Data CoffeeShop (total \(decodedCoffeeShopsData.count) item) berhasil disimpan ke SwiftData.")

        } catch {
            print("DataSeeder: KRITIKAL - Gagal mem-parse JSON atau mengonversi/menyimpan data: \(error)")
            print("DataSeeder: Error localized description: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("DataSeeder: Detail Decoding Error:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("  - Type '\(type)' mismatch: \(context.debugDescription)")
                    print("  - CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .valueNotFound(let type, let context):
                    print("  - Value '\(type)' not found: \(context.debugDescription)")
                    print("  - CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .keyNotFound(let key, let context):
                    print("  - Key '\(key.stringValue)' not found: \(context.debugDescription)")
                    print("  - CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .dataCorrupted(let context):
                    print("  - Data corrupted: \(context.debugDescription)")
                    print("  - CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                @unknown default:
                    print("  - Unknown decoding error: \(decodingError)")
                }
            }
        }
    }
}
