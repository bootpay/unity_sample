//
//  BootpayWebview.swift
//  client_bootpay_swift
//
//  Created by YoonTaesup on 2017. 8. 11..
//  Copyright © 2017년 bootpay.co.kr. All rights reserved.
//

import UIKit
import WebKit
//import

@objc public protocol BootpayRequestProtocol {
    @objc(onError:) func onError(data: [String: Any])
    @objc(onReady:) func onReady(data: [String: Any])
    @objc func onClose()
    @objc(onConfirm:) func onConfirm(data: [String: Any])
    @objc(onCancel:) func onCancel(data: [String: Any])
    @objc(onDone:) func onDone(data: [String: Any])
}

@objc class BootpayWebView: UIView {
    var wv: WKWebView!
 
    let configuration = WKWebViewConfiguration()
    
    var popupWV: WKWebView!
    final let BASE_URL = "https://inapp.bootpay.co.kr/3.2.3/production.html"
    final let bridgeName = "Bootpay_iOS"
    var firstLoad = false
    weak var sendable: BootpayRequestProtocol?
    var bootpayScript = ""
    var parentController: BootpayController!
     
    
    func bootpayRequest(_ script: String, _ isOneStroe: Bool = false) {
        HTTPCookieStorage.shared.cookieAcceptPolicy = HTTPCookie.AcceptPolicy.always  // 현대카드 등 쿠키설정 이슈 해결을 위해 필요
        configuration.userContentController.add(self, name: bridgeName)
        wv = WKWebView(frame: self.bounds, configuration: configuration)
        wv.uiDelegate = self
        wv.navigationDelegate = self
        self.addSubview(wv)
        self.bootpayScript = script
        self.loadUrl(BASE_URL)
    }
}

extension BootpayWebView {
    internal func doJavascript(_ script: String) {
        wv.evaluateJavaScript(script, completionHandler: nil)
    }
    
    internal func loadUrl(_ urlString: String) {
        let url = URL(string: urlString)
        if let url = url {
//            prin
            
            let request = URLRequest(url: url)
            wv.load(request)
        }
    }
    
    func startRequest(_ request: URLRequest) {
        wv.load(request)
    }
     
    func registerAppId() {
        doJavascript("window.BootPay.setApplicationId('\(Bootpay.sharedInstance.application_id)');")
    }
    
    func useOneStore() {
        let ad_id = "UNKNOWN_ADID"
        let sim_operation = "UNKNOWN_SIM_OPERATOR"
        let installerPackageName = "UNKNOWN_INSTALLER"
        
        doJavascript("window.BootPay.useOnestoreApi({ad_id: '\(ad_id)', sim_operation: '\(sim_operation)', installerPackageName: '\(installerPackageName)'});")
    }
    
    func setDevelopmode() {
        doJavascript("window.BootPay.setMode('development');")
    }
    
    internal func setDevice() {
        doJavascript("window.BootPay.setDevice('IOS');") 
    }
    
    internal func setAnalytics() {
         Bootpay.sharedInstance.sessionActive(active: true)
        if Bootpay.sharedInstance.sk_time == 0 {
            NSLog("Bootpay Analytics Warning: setAnalytics() not Work!! Please session active in AppDelegate")
            return
        }
        
        doJavascript("window.BootPay.setAnalyticsData({"
            + "sk: '\(Bootpay.sharedInstance.sk)', "
            + "sk_time: \(Bootpay.sharedInstance.sk_time), "
            + "time: \(Bootpay.sharedInstance.time), "
            + "uuid: '\(Bootpay.sharedInstance.uuid)'"
            + "});")
    }
    
    internal func loadBootapyRequest() {
        doJavascript(self.bootpayScript)
    }
}

extension BootpayWebView: WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler  {
     
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if firstLoad == false {
            firstLoad = true
            registerAppId() 
            setDevice()
            setAnalytics()
            loadBootapyRequest()
        }
    }
    
    func isMatch(_ urlString: String, _ pattern: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
//        let result = regex.matches(in: urlString, options: [], range: NSRange(location: 0, length: urlString.characters.count))
        let result = regex.matches(in: urlString, options: [], range: NSRange(location: 0, length: urlString.count))
        return result.count > 0
    }
    
    func isItunesURL(_ urlString: String) -> Bool {
        return isMatch(urlString, "\\/\\/itunes\\.apple\\.com\\/")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if(isItunesURL(url.absoluteString)) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
                decisionHandler(.cancel)
            } else if url.scheme != "http" && url.scheme != "https" {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    } 
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alertController = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "확인", style: .default) { _ in
            completionHandler()
        }
        let cancelAction = UIAlertAction(title: "결제창 닫기", style: .default) { _ in
            completionHandler()
            self.parentController.dismiss()
        }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        DispatchQueue.main.async { self.parentController.present(alertController, animated: true, completion: nil) }
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in
            completionHandler(true)
        }))
        alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in
            completionHandler(false)
        }))
        
        DispatchQueue.main.async { self.parentController.present(alertController, animated: true, completion: nil) }
    }
    
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if(message.name == self.bridgeName) {
            guard let body = message.body as? [String: Any] else {
                if message.body as? String == "close" {
//                    Bootpay.sharedInstance.sendab
//                    Bootpay.sharedInstance.vc.sendable.onClose()
                    sendable?.onClose()
                }
                return
            }
            guard let action = body["action"] as? String else { return }
            
            if action == "BootpayCancel" {
                sendable?.onCancel(data: body)
            } else if action == "BootpayError" {
                sendable?.onError(data: body)
            } else if action == "BootpayBankReady" {
                sendable?.onReady(data: body)
            } else if action == "BootpayConfirm" {
                sendable?.onConfirm(data: body)
            } else if action == "BootpayDone" {
                sendable?.onDone(data: body)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        if(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
            let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, cred)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
//         let wv = WKWebView()
         let wv = WKWebView(frame: self.bounds, configuration: configuration)
        wv.load(navigationAction.request)
        wv.uiDelegate = self
        wv.navigationDelegate = self
        self.addSubview(wv)
         
        return wv
    }
}


