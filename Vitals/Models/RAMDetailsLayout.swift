//
//  RAMDetailsLayout.swift
//  Vitals
//
//  Created by gd182 on 11/7/26.
//

nonisolated enum RAMDetailsLayout {
    static func showsUsedAndTotal(
        indicatorStyle: RAMIndicatorStyle,
        indicatorsVisible: Bool,
        repeatIndicatorValues: Bool
    ) -> Bool {
        if !indicatorsVisible || repeatIndicatorValues || indicatorStyle == .ring {
            return true
        }
        return false
    }
}