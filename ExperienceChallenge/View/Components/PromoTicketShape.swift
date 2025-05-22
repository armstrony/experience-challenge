//
//  Coupon.swift
//  ExplorationChallenge
//
//  Created by Hafi on 17/05/25.
//

// PromoTicketShape.swift
// PromoTicketShape.swift
import SwiftUI

struct PromoTicketShape: Shape {
    var notchRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notchRadius))
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.midY),
                    radius: notchRadius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(90),
                    clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + notchRadius))
        path.addArc(center: CGPoint(x: rect.minX, y: rect.midY),
                    radius: notchRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(-90),
                    clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
