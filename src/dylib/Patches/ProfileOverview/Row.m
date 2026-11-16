#import "Patches/ProfileOverview/ProfileOverview.h"

const CGFloat DPOverviewInset = 8, DPOverviewRowHeight = 30;

@implementation DPOverviewFlipped
- (BOOL)isFlipped { return YES; }
@end

@interface DPOverviewRow : NSView
@property(nonatomic, strong) id tab;
@property(nonatomic, weak) DPOverviewCard *card;
@property(nonatomic, strong) NSColor *ink;
@end

@implementation DPOverviewRow

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

- (void)mouseEntered:(NSEvent *)event { self.layer.backgroundColor = [self.ink colorWithAlphaComponent:0.1].CGColor; }
- (void)mouseExited:(NSEvent *)event { self.layer.backgroundColor = nil; }
- (void)mouseDown:(NSEvent *)event { if (self.card.picked) self.card.picked(self.card, self.tab); }

@end

NSTextField *DPOverviewLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

// Dia's own icon from the sidebar, else Chromium's saved one, else the site's first letter.
static NSView *DPIconView(NSString *title, NSString *url, NSColor *ink) {
    NSImage *image = DPOverviewIcon(title) ?: DPOverviewSiteIcon(url);
    if (image) {
        NSImageView *icon = [NSImageView imageViewWithImage:image];
        icon.imageScaling = NSImageScaleProportionallyUpOrDown;
        icon.wantsLayer = YES;
        icon.layer.cornerRadius = 4;
        icon.layer.masksToBounds = YES;
        return icon;
    }
    NSString *host = [NSURL URLWithString:url ?: @""].host ?: @"";
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    NSTextField *badge = DPOverviewLabel(host.length ? [host substringToIndex:1].uppercaseString : @"•", [NSFont systemFontOfSize:9 weight:NSFontWeightBold], ink);
    badge.alignment = NSTextAlignmentCenter;
    badge.wantsLayer = YES;
    badge.layer.cornerRadius = 4;
    badge.layer.backgroundColor = [ink colorWithAlphaComponent:0.15].CGColor;
    return badge;
}

NSView *DPOverviewRowFor(id tab, DPOverviewCard *card, CGFloat width, NSColor *ink) {
    DPOverviewRow *row = [[DPOverviewRow alloc] initWithFrame:NSMakeRect(DPOverviewInset, 0, width - 2 * DPOverviewInset, DPOverviewRowHeight)];
    row.wantsLayer = YES;
    row.layer.cornerRadius = 7;
    row.tab = tab;
    row.card = card;
    row.ink = ink;
    NSString *title = DPOverviewText([tab valueForKey:@"title"]), *url = DPOverviewText([tab valueForKey:@"URL"]);
    NSView *icon = DPIconView(title, url, ink);
    icon.frame = NSMakeRect(9, (DPOverviewRowHeight - 16) / 2, 16, 16);
    [row addSubview:icon];
    NSTextField *label = DPOverviewLabel(title.length ? title : url, [NSFont systemFontOfSize:13 weight:NSFontWeightMedium], ink);
    label.frame = NSMakeRect(33, (DPOverviewRowHeight - 17) / 2, NSWidth(row.frame) - 41, 17);
    [row addSubview:label];
    return row;
}
