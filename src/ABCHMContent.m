// ABCHMContent.m — .hhc/.hhk sitemap parser (libxml2 HTML parser, same dependency as original).
#import "ABCHMContent.h"
#include <libxml/HTMLparser.h>
#include <libxml/tree.h>

static NSStringEncoding EncodingFromName(NSString *name) {
    if (!name.length) return 0;
    CFStringEncoding cf = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)name);
    if (cf == kCFStringEncodingInvalidId) return 0;
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(cf);
    return enc ?: 0;
}

static NSString *DecodeParamsValue(xmlNode *obj, const char *which) {
    NSString *result = nil;
    for (xmlNode *p = obj->children; p; p = p->next) {
        if (p->type != XML_ELEMENT_NODE) continue;
        if (xmlStrcasecmp(p->name, (const xmlChar *)"param") != 0) continue;
        NSString *pname = nil, *pvalue = nil;
        for (xmlAttr *a = p->properties; a; a = a->next) {
            xmlChar *v = xmlGetProp(p, a->name);
            NSString *val = v ? [NSString stringWithUTF8String:(const char *)v] : nil;
            if (v) xmlFree(v);
            if (!val) continue;
            if (xmlStrcasecmp(a->name, (const xmlChar *)"name") == 0) pname = val;
            else if (xmlStrcasecmp(a->name, (const xmlChar *)"value") == 0) pvalue = val;
        }
        if (pname && pvalue &&
            [pname compare:@(which) options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            result = pvalue;
            break;
        }
    }
    return result;
}

static NSString *CleanupLocalPath(NSString *local) {
    if (!local.length) return nil;
    NSString *p = [local stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    if ([p hasPrefix:@"file://"]) {
        p = [p substringFromIndex:7];
        while ([p hasPrefix:@"/"]) p = [p substringFromIndex:1];
    }
    while ([p hasPrefix:@"./"]) p = [p substringFromIndex:2];
    while ([p hasPrefix:@"/"]) p = [p substringFromIndex:1];
    NSString *decoded = [p stringByRemovingPercentEncoding];
    return decoded ?: p;
}

static void ProcessList(xmlNode *ul, CHMTopicNode *parent) {
    for (xmlNode *li = ul->children; li; li = li->next) {
        if (li->type != XML_ELEMENT_NODE) continue;
        if (xmlStrcasecmp(li->name, (const xmlChar *)"li") != 0) continue;

        NSString *title = nil, *local = nil;
        for (xmlNode *kid = li->children; kid; kid = kid->next) {
            if (kid->type != XML_ELEMENT_NODE) continue;
            if (xmlStrcasecmp(kid->name, (const xmlChar *)"object") == 0) {
                NSString *t = DecodeParamsValue(kid, "Name");
                NSString *l = DecodeParamsValue(kid, "Local");
                if (t.length && !title) title = t;
                if (l.length && !local) local = CleanupLocalPath(l);
            }
        }
        CHMTopicNode *node = nil;
        if (title || local) {
            node = [[CHMTopicNode alloc] initWithTitle:title path:local];
            [parent appendChild:node];
        }
        for (xmlNode *kid = li->children; kid; kid = kid->next) {
            if (kid->type != XML_ELEMENT_NODE) continue;
            if (xmlStrcasecmp(kid->name, (const xmlChar *)"ul") == 0) {
                ProcessList(kid, node ?: parent);
            }
        }
    }
}

@implementation ABCHMContent

+ (nullable CHMTopicNode *)treeWithData:(NSData *)data
                           encodingName:(nullable NSString *)encodingName {
    NSStringEncoding enc = EncodingFromName(encodingName);
    if (!enc) {
        // Probe order: UTF-8 → GB18030 (superset of GBK, common for zh-CN CHMs) → Latin-1.
        NSString *probe = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (probe) {
            enc = NSUTF8StringEncoding;
        } else {
            probe = [[NSString alloc] initWithData:data encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
            enc = probe ? CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)
                        : NSWindowsCP1252StringEncoding;
        }
    }
    return [self treeWithData:data stringEncoding:enc];
}

+ (nullable CHMTopicNode *)treeWithData:(NSData *)data
                          stringEncoding:(NSStringEncoding)encoding {
    if (data.length == 0) return nil;
    NSString *html = [[NSString alloc] initWithData:data encoding:encoding];
    if (!html) html = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
    if (!html) return nil;

    CHMTopicNode *root = nil;
    htmlDocPtr doc = htmlReadMemory(html.UTF8String, (int)strlen(html.UTF8String),
                                    "toc.hhc", "utf-8",
                                    HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING | HTML_PARSE_RECOVER);
    if (doc) {
        root = [[CHMTopicNode alloc] initWithTitle:@"root" path:nil];
        for (xmlNode *n = xmlDocGetRootElement(doc); n && root.children.count == 0; n = n->next) {
            if (n->type != XML_ELEMENT_NODE) continue;
            // Find the first <ul> anywhere under the root element.
            NSMutableArray *stack = [NSMutableArray arrayWithObject:
                [NSValue valueWithPointer:n]];
            while (stack.count && root.children.count == 0) {
                xmlNode *cur = (xmlNode *)((NSValue *)stack.lastObject).pointerValue;
                [stack removeLastObject];
                for (xmlNode *c = cur->children; c; c = c->next) {
                    if (c->type != XML_ELEMENT_NODE) continue;
                    if (xmlStrcasecmp(c->name, (const xmlChar *)"ul") == 0) {
                        ProcessList(c, root);
                    } else {
                        [stack addObject:[NSValue valueWithPointer:c]];
                    }
                }
            }
        }
        xmlFreeDoc(doc);
        if (root.children.count == 0) root = nil;
    }
    return root;
}

@end
