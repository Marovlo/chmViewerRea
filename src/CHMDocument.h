// CHMDocument.h — model wrapper of one opened .chm
// (mirrors reversed CHMDocument responsibilities: open -> metadata -> TOC source)
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CHMFileHandle;
@class CHMTopicNode;

@interface CHMDocument : NSObject

/// Parse and open the archive. Returns nil when ITSF headers do not check out.
- (nullable instancetype)initWithPath:(NSString *)path;

@property (nonatomic, readonly, strong, nullable) CHMFileHandle *chmHandle;
@property (nonatomic, readonly, strong, nullable) CHMTopicNode *tocRoot;
@property (nonatomic, readonly, strong, nullable) CHMTopicNode *indexRoot;
@property (nonatomic, readonly, copy) NSString *documentTitle;

/// itss:// URL for an archive-relative path (composeURL: counterpart).
- (NSURL *)URLForCHMPath:(NSString *)path;
/// The home topic (findHomeForPath: counterpart).
- (nullable NSURL *)homeURL;
/// Raw bytes for an archive-relative path (nil if absent).
- (nullable NSData *)rawDataForCHMPath:(NSString *)path;
/// TOC node whose path equals the given archive-relative path (case-insensitive).
- (nullable CHMTopicNode *)nodeForPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
