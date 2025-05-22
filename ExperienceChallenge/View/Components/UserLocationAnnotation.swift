//
//  UserLocationAnnotation.swift
//  ExplorationChallenge
//
//  Created by Hafi on 22/05/25.
//

import SwiftUI
import CoreLocation // Diperlukan untuk CLLocationDirection

struct UserLocationAnnotation: View {
    var heading: CLLocationDirection? // Arah hadap dalam derajat (0-359.9)

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "location.north.fill") // Ikon panah default
                .font(.title) // Ukuran ikon
                .foregroundColor(.white) // Warna ikon
                .padding(6) // Padding di dalam lingkaran
                .background(Color.blue) // Warna latar belakang lingkaran
                .clipShape(Circle())
                .shadow(radius: 3)
                .rotationEffect(Angle(degrees: heading ?? 0)) // Putar ikon sesuai arah hadap
            
            // Opsional: Anda bisa menambahkan elemen lain di sini jika perlu
            // misalnya, lingkaran yang menunjukkan akurasi lokasi.
        }
    }
}

//#Preview {
//    UserLocationAnnotation(heading: 45)
//        .padding()
//        .background(Color.gray.opacity(0.2))
//}
