// CHMWindowController.m
#import "CHMWindowController.h"
#import "CHMDocument.h"
#import "CHMTopicNode.h"
#import "ItssSchemeHandler.h"

static NSString * const kToolbarID = @"CHMReMainToolbar";

@interface CHMWindowController () <NSToolbarDelegate, NSOutlineViewDataSource,
                                   NSOutlineViewDelegate, WKNavigationDelegate>
@property (nonatomic, strong, readwrite) CHMDocument *chmDoc;
@property (nonatomic, strong) NSSplitView *splitView;
@property (nonatomic, strong) NSLayoutConstraint *leftWidthConstraint;
@property (nonatomic, strong) NSOutlineView *outlineView;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) ItssSchemeHandler *schemeHandler;
@property (nonatomic, strong) NSURL *currentURL;
@end

// Ordered encoding menu: (encoding, label); encoding 0 = auto-detect.
static NSArray<NSArray *> *EncodingMenu() {
    static NSArray *menu = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        menu = @[
            @[@(0), @"Auto Detect"],
            @[@(NSUTF8StringEncoding), @"Unicode (UTF-8)"],
            @[@(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)),
              @"Simplified Chinese (GB18030/GBK)"],
            @[@(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)),
              @"Traditional Chinese (Big5)"],
            @[@(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese)),
              @"Japanese (Shift-JIS)"],
            @[@(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR)),
              @"Korean (EUC-KR)"],
            @[@(NSWindowsCP1252StringEncoding), @"Western (Windows Latin-1)"],
        ];
    });
    return menu;
}

@implementation CHMWindowController

- (nullable instancetype)initWithDocumentAtPath:(NSString *)path {
    CHMDocument *doc = [[CHMDocument alloc] initWithPath:path];
    if (!doc) return nil;
    _chmDoc = doc;

    NSWindow *win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 940, 600)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self = [super initWithWindow:win];
    if (!self) return nil;

    win.title = doc.documentTitle;
    win.minSize = NSMakeSize(560, 360);
    [win center];

    _splitView = [[NSSplitView alloc] initWithFrame:NSZeroRect];
    _splitView.vertical = YES;
    _splitView.dividerStyle = NSSplitViewDividerStyleThin;
    _splitView.autoresizesSubviews = YES;
    _splitView.translatesAutoresizingMaskIntoConstraints = NO;

    // Left pane — TOC outline.
    _outlineView = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0, 0, 210, 560)];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"topic"];
    col.title = @"Topics";
    col.resizingMask = NSTableColumnAutoresizingMask;
    [_outlineView addTableColumn:col];
    _outlineView.outlineTableColumn = col;
    _outlineView.headerView = nil;
    _outlineView.autoresizesOutlineColumn = NO;
    _outlineView.indentationPerLevel = 14;
    _outlineView.rowHeight = 22;   // keeps disclosure triangle vertically centered with text
    _outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    _outlineView.allowsEmptySelection = YES;
    _outlineView.focusRingType = NSFocusRingTypeNone;
    _outlineView.dataSource = self;
    _outlineView.delegate = self;
    NSScrollView *leftScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 210, 560)];
    leftScroll.hasVerticalScroller = YES;
    leftScroll.documentView = _outlineView;
    leftScroll.translatesAutoresizingMaskIntoConstraints = NO;

    // Right pane — content web view with the itss:// scheme handler attached.
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    _schemeHandler = [[ItssSchemeHandler alloc] init];
    _schemeHandler.document = doc;
    _schemeHandler.textEncoding = NSUTF8StringEncoding;
    [config setURLSchemeHandler:_schemeHandler forURLScheme:@"itss"];
    _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 700, 560) configuration:config];
    _webView.navigationDelegate = self;
    _webView.translatesAutoresizingMaskIntoConstraints = NO;

    [_splitView addArrangedSubview:leftScroll];
    [_splitView addArrangedSubview:_webView];

    // Sidebar width driven by a constraint at holding priority, so the divider
    // stays draggable while the pane keeps its width on window resize.
    _leftWidthConstraint = [leftScroll.widthAnchor constraintEqualToConstant:210];
    _leftWidthConstraint.priority = 260;   // == holding priority below
    _leftWidthConstraint.active = YES;
    [_splitView setHoldingPriority:260 forSubviewAtIndex:0];
    [_splitView setHoldingPriority:249 forSubviewAtIndex:1];

    NSView *content = win.contentView;
    [content addSubview:_splitView];
    [NSLayoutConstraint activateConstraints:@[
        [_splitView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [_splitView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [_splitView.topAnchor constraintEqualToAnchor:content.topAnchor],
        [_splitView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
    ]];

    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:kToolbarID];
    toolbar.delegate = self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    self.window.toolbar = toolbar;
    self.window.toolbarStyle = NSWindowToolbarStyleUnified;

    [_outlineView reloadData];
    for (CHMTopicNode *top in doc.tocRoot.children) [_outlineView expandItem:top];

    NSURL *home = doc.homeURL;
    if (home) [self navigateTo:home];

    [win makeFirstResponder:_outlineView];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[CHMRe] layout: window=%@ left=%@ web=%@ splitDiv=%@",
              NSStringFromRect(win.frame),
              NSStringFromRect(leftScroll.frame),
              NSStringFromRect(_webView.frame),
              @(_splitView.dividerThickness));
    });
    return self;
}

