import Foundation
import Cocoa

class kextinfo: NSViewController, NSSearchFieldDelegate {
    
    @IBOutlet weak var revealButton: NSButton!
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var unloadButton: NSButton!
    @IBOutlet weak var reloadButton: NSButton!
    @IBOutlet weak var kextLabel: NSTextField!
    @IBOutlet weak var pathText: NSTextField!
    @IBOutlet weak var kextClip: NSClipView!
    @IBOutlet weak var kextScroll: NSScrollView!
    @IBOutlet weak var disclosureButton: NSButton!
    @IBOutlet weak var kextNumber: NSTextField!
    @IBOutlet weak var kextSearch: NSSearchField!
    @IBOutlet weak var kextTable: NSTableView!
    var kextData = [[String:String]]()
    var kextDataBackup = [[String:String]]()
    var kextSelect = ["identifier":"", "path":"", "version":""]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //init table
        kextTable.delegate = self
        kextTable.dataSource = self
        self.kextSearch.delegate = self
        
        
        //Swift.print("hello world")
        let infoKeys = ["CFBundleIdentifier", "CFBundleVersion","OSBundlePath"] as CFArray
        let kextCFDic = KextManagerCopyLoadedKextInfo(nil,infoKeys)?.takeRetainedValue()
        let kextDic = kextCFDic as! [String: AnyObject]
        
        for element in kextDic {
            //Swift.print(element.value["CFBundleIdentifier"] as! String)
            let identifier = element.value["CFBundleIdentifier"] as? String ?? ""
            let version = element.value["CFBundleVersion"] as? String ?? ""
            let path = element.value["OSBundlePath"] as? String ?? ""
            
            let addElement = ["identifier":identifier, "version":version, "path":path]
            kextData.append(addElement)
        }
        /*
        for element in kextData {
            Swift.print(element)
        }
        */
        kextData = kextData.filter( { !$0.values.isEmpty }) //remove empty row
        kextNumber.stringValue = "Found: \(kextData.count)"
        kextDataBackup = kextData
        kextTable.reloadData()
    }
    
    @IBAction func runSearch(_ sender: Any) {
        kextData.removeAll()
        if kextSearch.stringValue == "" {
            //load original data
            kextData = kextDataBackup
        } else {
            //do search
            for element in kextDataBackup {
                //Swift.print(element.value["CFBundleIdentifier"] as! String)
                if element["identifier"]?.lowercased().contains(kextSearch.stringValue.lowercased()) ?? false {
                    kextData.append(element)
                }
            }
        }
        kextTable.reloadData()
    }
    
    @IBAction func reloadButton(_ sender: Any) {
        if pathText.stringValue.isEmpty{
            return
        }
        if let path = URL(string: "file://" + pathText.stringValue) {
            unloadButton("")
            KextManagerLoadKextWithURL(path as CFURL, nil)
        }
    }
    
    @IBAction func unloadButton(_ sender: Any) {
        if kextSelect["identifier"]?.isEmpty ?? true{
            return
        }
        let identifier = kextSelect["identifier"] ?? ""
        KextManagerUnloadKextWithIdentifier(identifier as CFString)
    }
    
    @IBAction func exportButton(_ sender: Any) {
        if pathText.stringValue.isEmpty{
            return
        }
        let path = URL(string: "file://" + pathText.stringValue)
        let savePanel = NSSavePanel()
        savePanel.prompt = "Export"
        savePanel.title = "Export"
        savePanel.nameFieldLabel = "Export As:"
        savePanel.directoryURL = homeURL
        savePanel.nameFieldStringValue = (pathText.stringValue as NSString).lastPathComponent
        
        savePanel.beginSheetModal(for:self.view.window!) { (response) in
            if let url = savePanel.url, response.rawValue == NSApplication.ModalResponse.OK.rawValue {
                // do whatever you what with the file path
                do {
                    let newPath = savePanel.url
                    try FileManager().copyItem(at: path ?? url, to: newPath ?? url)
                    
                } catch {
                    print(error.localizedDescription)
                }
            }
            savePanel.close()
        }
    }
    
    
    @IBAction func revealButton(_ sender: Any) {
        if !pathText.stringValue.isEmpty {
            NSWorkspace.shared.selectFile(pathText.stringValue,inFileViewerRootedAtPath: "")
        }
        
    }
    
    
    
    @IBAction func disclosureButton(_ sender: Any) {
        let dHeight = 70
        let smallOrigin = NSPoint(x: 20, y: 116)
        let bigOrigin = NSPoint(x: 20, y: 116-dHeight)
        let hideOrigin = NSPoint(x:0, y:25-dHeight)
        let showOrigin = NSPoint(x:0, y:25)
        if disclosureButton.state == .on {
            //hide
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.2
            kextScroll.animator().setFrameOrigin(bigOrigin)
            kextScroll.animator().setFrameSize(NSSize(width: 417, height: 249+dHeight))
            pathText.animator().setFrameOrigin(hideOrigin)
            reloadButton.animator().setFrameOrigin(NSPoint(x: 269, y:51-dHeight))
            unloadButton.animator().setFrameOrigin(NSPoint(x: 347, y:51-dHeight))
            exportButton.animator().setFrameOrigin(NSPoint(x: 269, y:-1-dHeight))
            revealButton.animator().setFrameOrigin(NSPoint(x: 347, y:-1-dHeight))
            kextLabel.animator().setFrameOrigin(NSPoint(x: 0, y:52-dHeight))
            NSAnimationContext.endGrouping()
        } else if disclosureButton.state == .off {
            //show
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0.2
            kextScroll.animator().setFrameOrigin(smallOrigin)
            kextScroll.animator().setFrameSize(NSSize(width: 417, height: 249))
            pathText.animator().setFrameOrigin(showOrigin)
            reloadButton.animator().setFrameOrigin(NSPoint(x: 269, y:51))
            unloadButton.animator().setFrameOrigin(NSPoint(x: 347, y:51))
            exportButton.animator().setFrameOrigin(NSPoint(x: 269, y:-1))
            revealButton.animator().setFrameOrigin(NSPoint(x: 347, y:-1))
            kextLabel.animator().setFrameOrigin(NSPoint(x: 0, y:52))
            NSAnimationContext.endGrouping()
        }
        
        
        
    }
}

