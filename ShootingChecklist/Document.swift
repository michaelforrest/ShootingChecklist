//
//  Document.swift
//  ShootingChecklist
//
//  Created by Michael Forrest on 28/03/2017.
//  Copyright © 2017 GoodToHear. All rights reserved.
//

import Cocoa
import AEXML
import Stencil
import PathKit

struct Location{
    let title: String
    var scenes: [Scene]
    var isVirtual = false
}
struct Action{
    let type: String
    let text: String
    var caption: String
}
struct Scene {
    let title: String
    var page: String
    var paragraphs: [Action]
    var number: String
    var isVirtual = false
}

struct FCPXAction {
    let text: String
    let offset: Int
    let index: Int
    let caption: String
    func sentences()-> [String]{
        return caption.components(separatedBy: ".")
    }
}

class Document: NSDocument {
    var title = "Untitled"
    var locations: [Location] = []
    var scenes: [Scene] = []
    var actions: [Action] = []
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }
    
    override class var autosavesInPlace:Bool {
        return false
    }

    var resourcesURL: URL{
        return Bundle.main.bundleURL.appendingPathComponent("Contents").appendingPathComponent("Resources")
        
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
        self.addWindowController(windowController)
        let frame = CGRect(x: 100, y: 900, width: 800, height: 1100);
        windowController.window?.setFrame(frame, display: true, animate: false)
        let vc = windowController.contentViewController as! ViewController
        
        let context = [
            "locations": self.locations
        ]
   
        let rendered = try?  render(name: "locations.html", context: context)
        vc.webView.mainFrame.loadHTMLString(rendered, baseURL: resourcesURL)
    }
    
    func render(name: String, context: [String: Any]) throws -> String {
        let path: Path = Path(resourcesURL.path)
        let environment = Environment(loader: FileSystemLoader(paths: [path]))
        return try environment.renderTemplate(name: name, context: context)
    }
    
    @IBAction func handleExportToFCPX(sender: NSObject){
        self.title = self.fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        
        let segmentDuration = 3 // seconds
        let context:[String: Any] = [
            "name": "\(self.title) Action List",
            "date": "2018-12-05 12:38:10 +0000",
            "eventUUID": UUID().uuidString,
            "uuid": UUID().uuidString,
            "duration": self.actions.count * segmentDuration,
            "actions": self.actions.enumerated().map{ FCPXAction(text: $0.element.text, offset: $0.offset * segmentDuration, index: $0.offset, caption: $0.element.caption )}
        ]
        let rendered = try? render(name: "markers-template.fcpxml", context: context);
        let panel = NSSavePanel()
        panel.nameFieldStringValue = self.title
        panel.begin { result in
            if result == .OK {
                if let url = panel.url{
                  try! rendered?.write(to: url.appendingPathExtension("fcpxml"), atomically: true, encoding: .utf8)
                }
            }
        }
    }

    // read-only
    override func data(ofType typeName: String) throws -> Data {
         throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        
        if typeName != "Final Draft 9" {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        
        do {
            let options = AEXMLOptions()
            let xmlDoc = try AEXMLDocument(xml: data, options: options)
            var currentScene: Scene?
            if let paragraphs = xmlDoc.root["Content"]["Paragraph"].all {
                for paragraph in paragraphs {
                    let type = paragraph.attributes["Type"] ?? ""
                    let textElements = paragraph["Text"].all
                    let text = textElements?.map({ $0.string }).joined() ?? ""
                    let number = paragraph.attributes["Number"] ?? ""
                    let page = paragraph["SceneProperties"].attributes["Page"] ?? ""
                    if type == "Scene Heading" {
                        if let scene = currentScene {
                         self.scenes.append(scene) // save the one we already had
                        }
                        currentScene = Scene(title: text, page: page, paragraphs: [], number: number, isVirtual: text.hasPrefix("GFX.") || text.hasPrefix("SCR."))
                        
                    }else if type == "Dialogue"{
                        var action = actions.count > 0 ? actions.removeLast() : Action(type: type, text: text, caption: text)
                        action.caption = text
                        actions.append(action)
                        
                    } else{
                        // hack: not currently interested in non-actions
                        if type == "Action"{
                            currentScene?.paragraphs.append(Action(type: type, text: text, caption: ""))
                        }
                    }
                    if type=="Action"{
                        actions.append(Action(type: type, text: text, caption: ""))
                    }
                }
            }
            if let scene = currentScene{
                self.scenes.append(scene)
            }
            if let locations = xmlDoc.root["SmartType"]["Locations"]["Location"].all {
                self.locations = locations.map({ el -> Location in
                    let title = el.string
                    let locationScenes = scenes.filter{ $0.title.uppercased().contains(title.uppercased())}
                    let isVirtual = locationScenes.filter({$0.isVirtual}).count > 0
                    return Location(title: title, scenes: locationScenes, isVirtual: isVirtual)
                })
            }
            
        }
        
    }


}

