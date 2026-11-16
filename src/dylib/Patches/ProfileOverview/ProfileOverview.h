#import "StdPatch/StdPatch.h"

#define DPDiaSidebarRoot      "_TtC10TabSidebarP33_1737451677CA9CA733FCF78BBDD9DE8A24SidebarContainerRootView"
#define DPDiaScriptProfile    "DiaAppleScriptProfile"
#define DPDiaScriptTab        "DiaAppleScriptTab"

extern DPPatch DPProfileOverview;

@interface DPOverviewCard : NSView
@property(nonatomic, strong) id profile;
@property(nonatomic, strong) CALayer *ghost;  // The profile's whole sidebar, shown while the card flies to or from it. A layer, so clicks pass it.
@property(nonatomic, copy) void (^picked)(DPOverviewCard *card, id target);
@property(nonatomic, readonly) NSArray<NSColor *> *colors;  // Top and bottom of the profile's sidebar, or nil before it has been seen.
- (instancetype)initWithProfile:(id)profile snapshot:(NSImage *)snapshot;
@end

NSString *DPOverviewText(id value);  // Scripting gives NSNull for what a tab lacks.
@interface DPOverviewFlipped : NSView
@end

extern const CGFloat DPOverviewInset, DPOverviewRowHeight;
NSTextField *DPOverviewLabel(NSString *text, NSFont *font, NSColor *color);
NSView *DPOverviewRowFor(id tab, DPOverviewCard *card, CGFloat width, NSColor *ink);

@interface DPProfileSpread : NSView
@property(nonatomic, strong) CAGradientLayer *backdrop;
@property(nonatomic, strong) NSView *page;  // Where the web page goes: it slides aside to make room, as in Arc.
@property(nonatomic, strong) NSButton *plus;
@property(nonatomic, strong) NSArray<DPOverviewCard *> *cards;
@property(nonatomic) NSInteger current;  // Zero-based: the card for the profile showing now.
@property(nonatomic) NSRect sidebar;     // Where the sidebar is, in our coordinates, or empty.
@property(nonatomic) BOOL closing;
- (void)open;
- (void)closeOn:(DPOverviewCard *)chosen target:(id)target;
@end

NSView *DPOverviewHost(NSWindow *window);
DPProfileSpread *DPOverviewIn(NSWindow *window);
NSMenuItem *DPOverviewNewProfileItem(NSMenu *menu);

id DPOverviewScriptWindow(NSWindow *window);
NSArray *DPOverviewProfiles(NSWindow *window);
NSInteger DPOverviewActiveIndex(NSWindow *window);  // One-based, as Dia's scripting counts; 0 if unknown.
NSView *DPOverviewSidebar(NSWindow *window);
void DPInstallOverviewCapture(void);
void DPOverviewCapture(NSWindow *window);
void DPOverviewCaptureSoon(NSWindow *window);
NSImage *DPOverviewSnapshot(id profile);
NSImage *DPOverviewIcon(NSString *title);
void DPOverviewLookUpIcons(NSArray<NSString *> *urls);
NSImage *DPOverviewSiteIcon(NSString *url);
NSArray<NSColor *> *DPOverviewColors(NSImage *snapshot);

void DPOverviewOpen(NSWindow *window);
BOOL DPOverviewShowing(NSWindow *window);
void DPOverviewDismiss(NSWindow *window);
void DPInstallOverviewGesture(void);
NSString *DPOverviewGestureProblem(void);

extern const CFTimeInterval DPOverviewResponse;
CATransform3D DPOverviewFromRect(NSRect from, NSRect to);
void DPOverviewAnimate(CALayer *layer, NSString *keyPath, id from, id to, CFTimeInterval delay, BOOL holds);
void DPOverviewFade(CALayer *layer, CGFloat from, CGFloat to, CFTimeInterval delay, CFTimeInterval duration, BOOL holds);
