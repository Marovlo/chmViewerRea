// CHMApplicationDelegate.m — menu bar + direct window flow (no NSDocumentController).
#import "CHMApplicationDelegate.h"
#import "CHMWindowController.h"

@interface CHMApplicationDelegate ()
@property (nonatomic, strong) NSMutableArray<CHMWindowController *> *windows;
@property (nonatomic, strong) NSMutableSet<NSString *> *openedPaths;
@end

@implementation CHMApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    self.windows = [NSMutableArray array];
    self.openedPaths = [NSMutableSet set];
    [self buildMenuBar];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"[CHMRe] didFinishLaunching");
    // Files delivered via argv at direct-exec time.
    NSArray *args = NSProcessInfo.processInfo.arguments;
    for (NSUInteger i = 1; i < args.count; i++) {
        NSString *a = args[i];
        if ([a.pathExtension.lowercaseString isEqualToString:@"chm"] &&
            [NSFileManager.defaultManager fileExistsAtPath:a]) {
            [self openPath:a];
        }
    }
    if (self.windows.count == 0) [self runOpenPanel];
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)filename {
    return [self openPath:filename];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (!flag) [self runOpenPanel];
    return YES;
}

- (BOOL)openPath:(NSString *)path {
    path = [path stringByStandardizingPath];
    if ([_openedPaths containsObject:path]) return YES;   // argv + odoc double delivery
    NSLog(@"[CHMRe] opening %@", path);
    CHMWindowController *wc = [[CHMWindowController alloc] initWithDocumentAtPath:path];
    if (!wc) {
        NSAlert *a = [[NSAlert alloc] init];
        a.messageText = @"无法打开 CHM";
        a.informativeText = @"该文件不是有效的 CHM (ITSF) 归档。";
        [a runModal];
        return NO;
    }
    [self.openedPaths addObject:path];
    [self.windows addObject:wc];
    [wc showWindow:nil];
    [wc.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    NSLog(@"[CHMRe] window opened, title=%@", wc.window.title);
    return YES;
}

- (void)runOpenPanel {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"chm"];
    panel.canChooseDirectories = NO;
    if ([panel runModal] == NSModalResponseOK) [self openPath:panel.URLs.firstObject.path];
}

- (void)buildMenuBar {
    NSMenu *menubar = [[NSMenu alloc] init];

    NSMenuItem *appItem = [menubar addItemWithTitle:@"CHM Viewer RE" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"About CHM Viewer RE"
                       action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit CHM Viewer RE"
                       action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    NSMenuItem *fileItem = [menubar addItemWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Open CHM…" action:@selector(runOpenPanel) keyEquivalent:@"o"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
    fileItem.submenu = fileMenu;

    NSMenuItem *editItem = [menubar addItemWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;

    NSMenuItem *viewItem = [menubar addItemWithTitle:@"View" action:nil keyEquivalent:@""];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem *sidebar = [viewMenu addItemWithTitle:@"Toggle Sidebar"
                                              action:@selector(toggleSidebar:)
                                       keyEquivalent:@"s"];
    sidebar.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    viewItem.submenu = viewMenu;

    NSApp.mainMenu = menubar;
}

@end
