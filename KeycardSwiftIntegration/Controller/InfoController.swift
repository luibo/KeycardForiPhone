//
//  InfoController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 06/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit

class InfoController: UIViewController {
    
    @IBOutlet weak var mkLabel: UILabel!
    @IBOutlet weak var slotsLabel: UILabel!
    @IBOutlet weak var instanceLabel: UILabel!
    @IBOutlet weak var appletLabel: UILabel!
    @IBOutlet weak var keyUIDLabel: UILabel!
    
    
    var hasMasterKey = false
    var freeSlots = 0
    var instanceUID: [UInt8]?
    var appletVersion: String?
    var keyUID: [UInt8]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mkLabel.text = (hasMasterKey == false) ? "no" : "yes"
        slotsLabel.text = String(freeSlots)
        instanceLabel.text =  (instanceUID != nil) ? String(instanceUID!.toHexString()) : "null"
        appletLabel.text = appletVersion ?? "null"
        keyUIDLabel.text = (keyUID != nil) ? String(keyUID!.toHexString()) : String(0)
        
        self.tabBarController?.navigationItem.titleView = imageView
        self.tabBarController?.navigationItem.hidesBackButton = true
                
        //self.tabBarItem.image = UIImage(named: "info")
    }
    


    @IBAction func unpairPressed(_ sender: Any) {
        
    }
    
}
