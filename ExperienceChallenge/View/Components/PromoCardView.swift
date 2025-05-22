//
//  PromoCardView.swift
//  ExplorationChallenge
//
//  Created by Hafi on 18/05/25.
//

// PromoCardView.swift
import SwiftUI

struct PromoCardView: View {
    let voucher: VoucherSwift // Sekarang menerima VoucherSwift

    var body: some View {
        HStack(spacing: 12) {
            // Tampilkan logo voucher jika ada
            Image(voucher.img) // Nama field di VoucherSwift adalah 'img'
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44) // Ukuran logo bisa disesuaikan
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.leading, 4) // Sedikit padding agar logo tidak terlalu mepet

            VStack(alignment: .leading, spacing: 4) {
                // Judul Promo bisa diambil dari tag voucher atau kombinasi
                Text("Diskon \(voucher.tag.capitalized)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Deskripsi bisa dari maxDiscountAmount dan minUsageAmount
                Text("Maks Diskon: Rp \(voucher.maxDiscountAmount / 1000)rb") // Asumsi dalam ribuan
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Min. Pemakaian: Rp \(voucher.minUsageAmount / 1000)rb") // Asumsi dalam ribuan
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer() // Mendorong konten ke kiri
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 16))
        // Ukuran kartu promo bisa lebih fleksibel atau fixed
        .frame(minWidth: 280, idealHeight: 90, maxHeight: 100) // Sesuaikan
        .background(
            PromoTicketShape(notchRadius: 10) // Gunakan shape kustom
                .fill(Color(UIColor.secondarySystemGroupedBackground)) // Warna latar tiket
        )
        .overlay(
            PromoTicketShape(notchRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Optional: border
        )
    }
}
