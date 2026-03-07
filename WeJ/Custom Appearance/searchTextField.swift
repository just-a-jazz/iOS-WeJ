//
//  searchTextField.swift
//  WeJ
//
//  Created by Mohammad Ali Siddiqui on 3/15/17.
//  Copyright © 2017 Mohammad Ali Siddiqui. All rights reserved.
//

import UIKit

class searchTextField: UITextField, UITableViewDelegate, UITableViewDataSource {
    
    private let searchIconView = UIImageView(frame: CGRect(x: 0, y: 0, width: 17, height: 17))
    
    private var closeButtonBar: UIToolbar!
    private var hintsTableView: UITableView!
    private var hintsList = [String]()
    private var latestTerm = String()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        customizeTextField()
    }
    
    private func customizeTextField() {
        tintColor = AppConstants.orange
        autocapitalizationType = UITextAutocapitalizationType.sentences
        returnKeyType = .search
        addBottomBorder()
        addSearchIcon()
        addKeyboardAccessory()
        addTargets()
    }
    
    private func addBottomBorder() {
        let bottomLine = CALayer()
        bottomLine.frame = CGRect(x: 0, y: frame.height - 1, width: frame.width, height: 1)
        bottomLine.backgroundColor = AppConstants.orange.cgColor
        borderStyle = .none
        layer.addSublayer(bottomLine)
    }
    
    private func addSearchIcon() {
        leftViewMode = .always
        
        searchIconView.image = #imageLiteral(resourceName: "searchIcon")
        leftView = searchIconView
    }
    
    private func addKeyboardAccessory() {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 194))
        containerView.backgroundColor = .clear
        
        containerView.addSubview(getCloseBarButton())
        containerView.addSubview(getHintsTableView())
        
        
        inputAccessoryView = containerView
    }
    
    private func getCloseBarButton() -> UIToolbar {
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let closeBarButton = UIBarButtonItem(customView: getCloseButton())
        
        closeButtonBar = UIToolbar(frame: CGRect(x: 0, y: 150, width: UIScreen.main.bounds.width, height: 44))
        closeButtonBar.barTintColor = AppConstants.darkerBlack
        closeButtonBar.isTranslucent = false
        closeButtonBar.items = [flexSpace, closeBarButton]
        closeButtonBar.sizeToFit()
        
        return closeButtonBar
    }
    
    private func getCloseButton() -> UIButton {
        let closeButton = UIButton(frame: CGRect(x: 0, y: 0, width: 51, height: 44))
        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.setTitleColor(AppConstants.orange, for: .highlighted)
        closeButton.addTarget(self, action: #selector(searchTextField.closeKeyboard), for: .touchUpInside)
        
        closeButton.titleLabel?.font = UIFont(name: "AvenirNext-Regular", size: 15)
        
        return closeButton
    }
    
    @objc private func closeKeyboard() {
        resignFirstResponder()
        hideHintsTableView()
    }
    
    private func getHintsTableView() -> UITableView {
        UITableView.appearance().backgroundColor = AppConstants.darkerBlack
        UITableView.appearance().separatorStyle = .none
        
        hintsTableView = UITableView(frame: CGRect(x: 0, y: 194, width: UIScreen.main.bounds.width, height: 150), style: .plain)
        hintsTableView.register(HintTableViewCell.self, forCellReuseIdentifier: "Hint Cell")
        
        hintsTableView.delegate = self
        hintsTableView.dataSource = self
        
        return hintsTableView
    }
    
    private func addTargets() {
        addTarget(self, action: #selector(reloadHintsList), for: .editingChanged)
    }
    
    func showHintsTableView() {
        UIView.animate(withDuration: 0.7) { [weak self] in
            self?.hintsTableView.frame = CGRect(x: 0, y: 44, width: UIScreen.main.bounds.width, height: 150)
            self?.closeButtonBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        }
    }
    
    func hideHintsTableView() {
        UIView.animate(withDuration: 0.7) { [weak self] in
            self?.hintsTableView.frame = CGRect(x: 0, y: 194, width: UIScreen.main.bounds.width, height: 150)
            self?.closeButtonBar.frame = CGRect(x: 0, y: 150, width: UIScreen.main.bounds.width, height: 44)
        }
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: searchIconView.frame.maxX + 10, y: bounds.origin.y, width: bounds.width, height: bounds.height)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: searchIconView.frame.maxX + 10, y: bounds.origin.y, width: bounds.width, height: bounds.height)
    }
    
    // MARK: - Table
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return hintsList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Hint Cell", for: indexPath) as! HintTableViewCell
        cell.backgroundColor = .clear
        cell.hintLabel.text = hintsList[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Hint Cell", for: indexPath) as! HintTableViewCell
        cell.backgroundColor = .clear
        text = hintsList[indexPath.row]
        
        let _ = delegate?.textFieldShouldReturn?(self)
    }
    
    @objc func reloadHintsList() {
        if text!.isEmpty {
            hideHintsTableView()
            return
        }
        
        latestTerm = text!
//        AppleMusicFetcher.getSearchHints(forTerm: text!) { [weak self] (hints) in
//            guard self != nil && self!.latestTerm == self!.text! else { return }
//            
//            self?.hintsList = hints
//            self?.hintsTableView.reloadData()
//            
//            if !hints.isEmpty {
//                self?.hintsTableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
//                self?.showHintsTableView()
//            } else {
//                self?.hideHintsTableView()
//            }
//        }
    }
    
}
