//
//  SettingsController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 12/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit
import Keycard

class SettingsController: UITableViewController {
    
    var session: KeycardController?
    var newPin: String?
    var newPuk: String?
    var newPairingPass: String?

    override func viewDidLoad() {
        super.viewDidLoad()
         self.title = "Settings"
    }
    

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 30))
        
        footerView.backgroundColor = UIColor.black

        return footerView
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            changeSettings()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    func changeSettings() {
        let alert = UIAlertController(title: "Change Keycard credentials", message: "Please enter new credentials.", preferredStyle: .alert)
        
        
        alert.addTextField { (pin) in
            pin.placeholder = "New PIN (must be 6 digits)"
            pin.keyboardType = .numberPad
            pin.isSecureTextEntry = true
        }
        
        alert.addTextField { (puk) in
            puk.placeholder = "New PUK (must be 12 digits)"
            puk.keyboardType = .numberPad
            puk.isSecureTextEntry = true
        }
        
        alert.addTextField { (password) in
            password.placeholder = "New pairing password"
            password.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
 
            print("the pin will be: " + (alert?.textFields![0].text)!)
            print("the puk will be: " + (alert?.textFields![1].text)!)
            print("the password will be: " + (alert?.textFields![2].text)!)
            
            self.newPin = alert?.textFields![0].text
            self.newPuk = alert?.textFields![1].text
            self.newPairingPass = alert?.textFields![2].text
            
            dGroup.enter()
            DispatchQueue.global(qos: .default).async {
                self.beginScanning()
            }
            dGroup.wait()
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
                let pinTextField = alert.textFields?[0]
                let pukTextField = alert.textFields![1]
                let passTextField = alert.textFields![2]
                alert.actions[0].isEnabled = !pukTextField.text!.isEmpty && !passTextField.text!.isEmpty &&  !pinTextField!.text!.isEmpty
            }
        }
    }
    
    
    func beginScanning() {
        session = KeycardController(onConnect: onCon, onFailure: nonCon)
        session?.start(alertMessage: "Hold your Keycard near iPhone.")
    }
    
    
    func onCon(cc:CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cc)
        
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
            try cmdSet.verifyPIN(pin: pin!).checkAuthOK()
    
            try cmdSet.changePIN(pin: newPin!).checkOK()
            try cmdSet.changePUK(puk: newPuk!).checkOK()
            try cmdSet.changePairingPassword(pairingPassword: newPairingPass!).checkOK()

            try cmdSet.autoUnpair()
     
        }catch let error{
            print("Interrupted: "+error.localizedDescription)
            session?.stop(errorMessage: "Could not complete the operation: \(error.localizedDescription)")
            
            do {
                try cmdSet.autoUnpair()
            } catch {
                print(error)
            }
            
        }
        session?.stop(alertMessage: "Credentials correctly changed.")
        dGroup.leave()
    }
    
}
