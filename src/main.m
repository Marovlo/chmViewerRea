// main.m
#import <AppKit/AppKit.h>
#import "CHMApplicationDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        CHMApplicationDelegate *delegate = [[CHMApplicationDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
