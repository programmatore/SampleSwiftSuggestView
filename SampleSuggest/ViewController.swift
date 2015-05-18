//
//  ViewController.swift
//  SampleSuggest
//
//  Created by nagisa-kosuge on 2015/05/18.
//  Copyright (c) 2015年 RyoKosuge. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

// MARK : - navigation bar item action.

extension ViewController {
    
    @IBAction func tapSearchBtn(sender: UIBarButtonItem) {
        println(__FUNCTION__)
        let viewController = SuggestViewController.instantiateViewController()
        presentViewController(viewController, animated: true, completion: nil)
    }
    
}