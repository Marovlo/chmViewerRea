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
/// Ancestor titles joined with " › " (excluding the synthetic root), e.g.
/// "配置指南 › 基础配置 › 配置用户登录提示信息".
- (NSString *)breadcrumb;

@end

NS_ASSUME_NONNULL_END
