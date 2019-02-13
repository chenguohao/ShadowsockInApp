
//
//  AMEWebVIewController.swift
//  GDWebBrowserClient
//
//  Created by Chen guohao on 2018/7/2.
//  Copyright © 2018年 Alexey Gordiyenko. All rights reserved.
//

import Foundation
import WebKit
@objcMembers
class AMEWebViewController:GDWebViewController,GDWebViewControllerDelegate{
    var webUrl = ""
    var btnBack : UIButton = UIButton.init(type: UIButtonType.custom)
    var closeHandler: (() -> ())?
    var usePush:Bool = false
    var defaultTitle:String? // 默认第一个界面的名字
    init(url:String , usePush: Bool = false) {
        super.init(nibName: nil, bundle: nil)
        webUrl = url
        self.usePush = usePush
        self.delegate = self
        self.loadURLWithString(webUrl)
        self.progressIndicatorStyle = .progressView
        self.allowsBackForwardNavigationGestures = true
        initNavItems()
    }
    
    init(localUrl:String , usePush: Bool = false) {
        super.init(nibName: nil, bundle: nil)
        webUrl = localUrl
        self.usePush = usePush
        self.delegate = self
        self.loadLocalUrlWithString(webUrl)
        self.progressIndicatorStyle = .progressView
        self.allowsBackForwardNavigationGestures = true
        initNavItems()
    }
    
    func initNavItems(){
        
        btnBack.setImage(UIImage.init(named: "webview_back_arrow"), for: .normal)
        btnBack.addTarget(self, action: #selector(onBack), for: .touchUpInside)
        let back = UIBarButtonItem.init(customView: btnBack)
        btnBack.isEnabled = true
//        let refresh = UIBarButtonItem.init(image: #imageLiteral(resourceName: "webview_refresh"), style: .plain, target: self, action: #selector(onRefresh))
//        self.navigationItem.leftBarButtonItems = [back,refresh]
        navigationItem.leftBarButtonItem = back
        
//        let close = UIBarButtonItem.init(image:#imageLiteral(resourceName: "webview_close"), style: .plain, target: self, action: #selector(onClose))
//        self.navigationItem.rightBarButtonItem = close
        
//        btnBack.isEnabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.barTintColor = .white
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.barStyle = .default
    }
    
    func onBack(){
        if usePush {
            self.navigationController?.popViewController(animated: true)
        }else {
            if webView.canGoBack == false {
                onClose()
            } else {
                self.webView.goBack()
            }
        } 
    }
    
    func onRefresh(){
        self.webView.reload()
    }
    
    func onClose(){
        if let closeHandler = self.closeHandler {
            closeHandler()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func webViewController(_ webViewController: GDWebViewController, didChangeTitle newTitle: NSString?) {
        if let titleStr = newTitle ,titleStr.length > 0 {
            self.navigationController?.navigationBar.topItem?.title = newTitle as String?
        }
    }
    
    func webViewController(_ webViewController: GDWebViewController, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        var containJumpUrl = false
        if let url = UserDefaults.standard.object(forKey: "kGroupChannelShareURLKey") as? String, webUrl.contains(url) {
            containJumpUrl = true
        }
        
        if webUrl.contains("//itunes.apple.com/") || containJumpUrl, let url = URL(string: webUrl), UIApplication.shared.canOpenURL(url) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                if let closeHandler = self.closeHandler {
                    closeHandler()
                }
                // self.dismiss(animated: true, completion: nil)
            })
        }
        
        decisionHandler(.allow)
    }
    
    func webViewController(_ webViewController: GDWebViewController, didFinishLoading loadedURL: URL?) {
 
        if loadedURL?.absoluteString == webUrl || loadedURL == URL(fileURLWithPath: webUrl), let title = defaultTitle {
              self.navigationController?.navigationBar.topItem?.title = title
        }
    }
}
