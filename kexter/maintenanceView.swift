//
//  maintenanceView.swift
//  Kexter
//
//  Created by Sai Zhou on 2/19/19.
//

import Foundation
import Cocoa
import ServiceManagement

class maintenance: NSViewController, AppProtocol {
    var destiny = String()
    private var dragDropType = NSPasteboard.PasteboardType.fileURL
    @IBOutlet weak var sleCheck: NSButton!
    @IBOutlet weak var slePermissionCheck: NSButton!
    @IBOutlet weak var leCheck: NSButton!
    @IBOutlet weak var lePermissionCheck: NSButton!
    @IBOutlet weak var cacheCheck: NSButton!
    @IBOutlet weak var executeButton: NSButton!
    @IBOutlet weak var maintenanceProgress: NSProgressIndicator!
    
    @objc dynamic private var helperIsInstalled = false
    @objc dynamic var currentHelperAuthData: NSData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //set install button to default
        executeButton.keyEquivalent = "\r"
        
        currentHelperAuthDataKeyPath = NSStringFromSelector(#selector(getter: self.currentHelperAuthData))
        helperIsInstalledKeyPath = NSStringFromSelector(#selector(getter: self.helperIsInstalled))
        
        do {
            try HelperAuthorization.authorizationRightsUpdateDatabase()
        } catch {
            //self.textViewOutput.appendText("Failed to update the authorization database rights with error: \(error)")
        }
        executeButton.isEnabled = false
        OperationQueue.main.maxConcurrentOperationCount = 1
        self.helperStatus { installed in
            OperationQueue.main.addOperation {
                //self.textFieldHelperInstalled.stringValue = (installed) ? "Yes1" : "No1"
                
                self.setValue(installed, forKey: helperIsInstalledKeyPath)
                helperInstalled = installed
                globalHelperIsInstalled = installed
                self.executeButton.isEnabled = true
            }
        }
        //OperationQueue.main.addOperation(completionOperation)
    }
    
    @IBAction func sleCheck(_ sender: Any) {
        if sleCheck.state == .on {
            slePermissionCheck.state = .on
            cacheCheck.state = .on
        } else if sleCheck.state == .off {
            slePermissionCheck.state = .off
            cacheCheck.state = .off
        } else {
            //mixed not allowed for user, so change to on
            sleCheck.state = .on
            slePermissionCheck.state = .on
            cacheCheck.state = .on
        }
    }
    @IBAction func slePermissionCheck(_ sender: Any) {
        if slePermissionCheck.state == .on {
            if cacheCheck.state == .on {
                sleCheck.state = .on
            } else {
                sleCheck.state = .mixed
            }
        } else {
            if cacheCheck.state == .on {
                sleCheck.state = .mixed
            } else {
                sleCheck.state = .off
            }
        }
    }
    @IBAction func leCheck(_ sender: Any) {
        if leCheck.state == .on {
            lePermissionCheck.state = .on
            cacheCheck.state = .on
        } else if leCheck.state == .off {
            lePermissionCheck.state = .off
            cacheCheck.state = .off
        } else {
            //mixed not allowed for user, so change to on
            leCheck.state = .on
            lePermissionCheck.state = .on
            cacheCheck.state = .on
        }
    }
    @IBAction func lePermissionCheck(_ sender: Any) {
        if lePermissionCheck.state == .on {
            if cacheCheck.state == .on {
                leCheck.state = .on
            } else {
                leCheck.state = .mixed
            }
        } else {
            if cacheCheck.state == .on {
                leCheck.state = .mixed
            } else {
                leCheck.state = .off
            }
        }
    }
    @IBAction func cacheCheck(_ sender: Any) {
        if cacheCheck.state == .on {
            if slePermissionCheck.state == .on {
                sleCheck.state = .on
            } else {
                sleCheck.state = .mixed
            }
            if lePermissionCheck.state == .on {
                leCheck.state = .on
            } else {
                leCheck.state = .mixed
            }
        } else {
            if slePermissionCheck.state == .on {
                sleCheck.state = .mixed
            } else {
                sleCheck.state = .off
            }
            if lePermissionCheck.state == .on {
                leCheck.state = .mixed
            } else {
                leCheck.state = .off
            }
        }
    }
    
    @IBAction func executeButton(_ sender: Any) {
        checkHelper()
        if sleCheck.state == .off, leCheck.state == .off{
            dialogAlert(question: "Error", text: "You haven't selected any option.")
            return
        }
        maintenanceProgress.isIndeterminate = false
        maintenanceProgress.doubleValue = 0.0
        maintenanceProgress.isIndeterminate = true
        maintenanceProgress.startAnimation(nil)
        commandView()
    }
    
    func checkHelper() {
        // Check if the current embedded helper tool is installed on the machine. Install helper if found no helper
        if globalHelperIsInstalled {
            self.helperIsInstalled = globalHelperIsInstalled
        }
        self.helperStatus { installed in
            OperationQueue.main.addOperation {
                //self.textFieldHelperInstalled.stringValue = (installed) ? "Yes" : "No"
                helperInstalled = installed
                self.setValue(installed, forKey: helperIsInstalledKeyPath)
            }
        }
        
        //need install?
        //if !globalHelperIsInstalled {
        if !helperIsInstalled {
            //install helper
            do {
                if try self.helperInstall() {
                    OperationQueue.main.addOperation {
                        //self.textViewOutput.appendText("Helper installed successfully.")
                        //self.textFieldHelperInstalled.stringValue = "Yes"
                        self.setValue(true, forKey: helperIsInstalledKeyPath)
                        globalHelperIsInstalled = true
                    }
                    //authentication pass, run following command
                    
                    return
                } else {
                    OperationQueue.main.addOperation {
                        //self.textFieldHelperInstalled.stringValue = "No"
                        //self.textViewOutput.appendText("Failed install helper with unknown error.")
                    }
                }
            } catch {
                OperationQueue.main.addOperation {
                    //self.textViewOutput.appendText("Failed to install helper with error: \(error)")
                }
            }
            OperationQueue.main.addOperation {
                //self.textFieldHelperInstalled.stringValue = "No"
                self.setValue(false, forKey: helperIsInstalledKeyPath)
            }
        }
    }
    
    func commandView() {
        guard
            let helper = self.helper(nil) else { return }
        
        //prepare commands
        var command = [String]()
        var option = [String]()
        var allPaths = [String]()
        var destinyPath = [String]()
        let backupPath = String()
        
        //permission change:
        if slePermissionCheck.state == .on {
            //sudo chmod -Rf 755 /S*/L*/E* and sudo chown -Rf 0:0 /S*/L*/E*
            //chmod 0755 location/*/Contents/MacOS/*
            //chmod 0755 lcoation/*/Contents/PlugIns/*/Contents/MacOS/*
            let N = 2
            let addCommand = ["/bin/chmod","/usr/sbin/chown"]
            let addOption = [String](repeating: "-Rf", count: N)
            let addAllPaths = ["755", "0:0"]
            //destinyPath = ["/L*/E*", "/L*/E*"]
            let addDestinyPath = [SLE, SLE]
            
            //add operation
            command = command + addCommand
            option = option + addOption
            allPaths = allPaths + addAllPaths
            destinyPath = destinyPath + addDestinyPath
        }
        if lePermissionCheck.state == .on {
            //sudo chmod -Rf 755 /L*/E* and sudo chown -Rf 0:0 /L*/E*
            let N = 2
            let addCommand = ["/bin/chmod","/usr/sbin/chown"]
            let addOption = [String](repeating: "-Rf", count: N)
            let addAllPaths = ["755", "0:0"]
            //destinyPath = ["/L*/E*", "/L*/E*"]
            let addDestinyPath = [LE, LE]
            
            //add operation
            command = command + addCommand
            option = option + addOption
            allPaths = allPaths + addAllPaths
            destinyPath = destinyPath + addDestinyPath
        }
        if cacheCheck.state == .on {
            //sudo kextcache -i /
            //let N = 3
            let addCommand = ["/usr/sbin/kextcache"]
            let addOption = ["-i"]
            let addAllPaths = ["/"]
            //destinyPath = ["/L*/E*", "/L*/E*"]
            let addDestinyPath = [""]
            
            //add operation
            command = command + addCommand
            option = option + addOption
            allPaths = allPaths + addAllPaths
            destinyPath = destinyPath + addDestinyPath
        }
        
        
        //copy if auth existed already
        currentHelperAuthData = installAuthData ?? currentHelperAuthData
        do {
            guard let authData = try self.currentHelperAuthData ?? HelperAuthorization.emptyAuthorizationExternalFormData() else {
                //self.textViewOutput.appendText("Failed to get the empty authorization external form")
                return
            }
            /*
            for i in allPaths.indices {
                let stringPrint = command[i] + " " + option[i] + " " + allPaths[i] + " " + destinyPath[i]
                //self.textViewOutput.appendText(stringPrint)
            }
             */
            //run command
            executeButton.isEnabled = false
            //let N = Double(command.count)
            helper.runCommand(withCommand: command, withOption: option, withPath: allPaths, withDest: destinyPath, withBackup: backupPath, authData: authData) { (exitCode) in
                OperationQueue.main.addOperation {
                    // Verify that authentication was successful
                    guard exitCode != kAuthorizationFailedExitCode else {
                        //self.textViewOutput.appendText("Authentication Failed")
                        self.executeButton.isEnabled = true
                        return
                    }
                    //self.textViewOutput.appendText("Command exit code: \(exitCode)")
                    
                    self.maintenanceProgress.stopAnimation(nil)
                    self.maintenanceProgress.isIndeterminate = false
                    let incrementNum : Double = 100.0
                    self.maintenanceProgress.increment(by : incrementNum)
                    self.executeButton.isEnabled = true
                    if self.currentHelperAuthData == nil {
                        self.currentHelperAuthData = authData
                        textFieldAuthorizationCached = true
                    }
                    //update global auth data for other class to use
                    maintainAuthData = self.currentHelperAuthData
                }
            }
        
        } catch {
            //self.textViewOutput.appendText("Command failed with error: \(error)")
            self.executeButton.isEnabled = true
            
        }
        
        
    }
    
    
    
    func helperStatus(completion: @escaping (_ installed: Bool) -> Void) {
        // Comppare the CFBundleShortVersionString from the Info.plis in the helper inside our application bundle with the one on disk.
        
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + HelperConstants.machServiceName)
        guard
            //helperBundleInfo is helper info version
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let helperVersion = helperBundleInfo["CFBundleShortVersionString"] as? String,
            let helper = self.helper(completion) else {
                completion(false)
                return
        }
        
        
        helper.getVersion { installedHelperVersion in
            completion(installedHelperVersion == helperVersion)
        }
        //installedHelperVersion is application info version
        
        
    }
    
