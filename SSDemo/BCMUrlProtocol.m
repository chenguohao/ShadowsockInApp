//
//  BCMUrlProtocol.m
//  AME_IM
//
//  Created by BCM on 2019/1/21.
//  Copyright © 2019年 AME. All rights reserved.
//

#import "BCMUrlProtocol.h"
#import "SSProxyManager.h"
#import "SSDemo-Swift.h"

static NSString *const kBCMUrlProtocolHandledKey = @"BCMUrlProtocolHandledKey";
static int requestCount = 0;

dispatch_semaphore_t semaphore;
dispatch_queue_t quene;
static int signalCount = 20;
static NSString* sumContent;
@interface BCMUrlProtocol() <NSURLSessionDataDelegate,NSURLSessionTaskDelegate,NSURLSessionDelegate>
@property (nonatomic, strong) NSMutableArray* contentArray;
@property (nonatomic, strong) NSURLSessionDataTask *connection;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSDateFormatter* dataFormat;

@end


@implementation BCMUrlProtocol
{
    NSURLSession *_urlSession;
}

- (void)initLog{
    
}

- (NSDateFormatter*)dataFormat{
    if (_dataFormat == nil){
        _dataFormat = [[NSDateFormatter alloc] init];
        _dataFormat.dateFormat = @"yyyy-MM-dd  HH:mm:ss:SSSS";
    }
    return _dataFormat;
}

- (NSString*)dataStr{
    NSDate* date = [NSDate date];
    NSString* str = [self.dataFormat stringFromDate:date];
    return str;
    
}

- (NSMutableArray*)contentArray{
    if (_contentArray == nil){
        _contentArray = [NSMutableArray new];
    }
    return _contentArray;
}

+(BOOL)canInitWithRequest:(NSURLRequest*)request
{
    if ([NSURLProtocol propertyForKey:kBCMUrlProtocolHandledKey inRequest:request]) {
        return NO;
    }
    
    return YES;
}

+ (void)initQueue{
    semaphore = dispatch_semaphore_create(signalCount);
    quene = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

+ (void)addCount{
    signalCount++;
    NSLog(@"signal +1:%d",signalCount);
}

+ (void)consumeCount{
    signalCount--;
    NSLog(@"signal -1:%d",signalCount);
}

- (void) startLoading {
    
    
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
//    dispatch_async(quene, ^{
//        [BCMUrlProtocol consumeCount];
        NSLog(@"signal will req %@",newRequest.URL.absoluteString);
//        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
//        NSMutableURLRequest *newRequest = [self.request mutableCopy];
        requestCount = requestCount+1;
        [NSURLProtocol setProperty:@(YES) forKey:kBCMUrlProtocolHandledKey inRequest:newRequest];
        NSLog(@"VPN log num %d request %@ ",requestCount,newRequest.URL.absoluteString);
        self.connection = [self.session dataTaskWithRequest:newRequest];
        [self.connection resume];
        
        
        NSLog(@"signal did req %@",newRequest.URL.absoluteString);
        NSString* content = [NSString stringWithFormat:@"\n%@ signal did req %@",[self dataStr],newRequest.URL.absoluteString];
    if (sumContent == nil){
        sumContent = content;
    }else{
        sumContent = [NSString stringWithFormat:@"%@%@",sumContent,content];
    }
//    });
}

- (NSURLSession *)session {
    
    if (_session == nil) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPMaximumConnectionsPerHost = 2;
        config.timeoutIntervalForRequest = 1;
        
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
//        if ( [[ShadowsockManager shared] isOpenSS] && [[ShadowsockManager shared] shouldOpenSS]){
            int port = SSProxyManager.sharedManager.httpProxyPort;
            config.connectionProxyDictionary = @
            {
                @"HTTPEnable":@YES,
                @"HTTPProxy":@"127.0.0.1",
                @"HTTPPort":@(port),
                @"HTTPSEnable":@YES,
                @"HTTPSProxy":@"127.0.0.1",
                @"HTTPSPort":@(port),
            };
//        }else{
//        }
//        
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return _session;
}


+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)reques
{
    return reques;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void) stopLoading {
    [self.connection cancel];
}


-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if( error ) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

//TODO: 重定向
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)newRequest completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    NSMutableURLRequest *redirectRequest;
    redirectRequest = [newRequest mutableCopy];
    [[self class] removePropertyForKey:kBCMUrlProtocolHandledKey inRequest:redirectRequest];
    [[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
    
    [self.connection cancel];
    [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
//    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    
   completionHandler(NSURLSessionAuthChallengeUseCredential,[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
//    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

@end


