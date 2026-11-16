#import "Patches/ProfileOverview/ProfileOverview.h"

static NSMutableDictionary<NSString *, NSImage *> *DPSnapshots;
static NSMutableDictionary<NSString *, NSImage *> *DPIcons;

static NSString *DPSnapshotKey(id profile) { return [profile valueForKey:@"name"]; }

NSImage *DPOverviewSnapshot(id profile) {
    NSString *key = DPSnapshotKey(profile);
    return key ? DPSnapshots[key] : nil;
}

NSImage *DPOverviewIcon(NSString *title) { return title ? DPIcons[title] : nil; }

// Each row of Dia's tab list holds the tab's icon and title; only the showing profile's rows exist.
static void DPHarvestIcons(NSWindow *window) {
    for (NSView *row in DPFindViews(DPDiaTabContentView)) {
        if (row.window != window) continue;
        NSImageView *icon = (NSImageView *)DPFindView(row, ^BOOL(NSView *view) { return [view isKindOfClass:NSImageView.class] && NSWidth(view.frame) == 16 && !view.accessibilityLabel.length; });
        NSTextField *label = (NSTextField *)DPSubview(row, DPDiaFeatheredLabel) ?: (NSTextField *)DPFindView(row, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaFeatheredLabel); });
        NSString *title = [label respondsToSelector:@selector(stringValue)] ? label.stringValue : nil;
        if (icon.image && title.length) DPIcons[title] = icon.image;
    }
}

// Drawn from the window's frame view, so the sidebar's tint and the window behind it come along. It takes a while: never mid-swipe.
void DPOverviewCapture(NSWindow *window) {
    NSView *sidebar = DPOverviewSidebar(window), *frame = window.contentView.superview;
    NSArray *profiles = DPOverviewProfiles(window);
    NSInteger index = DPOverviewActiveIndex(window);
    if (!sidebar || !frame || index < 1 || index > (NSInteger)profiles.count || DPOverviewShowing(window)) return;
    DPHarvestIcons(window);
    NSRect rect = [frame convertRect:sidebar.bounds fromView:sidebar];
    NSBitmapImageRep *rep = [frame bitmapImageRepForCachingDisplayInRect:rect];
    if (!rep) return;
    [frame cacheDisplayInRect:rect toBitmapImageRep:rep];
    NSImage *image = [[NSImage alloc] initWithSize:rect.size];
    [image addRepresentation:rep];
    NSString *key = DPSnapshotKey(profiles[index - 1]);
    if (key) DPSnapshots[key] = image;
}

void DPOverviewCaptureSoon(NSWindow *window) {
    static NSUInteger turn;
    NSUInteger mine = ++turn;
    __weak NSWindow *weak = window;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (mine == turn && DPProfileOverview.on && weak) DPOverviewCapture(weak);
    });
}

// The sidebar's own color, from its outer edge where no tab is drawn: top and bottom, for its gradient.
NSArray<NSColor *> *DPOverviewColors(NSImage *snapshot) {
    NSBitmapImageRep *rep = (NSBitmapImageRep *)snapshot.representations.firstObject;
    if (![rep isKindOfClass:NSBitmapImageRep.class] || rep.pixelsWide < 8 || rep.pixelsHigh < 200) return nil;
    NSInteger x = 3 * rep.pixelsWide / snapshot.size.width;
    NSColor *top = [rep colorAtX:x y:rep.pixelsHigh / 8], *bottom = [rep colorAtX:x y:rep.pixelsHigh - rep.pixelsHigh / 8];
    return top && bottom ? @[ [top colorUsingColorSpace:NSColorSpace.sRGBColorSpace], [bottom colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ] : nil;
}

void DPInstallOverviewCapture(void) {
    DPSnapshots = [NSMutableDictionary new];
    DPIcons = [NSMutableDictionary new];
    DPOnLaunch(^{
        // Switching from the menu or with a shortcut lands on a profile the swipe never saw.
        [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidSendActionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            if (DPProfileOverview.on) DPOverviewCaptureSoon(NSApp.keyWindow);
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            if (DPProfileOverview.on) DPOverviewCaptureSoon(note.object);
        }];
        // Anything else that switches profiles, such as a script or a click on the sidebar's dots.
        __block NSInteger last = 0;
        [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer *timer) {
            NSWindow *window = NSApp.keyWindow;
            NSInteger index = DPProfileOverview.on && window ? DPOverviewActiveIndex(window) : 0;
            if (index && index != last) DPOverviewCaptureSoon(window);
            last = index;
        }];
    });
}