    func helperConnection() -> NSXPCConnection? {
        guard currentHelperConnection == nil else {
            return currentHelperConnection
        }
        
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.exportedInterface = NSXPCInterface(with: AppProtocol.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.invalidationHandler = {
            currentHelperConnection?.invalidationHandler = nil
            OperationQueue.main.addOperation {
                currentHelperConnection = nil
            }
        }
        
        currentHelperConnection = connection
        currentHelperConnection?.resume()
        //var tempVar = self.currentHelperConnection
        return currentHelperConnection
    }
    
    func helper(_ completion: ((Bool) -> Void)?) -> HelperProtocol? {
        
        // Get the current helper connection and return the remote object (Helper.swift) as a proxy object to call functions on.
        guard let helper = self.helperConnection()?.remoteObjectProxyWithErrorHandler({ error in
            //self.textViewOutput.appendText("Helper connection was closed with error: \(error)")
            if let onCompletion = completion { onCompletion(false) }
        }) as? HelperProtocol else { return nil }
        return helper
    }
    
    func helperInstall() throws -> Bool {
        
        // Install and activate the helper inside our application bundle to disk.
        
        var cfError: Unmanaged<CFError>?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        //note: kSMRightBlessPrivilegedHelper = com.apple.ServiceManagement.blesshelper
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        
        guard
            let authRef = try HelperAuthorization.authorizationRef(&authRights, nil, [.interactionAllowed, .extendRights, .preAuthorize]),
            SMJobBless(kSMDomainSystemLaunchd, HelperConstants.machServiceName as CFString, authRef, &cfError) else {
                if let error = cfError?.takeRetainedValue() { throw error }
                return false
        }
        
        currentHelperConnection?.invalidate()
        currentHelperConnection = nil
        
        return true
    }
    
    func dialogAlert(question: String, text: String) -> Void {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.icon = NSImage (named: NSImage.cautionName)
        alert.beginSheetModal(for: self.view.window!, completionHandler: { (modalResponse) -> Void in})
        return
    }
    
    // MARK: AppProtocol Methods
    
    func log(stdOut: String) {
        guard !stdOut.isEmpty else { return }
        OperationQueue.main.addOperation {
            //self.textViewOutput.appendText(stdOut)
        }
    }
    
    func log(stdErr: String) {
        guard !stdErr.isEmpty else { return }
        OperationQueue.main.addOperation {
            //self.textViewOutput.appendText(stdErr)
        }
    }
    
    //normal command without priviledge
    func shell(launchPath: String, arguments: [String]) -> String?
    {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)
        
        return output
    }
}
