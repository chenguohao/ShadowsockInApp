//
//  ViewController.swift
//  SSDemo
//
//  Created by BCM on 2018/12/22.
//  Copyright © 2018年 BCM. All rights reserved.
//

import UIKit
import PotatsoBase
import PotatsoModel
import PotatsoLibrary

import WebKit


class ViewController: UIViewController {
    let upstreamProxy = Proxy()
    let webView = WKWebView(frame: CGRect(x: 0, y: 300, width: 300, height: 300))
    let switcher = UISwitch()
    let btTest = UIButton()
    override func viewDidLoad() {
        
        
        
        super.viewDidLoad()
        view.addSubview(webView)
        view.addSubview(btTest)
        registerSS()
        
        
        upstreamProxy.type = .Shadowsocks
        upstreamProxy.name = "SSR-name"
        upstreamProxy.host = "14.116.173.58"
        upstreamProxy.port = 999
        upstreamProxy.authscheme = "rc4-md5"
        upstreamProxy.password = "bcmbcm880"
        
        do {
            try DBUtils.add(upstreamProxy)
        }catch {
            
        }
        
        try? ConfigurationGroup.changeProxy(forGroupId: Manager.sharedManager.defaultConfigGroup.uuid, proxyId: self.upstreamProxy.uuid)
        
        let label = UILabel()
        label.text = "先打开VPN开关再开浏览器"
        label.frame = CGRect(x: 100, y: 150, width: 300, height: 30)
        view.addSubview(label)
        
        view.addSubview(switcher)
        switcher.frame  = CGRect(x: 100, y: 200, width: 30, height: 30)
        switcher.addTarget(self, action: #selector(switchVPN), for: .valueChanged)
        
        btTest.frame = CGRect(x: 200, y: 200, width: 150, height: 30)
        btTest.backgroundColor = .red
        btTest.setTitle("browser", for: .normal)
        btTest.addTarget(self, action: #selector(onBrowser), for: .touchUpInside)
    }
    
    func initProxy(){
        
    }
    
    @objc
    func switchVPN(){
        
        if switcher.isOn{
            ShadowsockManager.shared.openSS().done {
//                   self.visitGoogle()
                   print("vpn is on")
                }.catch { (error) in
                    print("\(error)")
            }
        }else{
            ShadowsockManager.shared.closeSS()
        }
    }
    @objc
    func visitGoogle(){
        let request = URLRequest(url: URL(string: "https://www.google.com")!)
        self.webView.load(request)
    }
    
    
    @objc
    func onBrowser(){
//        visitGoogle()
//        return
        
        let strUrl = Bundle.main.path(forResource: "testVPN", ofType: "html")
        let vc = AMEWebViewController.init(localUrl: strUrl! ,usePush:false)
        let nav = UINavigationController.init(rootViewController: vc)
        self.present(nav, animated: true, completion: nil)
        vc.closeHandler = {
            nav.dismiss(animated: true, completion: nil)
        }
        
//        let url = URL.init(string: "https://www.google.com")!
//        let req = URLRequest.init(url: url)
//        let task = URLSession.shared.dataTask(with: req) { (data, resp, error) in
//            let str = String.init(data: data ?? Data(), encoding: .utf8)
//            print("vpn log page \(str)")
//        }
//        task.resume()
    }
    
    @objc
    func connect() {
        Manager.sharedManager.switchVPN()
    }
    
    private func registerSS() {
//        if ShadowsockManager.shared.shouldOpenSS  {
//            ShadowsockManager.shared.openSS().catch { (error) in
//                // Logger.error("\(#function) \(#line) SS 开启失败 \(error)")
//                SharedHudView.shared.showToast(msg: "shadowsocks.connect.down".localized(), dealy: 2)
//            }
//        }
        
        guard let cls = NSClassFromString("WKBrowsingContextController") as? NSObject.Type else {
//            // Logger.info("\(#function) \(#line) 不存在 WKBrowsingContextController")
            return
        }
        let sel = NSSelectorFromString("registerSchemeForCustomProtocol:")
        if cls.responds(to: sel) {
            cls.perform(sel, with: "http")
            cls.perform(sel, with: "https")
        }
        
        URLProtocol.registerClass(BCMUrlProtocol.self)
    }
}

