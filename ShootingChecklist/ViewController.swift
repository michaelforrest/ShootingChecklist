//
//  ViewController.swift
//  ShootingChecklist
//
//  Created by Michael Forrest on 28/03/2017.
//  Copyright © 2017 GoodToHear. All rights reserved.
//

import Cocoa
import WebKit

class ViewController: NSViewController {
    
    @IBOutlet weak var webView: WebView!
    var document: Document?{
        return self.view.window?.windowController?.document as? Document
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
     
    }

    override var representedObject: Any? {
        didSet {
            print("represented object is now \(representedObject)")
        }
    }


}

