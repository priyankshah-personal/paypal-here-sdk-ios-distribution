//
//  InitializeViewController.swift
//  PPHSDKSampleApp
//
//  Created by Wright, Cory on 11/16/16.
//  Copyright © 2016 cowright. All rights reserved.
//

import UIKit
import SafariServices
import PayPalRetailSDK

// Set up the notification name which will receive the token from the sample server
let kCloseSafariViewControllerNotification = "kCloseSafariViewControllerNotification"

class InitializeViewController: UIViewController, SFSafariViewControllerDelegate {
    
    @IBOutlet weak var btnMerchantSettings: UIButton!
    @IBOutlet weak var envSelector: UISegmentedControl!
    @IBOutlet weak var initSdkButton: CustomButton!
    @IBOutlet weak var initSdkCode: UITextView!
    @IBOutlet weak var initMerchantButton: CustomButton!
    @IBOutlet weak var initMerchCode: UITextView!
    @IBOutlet weak var initOfflineButton: CustomButton!
    @IBOutlet weak var initOfflineCode: UITextView!
    @IBOutlet weak var merchAcctLabel: UILabel!
    @IBOutlet weak var merchEmailLabel: UILabel!
    @IBOutlet weak var initMerchantActivitySpinner: UIActivityIndicatorView!
    @IBOutlet weak var initOfflineActivitySpinner: UIActivityIndicatorView!
    @IBOutlet weak var logoutBtn: CustomButton!
    @IBOutlet weak var merchInfoView: UIView!
    @IBOutlet weak var connectCardReaderBtn: CustomButton!
    
    var svc: SFSafariViewController?
    var storeMerchant: PPRetailMerchant?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.btnMerchantSettings.isUserInteractionEnabled = false
        
        setUpDefaultView()
        // Receive the notification that the token is being returned
        NotificationCenter.default.addObserver(self, selector: #selector(setupMerchant(notification:)), name: NSNotification.Name(rawValue: kCloseSafariViewControllerNotification), object: nil)
        
    }
    
    @IBAction func initSDK(_ sender: CustomButton) {
        
        initMerchantButton.isEnabled = true
        initOfflineButton.isEnabled = true
        
        // First things first, we need to initilize the SDK itself.
        PayPalRetailSDK.initializeSDK()
        
        initSdkButton.changeToButtonWasSelected(initSdkButton)
        initSdkButton.isEnabled = false
    }
    
    @IBAction func initMerchant(_ sender: CustomButton) {
        
        envSelector.isEnabled = false
        self.initMerchantActivitySpinner.color = UIColor.black
        initMerchantActivitySpinner.startAnimating()
        performLogin(offline: false)
        
    }
    
    // In order for Offline initialization to be successful, at least one prior successful online log in required.
    // When you Initialize offline, only offline transactions will be allowed and replay transactions will not be allowed.
    @IBAction func initOffline(_ sender: CustomButton) {
        envSelector.isEnabled = false
        self.initOfflineActivitySpinner.color = UIColor.black
        initOfflineActivitySpinner.startAnimating()
        PayPalRetailSDK.initializeMerchantOffline { [weak self] (error, merchant) in
            if let err = error {
                print("Offline Init Failed")
                self?.merchantFailedLogIn(offline: true, error: err)
            } else {
                self?.storeMerchant = merchant
                print("Offline Init Successful")
                self?.merchantSuccessfullyLoggedIn(offline: true, merchant: merchant!)
                
            }
        }
    }
    
