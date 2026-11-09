#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_WEBVIEW_SUPPORTED

@class WKUserContentController;
@class WKWebView;
@class WKWebViewConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * Options for @c SentryObjCWebViewTracing.
 */
@interface SentryObjCWebViewTracingOptions : NSObject
SENTRY_NO_INIT

/**
 * The hosts whose pages receive the trace.
 *
 * A page matches when its hostname equals an entry or is a subdomain of it. Entries are normalized
 * to bare lowercase hostnames: whitespace, a scheme, a path, a port, a trailing dot, and a leading
 * @c *. are stripped.
 *
 * @warning @c allowedHosts is a trust boundary. The injected @c baggage can carry release and
 * environment data, so only list hosts whose content you control.
 */
@property (nonatomic, copy) NSArray<NSString *> *allowedHosts;

/**
 * @param allowedHosts The hosts whose pages receive the trace.
 */
- (instancetype)initWithAllowedHosts:(NSArray<NSString *> *)allowedHosts;

@end

/**
 * Connects traces of web content in a @c WKWebView with the app's trace.
 *
 * Adds a user script that writes the current trace as @c sentry-trace and @c baggage meta tags into
 * the document before any page script runs, so the Sentry browser SDK in the page continues the
 * trace on pageload. The root span name (@c sentry-transaction) is removed from @c baggage. Only
 * the main frame receives the tags.
 *
 * The script holds a snapshot of the trace at the time of the call. To propagate a newer trace,
 * call the method again: it replaces the previous Sentry script and keeps the app's own scripts.
 * Scripts apply from the next navigation.
 *
 * @note Call these methods from the main thread. They return @c NO when called from another thread.
 */
@interface SentryObjCWebViewTracing : NSObject
SENTRY_NO_INIT

/**
 * Adds trace propagation to web views that use this user content controller.
 *
 * @param userContentController The controller of the web views that receive the trace.
 * @param options The options, including the hosts whose pages receive the trace.
 * @return @c YES if the script was added; @c NO if @c allowedHosts has no valid entry, the SDK is
 * not enabled, or the method was called off the main thread.
 */
+ (BOOL)addTracePropagationToUserContentController:(WKUserContentController *)userContentController
                                           options:(SentryObjCWebViewTracingOptions *)options;

/**
 * Adds trace propagation to web views created with this configuration.
 *
 * @param configuration The configuration of the web views that receive the trace.
 * @param options The options, including the hosts whose pages receive the trace.
 * @return @c YES if the script was added.
 */
+ (BOOL)addTracePropagationToConfiguration:(WKWebViewConfiguration *)configuration
                                   options:(SentryObjCWebViewTracingOptions *)options;

/**
 * Adds trace propagation to this web view, starting with the next navigation.
 *
 * @param webView The web view that receives the trace.
 * @param options The options, including the hosts whose pages receive the trace.
 * @return @c YES if the script was added.
 */
+ (BOOL)addTracePropagationToWebView:(WKWebView *)webView
                             options:(SentryObjCWebViewTracingOptions *)options;

@end

NS_ASSUME_NONNULL_END

#endif
