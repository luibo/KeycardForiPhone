//
//  PinlessSignController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 27/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard

class PinlessSignController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var hashTF: UITextField!
    
    var session: KeycardController?


    override func viewDidLoad() {
        super.viewDidLoad()
        
        descriptionLabel.text = "Here it's possible to sign transactions (or meta-transactions) without inserting a PIN. In order to complete the operation a BIP32 path must be defined (if you have not defined one yet you can do it in Settings > Define pinless path). Please be careful with this feature."
        
        
         self.title = "Pinless signing"
    }
    
    
    func beginScanning() {
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "Hold your Keycard near iPhone.")
    }
    
    
    func onCon(cc:CardChannel) {
        let hash = self.hashTF.text
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        
        do{
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)
            
            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            if pairing == []{
                print("Saving pairing info")
                try cmdSet.autoPair(password: pp!)
            } else {
                print("Found pairing info while creating BIP39. Loading...")
                print(pairing)
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            try cmdSet.signPinless(hash: hash!.hexa).checkOK()
            
            try cmdSet.autoUnpair()
     
        } catch let error {
            print("Interrupted: " + error.localizedDescription)
            session?.stop(errorMessage: error.localizedDescription)
            do {
                try cmdSet.autoUnpair()
            } catch {
                print(error)
            }
            return
        }
        session?.stop(alertMessage: "Operation completed")
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "", message: "Transaction succesfully signed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    @IBAction func signButtonPresse(_ sender: Any) {
        guard let hashT = hashTF.text, !hashT.isEmpty else {
            let alert = UIAlertController(title: "", message: "Please insert the transaction hash to proceed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        beginScanning()
    }

}
