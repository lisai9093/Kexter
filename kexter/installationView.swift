//
//  ViewController.swift
//  CellBasedTableView
//
//  Created by Debasis Das on 5/15/17.
//  Copyright © 2017 Knowstack. All rights reserved.
//

//Cell based NSTableView using datasource.
import Cocoa
import ServiceManagement

let SLE = "/System/Library/Extensions/"
let LE = "/Library/Extensions/"
@available(OSX 10.12, *)
let homeURL = FileManager.default.homeDirectoryForCurrentUser

var helperInstalled = false

var helperIsInstalledKeyPath: String = ""
var currentHelperConnection: NSXPCConnection?
var currentHelperAuthDataKeyPath: String = ""
var textFieldAuthorizationCached: Bool = false
var maintainAuthData: NSData?
var installAuthData: NSData?
var globalHelperIsInstalled = false

class installaion: NSViewController, AppProtocol, mainCommand {
    var allPaths = [String]()
    var shownPaths = [String]()
    var fileNames = [String]()
    var onePath = [String]()
    var tableViewData = [[String: String]]()
    var destiny = LE
    
    @IBOutlet weak var buttonInstallHelper: NSButton!
    @IBOutlet var tableView: NSTableView!
    @IBOutlet weak var browseButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var radioNumber1: NSButton!
    @IBOutlet weak var radioNumber2: NSButton!
    @IBOutlet weak var backupCheck: NSButton!
    @IBOutlet weak var installationProgress: NSProgressIndicator!
    
    private var dragDropType = NSPasteboard.PasteboardType.fileURL
    
    
    
    @objc dynamic private var helperIsInstalled = false
    @objc dynamic private var currentHelperAuthData: NSData?
    
    
    
    let expectedExt = ["kext"]  //file extensions allowed for Drag&Drop (example: "jpg","png","docx", etc..
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([dragDropType])
        
        //set install button to default
        buttonInstallHelper.keyEquivalent = "\r"
        
