//
//  WalletCreationController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 12/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard

class WalletCreationController: UITableViewController {
    
    var session: KeycardController?
    var importingPhrase: String?
    var pass: String?
    var keyOperation: Int?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
         self.title = "Create wallet"
        
    }


    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 30))
        
        footerView.backgroundColor = UIColor.clear

        return footerView
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 1 {
            importPassphrase()
        } else if indexPath.row == 2 {
            generateKeyOnCard()
        } else if indexPath.row == 3 {
            importECKeypair()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    func importPassphrase() {
       let alert = UIAlertController(title: "Import wallet", message: "Insert a BIP39 passphrase (words must be separated by a single space) and the related password in order to import a wallet.", preferredStyle: .alert)
       
       
       alert.addTextField { (passphrase) in
           passphrase.placeholder = "BIP39 passphrase"
       }
       
       alert.addTextField { (password) in
           password.placeholder = "password"
           password.isSecureTextEntry = true
       }
       
       alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            
        self.keyOperation = 0
        self.importingPhrase = alert?.textFields![0].text
        self.pass = alert?.textFields![1].text
        self.beginScanning()

       }))
       alert.addAction(UIAlertAction(title: "Cancel", style: .destructive))

               
       self.present(alert, animated: true)
       
       alert.actions[0].isEnabled = false
       
       for textfield: UIView in alert.textFields! {
           let container: UIView = textfield.superview!
           let effectView: UIView = container.superview!.subviews[0]
           container.backgroundColor = UIColor.clear
           effectView.removeFromSuperview()
       }
               
       for tf in alert.textFields! {
           NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: tf, queue: OperationQueue.main) { (notification) -> Void in
               let phraseTextField = alert.textFields![0]
               //let passTextField = alert.textFields![1]
            alert.actions[0].isEnabled = !phraseTextField.text!.isEmpty
           }
       }

    }
    
    
    func generateKeyOnCard() {
        let alert = UIAlertController(title: "Generate key on card", message: "This is the simplest and safest method for loading a key on the card, because the generated wallet never leaves the card and there is no “paper backup” to keep secure.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
            self.keyOperation = 1
//             dGroup.enter()
              //   DispatchQueue.global(qos: .default).async {
                 self.beginScanning()
           //  }
             //dGroup.wait()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive))
        
        self.present(alert, animated: true)
    }
    
    
    func importECKeypair() {
        let alert = UIAlertController(title: "Import EC keypair", message: "You can import on the keycard any EC keypair on the SECP256k1 curve, with or without the BIP32 extension. If you import a key without the BIP32 extension, then key derivation will not work, but you will still be able to use the Keycard for signing transactions using the imported key.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
            self.keyOperation = 2
            // dGroup.enter()
              //   DispatchQueue.global(qos: .default).async {
                 self.beginScanning()
//             }
//             dGroup.wait()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive))
        
        self.present(alert, animated: true)
    }

    
    func beginScanning() {
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "Hold your Keycard near iPhone.")
    }
    
    
    func onCon(cc: CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        var returnMessage = ""
        
        do{
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)
            
            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            
            if pairing == []{
                try cmdSet.autoPair(password: pp!)
            }else{
                print("Found pairing info while creating BIP39. Loading...")
                print(pairing)
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            try cmdSet.autoOpenSecureChannel()
            
            
            print("pin verifying")
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
            print("pin verified")
            
            if keyOperation == 0 {
                returnMessage = "Key correctly imported"

                try cmdSet.loadKey(seed: Mnemonic.toBinarySeed(mnemonicPhrase: self.importingPhrase!, password: self.pass ?? "")).checkOK()
                
            } else if keyOperation == 1 {
                print("generating key on card")
                try cmdSet.generateKey().checkOK()
                returnMessage = "Key correctly generated"
            } else {
                print("importing EC keypair")
                returnMessage = "EC keypair correctly imported"
            }
            


            try cmdSet.autoUnpair()
     
        } catch let error {
            print("Interrupted: " + error.localizedDescription)
            session?.stop(errorMessage: error.localizedDescription)
            //dGroup.leave()
            do {
                try cmdSet.autoUnpair()
            } catch {
                print(error)
            }
            return
        }
        session?.stop(alertMessage: returnMessage)

//        DispatchQueue.main.async {
//            let alert = UIAlertController(title: "BIP39 phrase correctly generated:", message: generatedPhrase, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "Ok", style: .default))
//            self.present(alert, animated: true)
//        }
    }
       

}
