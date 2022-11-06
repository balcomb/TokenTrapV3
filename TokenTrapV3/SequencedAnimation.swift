//
//  SequencedAnimation.swift
//  TokenTrapV3
//
//  Created by Ben Balcomb on 9/18/22.
//

import SwiftUI

struct SequencedAnimation {
    var duration: Double = 0.3
    var delay: Double = 0
    let body: () -> Void

    private var waitTime: Int {
        Int((duration + delay) * 1000)
    }

    static func start(_ sequence: [SequencedAnimation], completion: (() -> Void)? = nil) {
        animate(sequence) { completion?() }
    }

    private static func animate(
        _ sequence: [SequencedAnimation],
        previousAnimation: SequencedAnimation? = nil,
        completion: (() -> Void)?
    ) {
        let waitTime = previousAnimation?.waitTime ?? 0
        guard !sequence.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(waitTime)) {
                completion?()
            }
            return
        }
        var sequence = sequence
        let currentAnimation = sequence.removeFirst()

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(waitTime)) {
            withAnimation(.easeInOut(duration: currentAnimation.duration), currentAnimation.body)
            animate(sequence, previousAnimation: currentAnimation, completion: completion)
        }
    }
}
