//
//  AuthenticationController.swift
//  KeycardSwiftIntegration
//
//  Created by Luigi Borchia on 06/01/2020.
//  Copyright © 2020 Luigi Borchia. All rights reserved.
//

import UIKit

class AuthenticationController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

         self.tabBarController?.navigationItem.titleView = imageView
        //self.tabBarItem.image = UIImage(named: "authentication")
    }
 

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 30))
        
        footerView.backgroundColor = UIColor.black

        return footerView
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 && indexPath.row == 1 {
            print("mario")
            performSegue(withIdentifier: "initialScreenUnwind", sender: self)
        }
    }

}
