//
//  SigningController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 26/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard

class SigningController: UIViewController {
    
    @IBOutlet weak var descLabel: UILabel! {
        didSet {
            descLabel?.text = "Here it's' possible to securely sign a transaction through Keycard.\n Insert the transaction hash and start the card reading session. PIN is required."
        }
    }
    
    
    @IBOutlet weak var hashTF: UITextField!
    
    var session: KeycardController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Signing"
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

        view.addGestureRecognizer(tap)
    }
    

    @IBAction func signButtonPressed(_ sender: Any) {
        
        guard let hashT = hashTF.text, !hashT.isEmpty else {
            let alert = UIAlertController(title: "", message: "Please insert the transaction hash to proceed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        beginScanning()
    }
    
    
    func beginScanning() {
        //lettura pin
        let alert = UIAlertController(title: "Insert card PIN", message: "", preferredStyle: .alert)
        
        alert.addTextField { (pin) in
            pin.placeholder = "PIN"
            pin.keyboardType = .numberPad
            pin.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {
            (_) in
            self.session = KeycardController(onConnect: self.onCon, onFailure: nonCon)
            self.session?.start(alertMessage: "Hold your Keycard near iPhone.")
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
        
    }
    
    
    func onCon(cc:CardChannel) {
        let hash = self.hashTF.text
        let signature: RecoverableSignature?
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

            try cmdSet.autoOpenSecureChannel()

            print("pin verifying")
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
            
            print(hash!.hexa)

            signature = try RecoverableSignature(hash: hash!.hexa, data: try cmdSet.sign(hash: hash!.hexa).checkOK().data)
            
            
            print(signature?.publicKey.toHexString() ?? "null")
            print(signature?.r.toHexString() ?? "no r")
            print(signature?.s.toHexString() ?? "no s")

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
            let alert = UIAlertController(title: "Transaction succesfully signed", message: "\nS\n 0x\(signature!.s.toHexString())\n\nR\n 0x\(signature!.r.toHexString())", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
        }

    }
    
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
        
}
