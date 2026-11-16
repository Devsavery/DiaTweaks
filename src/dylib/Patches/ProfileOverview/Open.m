#import "Patches/ProfileOverview/ProfileOverview.h"

static NSView *DPPage(NSColor *ink) {
    NSView *page = [NSView new];
    page.wantsLayer = YES;
    page.layer.cornerRadius = 10;
    page.layer.backgroundColor = [ink colorWithAlphaComponent:0.08].CGColor;
    page.layer.borderWidth = 1;
    page.layer.borderColor = [ink colorWithAlphaComponent:0.1].CGColor;
    return page;
}

void DPOverviewOpen(NSWindow *window) {
    NSView *host = DPOverviewHost(window), *content = window.contentView;
    NSArray *profiles = DPOverviewProfiles(window);
    if (!host || !profiles.count || DPOverviewShowing(window)) return;
    NSInteger current = MAX(0, MIN((NSInteger)profiles.count - 1, DPOverviewActiveIndex(window) - 1));
    if (!DPOverviewSnapshot(profiles[current])) DPOverviewCapture(window);  // Usually taken already, once the last swipe settled.
    DPProfileSpread *overview = [[DPProfileSpread alloc] initWithFrame:content.frame];
    overview.wantsLayer = YES;
    overview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    NSView *sidebar = DPOverviewSidebar(window);
    overview.sidebar = sidebar ? [content convertRect:sidebar.bounds fromView:sidebar] : NSZeroRect;  // Both flipped, at the same place.
    overview.current = current;
    NSMutableArray *cards = [NSMutableArray new];
    __weak DPProfileSpread *weak = overview;
    for (id profile in profiles) {
        DPOverviewCard *card = [[DPOverviewCard alloc] initWithProfile:profile snapshot:DPOverviewSnapshot(profile)];
        card.picked = ^(DPOverviewCard *picked, id target) { [weak closeOn:picked target:target]; };
        [cards addObject:card];
    }
    overview.cards = cards;
    // The window takes the showing profile's color, as Arc's does.
    NSArray<NSColor *> *colors = overview.cards[overview.current].colors;
    overview.backdrop = [CAGradientLayer layer];
    overview.backdrop.colors = colors ? @[ (id)colors[0].CGColor, (id)colors[1].CGColor ] : @[ (id)NSColor.windowBackgroundColor.CGColor, (id)NSColor.windowBackgroundColor.CGColor ];
    overview.backdrop.zPosition = -1;
    [overview.layer addSublayer:overview.backdrop];
    NSColor *ink = !colors ? NSColor.labelColor : NSColor.whiteColor;
    overview.page = DPPage(ink);
    [overview addSubview:overview.page];
    for (DPOverviewCard *card in cards) [overview addSubview:card];
    if (DPOverviewNewProfileItem(NSApp.mainMenu)) {
        NSImage *plus = [[NSImage imageWithSystemSymbolName:@"plus.circle.fill" accessibilityDescription:@"New Profile"] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:22 weight:NSFontWeightMedium]];
        overview.plus = [NSButton buttonWithImage:plus target:overview action:@selector(addProfile:)];
        overview.plus.bordered = NO;
        overview.plus.wantsLayer = YES;
        overview.plus.contentTintColor = ink;
        [overview addSubview:overview.plus];
    }
    [host addSubview:overview positioned:NSWindowAbove relativeTo:content];
    [overview open];
}

void DPOverviewClose(NSWindow *window) {
    [DPOverviewIn(window) closeOn:nil target:nil];
}

void DPOverviewDismiss(NSWindow *window) {
    [DPOverviewIn(window) removeFromSuperview];
}