    func performLogin(offline: Bool) {
        
        // Set your URL for your backend server that handles OAuth.  This sample uses an instance of the
        // sample retail node server that's available at https://github.com/paypal/paypal-retail-node. To
        // set this to Live, simply change /sandbox to /live.  The returnTokenOnQueryString value tells
        // the sample server to return the actual token values instead of the compositeToken
        let url = NSURL(string: "http://pph-retail-sdk-sample.herokuapp.com/toPayPal/" + envSelector.titleForSegment(at: envSelector.selectedSegmentIndex)!.lowercased() + "?returnTokenOnQueryString=true")
        
        // Check if there's a previous token saved in UserDefaults and, if so, use that.  This will also
        // check that the saved token matches the environment.  Otherwise, kick open the
        // SFSafariViewController to expose the login and obtain another token.
        let tokenDefault = UserDefaults.init()
        if((tokenDefault.string(forKey: "ACCESS_TOKEN") != nil) && (envSelector.titleForSegment(at: envSelector.selectedSegmentIndex)!.lowercased() == tokenDefault.string(forKey: "ENVIRONMENT"))) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kCloseSafariViewControllerNotification), object: tokenDefault.string(forKey: "ACCESS_TOKEN"))
        } else {
            // Present a SFSafariViewController to handle the login to get the merchant account to use.
            let svc = SFSafariViewController(url: url! as URL)
            svc.delegate = self
            self.present(svc, animated: true, completion: nil)
        }
    }
    
    @objc func setupMerchant(notification: NSNotification) {
        
        self.initMerchantButton.isHidden = true
        self.initOfflineButton.isHidden = true
        
        
        // Dismiss the SFSafariViewController when the notification of token has been received.
        self.presentedViewController?.dismiss(animated: true, completion: {
            print("successful dismissal")
        })
        
        // Grab the token(s) from the notification and pass it into the merchant initialize call to set up
        // the merchant.  Upon successful initialization, the 'Connect Card Reader' button will be
        // enabled for use.
        let accessToken = notification.object as! String
        
        let tokenDefault = UserDefaults.init()
        let sdkCreds = SdkCredential.init(accessToken: accessToken, refreshUrl: tokenDefault.string(forKey: "REFRESH_URL"), environment: tokenDefault.string(forKey: "ENVIRONMENT"))
        
        PayPalRetailSDK.initializeMerchant(withCredentials: sdkCreds) { [weak self] (error, merchant) in
            if let err = error {
                self?.merchantFailedLogIn(offline: false, error: err)
            } else {
                print("Merchant Success!")
                self?.storeMerchant = merchant
                self?.merchantSuccessfullyLoggedIn(offline: false, merchant: merchant!)
            }
        }
    }
    
    func merchantSuccessfullyLoggedIn(offline: Bool, merchant: PPRetailMerchant){
        let tokenDefault = UserDefaults.init()
        if offline {
            // Remeber to store whether you initialized in Offline Mode.
            // For now, there is no way to query offlineInit state for Merchant on SDK.
            tokenDefault.setValue(true, forKey: "offlineSDKInit")
            self.initOfflineActivitySpinner.stopAnimating()
            self.initOfflineButton.isHidden = false
            self.initOfflineButton.changeToButtonWasSelected(self.initOfflineButton)
            self.initOfflineButton.isEnabled = false
            self.merchEmailLabel.text = "Initialized Offline"
        } else {
            tokenDefault.removeObject(forKey: "offlineSDKInit")
            self.initMerchantActivitySpinner.stopAnimating()
            self.initMerchantButton.isHidden = false
            self.initMerchantButton.changeToButtonWasSelected(self.initMerchantButton)
            self.initMerchantButton.isEnabled = false
            self.merchEmailLabel.text = merchant.emailAddress
            self.btnMerchantSettings.backgroundColor = UIColor(red: 0/255.0, green: 104.0/255.0, blue: 174.0/255.0, alpha: 1)
            self.btnMerchantSettings.isUserInteractionEnabled = true
        }
        
        self.merchInfoView.isHidden = false
        
        // Save currency to UserDefaults for further usage. This needs to be used to initialize
        // the PPRetailRetailInvoice for the payment later on. This app is using UserDefault but
        // it could just as easily be passed through the segue.
        tokenDefault.setValue(merchant.currency, forKey: "MERCH_CURRENCY")
        self.setCurrencyType()
        
        // Add the BN code for Partner tracking. To obtain this value, contact
        // your PayPal account representative. Please do not change this value when
        // using this sample app for testing.
        //        merchant.referrerCode = "PPHSDK_SampleApp_iOS"
        
        //Enable the connect card reader button here
        self.connectCardReaderBtn.isHidden = false
    }
    
    func merchantFailedLogIn(offline: Bool, error: PPRetailError){
        if offline {
            self.initOfflineButton.isHidden = false
            self.initOfflineActivitySpinner.color = UIColor.red
            self.initOfflineActivitySpinner.stopAnimating()
        } else {
            self.initMerchantButton.isHidden = false
            self.initMerchantActivitySpinner.color = UIColor.red
            self.initMerchantActivitySpinner.stopAnimating()
        }
        print("Debug ID: \(String(describing: error.debugId))")
        print("Error Message: \(String(describing: error.message))")
        print("Error Code: \(String(describing: error.code))")
        
        // The token did not work, so clear the saved token so we can go back to the login page
        let tokenDefault = UserDefaults.init()
        tokenDefault.removeObject(forKey: "ACCESS_TOKEN")
    }
    
    @IBAction func logout(_ sender: CustomButton) {
        
        // Clear out the UserDefaults and show the appropriate buttons/labels
        let tokenDefault = UserDefaults.init()
        tokenDefault.removeObject(forKey: "ACCESS_TOKEN")
        tokenDefault.removeObject(forKey: "REFRESH_URL")
        tokenDefault.removeObject(forKey: "ENVIRONMENT")
        tokenDefault.removeObject(forKey: "MERCH_CURRENCY")
        tokenDefault.synchronize()
        
        merchEmailLabel.text = ""
        merchInfoView.isHidden = true
        initMerchantButton.isEnabled = true
        initMerchantButton.borderWidth = 1.0
        initOfflineButton.isHidden = false
        initOfflineButton.isEnabled = true
        initOfflineButton.borderWidth = 1.0
        envSelector.isEnabled = true
        connectCardReaderBtn.isHidden = true
    }
    
    
    @IBAction func goToDeviceDiscovery(_ sender: Any) {
        performSegue(withIdentifier: "showDeviceDiscovery", sender: sender)
    }
    
    
    // This function would be called if the user pressed the Done button inside the SFSafariViewController.
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        
        initMerchantActivitySpinner.stopAnimating()
        initMerchantButton.isEnabled = true
        envSelector.isEnabled = true
        
    }
    
    func setCurrencyType(){
        let userDefaults = UserDefaults.init()
        guard let merchantCurrency: String = userDefaults.value(forKey: "MERCH_CURRENCY") as? String else { return }
        print("Merchant Currency is: ", merchantCurrency)
        
        if merchantCurrency == Currency.GBP.rawValue {
            userDefaults.set("￡", forKey: "CURRENCY_SYMBOL")
        } else {
            userDefaults.set("$", forKey: "CURRENCY_SYMBOL")
        }
    }
    
    private func setUpDefaultView(){
        // Setting up initial aesthetics.
        merchInfoView.isHidden = true
        initMerchantButton.isEnabled = false
        initOfflineButton.isEnabled = false
        connectCardReaderBtn.isHidden = true
        
        initSdkCode.text = "PayPalRetailSDK.initializeSDK()"
        initMerchCode.text = "PayPalRetailSDK.initializeMerchant(withCredentials: sdkCreds) { (error, merchant) -> Void in \n" +
            "     <code to handle success/failure>\n" +
            "})"
        initOfflineCode.text = "PayPalRetailSDK.initializeMerchantOffline { (error, merchant) -> Void in \n" +
            "     <code to handle success/failure>\n" +
            "})"
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
    
}

extension InitializeViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "MerchantSettingsSegue" {
            if segue.destination.isKind(of: MerchantSettingsController.self) {
                guard let merchantVC = segue.destination as? MerchantSettingsController else {
                    return
                }
                merchantVC.merchant = storeMerchant
            }
        }
    }
}

enum Currency: String {
    case USD = "USD"
    case GBP = "GBP"
    case AUD = "AUD"
}

