#import "Patches/ProfileOverview/ProfileOverview.h"

static const CGFloat DPPullDistance = 90;

static BOOL DPPulling, DPDecided;
static CGFloat DPPulled;
static __weak NSWindow *DPPullWindow;

static BOOL DPOnLastProfile(NSWindow *window) {
    NSUInteger count = DPOverviewProfiles(window).count;
    return count && DPOverviewActiveIndex(window) == (NSInteger)count;
}

static BOOL DPInSidebar(NSEvent *event) {
    NSView *sidebar = DPOverviewSidebar(event.window);
    return sidebar && NSPointInRect([sidebar convertPoint:event.locationInWindow fromView:nil], sidebar.bounds);
}

static void DPTrackPull(NSEvent *event) {
    if (event.phase == NSEventPhaseBegan) {
        DPPulling = DPInSidebar(event) && !DPOverviewShowing(event.window) && DPOnLastProfile(event.window);
        DPPullWindow = event.window;
        DPDecided = NO;
        DPPulled = 0;
    }
    // Once a swipe settles on a profile, keep a picture of it for the overview.
    if (event.momentumPhase == NSEventPhaseEnded || (event.phase == NSEventPhaseEnded && DPInSidebar(event))) DPOverviewCaptureSoon(event.window);
    if (!DPPulling || (event.phase != NSEventPhaseBegan && event.phase != NSEventPhaseChanged)) return;
    // A swipe that starts out vertical is scrolling the tabs.
    if (!DPDecided && (event.scrollingDeltaX != 0 || event.scrollingDeltaY != 0)) {
        DPDecided = YES;
        if (fabs(event.scrollingDeltaY) > fabs(event.scrollingDeltaX)) return (void)(DPPulling = NO);
    }
    // Toward the next profile the content moves left, whichever way the user's scrolling runs.
    DPPulled = MAX(0, DPPulled - event.scrollingDeltaX);
    if (DPPulled < DPPullDistance) return;
    DPPulling = NO;
    DPOverviewOpen(DPPullWindow);
}

// Dia's tab list is a scroll view, which reads a swipe's events in a loop of its own once it starts: every one is dequeued here.
static NSEvent *DPApplication_nextEvent(NSApplication *self, SEL _cmd, NSEventMask mask, NSDate *until, NSRunLoopMode mode, BOOL dequeue) {
    NSEvent *event = DPCallOriginal(DPApplication_nextEvent, self, mask, until, mode, dequeue);
    if (dequeue && event.type == NSEventTypeScrollWheel && DPProfileOverview.on && event.hasPreciseScrollingDeltas) DPTrackPull(event);
    return event;
}

void DPInstallOverviewGesture(void) {
    DPHookClass(NSApplication.class, @selector(nextEventMatchingMask:untilDate:inMode:dequeue:), (IMP)DPApplication_nextEvent);
}

NSString *DPOverviewGestureProblem(void) {
    if (class_getMethodImplementation(NSApplication.class, @selector(nextEventMatchingMask:untilDate:inMode:dequeue:)) != (IMP)DPApplication_nextEvent)
        return @"swipes in the sidebar don't reach the overview";
    return nil;
}
