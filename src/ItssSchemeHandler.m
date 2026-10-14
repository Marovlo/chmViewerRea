// ItssSchemeHandler.m
#import "ItssSchemeHandler.h"
#import "CHMDocument.h"

static NSString *MIMEForPath(NSString *path) {
    NSString *ext = path.pathExtension.lowercaseString;
    NSDictionary *map = @{
        @"html": @"text/html", @"htm": @"text/html",
        @"css": @"text/css",
        @"js": @"application/javascript",
        @"png": @"image/png", @"jpg": @"image/jpeg", @"jpeg": @"image/jpeg",
        @"gif": @"image/gif", @"svg": @"image/svg+xml", @"bmp": @"image/bmp",
        @"ico": @"image/x-icon", @"tif": @"image/tiff", @"tiff": @"image/tiff",
        @"pdf": @"application/pdf", @"xml": @"application/xml", @"txt": @"text/plain",
    };
    return map[ext] ?: @"application/octet-stream";
}

static BOOL IsTextMIME(NSString *mime) {
    return [mime hasPrefix:@"text/"] ||
           [mime isEqualToString:@"application/javascript"] ||
           [mime isEqualToString:@"application/xml"];
}

@implementation ItssSchemeHandler

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)task {
    NSURL *url = task.request.URL;
    NSString *path = url.path;                       // "/chm/<target>"
    NSLog(@"[CHMRe] itss request: %@", url.absoluteString);
    if ([path hasPrefix:@"/chm/"]) path = [path substringFromIndex:5];
    else if ([path hasPrefix:@"/"]) path = [path substringFromIndex:1];
    path = [path stringByRemovingPercentEncoding] ?: path;

    NSData *data = [self.document rawDataForCHMPath:path];
    if (!data) {
        data = [@"<html><body style='font:14px -apple-system;padding:2em;color:#888'>"
                @"<h3>Topic not found in this CHM</h3></body></html>"
                dataUsingEncoding:NSUTF8StringEncoding];
        path = @"error.html";
    }

    NSString *mime = MIMEForPath(path);
    if (IsTextMIME(mime)) {
        NSString *s = nil;
        if (_textEncoding) s = [[NSString alloc] initWithData:data encoding:_textEncoding];
        if (!s) {  // auto-probe: UTF-8 → GB18030 (zh-CN CHMs) → let <meta charset> handle it
            s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!s) s = [[NSString alloc] initWithData:data
                    encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
        }
        if (s) data = [s dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc]
        initWithURL:url statusCode:data ? 200 : 404
        HTTPVersion:@"HTTP/1.1"
        headerFields:@{@"Content-Type": [NSString stringWithFormat:@"%@; charset=utf-8", mime],
                       @"Cache-Control": @"no-store"}];
    [task didReceiveResponse:resp];
    [task didReceiveData:data];
    [task didFinish];
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)task {
    // In-memory responses complete synchronously; nothing to cancel.
}

@end