        currentHelperAuthDataKeyPath = NSStringFromSelector(#selector(getter: self.currentHelperAuthData))
        helperIsInstalledKeyPath = NSStringFromSelector(#selector(getter: self.helperIsInstalled))
        
        do {
            try HelperAuthorization.authorizationRightsUpdateDatabase()
        } catch {
            //self.textViewOutput.appendText("Failed to update the authorization database rights with error: \(error)")
        }
        
        buttonInstallHelper.isEnabled = false
        OperationQueue.main.maxConcurrentOperationCount = 1 //wait for helper status
        self.helperStatus { installed in
            OperationQueue.main.addOperation {
                //self.textFieldHelperInstalled.stringValue = (installed) ? "Yes1" : "No1"
                self.setValue(installed, forKey: helperIsInstalledKeyPath)
                helperInstalled = installed
                globalHelperIsInstalled = installed
                self.buttonInstallHelper.isEnabled = true
            }
        }
        
    }
    
    @IBAction func buttonInstallHelper(_ sender: Any) {
        installationProgress.doubleValue = 0.0
        checkHelper()
        if allPaths.isEmpty {
            dialogAlert(question: "Error", text: "You haven't selected any kext to install.")
            return
        }
        commandView()
    }
    
    @IBAction func clearButton(_ sender: Any) {
        shownPaths.removeAll()
        allPaths.removeAll()
        tableViewData.removeAll()
        self.tableView.reloadData()
    }
    
    @IBAction func browseButton(_ sender: Any) {
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose a .kext file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = true;
        dialog.allowedFileTypes        = ["kext"];
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.urls // Pathname of the files
            if (!result.isEmpty) {
                for element in result {
                    let path = element.path
                    
                    if !allPaths.contains(path) {
                        //run only if unique element added
                        allPaths.append(path)
                        tableViewData.append(["path":path])
                    }
                }
                tableView.reloadData()
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }
    
    @IBAction func radioNumber1(_ sender: Any) {
        radioNumber2.state = NSControl.StateValue.off
        destiny = SLE
    }
    
    @IBAction func radioNumber2(_ sender: Any) {
        radioNumber1.state = NSControl.StateValue.off
        destiny = LE
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
        if !globalHelperIsInstalled {
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
        
        //prepare destiny
        let N = allPaths.count
        //destiny = homeURL.path + "/Desktop/" //debug only, must remove
        let command = [String](repeating: "/bin/cp", count: N)
        let option = [String](repeating: "-rf", count: N)
        var destinyPath = [String]()
        var backupPath = String()
        destinyPath = allPaths
        for i in allPaths.indices {
            destinyPath[i] = destiny + (allPaths[i] as NSString).lastPathComponent
        }
        
        
        if backupCheck.state == NSControl.StateValue.off {
            //self.textViewOutput.appendText("No back up")
        } else {
            //self.textViewOutput.appendText("Need back up")
            // get the current date and time
            let currentDateTime = Date()
            // get the user's calendar
            let userCalendar = Calendar.current
            // choose which date and time components are needed
            let requestedComponents: Set<Calendar.Component> = [
                .year,
                .month,
                .day,
                .hour,
                .minute,
                .second
            ]
            // get the components
            let dateTimeComponents = userCalendar.dateComponents(requestedComponents, from: currentDateTime)
            let timeStamp = String(dateTimeComponents.year!) + "-" + String(dateTimeComponents.month!) + "-" + String(dateTimeComponents.day!) + "_" + String(dateTimeComponents.hour!) + "-" + String(dateTimeComponents.minute!) + "-" + String(dateTimeComponents.second!)

            backupPath = homeURL.path + "/Desktop" + "/Kexter_Backup_" + timeStamp
            do
            {
                try FileManager.default.createDirectory(atPath: backupPath, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error as NSError
            {
                NSLog("Unable to create directory. %s", error.debugDescription)
            }
        }
        
        //copy if auth existed already
        currentHelperAuthData = maintainAuthData ?? currentHelperAuthData
        do {
            //check auth
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
            buttonInstallHelper.isEnabled = false
            helper.runCommand(withCommand: command, withOption: option, withPath: allPaths, withDest: destinyPath, withBackup: backupPath, authData: authData) { (exitCode) in
                OperationQueue.main.addOperation {
                    // Verify that authentication was successful
                    guard exitCode != kAuthorizationFailedExitCode else {
                        //self.textViewOutput.appendText("Authentication Failed")
                        self.buttonInstallHelper.isEnabled = true
                        return
                    }
                    
                    //self.textViewOutput.appendText("Command exit code: \(exitCode)")
                    let incrementNum : Double = 100.0
                    self.installationProgress.increment(by : incrementNum)
                    self.buttonInstallHelper.isEnabled = true
                    if self.currentHelperAuthData == nil {
                        self.currentHelperAuthData = authData
                        textFieldAuthorizationCached = true
                    }
                    //update global auth data for other class to use
                    installAuthData = self.currentHelperAuthData
                    
                }
            }
        
        } catch {
            //self.textViewOutput.appendText("Command failed with error: \(error)")
            self.buttonInstallHelper.isEnabled = true
        }
    }
    
    func helperStatus(completion: @escaping (_ installed: Bool) -> Void) {
        // Comppare the CFBundleShortVersionString from the Info.plis in the helper inside our application bundle with the one on disk.
        
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + HelperConstants.machServiceName)
        Swift.print(helperURL.absoluteString)
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
    
}
extension installaion: NSTableViewDelegate, NSTableViewDataSource {
    // numerbOfRow and viewForTableColumn methods
    func numberOfRowsInTableView(in tableView: NSTableView) -> Int {
        return tableViewData.count
    }
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableViewData.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return tableViewData[row][(tableColumn?.identifier.rawValue)!]
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        
        let item = NSPasteboardItem()
        item.setString(String(row), forType: self.dragDropType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard let board = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let path = board[0] as? String
            else { return [] }
        
        let suffix = URL(fileURLWithPath: path).pathExtension
        for ext in self.expectedExt {
            if ext.lowercased() == suffix {
                return .move
            }
        }
        return []
        /*
         if dropOperation == .above {
         return .move
         }
         return []
         */
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                oldIndexes.append(index)
                
            }
        }
        guard let pasteboard = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray
            //let pathNS = pasteboard as? NSArray
            //let path = pasteboard.copy()
            else { return false }
        
        //GET YOUR FILE PATH !!!
        //convert NSArray to Array
        let objCArray = NSMutableArray(array: pasteboard)
        shownPaths = objCArray as NSArray as! [String]
        
        
        tableView.beginUpdates()
        for element in shownPaths {
            if !allPaths.contains(element) {
                //run only if unique element added
                allPaths.append(element)
                tableViewData.append(["path":element])
            }
        }
        tableView.endUpdates()
        
        tableView.reloadData()
        return true
    }
    func uniq<S : Sequence, T : Hashable>(source: S) -> [T] where S.Iterator.Element == T {
        var buffer = [T]()
        var added = Set<T>()
        for elem in source {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }
    func debugPrint() {
        Swift.print("debug at maintenance")
    }
}





