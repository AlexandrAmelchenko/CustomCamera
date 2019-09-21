import Foundation
import UIKit


final class FilterManager {

    enum CustomFilterType: CaseIterable {

        case disabled, gaussian, comic, crystalize

        func next() -> CustomFilterType {
            let allCases = type(of: self).allCases
            return allCases[(allCases.index(of: self)! + 1) % allCases.count]
        }

        func prev() -> CustomFilterType {
            let allCases = type(of: self).allCases
            var prevIndex = allCases.index(of: self)! - 1
            if prevIndex < 0 {
                prevIndex = allCases.count - 1
            }
            return allCases[prevIndex]
        }

    }

    private var currentFilter: CustomFilterType = .disabled

    func switchToNextFilter() {
        currentFilter = currentFilter.next()
    }

    func switchTopreviousFilter() {
        currentFilter = currentFilter.prev()
    }

    func selectedFilter() -> CIFilter? {

        switch currentFilter {
        case .disabled:
            return nil
        case .gaussian:
            return CIFilter(name: "CIGaussianBlur")
        case .comic:
            return CIFilter(name: "CIComicEffect")
        case .crystalize:
            return CIFilter(name: "CICrystallize")
        }
    }

}
