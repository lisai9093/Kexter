

import Foundation

@objc(AppProtocol)
protocol AppProtocol {
    func log(stdOut: String) -> Void
    func log(stdErr: String) -> Void
}

protocol mainCommand: class {
    func checkHelper()
    func debugPrint()
}
