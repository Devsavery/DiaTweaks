#import "Patches/ProfileOverview/ProfileOverview.h"

const CFTimeInterval DPOverviewResponse = 0.42;
static const CAFrameRateRange DPOverviewFrameRate = {80, 120, 120};  // Without it, ProMotion starts these at 60 Hz.

static CASpringAnimation *DPOverviewSpring(NSString *keyPath, CFTimeInterval response, CGFloat dampingRatio) {
    CGFloat w = 2 * M_PI / response;
    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:keyPath];
    spring.stiffness = w * w;
    spring.damping = 2 * dampingRatio * w;
    spring.duration = spring.settlingDuration;
    spring.preferredFrameRateRange = DPOverviewFrameRate;
    return spring;
}

// Maps a layer laid out at `to` onto `from`: NSView layers anchor at their origin.
CATransform3D DPOverviewFromRect(NSRect from, NSRect to) {
    CATransform3D t = CATransform3DMakeTranslation(NSMinX(from) - NSMinX(to), NSMinY(from) - NSMinY(to), 0);
    return CATransform3DScale(t, NSWidth(from) / MAX(1, NSWidth(to)), NSHeight(from) / MAX(1, NSHeight(to)), 1);
}

void DPOverviewAnimate(CALayer *layer, NSString *keyPath, id from, id to, CFTimeInterval delay, BOOL holds) {
    BOOL fade = [keyPath isEqualToString:@"opacity"];  // A fade that overshoots flickers.
    CASpringAnimation *spring = DPOverviewSpring(keyPath, DPOverviewResponse, fade ? 1 : 0.9);
    spring.fromValue = from;
    spring.toValue = to;
    spring.beginTime = CACurrentMediaTime() + delay;
    spring.fillMode = kCAFillModeBoth;
    spring.removedOnCompletion = !holds;  // Closing holds its end, or the card flashes back.
    [layer addAnimation:spring forKey:keyPath];
}

void DPOverviewFade(CALayer *layer, CGFloat from, CGFloat to, CFTimeInterval delay, CFTimeInterval duration, BOOL holds) {
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @(from);
    fade.toValue = @(to);
    fade.beginTime = CACurrentMediaTime() + delay;
    fade.duration = duration;
    fade.fillMode = kCAFillModeBoth;
    fade.removedOnCompletion = !holds;
    [layer addAnimation:fade forKey:@"opacity"];
}
