#import "Patches/ProfileOverview/ProfileOverview.h"

id DPOverviewScriptWindow(NSWindow *window) {
    for (id scripted in [(id)NSApp.delegate valueForKey:@"appleScriptWindows"])
        if ([[scripted valueForKey:@"windowId"] isEqual:window.identifier]) return scripted;
    return nil;
}

NSArray *DPOverviewProfiles(NSWindow *window) {
    NSArray *profiles = [DPOverviewScriptWindow(window) valueForKey:@"appleScriptProfiles"];
    return [profiles isKindOfClass:NSArray.class] ? profiles : @[];
}

NSInteger DPOverviewActiveIndex(NSWindow *window) {
    return [[[DPOverviewScriptWindow(window) valueForKey:@"activeProfile"] valueForKey:@"orderedIndex"] integerValue];
}

NSView *DPOverviewSidebar(NSWindow *window) {
    for (NSView *view in DPFindViews(DPDiaSidebarRoot))
        if (view.window == window && !view.hiddenOrHasHiddenAncestor && NSWidth(view.bounds) > 0) return view;
    return nil;
}

static void DPInstallProfileOverview(void) {
    DPInstallOverviewCapture();
    DPInstallOverviewGesture();
}

static void DPApplyProfileOverview(DPPatch *patch) {
    if (patch->on) return;
    for (NSWindow *window in NSApp.windows) DPOverviewDismiss(window);
}

static NSString *DPVerifyProfileOverview(DPPatch *patch) {
    NSString *problem = DPOverviewGestureProblem();
    if (problem) return problem;
    if (![objc_getClass(DPDiaScriptProfile) instancesRespondToSelector:@selector(focus:)]) return @"Dia's profiles can't be switched to";
    if (![objc_getClass(DPDiaScriptTab) instancesRespondToSelector:@selector(focus:)]) return @"Dia's tabs can't be switched to";
    NSWindow *window = NSApp.mainWindow ?: NSApp.orderedWindows.firstObject;
    if (DPOverviewScriptWindow(window) && !DPOverviewProfiles(window).count) return @"Dia lists no profiles";
    for (NSWindow *each in NSApp.windows)
        if (!patch->on && DPOverviewShowing(each)) return @"the overview stays open";
    return nil;
}

DP_PATCH(DPProfileOverview) {
    .key = @"profileOverview",
    .order = 79,
    .title = @"Profile Overview",
    .detail = @"Keep swiping past your last profile in the sidebar to lay all your profiles out side by side with their tabs, like Arc's spaces. Click one, or one of its tabs, to switch to it. Press Escape to go back.",
    .symbol = @"rectangle.split.3x1.fill rectangle.split.3x1",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaSidebarRoot, DPDiaScriptProfile, DPDiaScriptTab),
    .install = DPInstallProfileOverview,
    .apply = DPApplyProfileOverview,
    .verify = DPVerifyProfileOverview,
};
