//
//  ProxyManager.h
//  network
//
//  Created by javis on 2019/1/3.
//  Copyright © 2019 AME. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SocksProxyCompletion)(int port, NSError *error);

typedef void(^HttpProxyCompletion)(int port, NSError *error);

typedef void(^ShadowsocksProxyCompletion)(int port, NSError *error);

extern int sock_port (int fd);

@interface SSProxyManager : NSObject

+ (SSProxyManager *)sharedManager;

@property (nonatomic, readonly) BOOL socksProxyRunning;

@property (nonatomic, readonly) int socksProxyPort;

@property (nonatomic, readonly) BOOL httpProxyRunning;

@property (nonatomic, readonly) int httpProxyPort;

@property (nonatomic, readonly) BOOL shadowsocksProxyRunning;

@property (nonatomic, readonly) int shadowsocksProxyPort;

- (void)startSocksProxy: (SocksProxyCompletion)completion;

- (void)stopSocksProxy;

- (void)startHttpProxy: (HttpProxyCompletion)completion;

- (void)startShadowsocks: (ShadowsocksProxyCompletion)completion;

- (void)stopShadowsocks;

- (void)stopHttpProxy;
@end
