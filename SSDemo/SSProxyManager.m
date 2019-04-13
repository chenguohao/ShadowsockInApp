//
//  ProxyManager.m
//  network
//
//  Created by javis on 2019/1/3.
//  Copyright © 2019 AME. All rights reserved.
//


#import "SSProxyManager.h"
#import <ShadowPath/ShadowPath.h>
#import <netinet/in.h>
#import <PotatsoBase/Potatso.h>
#import <PotatsoBase/JSONUtils.h>
#import <PotatsoBase/NSError+Helper.h>
#import <PotatsoBase/Settings.h>

@interface SSProxyManager () {
    struct ss_local_svr* _ssLocalSvr;
}

@property (nonatomic) BOOL socksProxyRunning;
@property (nonatomic) int socksProxyPort;
@property (nonatomic) BOOL httpProxyRunning;
@property (nonatomic) int httpProxyPort;
@property (nonatomic) BOOL shadowsocksProxyRunning;
@property (nonatomic) int shadowsocksProxyPort;
@property (nonatomic) int http_fd;
@property (nonatomic, assign) pthread_t shadowsocksThread;
@property (nonatomic, copy) SocksProxyCompletion socksCompletion;
@property (nonatomic, copy) HttpProxyCompletion httpCompletion;
@property (nonatomic, copy) ShadowsocksProxyCompletion shadowsocksCompletion;
- (void)onSocksProxyCallback: (int)fd;
- (void)onHttpProxyCallback: (int)fd;
- (void)onShadowsocksCallback:(int)fd;
@end

void http_proxy_handler(int fd, void *udata) {
    SSProxyManager *provider = (__bridge SSProxyManager *)udata;
    [provider onHttpProxyCallback:fd];
}

void shadowsocks_handler(int fd, void *udata) {
    SSProxyManager *provider = (__bridge SSProxyManager *)udata;
    provider.shadowsocksThread = pthread_self();
    [provider onShadowsocksCallback:fd];
}

void shadowsocks_start_callback(struct ss_local_svr* ss, void* udata) {
    SSProxyManager *provider = (__bridge SSProxyManager*)udata;
    int listenfd = ss_local_svr__listenfd(ss);
    provider.shadowsocksThread = pthread_self();
    [provider onShadowsocksCallback:listenfd];
}

void shadowsocks_logCallback(char* str){
    NSLog(@"[SSVPN]%s",str);
}

int sock_port (int fd) {
    struct sockaddr_in sin;
    socklen_t len = sizeof(sin);
    if (getsockname(fd, (struct sockaddr *)&sin, &len) < 0) {
        NSLog(@"getsock_port(%d) error: %s",
              fd, strerror (errno));
        return 0;
    }else{
        return ntohs(sin.sin_port);
    }
}

@implementation SSProxyManager

+ (SSProxyManager *)sharedManager {
    static dispatch_once_t onceToken;
    static SSProxyManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [SSProxyManager new];
    });
    return manager;
}

- (SSProxyManager*)init {
    self = [super init];
    if (self != nil) {
        _ssLocalSvr = ss_local_svr__new();
        _shadowsocksProxyRunning = NO;
        _httpProxyRunning = NO;
    }
    return self;
}

- (void)dealloc {
    ss_local_svr__destroy(_ssLocalSvr);
}

- (void)startSocksProxy:(SocksProxyCompletion)completion {
    self.socksCompletion = [completion copy];
    NSString *confContent = [NSString stringWithContentsOfURL:[Potatso sharedSocksConfUrl] encoding:NSUTF8StringEncoding error:nil];
    confContent = [confContent stringByReplacingOccurrencesOfString:@"${ssport}" withString:[NSString stringWithFormat:@"%d", [self shadowsocksProxyPort]]];
    int fd = [[AntinatServer sharedServer] startWithConfig:confContent];
    [self onSocksProxyCallback:fd];
}

- (void)stopSocksProxy {
    [[AntinatServer sharedServer] stop];
    self.socksProxyRunning = NO;
}

- (void)onSocksProxyCallback:(int)fd {
    NSError *error;
    if (fd > 0) {
        self.socksProxyPort = sock_port(fd);
        self.socksProxyRunning = YES;
    }else {
        error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:@{NSLocalizedDescriptionKey: @"Fail to start socks proxy"}];
    }
    if (self.socksCompletion) {
        self.socksCompletion(self.socksProxyPort, error);
    }
}

# pragma mark - Shadowsocks

- (void)startShadowsocks: (ShadowsocksProxyCompletion)completion {
    self.shadowsocksCompletion = [completion copy];
    [NSThread detachNewThreadSelector:@selector(_startShadowsocks) toTarget:self withObject:nil];
}