#pragma mark Navigation

- (void)navigateTo:(NSURL *)url {
    if (!url) return;
    self.currentURL = url;
    [_webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (IBAction)goHome:(id)sender {
    NSURL *home = self.chmDoc.homeURL;
    if (home) [self navigateTo:home];
}

- (IBAction)goBack:(id)sender    { [_webView goBack]; }
- (IBAction)goForward:(id)sender { [_webView goForward]; }

- (IBAction)toggleSidebar:(id)sender {
    BOOL hidden = _leftWidthConstraint.constant == 0;
    _leftWidthConstraint.constant = hidden ? 210 : 0;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    // Keep the width constraint in sync so user divider drags persist.
    NSView *leftPane = _splitView.arrangedSubviews.firstObject;
    CGFloat w = leftPane.frame.size.width;
    if (w > 1 && ABS(w - _leftWidthConstraint.constant) > 0.5)
        _leftWidthConstraint.constant = w;
}

- (void)encodingChanged:(NSPopUpButton *)sender {
    NSNumber *enc = sender.selectedItem.representedObject;
    if (!enc) return;
    _schemeHandler.textEncoding = enc.unsignedIntegerValue;   // 0 = auto-detect
    [_webView reload];
}

#pragma mark NSToolbarDelegate

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[ NSToolbarToggleSidebarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
              @"back", @"forward", @"home", NSToolbarFlexibleSpaceItemIdentifier, @"encoding" ];
}

- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar
          itemForItemIdentifier:(NSToolbarItemIdentifier)identifier
      willBeInsertedIntoToolbar:(BOOL)flag {
    if ([identifier isEqualToString:NSToolbarToggleSidebarItemIdentifier]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        item.label = @"Sidebar";
        item.action = @selector(toggleSidebar:);
        NSImage *img = [NSImage imageWithSystemSymbolName:@"sidebar.left"
                                   accessibilityDescription:@"Toggle sidebar"];
        if (img) item.image = img;
        return item;
    }
    if ([identifier isEqualToString:@"back"] || [identifier isEqualToString:@"forward"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        BOOL back = [identifier isEqualToString:@"back"];
        item.label = back ? @"Back" : @"Forward";
        item.image = [NSImage imageWithSystemSymbolName:back ? @"chevron.left" : @"chevron.right"
                                 accessibilityDescription:item.label];
        item.action = back ? @selector(goBack:) : @selector(goForward:);
        return item;
    }
    if ([identifier isEqualToString:@"home"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        item.label = @"Home";
        item.image = [NSImage imageWithSystemSymbolName:@"house" accessibilityDescription:@"Home"];
        item.action = @selector(goHome:);
        return item;
    }
    if ([identifier isEqualToString:@"encoding"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        item.label = @"Text Encoding";
        NSPopUpButton *btn = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 190, 26)
                                                            pullsDown:NO];
        for (NSArray *entry in EncodingMenu()) {
            [btn addItemWithTitle:entry[1]];
            btn.lastItem.representedObject = entry[0];
        }
        [btn selectItemAtIndex:0];   // Auto Detect
        btn.target = self;
        btn.action = @selector(encodingChanged:);
        item.view = btn;
        return item;
    }
    return nil;
}

#pragma mark NSOutlineViewDataSource / Delegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    CHMTopicNode *root = self.chmDoc.tocRoot;
    NSArray *kids = item ? ((CHMTopicNode *)item).children : root.children;
    return kids.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    CHMTopicNode *root = self.chmDoc.tocRoot;
    NSArray *kids = item ? ((CHMTopicNode *)item).children : root.children;
    return kids.count > index ? kids[index] : nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (id)outlineView:(NSOutlineView *)outlineView
    objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(id)item {
    return ((CHMTopicNode *)item).title;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    CHMTopicNode *node = [_outlineView itemAtRow:_outlineView.selectedRow];
    if (node.path.length) [self navigateTo:[self.chmDoc URLForCHMPath:node.path]];
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"[CHMRe] page loaded: %@", _currentURL);
    [webView evaluateJavaScript:@"JSON.stringify({t: document.title, len: (document.body.innerText||'').length, imgs: document.images.length})"
              completionHandler:^(id res, NSError *err) {
        NSLog(@"[CHMRe] DOM: %@ (err=%@)", res, err);
    }];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                        decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    if ([scheme isEqualToString:@"itss"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] ||
        [scheme isEqualToString:@"mailto"] || [scheme isEqualToString:@"macappstore"]) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
    decisionHandler(WKNavigationActionPolicyCancel);
}

@end
