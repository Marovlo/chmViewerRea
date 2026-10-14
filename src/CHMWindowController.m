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
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSOutlineView *outlineView;
@property (nonatomic, copy) NSArray<CHMTopicNode *> *searchResults;
@property (nonatomic, assign) BOOL syncingSelection;
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

    // Left pane — search field + TOC outline, stacked vertically.
    NSView *leftPane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 210, 560)];

    _outlineView = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0, 0, 210, 530)];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"topic"];
    col.title = @"Topics";
    col.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
    col.width = 210;
    [_outlineView addTableColumn:col];
    _outlineView.outlineTableColumn = col;
    _outlineView.headerView = nil;
    _outlineView.autoresizesOutlineColumn = YES;
    _outlineView.indentationPerLevel = 14;
    _outlineView.rowHeight = 22;   // keeps disclosure triangle vertically centered with text
    _outlineView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    _outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    _outlineView.allowsEmptySelection = YES;
    _outlineView.focusRingType = NSFocusRingTypeNone;
    _outlineView.dataSource = self;
    _outlineView.delegate = self;
    NSScrollView *leftScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 210, 526)];
    leftScroll.hasVerticalScroller = YES;
    leftScroll.documentView = _outlineView;
    leftScroll.translatesAutoresizingMaskIntoConstraints = NO;

    _searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 194, 26)];
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.placeholderString = @"搜索目录";
    _searchField.sendsWholeSearchString = NO;
    _searchField.sendsSearchStringImmediately = YES;
    _searchField.target = self;
    _searchField.action = @selector(searchChanged:);
    _searchField.font = [NSFont systemFontOfSize:12];

    [leftPane addSubview:_searchField];
    [leftPane addSubview:leftScroll];
    [NSLayoutConstraint activateConstraints:@[
        [_searchField.topAnchor constraintEqualToAnchor:leftPane.topAnchor constant:8],
        [_searchField.leadingAnchor constraintEqualToAnchor:leftPane.leadingAnchor constant:8],
        [_searchField.trailingAnchor constraintEqualToAnchor:leftPane.trailingAnchor constant:-8],
        [_searchField.heightAnchor constraintEqualToConstant:26],
        [leftScroll.topAnchor constraintEqualToAnchor:_searchField.bottomAnchor constant:6],
        [leftScroll.leadingAnchor constraintEqualToAnchor:leftPane.leadingAnchor],
        [leftScroll.trailingAnchor constraintEqualToAnchor:leftPane.trailingAnchor],
        [leftScroll.bottomAnchor constraintEqualToAnchor:leftPane.bottomAnchor],
    ]];

    // Right pane — content web view with the itss:// scheme handler attached.
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    _schemeHandler = [[ItssSchemeHandler alloc] init];
    _schemeHandler.document = doc;
    _schemeHandler.textEncoding = NSUTF8StringEncoding;
    [config setURLSchemeHandler:_schemeHandler forURLScheme:@"itss"];
    _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 700, 560) configuration:config];
    _webView.navigationDelegate = self;

    [_splitView addArrangedSubview:leftPane];
    [_splitView addArrangedSubview:_webView];

    // Frame-based panes: holding priority keeps the sidebar width on window
    // resize; the divider stays freely draggable.
    [_splitView setHoldingPriority:261 forSubviewAtIndex:0];
    [_splitView setHoldingPriority:250 forSubviewAtIndex:1];

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

    // Apply the divider position after the first layout pass.
    dispatch_async(dispatch_get_main_queue(), ^{
        [_splitView setPosition:210 ofDividerAtIndex:0];
        [_outlineView sizeLastColumnToFit];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[CHMRe] layout: window=%@ pane=%@ scroll=%@ web=%@",
              NSStringFromRect(win.frame),
              NSStringFromRect(leftPane.frame),
              NSStringFromRect(leftScroll.frame),
              NSStringFromRect(_webView.frame));
        if (getenv("CHMRE_TEST")) [self runSmokeTest];
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
    NSView *leftPane = _splitView.arrangedSubviews.firstObject;
    BOOL hiding = leftPane.frame.size.width > 1;
    [_splitView setPosition:hiding ? 0 : 210 ofDividerAtIndex:0];
    [_outlineView sizeLastColumnToFit];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    // Stretch the single TOC column so text is never clipped.
    [_outlineView sizeLastColumnToFit];
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

#pragma mark Search

// CHMRE_TEST=1: programmatic verification of search + selection sync.
- (void)runSmokeTest {
    _searchField.stringValue = @"YANG";
    [self searchChanged:_searchField];
    NSLog(@"[CHMRe] TEST search hits=%lu", (unsigned long)_searchResults.count);
    for (NSInteger i = 0; i < MIN(2, (NSInteger)_searchResults.count); i++) {
        CHMTopicNode *n = _searchResults[i];
        NSLog(@"[CHMRe] TEST hit%ld: '%@' breadcrumb='%@'", (long)i, n.title, n.breadcrumb);
    }

    _searchField.stringValue = @"";
    [self searchChanged:_searchField];
    [self syncOutlineSelectionToPagePath:@"huawei-aaa.html"];
    NSInteger row = _outlineView.selectedRow;
    CHMTopicNode *sel = [_outlineView itemAtRow:row];
    NSLog(@"[CHMRe] TEST sync row=%ld title='%@' path='%@'",
          (long)row, sel.title, sel.path ?: @"-");
    // verify the row actually renders its text (regression: empty cells)
    NSTableCellView *cv = [_outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
    NSLog(@"[CHMRe] TEST cell text='%@'", cv.textField.stringValue ?: @"<nil view>");
}

- (BOOL)isSearching {
    return _searchField.stringValue.length > 0;
}

- (IBAction)searchChanged:(NSSearchField *)sender {
    NSString *q = sender.stringValue;
    if (q.length == 0) {
        _searchResults = nil;
        _outlineView.rowHeight = 22;
        [_outlineView reloadData];
        for (CHMTopicNode *top in self.chmDoc.tocRoot.children)
            [_outlineView expandItem:top];
        [_outlineView sizeLastColumnToFit];
        // Back from search: the tree follows whatever page the right side shows.
        NSString *pagePath = _webView.URL.path;
        if (pagePath.length > 1) {
            pagePath = [pagePath substringFromIndex:1];
            pagePath = [pagePath stringByRemovingPercentEncoding] ?: pagePath;
            [self syncOutlineSelectionToPagePath:pagePath];
        }
        return;
    }
    NSMutableArray<CHMTopicNode *> *hits = [NSMutableArray array];
    NSMutableArray<CHMTopicNode *> *stack =
        [self.chmDoc.tocRoot.children mutableCopy];
    while (stack.count) {
        CHMTopicNode *n = stack.lastObject;
        [stack removeLastObject];
        if ([n.title localizedCaseInsensitiveContainsString:q] ||
            [n.path localizedCaseInsensitiveContainsString:q])
            [hits addObject:n];
        [stack addObjectsFromArray:n.children];
    }
    _searchResults = hits;
    _outlineView.rowHeight = 34;   // two-line result cells
    [_outlineView reloadData];
    [_outlineView sizeLastColumnToFit];
    NSLog(@"[CHMRe] search '%@': %lu hits", q, (unsigned long)hits.count);
}

#pragma mark NSOutlineViewDataSource / Delegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (self.isSearching) return item == nil ? _searchResults.count : 0;
    CHMTopicNode *root = self.chmDoc.tocRoot;
    NSArray *kids = item ? ((CHMTopicNode *)item).children : root.children;
    return kids.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (self.isSearching) return item == nil ? _searchResults[index] : nil;
    CHMTopicNode *root = self.chmDoc.tocRoot;
    NSArray *kids = item ? ((CHMTopicNode *)item).children : root.children;
    return kids.count > index ? kids[index] : nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if (self.isSearching) return NO;
    return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (id)outlineView:(NSOutlineView *)outlineView
    objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(id)item {
    return ((CHMTopicNode *)item).title;
}

// Search mode: two-line cell (title + gray path). Tree mode: single-line cell.
- (nullable NSView *)outlineView:(NSOutlineView *)outlineView
              viewForTableColumn:(nullable NSTableColumn *)tableColumn
                            item:(id)item {
    CHMTopicNode *node = item;

    if (!self.isSearching) {
        NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"treeCell" owner:self];
        if (!cell) {
            cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
            cell.identifier = @"treeCell";
            NSTextField *title = [NSTextField labelWithString:@""];
            title.translatesAutoresizingMaskIntoConstraints = NO;
            title.lineBreakMode = NSLineBreakByTruncatingTail;
            [cell addSubview:title];
            cell.textField = title;
            [NSLayoutConstraint activateConstraints:@[
                [title.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
                [title.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-2],
                [title.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            ]];
        }
        cell.textField.stringValue = node.title;
        return cell;
    }

    NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"resultCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        cell.identifier = @"resultCell";

        NSTextField *title = [NSTextField labelWithString:@""];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        title.lineBreakMode = NSLineBreakByTruncatingTail;
        title.identifier = @"title";
        [cell addSubview:title];
        cell.textField = title;

        NSTextField *detail = [NSTextField labelWithString:@""];
        detail.translatesAutoresizingMaskIntoConstraints = NO;
        detail.lineBreakMode = NSLineBreakByTruncatingMiddle;
        detail.font = [NSFont systemFontOfSize:10];
        detail.textColor = [NSColor secondaryLabelColor];
        detail.identifier = @"detail";
        [cell addSubview:detail];

        [NSLayoutConstraint activateConstraints:@[
            [title.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:2],
            [title.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-2],
            [title.topAnchor constraintEqualToAnchor:cell.topAnchor constant:2],
            [detail.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [detail.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-2],
            [detail.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:1],
        ]];
    }
    cell.textField.stringValue = node.title;
    for (NSView *sv in cell.subviews) {
        if ([sv isKindOfClass:[NSTextField class]] &&
            [sv.identifier isEqualToString:@"detail"]) {
            ((NSTextField *)sv).stringValue = node.breadcrumb;   // chapter path
            break;
        }
    }
    return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    if (_syncingSelection) return;
    CHMTopicNode *node = [_outlineView itemAtRow:_outlineView.selectedRow];
    if (node.path.length) [self navigateTo:[self.chmDoc URLForCHMPath:node.path]];
}

#pragma mark WKNavigationDelegate

// Right -> left sync: highlight the TOC entry matching the page just loaded.
- (void)syncOutlineSelectionToPagePath:(NSString *)pagePath {
    if (self.isSearching || pagePath.length == 0) return;
    CHMTopicNode *node = [self.chmDoc nodeForPath:pagePath];
    if (!node) return;

    // expand ancestors so the row is visible
    NSMutableArray<CHMTopicNode *> *chain = [NSMutableArray array];
    for (CHMTopicNode *p = node.parent; p && p.parent; p = p.parent)
        [chain insertObject:p atIndex:0];
    for (CHMTopicNode *a in chain) [_outlineView expandItem:a];

    NSInteger row = [_outlineView rowForItem:node];
    if (row < 0) return;
    _syncingSelection = YES;
    [_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                 byExtendingSelection:NO];
    [_outlineView scrollRowToVisible:row];
    _syncingSelection = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    NSLog(@"[CHMRe] page loaded: %@", _currentURL);
    // Derive the archive-relative path of the loaded page (host "chm").
    NSString *pagePath = webView.URL.path;                       // "/toctopics/x.html"
    if (pagePath.length > 1) {
        pagePath = [pagePath substringFromIndex:1];
        pagePath = [pagePath stringByRemovingPercentEncoding] ?: pagePath;
        [self syncOutlineSelectionToPagePath:pagePath];
    }
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
