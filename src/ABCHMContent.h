// ABCHMContent.h — .hhc (TOC) / .hhk (index) HTML parser.
// Original app parses these with libxml2 (it links /usr/lib/libxml2.2.dylib); we do the same.
#import <Foundation/Foundation.h>
#import "CHMTopicNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface ABCHMContent : NSObject

/// Parse an .hhc / .hhk byte stream. The bytes are decoded with encoding first;
/// pass 0 to fall back to trying UTF-8 then Windows Latin-1.
/// Returns the root node (title may be the file's implicit root with children).
+ (nullable CHMTopicNode *)treeWithData:(NSData *)data
                           encodingName:(nullable NSString *)encodingName;

+ (nullable CHMTopicNode *)treeWithData:(NSData *)data
                          stringEncoding:(NSStringEncoding)encoding;

@end

NS_ASSUME_NONNULL_END
