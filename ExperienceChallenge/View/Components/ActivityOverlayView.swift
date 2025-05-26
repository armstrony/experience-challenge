//
//  ActivityOverlayView.swift
//  ExperienceChallenge
//
//  Created by Hafi on 26/05/25.
//

import SwiftUI

struct ActivityOverlayView: View {
    let steps: Int
    let calories: Double
    var onExit: () -> Void
    
    private func formatSteps(_ number: Int) -> String {
        return "\(number)"
    }
    private func formatCalories(_ number: Double) -> String {
        return String(format: "%.0f", number)
    }
    
    var body: some View {
        Spacer()
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image (systemName: "figure.walk")
                    .padding(.bottom)
                Text("Your Activity")
                    .foregroundColor(Color.brownapp)
                    .padding(.bottom)
                    .fontWeight(.bold)
                Spacer()
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red.opacity(0.8))
                }
                .padding(.bottom)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Move")
                        .font(.headline)
                        .foregroundStyle(Color.brownapp)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatCalories(calories))
                            .font(.title)
                            .foregroundStyle(.primary)
                        
                        Text("CAL")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                    }
                }
                
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Steps")
                        .font(.headline)
                        .foregroundStyle(Color.brownapp)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatSteps(steps))
                            .font(.title)
                            .foregroundStyle(.primary)
                        Text("STEPS")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 320, height: 130)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

#Preview {
    ActivityOverlayView(steps: 5320, calories: 210, onExit: {
        print("Tombol Exit ditekan di preview")
    })// Latar belakang untuk preview agar overlay terlihat
}
