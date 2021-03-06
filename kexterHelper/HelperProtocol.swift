

import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func getVersion(completion: @escaping (String) -> Void)
    //func runCommandLs(withPath: String, completion: @escaping (NSNumber) -> Void)
    //func runCommandLs(withPath: String, authData: NSData?, completion: @escaping (NSNumber) -> Void)
    func runCommand(withCommand: [String], withArgs: [[String]], completion: @escaping (NSNumber) -> Void)
    func runCommand(withCommand: [String], withArgs: [[String]], authData: NSData?, completion: @escaping (NSNumber) -> Void)
}