extension kextinfo: NSTableViewDelegate, NSTableViewDataSource {
    func tableView(_ kextTable: NSTableView, accessoryButtonTappedForRowWith disclosureButton: NSButton){
        Swift.print("debug")
    }
    // numerbOfRow and viewForTableColumn methods
    func numberOfRowsInTableView(in tableView: NSTableView) -> Int {
        return kextData.count
    }
    func numberOfRows(in tableView: NSTableView) -> Int {
        return kextData.count
    }
    
    func tableView(_ kextTable: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let identifier = kextData[row]["identifier"] ?? ""
        let version = kextData[row]["version"] ?? ""
        return identifier + " " + "(" + version + ")"
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let myTable = notification.object as? NSTableView {
            // we create an [Int] array from the index set
            let selected = myTable.selectedRowIndexes.map { Int($0) }
            if !selected.isEmpty {
                pathText.stringValue = kextData[selected[0]]["path"] ?? ""
                kextLabel.stringValue = (pathText.stringValue as NSString).lastPathComponent
                kextSelect["identifier"] = kextData[selected[0]]["identifier"] ?? ""
                kextSelect["path"] = kextData[selected[0]]["path"] ?? ""
                kextSelect["version"] = kextData[selected[0]]["version"] ?? ""
            }
            
        }
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
}

/*
public class subKext: NSViewController{
    @IBOutlet weak var pathText: NSTextField!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
}

extension subKext {
    func hide() {
        Swift.print("Hide")
        let hideOrigin = NSPoint(x:20, y:-40)
        pathText.setFrameOrigin(hideOrigin)
        pathText.stringValue = "debug"
    }
    
    func show() {
        Swift.print("Show")
        let showOrigin = NSPoint(x:20, y:38)
        pathText.setFrameOrigin(showOrigin)
        pathText.stringValue = "debug"
    }
}
*/
