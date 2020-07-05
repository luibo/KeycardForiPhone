//
//  ViewController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 11/12/2019.
//  Copyright © 2019 Luigi Borchia. All rights reserved.
//

import UIKit
import Foundation
import CoreNFC
import Keycard

//last revision 04-07-2020

class ViewController: UIViewController {
    
    @IBOutlet weak var pinTF: UITextField!
    @IBOutlet weak var passTF: UITextField!
    @IBOutlet weak var versionLabel: UILabel! {
        didSet {
            versionLabel.text = "v \(appVersion)"
        }
    }
    
    var session: KeycardController?
    //var applicationInfo: ApplicationInfo?
    var hasMasterKey = false
    var freeSlots = 0
    var instanceUID: [UInt8]?
    var appletVersion: String?
    var keyUID: [UInt8]?
    
    @IBOutlet weak var scanButton: UIButton! {
        didSet {
            scanButton.layer.cornerRadius = 10
        }
    }
    
    @IBOutlet weak var cardManagerButton: UIButton! {
        didSet {
            cardManagerButton.isHidden = true
        }
    }
    
    var alert = UIAlertController()

    override func viewDidLoad() {
        super.viewDidLoad()
        //self.title = "Keycard for iPhone"

        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

        view.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        checkAvailability()
        //self.navigationController?.navigationBar.topItem?.titleView = imageView

    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.navigationBar.topItem?.titleView = imageView
        
    }
    
    @IBAction func unwindToVC1(segue:UIStoryboardSegue) { }

    
    func checkAvailability() {
        
        guard NFCReaderSession.readingAvailable else {
            let alert = UIAlertController(title: "Execution stopped", message: "\nNFC not available on this device.", preferredStyle: .alert)

            self.present(alert, animated: true)

            return
        }
    }


