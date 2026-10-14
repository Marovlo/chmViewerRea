// CHMFileHandle.m — thin, thread-safe wrapper over chmlib.
#import "CHMFileHandle.h"
#include <string.h>
#include <stdio.h>
#include "chm_lib.h"

@implementation CHMUnitInfo
@end

@interface CHMFileHandle ()
@property (nonatomic, strong) NSString *sourcePath;
@property (nonatomic, assign) struct chmFile *handle;
@end

static NSString *NormalizedPath(NSString *path) {
    NSString *p = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    while ([p hasPrefix:@"/"]) p = [p substringFromIndex:1];
    return p;
}

typedef struct {
    NSMutableArray<NSString *> *acc;
} CHMCollectContext;

static int CHMCollectEnumerator(struct chmFile *h, struct chmUnitInfo *ui, void *context) {
    CHMCollectContext *ctx = (CHMCollectContext *)context;
    NSString *p = [NSString stringWithUTF8String:ui->path];
    if (p) [ctx->acc addObject:p];
    return CHM_ENUMERATOR_CONTINUE;
}

@implementation CHMFileHandle

- (nullable instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (!self) return nil;
    struct chmFile *h = chm_open(path.fileSystemRepresentation);
    if (!h) return nil;
    _handle = h;
    _sourcePath = [path copy];
    return self;
}

- (void)close {
    if (_handle) {
        chm_close(_handle);
        _handle = NULL;
    }
}

- (void)dealloc {
    [self close];
}

- (NSArray<NSString *> *)allFilePaths {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    if (!_handle) return out;
    CHMCollectContext ctx;
    ctx.acc = out;
    chm_enumerate(_handle, CHM_ENUMERATE_NORMAL | CHM_ENUMERATE_META,
                  CHMCollectEnumerator, &ctx);
    return out;
}

- (nullable NSData *)dataForPath:(NSString *)rawPath {
    if (!_handle || rawPath.length == 0) return nil;
    NSString *path = NormalizedPath(rawPath);
    struct chmUnitInfo ui;
    char cs[CHM_MAX_PATHLEN + 4];
    snprintf(cs, sizeof(cs), "/%s", path.UTF8String);
    if (chm_resolve_object(_handle, cs, &ui) != CHM_RESOLVE_SUCCESS) return nil;
    if (ui.length == 0) return [NSData data];
    NSMutableData *buf = [NSMutableData dataWithLength:(NSUInteger)ui.length];
    LONGINT64 got = chm_retrieve_object(_handle, &ui, buf.mutableBytes, 0, (LONGINT64)ui.length);
    if (got <= 0) return nil;
    buf.length = (NSUInteger)got;
    return buf;
}

- (nullable NSString *)firstPathWithExtension:(NSString *)ext {
    NSString *want = ext.lowercaseString;
    for (NSString *p in [self allFilePaths]) {
        if ([p.pathExtension.lowercaseString isEqualToString:want]) return p;
    }
    return nil;
}

@end
