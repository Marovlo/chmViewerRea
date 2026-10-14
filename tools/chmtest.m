// chmtest.m — headless smoke test of the rebuilt CHM core.
// Usage: chmtest <file.chm>
#import <Foundation/Foundation.h>
#import "../src/CHMFileHandle.h"
#import "../src/CHMTopicNode.h"
#import "../src/ABCHMContent.h"

static void PrintTree(CHMTopicNode *node, int depth) {
    if (depth > 2) return;
    for (CHMTopicNode *c in node.children) {
        for (int i = 0; i < depth; i++) printf("  ");
        printf("- %s%s%s\n", c.title.UTF8String, c.path ? " -> " : "",
               c.path ? [(NSString *)c.path UTF8String] : "");
        PrintTree(c, depth + 1);
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) { fprintf(stderr, "usage: chmtest <file.chm>\n"); return 2; }
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        CHMFileHandle *h = [[CHMFileHandle alloc] initWithPath:path];
        if (!h) { fprintf(stderr, "FAIL: not a valid CHM archive\n"); return 1; }
        printf("OK: opened %s\n", argv[1]);

        if (argc >= 3) {   // dump one entry: chmtest <file> <internal/path> [offset len]
            NSData *d = [h dataForPath:[NSString stringWithUTF8String:argv[2]]];
            if (!d) { fprintf(stderr, "FAIL: entry not found or unreadable\n"); return 1; }
            NSUInteger off = argc >= 4 ? (NSUInteger)atol(argv[3]) : 0;
            NSUInteger len = argc >= 5 ? (NSUInteger)atol(argv[4]) : 400;
            off = MIN(off, d.length);
            len = MIN(len, d.length - off);
            fwrite((char *)d.bytes + off, 1, len, stdout);
            printf("\n[bytes=%lu of %lu]\nPASS\n", (unsigned long)len, (unsigned long)d.length);
            return 0;
        }

        NSArray *files = [h allFilePaths];
        printf("entries: %lu\n", (unsigned long)files.count);
        for (NSUInteger i = 0; i < files.count && i < 12; i++)
            printf("  [%lu] %s\n", (unsigned long)i, [(NSString *)files[i] UTF8String]);

        NSString *tocPath = [h firstPathWithExtension:@"hhc"];
        printf("toc file: %s\n", tocPath.UTF8String ?: "(none)");
        if (tocPath) {
            NSData *d = [h dataForPath:tocPath];
            printf("toc bytes: %lu\n", (unsigned long)d.length);
            CHMTopicNode *root = [ABCHMContent treeWithData:d encodingName:nil];
            if (root) {
                printf("TOC tree (2 levels):\n");
                PrintTree(root, 0);
                CHMTopicNode *first = [root firstNodeWithPath];
                if (first.path) {
                    NSData *page = [h dataForPath:first.path];
                    printf("first topic: %s (%lu bytes)\n", first.path.UTF8String,
                           (unsigned long)page.length);
                    NSString *head = [[NSString alloc] initWithData:
                        [page subdataWithRange:NSMakeRange(0, MIN(160UL, page.length))]
                        encoding:NSUTF8StringEncoding];
                    printf("preview: %s\n", head.UTF8String ?: "(binary)");
                }
            } else {
                printf("WARN: TOC parse produced no entries\n");
            }
        }
        NSData *probe = [h dataForPath:@"nonexistent/nope.html"];
        printf("absent-path probe: %s\n", probe ? "UNEXPECTED HIT" : "correctly nil");
        printf("PASS\n");
    }
    return 0;
}
