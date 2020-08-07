import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    init(repeating elements: [Element], capacity: Int) {
        let repeatable = capacity / elements.count
        let remainder = capacity - repeatable * elements.count

        self.init(
            [[Element]](repeating: elements, count: repeatable).flatMap{ $0 }
                + Array(elements[0..<remainder])
        )
    }

    func repeated(capacity: Int) -> [Element] {
        return [Element](repeating: self, capacity: capacity)
    }

    func stretched(by number: Int) -> [Element] {
        let out = flatMap { element in Array(repeating: element, count: number) }
        return out
    }

    func wrap(first number: Int) -> [Element] {
        let first = Array(self[0..<count - number % count])
        let last = Array(self[first.count..<count])

        return last + first
    }
}

extension StringProtocol {
    var hexa: [UInt8] {
        var startIndex = self.startIndex
        return (0..<count / 2).compactMap { _ in
            let endIndex = index(after: startIndex)
            defer { startIndex = index(after: endIndex) }
            return UInt8(self[startIndex...endIndex], radix: 16)
        }
    }
}

extension Sequence where Element == UInt8 {
    var data: Data { .init(self) }
    var hexa: String { map { .init(format: "%02x ", $0) }.joined() }
}
