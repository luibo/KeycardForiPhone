//
//  CreateBIP39Controller.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 21/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard

class CreateBIP39Controller: UIViewController {
    
    
    @IBOutlet weak var numberTF: UITextField!
    @IBOutlet weak var bip39Label: UILabel!
    
    let wordsNumberPicker = UIPickerView()
    var wordsNumber = 12
    var pickerData = [12, 15, 18, 21, 24]
    var session: KeycardController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bip39Label.text = "Here is possible to generate a BIP39 mnemonic phrase to be loaded on the card. The mnemonic phrase can be used to recover a wallet and,\n once generated, should be written on paper and securely stored.\n You can choose to create a 12, 15, 18, 21 or 24 words phrase."
        createPicker()
         self.title = "BIP39"
    }
    
    
    func beginScanning() {
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "Hold your Keycard near iPhone.")
    }
    
    
    func onCon(cc:CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        var generatedPhrase = ""
        
        do{
            let info = try ApplicationInfo(cmdSet.select().checkOK().data)
            
            let pairing = (UserDefaults.standard.object(forKey: info.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
            if pairing == []{
                try cmdSet.autoPair(password: pp!)
            } else {
                print("Found pairing info while creating BIP39. Loading...")
                print(pairing)
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            try cmdSet.autoOpenSecureChannel()
            
            print("creating mnemonic")
            
            var uint: UInt8 = 0x04 //12
            
            switch wordsNumber {
            case 15:
                uint = 0x05
            case 18:
                uint = 0x06
            case 21:
                uint = 0x07
            case 24:
                uint = 0x08
            default:
                break
            }
            
            let mnemonic = Mnemonic(rawData: try cmdSet.generateMnemonic(p1: uint).checkOK().data)
            mnemonic.useBIP39EnglishWordlist()
            print(mnemonic.toMnemonicPhrase())
            generatedPhrase = mnemonic.toMnemonicPhrase()
                
            print("pin verifying")
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
            print("pin verified")
            
//            print("loading key")
//            try cmdSet.loadKey(keyPair: mnemonic.toBIP32KeyPair()).checkOK()

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
            
            let alert = UIAlertController(title: "BIP39 phrase correctly generated:", message: "\(generatedPhrase)", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Export", style: .default, handler: {
                (_) in
                share(str: (generatedPhrase), instance: self)
            }))
            self.present(alert, animated: true)
            
        }
    }
        
    
    
    @IBAction func generateButtonPressed(_ sender: Any) {
        beginScanning()
    }
    
}


extension CreateBIP39Controller: UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String(pickerData[row])
    }
    
    
    func createPicker() {
        wordsNumberPicker.delegate = self
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let button = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.dismissPicker))
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancel))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([button, flexibleSpace, cancel], animated: true)
        toolbar.isUserInteractionEnabled = true
        
        numberTF.inputAccessoryView = toolbar
        numberTF.inputView = wordsNumberPicker
    }
    
    
    @objc func dismissPicker() {
        let dataString = pickerView(wordsNumberPicker, titleForRow: wordsNumberPicker.selectedRow(inComponent: 0), forComponent: 0)
        wordsNumber = Int(dataString!)!
        numberTF.text = String(wordsNumber)
        numberTF.resignFirstResponder()
        
        wordsNumberPicker.selectRow(0, inComponent: 0, animated: true)
    }
    
    
    @objc func cancel() {
        view.endEditing(true)
        wordsNumberPicker.selectRow(0, inComponent: 0, animated: true)
    }
    

}


