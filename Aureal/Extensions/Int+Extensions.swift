import Foundation

// essentially "%", but also works on negative numbers
// via https://stackoverflow.com/a/59461073
infix operator %%
extension Int {
    static func %% (_ left: Int, _ right: Int) -> Int {
        if left >= 0 { return left % right }
        if left >= -right { return (left + right) }
        return ((left % right) + right) % right
    }
}
