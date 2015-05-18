//
//  SuggestViewController.swift
//  SampleSuggest
//
//  Created by nagisa-kosuge on 2015/05/18.
//  Copyright (c) 2015年 RyoKosuge. All rights reserved.
//

import UIKit
import BrightFutures

class SuggestViewController: UIViewController {
    
    private static let StoryboardFilename = "Main"
    private static let StoryboardIdentifier = "SuggestViewController"
    private static let StoryboardNavigationIdentifier = "SuggestNavigationController"
    
    dynamic var suggestItems: [String] = []
    
    class func instantiateViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: StoryboardFilename, bundle: nil)
        
        let navViewController = storyboard.instantiateViewControllerWithIdentifier(StoryboardNavigationIdentifier) as! UINavigationController
        navViewController.modalPresentationStyle = UIModalPresentationStyle.OverCurrentContext
        navViewController.modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
        navViewController.navigationBarHidden = true
        
        let viewControlelr = navViewController.viewControllers.first as! UIViewController
        
        return navViewController
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var constTableViewHeight: NSLayoutConstraint!
    
    var searchBar: UISearchBar!

    override func viewDidLoad() {
        super.viewDidLoad()
        println(__FUNCTION__)
        setupSearchBar()
        setupTableView()
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: "suggestItems")
        tableView.removeObserver(self, forKeyPath: "contentSize")
    }
}

// MARK : - set up

extension SuggestViewController {
    
    private func setupSearchBar() {
        if let navigationBarFrame = navigationController?.navigationBar.bounds {
            let searchBar: UISearchBar = UISearchBar(frame: navigationBarFrame)
            searchBar.delegate = self
            searchBar.showsCancelButton = true
            searchBar.keyboardAppearance = UIKeyboardAppearance.Dark
            searchBar.keyboardType = UIKeyboardType.Default
            navigationItem.titleView = searchBar
            navigationItem.titleView?.frame = searchBar.frame
            self.searchBar = searchBar
            searchBar.becomeFirstResponder()
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.hidden = true
        
        self.addObserver(self, forKeyPath: "suggestItems", options: NSKeyValueObservingOptions.New, context: nil)
        tableView.addObserver(self, forKeyPath: "contentSize", options: (NSKeyValueObservingOptions.New), context: nil)
    }
}

// MARK : - tableView height observer

extension SuggestViewController {
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        println(__FUNCTION__)
        if keyPath == "contentSize" {
            didChangeTableViewContentHeight()
        } else if keyPath == "suggestItems" {
            didChangeSuggestItems()
        }
    }
    
    private func didChangeTableViewContentHeight() {
        println(__FUNCTION__)
        constTableViewHeight.constant = tableView.contentSize.height
        tableView.setNeedsLayout()
        tableView.setNeedsUpdateConstraints()
        UIView.animateWithDuration(0.6, animations: {[weak self] () -> Void in
            self?.tableView.layoutIfNeeded()
        })
    }
    
    private func didChangeSuggestItems() {
        dispatch_async(dispatch_get_main_queue(), {[weak self] () -> Void in
            self?.tableView.hidden = false
            self?.tableView.reloadData()
        })
    }
}

// MARK : - tableview delegate

extension SuggestViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

// MARK : - tableview dataSource

extension SuggestViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let TableViewBasicCellIdentifier = "BasicCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(TableViewBasicCellIdentifier, forIndexPath: indexPath) as! UITableViewCell
        cell.textLabel?.text = suggestItems[indexPath.row]
        return cell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestItems.count
    }
}

// MARK : - search bar delegate

extension SuggestViewController: UISearchBarDelegate {
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        println(__FUNCTION__)
        searchBar.resignFirstResponder()
        navigationController?.setNavigationBarHidden(true, animated: true)
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        println(__FUNCTION__)
        println("searchText = \(searchText)")
        self.searchSuggestKeyword(searchText)
    }
    
}

// MARK : - search suggest keyword

extension SuggestViewController {
    
    private func searchSuggestKeyword(keyword: String) {
        if count(keyword) < 1 {
            return
        }
        
        futureSuggestRequest(keyword).onSuccess { suggestItems in
            self.suggestItems = suggestItems
        }.onFailure { error in
            println("error = \(error)")
        }
        
    }
    
    private func futureSuggestRequest(searchKeywork: String) -> Future<[String]> {
        println(__FUNCTION__)
        let promiss = Promise<[String]>()
        
        Queue.global.async {
            if let URL = self.createSuggestURL(searchKeywoard: searchKeywork) {
                let request = self.requestURL(URL)
                self.sendRequest(request).flatMap { data in
                    self.futureSuggestItems(data: data)
                }.onSuccess { suggestItems in
                    promiss.success(suggestItems)
                }.onFailure { error in
                    promiss.failure(error)
                }
            }
        }
        
        return promiss.future
    }
    
    private func sendRequest(request: NSURLRequest) -> Future<NSData> {
        println(__FUNCTION__)
        let promiss = Promise<NSData>()
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request, completionHandler: { (responseData: NSData!, urlResponse: NSURLResponse?, connectError: NSError?) -> Void in
            if let error = connectError {
                promiss.failure(error)
            } else {
                promiss.success(responseData)
            }
        })
        task.resume()
        return promiss.future
    }
    
    private func futureSuggestItems(#data: NSData) -> Future<[String]> {
        println(__FUNCTION__)
        let promiss = Promise<[String]>()
        if let dataString = NSString(data: data, encoding: NSShiftJISStringEncoding), d = dataString.dataUsingEncoding(NSUTF8StringEncoding) {
            var error: NSError? = nil
            if let jsonArray = NSJSONSerialization.JSONObjectWithData(d, options: NSJSONReadingOptions.AllowFragments, error: &error) as? NSArray {
                let suggestItems = convertSuggestItems(jsonArray)
                promiss.success(suggestItems)
            } else {
                if let e = error {
                    promiss.failure(e)
                }
            }
        } else {
            let error = NSError(domain: "SampleSuggest", code: 9999, userInfo: nil)
            promiss.failure(error)
        }
        return promiss.future
    }
    
    private func convertSuggestItems(jsonArray: NSArray) -> [String] {
        println(__FUNCTION__)
        var newSuggestWords: [String] = []
        if let strs = jsonArray.lastObject as? [String] {
            for str in strs {
                newSuggestWords.append(str)
            }
        }
        
        return newSuggestWords
    }
    
    private func requestURL(URL: NSURL) -> NSURLRequest {
        println(__FUNCTION__)
        var request = NSMutableURLRequest(URL: URL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("applicatoin/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.HTTPMethod = "GET"
        return request
    }
    
    private func createSuggestURL(#searchKeywoard: String) -> NSURL? {
        println(__FUNCTION__)
        let urlString = "http://clients1.google.com/complete/search?hl=ja&ds=yt&client=firefox&q=\(searchKeywoard.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)"
        return NSURL(string: urlString)
    }
    
}