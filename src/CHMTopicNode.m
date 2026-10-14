// CHMTopicNode.m
#import "CHMTopicNode.h"

@implementation CHMTopicNode

- (instancetype)initWithTitle:(NSString *)title path:(nullable NSString *)path {
    self = [super init];
    if (self) {
        _title = [title ?: @"(untitled)" copy];
        _path = [path copy];
        _children = [NSMutableArray array];
    }
    return self;
}

- (void)appendChild:(CHMTopicNode *)child {
    child.parent = self;
    [self.children addObject:child];
}

- (nullable CHMTopicNode *)firstNodeWithPath {
    if (self.path.length > 0) return self;
    for (CHMTopicNode *c in self.children) {
        CHMTopicNode *hit = [c firstNodeWithPath];
        if (hit) return hit;
    }
    return nil;
}

- (NSArray<CHMTopicNode *> *)navigableNodes {
    NSMutableArray<CHMTopicNode *> *out = [NSMutableArray array];
    NSMutableArray<CHMTopicNode *> *stack = [NSMutableArray arrayWithObject:self];
    while (stack.count) {
        CHMTopicNode *n = stack.firstObject;
        [stack removeObjectAtIndex:0];
        if (n.path.length > 0) [out addObject:n];
        [stack insertObjects:n.children atIndexes:
            [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, n.children.count)]];
    }
    return out;
}

@end
