// CHMWindowController.h — programmatic document window:
// toolbar (sidebar / back / forward / home / encoding) + TOC outline + WKWebView.
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CHMDocument;

@interface CHMWindowController : NSWindowController
- (nullable instancetype)initWithDocumentAtPath:(NSString *)path;
@property (nonatomic, readonly, strong, nullable) CHMDocument *chmDoc;
@end

NS_ASSUME_NONNULL_END
