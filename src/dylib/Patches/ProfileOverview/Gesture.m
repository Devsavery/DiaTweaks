#import "Patches/ProfileOverview/ProfileOverview.h"

static const CGFloat DPPullDistance = 90;

static BOOL DPPulling, DPDecided, DPLeaving;  // Leaving: the swipe back out of the overview.
static CGFloat DPPulled;
static BOOL DPHooked;
static CFTimeInterval DPSwallowUntil;  // After a swipe closes the overview, the rest of it would page Dia's sidebar.
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
        DPLeaving = DPOverviewShowing(event.window);
        DPPulling = DPLeaving || (DPInSidebar(event) && DPOnLastProfile(event.window));
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
    // Toward the next profile the content moves left, whichever way the user's scrolling runs; back out is the other way.
    DPPulled = MAX(0, DPPulled + (DPLeaving ? event.scrollingDeltaX : -event.scrollingDeltaX));
    if (DPPulled < DPPullDistance) return;
    DPPulling = NO;
    if (!DPLeaving) return DPOverviewOpen(DPPullWindow);
    DPSwallowUntil = CACurrentMediaTime() + 1.5;
    DPOverviewClose(DPPullWindow);
}

// Dia's tab list is a scroll view, which reads a swipe's events in a loop of its own once it starts: every one is dequeued here.
static NSEvent *DPApplication_nextEvent(NSApplication *self, SEL _cmd, NSEventMask mask, NSDate *until, NSRunLoopMode mode, BOOL dequeue) {
    NSEvent *event = DPCallOriginal(DPApplication_nextEvent, self, mask, until, mode, dequeue);
    if (dequeue && event.type == NSEventTypeScrollWheel && DPProfileOverview.on && event.hasPreciseScrollingDeltas) DPTrackPull(event);
    return event;
}

// Until the swipe and its momentum end, or a new one starts.
static BOOL DPSwallowRest(NSEvent *event) {
    BOOL over = CACurrentMediaTime() > DPSwallowUntil || event.phase == NSEventPhaseBegan || event.phase == NSEventPhaseMayBegin;
    if (over || event.momentumPhase == NSEventPhaseEnded || event.momentumPhase == NSEventPhaseCancelled) DPSwallowUntil = 0;
    return !over;
}

void DPInstallOverviewGesture(void) {
    SEL next = @selector(nextEventMatchingMask:untilDate:inMode:dequeue:);
    DPHookClass(NSApplication.class, next, (IMP)DPApplication_nextEvent);
    DPHooked = class_getMethodImplementation(NSApplication.class, next) == (IMP)DPApplication_nextEvent;
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel handler:^NSEvent *(NSEvent *event) {
        return DPSwallowUntil && DPSwallowRest(event) ? nil : event;
    }];
}

// Close Tabs from Tab Switcher hooks the same method and may sit in front, calling through to this one: check it went in, not that it's last.
NSString *DPOverviewGestureProblem(void) {
    return DPHooked ? nil : @"swipes in the sidebar don't reach the overview";
}
