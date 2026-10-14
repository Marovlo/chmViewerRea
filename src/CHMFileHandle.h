// CHMFileHandle.h — Objective-C wrapper over chmlib (LGPL) handle.
// Rebuild of the reversed CHMFile layer: open / resolve / retrieve / enumerate.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CHMUnitInfo : NSObject
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly) unsigned long long start;
@property (nonatomic, readonly) unsigned long long length;
@end

@interface CHMFileHandle : NSObject

/// Open a .chm archive. Returns nil when the ITSF/ITSP headers do not check out.
- (nullable instancetype)initWithPath:(NSString *)path;

- (void)close;

/// All file entries in the archive (path relative, without leading '/').
- (NSArray<NSString *> *)allFilePaths;

/// Resolve a path (leading '/' optional, '\\' tolerated) to raw bytes. nil if absent.
- (nullable NSData *)dataForPath:(NSString *)path;

/// Find the first entry whose path extension matches (case-insensitive), e.g. "hhc".
- (nullable NSString *)firstPathWithExtension:(NSString *)ext;

@property (nonatomic, readonly, copy) NSString *sourcePath;

@end

NS_ASSUME_NONNULL_END
