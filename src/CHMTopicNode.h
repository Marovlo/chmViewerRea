// CHMTopicNode.h — TOC tree node, counterpart of the original ABCHMContent entries.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CHMTopicNode : NSObject
@property (nonatomic, copy) NSString *title;
/// Path inside the CHM archive (may be nil for pure grouping entries).
@property (nonatomic, copy, nullable) NSString *path;
@property (nonatomic, readonly, strong) NSMutableArray<CHMTopicNode *> *children;
@property (nonatomic, weak, nullable) CHMTopicNode *parent;

- (instancetype)initWithTitle:(NSString *)title path:(nullable NSString *)path;
- (void)appendChild:(CHMTopicNode *)child;
- (nullable CHMTopicNode *)firstNodeWithPath;
/// Depth-first flattened list of nodes that have a path.
- (NSArray<CHMTopicNode *> *)navigableNodes;

@end

NS_ASSUME_NONNULL_END
