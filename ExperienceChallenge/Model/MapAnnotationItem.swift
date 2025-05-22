//
//  MapAnnotationItem.swift
//  ExplorationChallenge
//
//  Created by Hafi on 22/05/25.
//

import Foundation
import MapKit // Diperlukan untuk CLLocationCoordinate2D
import SwiftUI // Diperlukan untuk Color

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    var tint: Color = .blue // Warna default, bisa diubah saat pembuatan instance
}
