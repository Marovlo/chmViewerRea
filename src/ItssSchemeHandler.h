// ItssSchemeHandler.h — WKURLSchemeHandler serving CHM entries over "itss://chm/<path>".
// Mirrors the reversed design: itss://chm/%@ composed by CHMDocument::composeURL:.
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CHMDocument;

@interface ItssSchemeHandler : NSObject <WKURLSchemeHandler>
/// The document whose CHM handle answers requests.
@property (nonatomic, weak, nullable) CHMDocument *document;
/// NSStringEncoding used to re-encode text content (0 = serve bytes untouched).
@property (nonatomic, assign) NSStringEncoding textEncoding;
@end

NS_ASSUME_NONNULL_END