- (void)_startShadowsocks {
    NSString *confContent = [NSString stringWithContentsOfURL:[Potatso sharedProxyConfUrl] encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *json = [confContent jsonDictionary];
    NSString *host = json[@"host"];
    NSNumber *port = json[@"port"];
    NSString *password = json[@"password"];
    NSString *authscheme = json[@"authscheme"];
    NSString *protocol = json[@"protocol"];
    NSString *obfs = json[@"obfs"];
    NSString *obfs_param = json[@"obfs_param"];
    BOOL ota = [json[@"ota"] boolValue];
    if (host && port && password && authscheme) {
        profile_t profile;
        memset(&profile, 0, sizeof(profile_t));
        profile.remote_host = strdup([host UTF8String]);
        profile.remote_port = [port intValue];
        profile.password = strdup([password UTF8String]);
        profile.method = strdup([authscheme UTF8String]);
        profile.local_addr = "127.0.0.1";
        profile.local_port = 0;
        profile.timeout = 600;
        profile.auth = ota;
        if (protocol.length > 0) {
            profile.protocol = strdup([protocol UTF8String]);
        }
        if (obfs.length > 0) {
            profile.obfs = strdup([obfs UTF8String]);
        }
        if (obfs_param.length > 0) {
            profile.obfs_param = strdup([obfs_param UTF8String]);
        }
        setLogCallback(shadowsocks_logCallback);
//        start_ss_local_server(profile, shadowsocks_handler, (__bridge void *)self);
        ss_local_svr__start(_ssLocalSvr, &profile, shadowsocks_start_callback,
                            (__bridge void*)self);
        
        NSLog(@"sslocal: ss local server terminated gracefully");
        self.shadowsocksProxyRunning = NO;
        
    }else {
        __weak __typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof(self) strongSelf = weakSelf;
            if (strongSelf.shadowsocksCompletion) {
                strongSelf.shadowsocksCompletion(0, nil);
            }
        });
        return;
    }
}

- (void)stopShadowsocks{
    if (self.shadowsocksThread != nil) {
        NSLog(@"sslocal: stop ss local server");
        ss_local_svr__stop(_ssLocalSvr);
        self.shadowsocksThread = nil;
    }
}

- (void)onShadowsocksCallback:(int)fd {
    NSError *error;
    if (fd > 0) {
        self.shadowsocksProxyPort = sock_port(fd);
        self.shadowsocksProxyRunning = YES;
//        DDLogInfo(@"shadowsocksProxyRunning = YES");
        NSLog(@"sslocal: ss local server is running");
    }else {
        error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:@{NSLocalizedDescriptionKey: @"Fail to start http proxy"}];
//        DDLogInfo(@"shadowsocksProxy 启动失败 error %@", error);
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(self) strongSelf = weakSelf;
        if (strongSelf.shadowsocksCompletion) {
            strongSelf.shadowsocksCompletion(strongSelf.shadowsocksProxyPort, error);
        }
    });
}

# pragma mark - Http Proxy

- (void)startHttpProxy:(HttpProxyCompletion)completion {
    self.httpCompletion = [completion copy];
    [NSThread detachNewThreadSelector:@selector(_startHttpProxy:) toTarget:self withObject:[Potatso sharedHttpProxyConfUrl]];
}

- (void)_startHttpProxy: (NSURL *)confURL {
    struct forward_spec *proxy = NULL;
    if (self.shadowsocksProxyPort > 0) {
        proxy = (malloc(sizeof(struct forward_spec)));
        memset(proxy, 0, sizeof(struct forward_spec));
        proxy->type = SOCKS_5;
        proxy->gateway_host = "127.0.0.1";
        proxy->gateway_port = self.shadowsocksProxyPort;
    }
    shadowpath_main(strdup([[confURL path] UTF8String]), proxy, http_proxy_handler, (__bridge void *)self);
    
    NSLog(@"privoxy: http proxy server terminated gracefully");
    self.httpProxyRunning = NO;
    
}

- (void)stopHttpProxy{
    NSLog(@"privoxy: stop http proxy");
    shadowpath_closeHttp(self.http_fd);
}

- (void)onHttpProxyCallback:(int)fd {
    NSError *error;
    if (fd > 0) {
        self.http_fd = fd;
        self.httpProxyPort = sock_port(fd);
        self.httpProxyRunning = YES;
        
        NSLog(@"privoxy: http proxy is running");
    }else {
        error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:@{NSLocalizedDescriptionKey: @"Fail to start http proxy"}];
    }
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(self) strongSelf = weakSelf;
        if (strongSelf.httpCompletion) {
            strongSelf.httpCompletion(strongSelf.httpProxyPort, error);
        }
    });
}
@end