    @IBAction func scanAction(_ sender: Any) {
        
        guard let pinT = pinTF.text, !pinT.isEmpty else {
            let alert = UIAlertController(title: "", message: "Please insert your PIN to proceed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        guard let password = passTF.text, !password.isEmpty else {
            let alert = UIAlertController(title: "", message: "Please insert your pairing password to proceed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        pp = passTF.text!
        pin = pinTF.text!
                
        session = KeycardController(onConnect: onConnection, onFailure: onDisconnection)
        print("Started scanning")
        session?.start(alertMessage: "Hold your Keycard near iPhone.")
    }
    
    
    //Card connection
    func onConnection(cardChannel: CardChannel) {
        let cmdSet = KeycardCommandSet(cardChannel: cardChannel)
        //var authData: [UInt8] = []
        
        do {
            //Preparation
            applicationInfo = try ApplicationInfo(cmdSet.select().checkOK().data)
            
            instanceUID = applicationInfo?.instanceUID
            appletVersion = applicationInfo?.appVersionString
            keyUID = applicationInfo?.keyUID
            
            if(!applicationInfo!.initializedCard) {
                
                if(puk == nil) {
                    session?.stop(alertMessage: "Keycard connected")
                    let group = DispatchGroup()
                    group.enter()
                    insertCredentials(group: group)
                    group.notify(queue: .main) {
                        self.scanAction(self)
                    }
                } else {
                    print(pin!)
                    print(puk!)
                    print(pp!)
                    try cmdSet.initialize(pin: pin!, puk: puk!, pairingPassword: pp!).checkOK()
                    //performPairing(applicationInfo: applicationInfo, cmdSet: cmdSet)
                }
                
            } else {
                print("Keycard already initialized")
            }
            


        } catch let error {
            print("An error occurred: \(error.localizedDescription)")
            session?.stop(errorMessage: error.localizedDescription)
            
        }
        
        //Pairing
        if !self.performPairing(applicationInfo: applicationInfo!, cmdSet: cmdSet) {
            return
        }
        
        //User authentication
        if !self.performAuthentication(info: applicationInfo!, cmdSet: cmdSet) {
            return
        }
        
        //Wallet verification
        self.checkWallet(info: applicationInfo!, cmd: cmdSet)
        
        //Current key derivation path
        currentKeypath = self.currentPath(cmdSet: cmdSet)
                       
        session?.stop(alertMessage: "Keycard connected")
    }
    
    
    func onDisconnection(error: Error) {
        print("Connection interrupted due to error: \(error)")
    }
    
    
    func onPause() {
        
    }
    
    
    func onResume() {
        
    }
    
    
    func insertCredentials(group: DispatchGroup) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Keycard not initialized", message: "Please enter new credentials to initialize the card.", preferredStyle: .alert)
            
            
            alert.addTextField { (pin) in
                pin.placeholder = "PIN (must be 6 digits)"
                pin.keyboardType = .numberPad
                pin.isSecureTextEntry = true
            }
            
            alert.addTextField { (puk) in
                puk.placeholder = "PUK (must be 12 digits)"
                puk.keyboardType = .numberPad
                puk.isSecureTextEntry = true
            }
            
            alert.addTextField { (password) in
                password.placeholder = "Pairing password"
                password.isSecureTextEntry = true
            }
            
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
                    //let textField = alert?.textFields![0] // Force unwrapping because we know it exists.
                    //print("Text field: \(textField!.text ?? "")")
                    
                let pinA = alert?.textFields![0].text
                print(pinA!)
            //              try cmdSet.initialize(pin: (alert?.textFields![0].text)!, puk: (alert?.textFields![1].text)!, pairingPassword: (alert?.textFields![2].text)!).checkOK()
                    print("the pin will be: " + (alert?.textFields![0].text)!)
                    print("the puk will be: " + (alert?.textFields![1].text)!)
                    print("the password will be: " + (alert?.textFields![2].text)!)
                pin = alert?.textFields![0].text
                puk = alert?.textFields![1].text
                pp = alert?.textFields![2].text

                UserDefaults.standard.set(pp, forKey: "pairingPassword")
                
                group.leave()
                            
            //                self.session?.stop(alertMessage: "Keycard connected")
            //                self.performPairing(applicationInfo: applicationInfo, cmdSet: cmdSet)


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
    }
    
     
    
    
    func performPairing(applicationInfo: ApplicationInfo, cmdSet: KeycardCommandSet) -> Bool {
        
        do {
            print("Pairing slots: ", applicationInfo.freePairingSlots)
            freeSlots = applicationInfo.freePairingSlots
            
            let pairing = (UserDefaults.standard.object(forKey: applicationInfo.instanceUID.toHexString()) as? [UInt8] ?? [UInt8] ())
                
            if pairing == [] {
                do {
                    //print("Saving pairing info")
                    try cmdSet.autoPair(password: pp!)
                    //UserDefaults.standard.set(cmdSet.pairing?.bytes, forKey: applicationInfo.instanceUID.toHexString())
                } catch {
                    print("Error: \(error)")
                }
            } else {
                print("Found pairing info")
                cmdSet.pairing = Pairing(pairingData: pairing)
            }

            //Opening secure channel
            print("opening secure channel")
            try cmdSet.autoOpenSecureChannel()
            print("secure channel opened")
                        
        } catch {
            print(error)
            session?.stop(errorMessage: error.localizedDescription)
            return false
        }
        
        return true
    }
    
    
    func performAuthentication(info: ApplicationInfo, cmdSet: KeycardCommandSet) -> Bool {
        let userPin = pin!
            print("user pin: \(userPin)")
            
            do {
                print("verifying pin: \(userPin)")
                try cmdSet.verifyPIN(pin: userPin).checkAuthOK()
                print("pin verified")
                
                try cmdSet.autoUnpair()
                //UserDefaults.standard.removeObject(forKey: info.instanceUID.toHexString())
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "goToHome", sender: self)
                    self.pinTF.text = ""
                    self.passTF.text = ""
                }
            } catch {
                print("cannot complete the operation due to error: \(error.localizedDescription)")
                session?.stop(errorMessage: error.localizedDescription)
                return false
            }
        return true
    }
    
    func checkWallet(info: ApplicationInfo, cmd: KeycardCommandSet) {
        if(info.hasMasterKey) {
            print("This Keycard already has a wallet.")
            hasMasterKey = true
        } else {
            print("No wallets found for this Keycard.")
        }
    }
    
    
    func currentPath(cmdSet: KeycardCommandSet) -> String {
        var k = ""
        do {
            let keyPath = KeyPath(data: try cmdSet.getStatus(info: 0x01).checkOK().data)
            k = keyPath.description
        } catch {
            print(error)
        }
        return k
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToHome" {
            //let destination = segue.destination as! InfoController
            let tabCtrl: UITabBarController = segue.destination as! UITabBarController
            let destination = tabCtrl.viewControllers![0] as! InfoController
            destination.hasMasterKey = self.hasMasterKey
            destination.appletVersion = self.appletVersion
            destination.freeSlots = self.freeSlots
            destination.instanceUID = self.instanceUID
            destination.keyUID = self.keyUID
        }
    }
    
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
}




