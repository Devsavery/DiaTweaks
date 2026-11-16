#import "Patches/ProfileOverview/ProfileOverview.h"

NSString *DPOverviewText(id value) { return [value isKindOfClass:NSString.class] ? value : nil; }

static CGFloat DPLuminance(NSColor *color) { return 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent; }

@implementation DPOverviewCard {
    NSTextField *_name;
    NSScrollView *_list;
    CAGradientLayer *_fill;
    NSColor *_ink;
}

- (instancetype)initWithProfile:(id)profile snapshot:(NSImage *)snapshot {
    self = [super initWithFrame:NSZeroRect];
    self.profile = profile;
    _colors = DPOverviewColors(snapshot);
    // White, as on Dia's sidebar, unless the profile's color is very light.
    _ink = _colors && DPLuminance(_colors[0]) > 0.78 ? [NSColor colorWithWhite:0 alpha:0.85] : [NSColor colorWithWhite:1 alpha:0.92];
    self.wantsLayer = YES;
    self.layer.cornerRadius = 10;
    self.layer.masksToBounds = YES;
    _fill = [CAGradientLayer layer];
    // A touch lighter than the profile's own color, so a column stands out on a window of the same color.
    NSArray<NSColor *> *fill = _colors ?: @[ [NSColor colorWithWhite:0.45 alpha:0.5], [NSColor colorWithWhite:0.45 alpha:0.5] ];
    _fill.colors = @[ (id)[fill[0] blendedColorWithFraction:0.1 ofColor:NSColor.whiteColor].CGColor, (id)[fill[1] blendedColorWithFraction:0.1 ofColor:NSColor.whiteColor].CGColor ];
    _fill.zPosition = -1;
    [self.layer addSublayer:_fill];
    self.layer.borderWidth = 1;
    self.layer.borderColor = [NSColor colorWithWhite:1 alpha:0.18].CGColor;
    _name = DPOverviewLabel(DPOverviewText([profile valueForKey:@"name"]), [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold], [_ink colorWithAlphaComponent:0.6]);
    [self addSubview:_name];
    _list = [NSScrollView new];
    _list.drawsBackground = NO;
    _list.hasVerticalScroller = YES;
    _list.autohidesScrollers = YES;
    _list.scrollerStyle = NSScrollerStyleOverlay;
    [self addSubview:_list];
    if (snapshot) {
        self.ghost = [CALayer layer];
        self.ghost.contents = (__bridge id)[snapshot CGImageForProposedRect:NULL context:nil hints:nil];
        self.ghost.contentsGravity = kCAGravityResize;
        self.ghost.opacity = 0;
        self.ghost.zPosition = 1;
        [self.layer addSublayer:self.ghost];
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (void)mouseDown:(NSEvent *)event { if (self.picked) self.picked(self, self.profile); }

- (void)layout {
    [super layout];
    CGFloat width = NSWidth(self.bounds);
    _name.frame = NSMakeRect(DPOverviewInset + 9, 12, width - 2 * DPOverviewInset - 18, 16);
    _list.frame = NSMakeRect(0, 34, width, MAX(0, NSHeight(self.bounds) - 38));
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fill.frame = self.ghost.frame = self.layer.bounds;
    [CATransaction commit];
    if (NSWidth(_list.documentView.frame) != width) [self fillList];
}

// Dia's scripting lists favorites first, then the rest: a line between them, as in the sidebar.
- (void)fillList {
    CGFloat width = NSWidth(_list.frame), y = 0;
    NSView *list = [[DPOverviewFlipped alloc] initWithFrame:NSZeroRect];
    NSArray *tabs = [self.profile valueForKey:@"appleScriptTabs"];
    DPOverviewLookUpIcons([tabs valueForKey:@"URL"]);
    NSPredicate *pinned = [NSPredicate predicateWithFormat:@"isPinned == YES"];
    NSArray *groups = @[ [tabs filteredArrayUsingPredicate:pinned] ?: @[], [tabs filteredArrayUsingPredicate:[NSCompoundPredicate notPredicateWithSubpredicate:pinned]] ?: @[] ];
    for (NSArray *group in groups) {
        if (!group.count) continue;
        if (y > 0) {
            NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(DPOverviewInset + 9, y + 5, width - 2 * DPOverviewInset - 18, 1)];
            line.boxType = NSBoxCustom;
            line.borderWidth = 0;
            line.fillColor = [_ink colorWithAlphaComponent:0.15];
            [list addSubview:line];
            y += 11;
        }
        for (id tab in group) {
            NSView *row = DPOverviewRowFor(tab, self, width, _ink);
            row.frame = NSOffsetRect(row.frame, 0, y);
            [list addSubview:row];
            y += DPOverviewRowHeight;
        }
    }
    list.frame = NSMakeRect(0, 0, width, y + 6);
    _list.documentView = list;
}

@end
