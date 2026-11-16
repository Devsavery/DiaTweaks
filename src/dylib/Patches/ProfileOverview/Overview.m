#import "Patches/ProfileOverview/ProfileOverview.h"

static const CGFloat DPGap = 12, DPEdge = 10, DPTop = 40;


// Over Dia's content view rather than in it: Dia keeps its own views above anything added there.
NSView *DPOverviewHost(NSWindow *window) { return window.contentView.superview; }

DPProfileSpread *DPOverviewIn(NSWindow *window) {
    for (NSView *view in DPOverviewHost(window).subviews)
        if ([view isKindOfClass:DPProfileSpread.class]) return (DPProfileSpread *)view;
    return nil;
}

BOOL DPOverviewShowing(NSWindow *window) { return DPOverviewIn(window) != nil; }

NSMenuItem *DPOverviewNewProfileItem(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        NSString *title = item.title.lowercaseString;
        if (([title hasPrefix:@"new profile"] || [title hasPrefix:@"add profile"]) && item.action) return item;
        NSMenuItem *found = item.submenu ? DPOverviewNewProfileItem(item.submenu) : nil;
        if (found) return found;
    }
    return nil;
}

@implementation DPProfileSpread

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

// The row of profiles starts at the window's edge, as wide as the sidebar while there's room, and the page keeps the rest.
- (void)layout {
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.backdrop.frame = self.layer.bounds;
    [CATransaction commit];
    NSUInteger n = self.cards.count;
    if (!n) return;
    CGFloat plus = self.plus ? 64 : 24, room = NSWidth(self.bounds) * 0.65 - DPEdge - plus - DPGap * (n - 1);
    CGFloat width = MIN(MAX(220, MIN(320, NSWidth(self.sidebar))), MAX(150, room / n));
    CGFloat height = NSHeight(self.bounds) - DPTop - DPEdge;
    for (NSUInteger i = 0; i < n; i++)
        self.cards[i].frame = [self backingAlignedRect:NSMakeRect(DPEdge + i * (width + DPGap), DPTop, width, height) options:NSAlignAllEdgesNearest];
    CGFloat end = NSMaxX(self.cards.lastObject.frame);
    self.plus.frame = NSMakeRect(end + 32 - 12, NSMidY(self.cards[0].frame) - 12, 24, 24);
    self.page.frame = NSMakeRect(end + plus, DPEdge, MAX(0, NSWidth(self.bounds) - end - plus - DPEdge), NSHeight(self.bounds) - 2 * DPEdge);
}

- (NSRect)content {
    CGFloat left = NSIsEmptyRect(self.sidebar) ? 0 : NSMaxX(self.sidebar);
    return NSMakeRect(left, 0, NSWidth(self.bounds) - left, NSHeight(self.bounds));
}

// How far the row sits from where it would put `card` over the sidebar; with none, it comes from off the left edge.
- (CGFloat)shiftFor:(DPOverviewCard *)card {
    return NSIsEmptyRect(self.sidebar) ? NSMaxX(card.frame) : NSMinX(card.frame) - NSMinX(self.sidebar);
}

- (void)moveFor:(DPOverviewCard *)anchor opening:(BOOL)opening {
    CGFloat shift = [self shiftFor:anchor];
    CATransform3D aside = CATransform3DMakeTranslation(-shift, 0, 0);
    NSValue *rest = [NSValue valueWithCATransform3D:CATransform3DIdentity];
    for (DPOverviewCard *card in self.cards) {
        CATransform3D away = card == anchor && !NSIsEmptyRect(self.sidebar) ? DPOverviewFromRect(self.sidebar, card.frame) : aside;
        NSValue *moved = [NSValue valueWithCATransform3D:away];
        DPOverviewAnimate(card.layer, @"transform", opening ? moved : rest, opening ? rest : moved, 0, !opening);
        if (card == anchor && card.ghost) DPOverviewAnimate(card.ghost, @"opacity", opening ? @1 : @0, opening ? @0 : @1, opening ? 0.05 : 0, !opening);
    }
    NSValue *page = [NSValue valueWithCATransform3D:DPOverviewFromRect(self.content, self.page.frame)];
    DPOverviewAnimate(self.page.layer, @"transform", opening ? page : rest, opening ? rest : page, 0, !opening);
    if (self.plus) DPOverviewAnimate(self.plus.layer, @"opacity", opening ? @0 : @1, opening ? @1 : @0, opening ? 0.1 : 0, !opening);
    // Quick, so the page under it never shows through; closing waits until the columns are nearly home.
    DPOverviewFade(self.backdrop, opening ? 0 : 1, opening ? 1 : 0, opening ? 0 : DPOverviewResponse * 0.6, 0.14, !opening);
    if (!opening) DPOverviewFade(self.page.layer, 1, 0, DPOverviewResponse * 0.6, 0.14, YES);
}

- (void)open {
    [self layoutSubtreeIfNeeded];
    [self moveFor:self.cards[self.current] opening:YES];
    [self.window makeFirstResponder:self];
}

- (void)closeOn:(DPOverviewCard *)chosen target:(id)target {
    if (self.closing) return;
    self.closing = YES;
    chosen = chosen ?: self.cards[self.current];
    if (target) [target performSelector:@selector(focus:) withObject:nil];
    [self moveFor:chosen opening:NO];
    // Once the background has faded: most of the travel is over well before the spring settles.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((DPOverviewResponse * 0.6 + 0.14) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeFromSuperview];
    });
}

- (void)addProfile:(id)sender {
    NSMenuItem *item = DPOverviewNewProfileItem(NSApp.mainMenu);
    [self closeOn:nil target:nil];
    if (item) [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
}

- (void)mouseDown:(NSEvent *)event { [self closeOn:nil target:nil]; }

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 53) return [self closeOn:nil target:nil];  // Escape
    [super keyDown:event];
}

@end
