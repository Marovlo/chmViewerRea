// CHMDocument.m
#import "CHMDocument.h"
#import "ABCHMContent.h"
#import "CHMFileHandle.h"
#import "CHMTopicNode.h"

@interface CHMDocument ()
@property (nonatomic, strong, nullable) CHMFileHandle *chmHandle;
@property (nonatomic, strong, nullable) CHMTopicNode *tocRoot;
@property (nonatomic, strong, nullable) CHMTopicNode *indexRoot;
@property (nonatomic, copy) NSString *documentTitle;
@end

@implementation CHMDocument

- (nullable instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (!self) return nil;

    CHMFileHandle *handle = [[CHMFileHandle alloc] initWithPath:path];
    if (!handle) return nil;
    _chmHandle = handle;
    _documentTitle = path.lastPathComponent.stringByDeletingPathExtension ?: @"CHM";

    // setupTOCSource: first .hhc -> TOC tree, first .hhk -> index tree.
    NSString *tocPath = [handle firstPathWithExtension:@"hhc"];
    if (tocPath) {
        NSData *d = [handle dataForPath:tocPath];
        _tocRoot = [ABCHMContent treeWithData:d encodingName:nil];
    }
    NSString *idxPath = [handle firstPathWithExtension:@"hhk"];
    if (idxPath) {
        NSData *d = [handle dataForPath:idxPath];
        _indexRoot = [ABCHMContent treeWithData:d encodingName:nil];
    }
    if (!_tocRoot) {
        // Synthesize a flat root so the outline still lists every entry.
        CHMTopicNode *root = [[CHMTopicNode alloc] initWithTitle:@"root" path:nil];
        for (NSString *p in [handle allFilePaths]) {
            NSString *ext = p.pathExtension.lowercaseString;
            if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"]) {
                [root appendChild:[[CHMTopicNode alloc] initWithTitle:p.pathComponents.lastObject
                                                                 path:p]];
            }
        }
        _tocRoot = root;
    }
    return self;
}

- (nullable NSData *)rawDataForCHMPath:(NSString *)path {
    return [self.chmHandle dataForPath:path];
}

- (NSURL *)URLForCHMPath:(NSString *)path {
    NSString *escaped = [path stringByAddingPercentEncodingWithAllowedCharacters:
        [NSCharacterSet URLPathAllowedCharacterSet]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"itss://chm/%@", escaped]];
}

- (nullable NSURL *)homeURL {
    CHMTopicNode *first = [self.tocRoot firstNodeWithPath];
    if (first.path) return [self URLForCHMPath:first.path];
    if ([self rawDataForCHMPath:@"index.html"] != nil) return [self URLForCHMPath:@"index.html"];
    for (NSString *p in [self.chmHandle allFilePaths]) {
        NSString *ext = p.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"])
            return [self URLForCHMPath:p];
    }
    return nil;
}

@end
