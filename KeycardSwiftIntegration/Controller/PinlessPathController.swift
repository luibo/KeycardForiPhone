//
//  PinlessPathController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 18/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit

class PinlessPathController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var pathTF: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        descriptionLabel.text = "This option allows you to define a BIP32 \n path which can be used to sign transactions (or meta-transactions) \n without requiring a PIN. \n The wallet assigned to this path can be \n considered unprotected, so our advice is \n to not hold great values on it."

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

        view.addGestureRecognizer(tap)
        
        
    }
    
    @IBAction func setPathPressed(_ sender: Any) {
        guard let pathT = pathTF.text, !pathT.isEmpty else {
            let alert = UIAlertController(title: "", message: "Please insert the path to proceed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        setPinlessPath(path: pathT)
         
    }
    
    
    func setPinlessPath(path: String) {
        
        dGroup.enter()
        DispatchQueue.global(qos: .default).async {
           beginCardSession()
        }
        dGroup.wait()
        
        do {
            try cmdSet?.setPinlessPath(path: path).checkOK()
            kSession?.stop(alertMessage: "Pinless path successfully defined.")
        } catch {
            print(error)
            kSession?.stop(errorMessage: "Could not complete the operation: \(error.localizedDescription)")
            
            do {
                try cmdSet?.autoUnpair()
            } catch {
                print(error)
            }
        }
    }
    
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
