//
//  MotionManager.swift
//  ExperienceChallenge
//
//  Created by Hafi on 26/05/25.
//

import Foundation
import CoreMotion // Impor CoreMotion
import Combine   // Untuk @Published

@MainActor // Pastikan update ke @Published terjadi di Main Thread
class MotionManager: ObservableObject {
    private let pedometer = CMPedometer()
    private var sessionStartDate: Date? // Waktu mulai sesi pelacakan

    @Published var isPedometerAvailable: Bool = false
    @Published var stepsSinceSessionStart: Int = 0
    @Published var caloriesBurnedThisSession: Double = 0 // Dihitung dari langkah
    @Published var motionError: String? = nil

    // Faktor perkiraan kalori per langkah (ini sangat kasar, sesuaikan jika perlu)
    // Rata-rata orang membakar sekitar 0.04 - 0.05 kalori per langkah.
    private let caloriesPerStepFactor: Double = 0.045

    init() {
        print("MotionManager: init.")
        self.isPedometerAvailable = CMPedometer.isStepCountingAvailable() && CMPedometer.isPedometerEventTrackingAvailable()
        if !isPedometerAvailable {
            print("MotionManager: Pedometer tidak tersedia di perangkat ini.")
            self.motionError = "Pedometer tidak tersedia di perangkat ini."
        }
    }

    func startTrackingSession() {
        guard isPedometerAvailable else {
            print("MotionManager: Tidak bisa memulai sesi, pedometer tidak tersedia.")
            return
        }

        // Reset data sesi sebelumnya
        resetSessionData()
        sessionStartDate = Date() // Tandai waktu mulai sesi saat ini
        motionError = nil
        print("MotionManager: Memulai sesi pelacakan langkah dari \(sessionStartDate!).")

        pedometer.startUpdates(from: sessionStartDate!) { [weak self] (data, error) in
            // Pedometer updates bisa datang di background thread, jadi pastikan update UI di main thread
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    print("MotionManager: Error menerima update pedometer: \(error.localizedDescription)")
                    self.motionError = "Error data gerakan: \(error.localizedDescription)"
                    // Pertimbangkan untuk menghentikan update jika ada error persisten
                    // self.stopTrackingSession()
                    return
                }

                if let pedometerData = data {
                    print("MotionManager: Menerima data pedometer - Langkah: \(pedometerData.numberOfSteps.intValue)")
                    self.stepsSinceSessionStart = pedometerData.numberOfSteps.intValue
                    // Hitung kalori berdasarkan langkah sesi ini
                    self.caloriesBurnedThisSession = Double(self.stepsSinceSessionStart) * self.caloriesPerStepFactor
                }
            }
        }
    }

    func stopTrackingSession() {
        guard isPedometerAvailable else { return }
        print("MotionManager: Menghentikan sesi pelacakan langkah.")
        pedometer.stopUpdates()
        sessionStartDate = nil // Hapus waktu mulai sesi
    }

    func resetSessionData() {
        print("MotionManager: Mereset data sesi.")
        DispatchQueue.main.async { // Pastikan update @Published di main thread
            self.stepsSinceSessionStart = 0
            self.caloriesBurnedThisSession = 0
            self.motionError = nil
        }
    }
}
