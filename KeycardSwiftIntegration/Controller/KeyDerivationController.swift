//
//  KeyDerivationController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 25/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard

class KeyDerivationController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var currentPath: UILabel!
    @IBOutlet weak var coinTypeTF: UITextField!
    @IBOutlet weak var radioContainer: UIView!
    
    @IBOutlet weak var buttonContainer1: UIView! {
        didSet {
            buttonContainer1.layer.cornerRadius = buttonContainer1.frame.height/2
            buttonContainer1.layer.borderWidth = 3
            buttonContainer1.layer.borderColor = UIColor.link.cgColor
            buttonContainer1.backgroundColor = UIColor.clear
        }
    }
    @IBOutlet weak var accountRadioButton: UIButton! {
        didSet {
            accountRadioButton.layer.cornerRadius = accountRadioButton.frame.height/2
            accountRadioButton.backgroundColor = UIColor.clear
        }
    }

    
    let picker = UIPickerView()
    //var path: String?
    var newAccountChecked = false
    var session: KeycardController?


    var coin = ""
    var coinIdx: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if currentKeypath != "" {
            currentPath.text = "Current path:\n\(currentKeypath)"
        } else {
            currentPath.text = "No derivation paths found for this Keycard."
            radioContainer.isHidden = true
        }
        
        descriptionLabel.text = "Here is possible to perform key derivation as defined by the BIP32 specification in order to create a hierarchical deterministic wallet. The derived key will become the active key."
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

        view.addGestureRecognizer(tap)
        createPicker()
         self.title = "Key derivation"
    }
    
    
    @IBAction func deriveButtonPressed(_ sender: Any) {
        guard let coinType = coinTypeTF.text, !coinType.isEmpty else {
            let alert = UIAlertController(title: "", message: "Please choose a coin type.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        beginScanning()
    }
    
    
    @IBAction func radioButtonPressed(_ sender: UIButton) {
        if !newAccountChecked {
            sender.backgroundColor = UIColor.link
            newAccountChecked = true
        } else {
            sender.backgroundColor = UIColor.clear
            newAccountChecked = false
        }
        
    }
    
    
    func beginScanning() {
        //path = pathTF.text
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "PHold your Keycard near iPhone.")
    }
    
    
    func onCon(cc:CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        var pathToDerive: String = ""
                
        if currentKeypath != "m" {
            let splits = currentKeypath.components(separatedBy: "/")
            let addressIndex = (newAccountChecked) ? 0 : (Int(splits[splits.count - 1])!) + 1
            let accountIndex = Int(splits[3].replacingOccurrences(of: "'", with: ""))
            
            pathToDerive += (splits[0] + "/")
            pathToDerive += (splits[1] + "/")
            pathToDerive += "\(coinIndexes[coin] ?? "0")'/"
            pathToDerive += (newAccountChecked) ? String(accountIndex! + 1) + "'/" : (String(accountIndex!) + "'/")
            pathToDerive += (splits[4] + "/")
            pathToDerive += String(addressIndex)
        } else {
            pathToDerive = "m/44'/\(coinIndexes[coin] ?? "0")'/0'/0/0"
        }
        
        print("path to derive: \(pathToDerive)")
        
        
        do{
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)
            
            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            if pairing == [] {
                try cmdSet.autoPair(password: pp!)
            } else {
                print("Found pairing info while key derivation")
                print(pairing)
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            print("opening secure channel")
            try cmdSet.autoOpenSecureChannel()
                
            print("pin verifying")
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
            
            print("key derivation")
            try cmdSet.deriveKey(path: pathToDerive).checkOK()

            try cmdSet.autoUnpair()
     
        } catch let error {
            print("Interrupted: "+error.localizedDescription)
            session?.stop(errorMessage: error.localizedDescription)
        }
        session?.stop(alertMessage: "Derivation completed")
        
        currentKeypath = pathToDerive
        DispatchQueue.main.async {
            self.currentPath.text = currentKeypath
            //self.pathTF.text = ""
        }
        
        do {
            try cmdSet.autoUnpair()
        } catch {
            print(error)
        }
    }
    
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}


extension KeyDerivationController: UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return coins.count
    }
    
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return coins[row]
    }
    
    
    func createPicker() {
        picker.delegate = self
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let button = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.dismissPicker))
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancel))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([button, flexibleSpace, cancel], animated: true)
        toolbar.isUserInteractionEnabled = true
        
        coinTypeTF.inputAccessoryView = toolbar
        coinTypeTF.inputView = picker
    }
    
    
    @objc func dismissPicker() {
            let dataString = pickerView(picker, titleForRow: picker.selectedRow(inComponent: 0), forComponent: 0)
            coin = dataString!
//            coinIdx = coins2[dataString!]
            coinTypeTF.text = coin
            coinTypeTF.resignFirstResponder()
            
            picker.selectRow(0, inComponent: 0, animated: true)
    }
    
    
    @objc func cancel() {
        view.endEditing(true)
        picker.selectRow(0, inComponent: 0, animated: true)
    }
}
