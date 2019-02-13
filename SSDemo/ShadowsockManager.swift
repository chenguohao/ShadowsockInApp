//
//  ShadowsockManager.swift
//  AME_IM
//
//  Created by BCM on 2018/12/28.
//  Copyright © 2018年 AME. All rights reserved.

import UIKit
import PromiseKit
import PotatsoBase
import PotatsoModel
import PotatsoLibrary

struct BCMShadowsocksStaticValue {
    static let isShouldOpenKey = "BCMShadowsocksStaticValue.isShouldOpenKey"
}

class ShadowsockManager: NSObject {
    
    @objc public static let shared = ShadowsockManager()
    
    // 标记 APP 内是否走 SS， SS 关闭是比较麻烦的 所以开启后 没有关闭 以此标志位来表示走不走 SS
    @objc var shouldOpenSS: Bool {
        get {
            let shouldOpenSS = UserDefaults.standard.bool(forKey: BCMShadowsocksStaticValue.isShouldOpenKey)
            // Logger.info("\(#function) \(#line) shouldOpenSS: \(shouldOpenSS)")
           return shouldOpenSS
        }
        set {
            // Logger.info("\(#function) \(#line) set shouldOpenSS: \(newValue)")
            UserDefaults.standard.set(newValue, forKey: BCMShadowsocksStaticValue.isShouldOpenKey)
            UserDefaults.standard.synchronize()
            DispatchQueue.main.async {
//                TSSocketManager.shared()?.createSocket()
            }
        }
    }
    
    // 标记 APP 的 SS 是否开启 当进入后台后 这个标志位不一定准确
    @objc var isOpenSS: Bool {
        let isOpenSS = SSProxyManager.shared()?.shadowsocksProxyRunning ?? false && SSProxyManager.shared()?.httpProxyRunning ?? false
        // Logger.info("\(#function) \(#line) shadowsocksProxyRunning \(SSProxyManager.shared()?.shadowsocksProxyRunning) ")
        // Logger.info("\(#function) \(#line) httpProxyRunning \(SSProxyManager.shared()?.httpProxyRunning)")
        // Logger.info("\(#function) \(#line) isOpenSS: \(isOpenSS)")
        return isOpenSS
    }
    
    @objc func startSS() -> AnyPromise {
        return AnyPromise(openSS())
    }
    
    func openSS() -> Promise<Void> {
        
        do {
            try Manager.sharedManager.regenerateConfigFiles()
        }catch {
            return Promise.init(error: error)
        }
        
        return Promise { seal in
            SSProxyManager.shared()?.startShadowsocks { (port, error) in
                // Logger.info("\(#function) \(#line) startShadowsocks port \(port) error \(error)")
                if let `error` = error {
                    // Logger.info("\(#function) \(#line) 启动 SS 失败 \(error)")
                    self.shouldOpenSS = false;
                    seal.reject(error)
                } else {
                    SSProxyManager.shared()?.startHttpProxy { (port, error) in
                        // Logger.info("\(#function) \(#line) startHttpProxy port \(port) error \(error)")
                        if let `error` = error {
                            // Logger.info("\(#function) \(#line) 启动 SS 失败 \(error)")
                            self.shouldOpenSS = false;
                            seal.reject(error)
                        } else {
                            // Logger.info("\(#function) \(#line) 启动 SS 成功")
                            self.shouldOpenSS = true
                            seal.fulfill(Void())
                        }
                    }
                }
            }
        }
    }
    
    func closeSS(){
        SSProxyManager.shared()?.stopShadowsocks()
        SSProxyManager.shared()?.stopHttpProxy()
    }

    
   
}

