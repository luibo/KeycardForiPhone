//
//  DerivationAndSigningController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 27/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard

class DerivationAndSigningController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var pathTF: UITextField!
    @IBOutlet weak var hashTF: UITextField!
    @IBOutlet weak var buttonContainer: UIView! {
        didSet {
            buttonContainer.layer.cornerRadius = buttonContainer.frame.height/2
            buttonContainer.layer.borderWidth = 3
            buttonContainer.layer.borderColor = UIColor.link.cgColor
            buttonContainer.backgroundColor = UIColor.clear
        }
    }
    @IBOutlet weak var radioButton: UIButton! {
        didSet {
            radioButton.layer.cornerRadius = radioButton.frame.height/2
            radioButton.backgroundColor = UIColor.clear
        }
    }
    
    var unchecked = true
    var setToActive = false
    var session: KeycardController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        descriptionLabel.text = "Here is possibile to combine derivation and sign in one step. You can also decide to make the specified path the current active path."

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
         self.title = "Derivation and signing"
    }
    
    
    func beginScanning() {
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "Hold your Keycard near iPhone.")
    }
    
    
    func onCon(cc:CardChannel) {
        let hash = self.hashTF.text
        let signature: RecoverableSignature?
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        let resp: APDUResponse?
        
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
            
            resp = try cmdSet.sign(hash: hash!.hexa, path: pathTF.text!, makeCurrent: setToActive)
            signature = try RecoverableSignature(hash: hash!.hexa, data: (resp?.checkOK().data)!)

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
            let alert = UIAlertController(title: "Transaction succesfully signed", message: "Sender: \(signature!.s)\nReiceiver: \(signature!.r)\nPublic key: \(signature!.publicKey)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    
    @IBAction func radioButtonPressed(_ sender: UIButton) {
        if unchecked {
            sender.backgroundColor = UIColor.link
            unchecked = false
            setToActive = true
        }
        else {
            sender.backgroundColor = UIColor.clear
            unchecked = true
            setToActive = false
        }
    }
    
    
    @IBAction func signButtonPresse(_ sender: Any) {
        guard let p = pathTF.text, !p.isEmpty else {
            let alert = UIAlertController(title: "", message: "Please insert a valid path for derivation.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        beginScanning()
    }
    
    
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
