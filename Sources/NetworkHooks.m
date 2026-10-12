#import "Includes/GNCommon.h"
#import <substrate.h>

// Known original method from ARM64 analysis; no hooks to authentication or billing.
typedef NSURLSessionDataTask *(*GNDataTaskIMP)(NSURLSession *, SEL, NSURLRequest *,
    void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable));
static GNDataTaskIMP gOriginalDataTask;
static BOOL gNetworkHookInstalled = NO;

static NSURLSessionDataTask *GNHookDataTask(NSURLSession *session, SEL cmd, NSURLRequest *request,
    void (^completion)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable)) {
    if (!gOriginalDataTask) return nil;
    NSURL *url = request.URL;
    NSString *scheme = [url.scheme lowercaseString];
    if (!completion || !url || !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) ||
        !GNHostIsBlocked(url.host)) {
        return gOriginalDataTask(session, cmd, request, completion);
    }

    GNLog(@"Suppressing ad request to host %@", url.host); // Never logs URL/query or user data.
    NSURL *localURL = [NSURL URLWithString:@"about:blank"];
    NSURLRequest *noop = [NSURLRequest requestWithURL:localURL];
    // Return a genuine NSURLSessionDataTask in the *same session*. Caller controls resume/cancel.
    // The benign URL never sends the blocked request over the network. URLSession may report an
    // unsupported-scheme error, which is intentionally mapped to the synthetic empty HTTP 204.
    // Only after resume will the completion run, unlike the original tweak's eager callback.
    return gOriginalDataTask(session, cmd, noop,
        ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error && error.code == NSURLErrorCancelled) {
                completion(nil, nil, error);
                return;
            }
            NSHTTPURLResponse *synthetic = [[NSHTTPURLResponse alloc]
                initWithURL:url statusCode:204 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
            completion([NSData data], synthetic, nil);
        });
}

void GNInstallNetworkHooks(void) {
    if (gNetworkHookInstalled) return;
    Class cls = objc_getClass("NSURLSession");
    SEL selector = @selector(dataTaskWithRequest:completionHandler:);
    if (!cls || !class_getInstanceMethod(cls, selector)) { GNLog(@"NSURLSession selector missing"); return; }
    gNetworkHookInstalled = YES;
    MSHookMessageEx(cls, selector, (IMP)GNHookDataTask, (IMP *)&gOriginalDataTask);
    GNLog(@"NSURLSession hook installed");
}
