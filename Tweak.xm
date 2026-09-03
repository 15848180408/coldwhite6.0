#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>

static NSString * const kDomain = @"com.chatgpt.coldwhite";

#define kGammaCount 256

// ========== IOMobileFramebuffer 私有函数声明 ==========
typedef void *IOMobileFramebufferRef;

typedef int (*IOFBSetGammaTableFunc)(
    IOMobileFramebufferRef connection,
    unsigned int entryCount,
    const float *redTable,
    const float *greenTable,
    const float *blueTable
);

typedef IOMobileFramebufferRef (*IOFBGetMainDisplayFunc)(void);

static IOFBSetGammaTableFunc   s_setGammaTable = NULL;
static IOFBGetMainDisplayFunc   s_getMainDisplay = NULL;
static IOMobileFramebufferRef   s_fbConnection = NULL;
static BOOL                     s_hwGammaAvailable = NO;

// ========== 全屏窗口降级 ==========
static UIWindow *g_overlayWindow = nil;

static CGFloat clampv(CGFloat x, CGFloat a, CGFloat b) {
    return MIN(MAX(x, a), b);
}

// ========== 初始化 ==========
static void initHardwareGamma(void) {
    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer",
        RTLD_LAZY
    );
    if (!handle) return;

    s_setGammaTable  = (IOFBSetGammaTableFunc)dlsym(handle, "IOMobileFramebufferSetGammaTable");
    s_getMainDisplay = (IOFBGetMainDisplayFunc)dlsym(handle, "IOMobileFramebufferGetMainDisplay");

    if (s_getMainDisplay) {
        s_fbConnection = s_getMainDisplay();
    }

    s_hwGammaAvailable = (s_setGammaTable != NULL && s_fbConnection != NULL);
}

// ========== 硬件 Gamma（冷白：降红、微提蓝、绿不动） ==========
static BOOL applyHardwareGamma(CGFloat intensity) {
    if (!s_hwGammaAvailable) return NO;

    CGFloat k = clampv(intensity, 0, 100) / 100.0;

    // 冷白参数：降红 20%，蓝只提 10%，绿不动
    // 这样白色更白，但不会明显变蓝
    CGFloat redScale   = 1.0 - 0.20 * k;
    CGFloat greenScale = 1.0;
    CGFloat blueScale  = 1.0 + 0.10 * k;

    float r[kGammaCount], g[kGammaCount], b[kGammaCount];
    for (int i = 0; i < kGammaCount; i++) {
        CGFloat val = (CGFloat)i / (kGammaCount - 1);
        r[i] = clampv(val * redScale,   0, 1);
        g[i] = clampv(val * greenScale, 0, 1);
        b[i] = clampv(val * blueScale,  0, 1);
    }

    int kr = s_setGammaTable(s_fbConnection, kGammaCount, r, g, b);
    return (kr == 0);
}

static BOOL restoreHardwareGamma(void) {
    if (!s_hwGammaAvailable) return NO;

    float r[kGammaCount], g[kGammaCount], b[kGammaCount];
    for (int i = 0; i < kGammaCount; i++) {
        CGFloat val = (CGFloat)i / (kGammaCount - 1);
        r[i] = g[i] = b[i] = val;
    }

    int kr = s_setGammaTable(s_fbConnection, kGammaCount, r, g, b);
    return (kr == 0);
}

// ========== 窗口降级（极低透明度，避免变蓝） ==========
static void applyOverlayGamma(CGFloat intensity) {
    CGFloat k = clampv(intensity, 0, 100) / 100.0;

    if (!g_overlayWindow) {
        g_overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_overlayWindow.windowLevel = UIWindowLevelAlert + 1000;
        g_overlayWindow.userInteractionEnabled = NO;
        g_overlayWindow.rootViewController = [UIViewController new];
    }

    if (k < 0.01) {
        g_overlayWindow.hidden = YES;
        return;
    }

    g_overlayWindow.hidden = NO;
    // 最大 10% 透明度的淡蓝，只去黄不变蓝
    CGFloat alpha = k * 0.10;
    g_overlayWindow.backgroundColor = [UIColor colorWithRed:0.85 green:0.92 blue:1.0 alpha:alpha];
}

// ========== 主入口 ==========
static void CWApply(void) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:kDomain];
    BOOL enabled = [d objectForKey:@"Enabled"] ? [d boolForKey:@"Enabled"] : YES;
    NSInteger temp = [d objectForKey:@"Temperature"] ? [d integerForKey:@"Temperature"] : 0;
    temp = MAX(0, MIN(100, temp));

    if (!enabled || temp == 0) {
        // 关闭或强度为 0，恢复原厂
        BOOL ok = restoreHardwareGamma();
        if (!ok) {
            applyOverlayGamma(0);
        }
        return;
    }

    // 应用冷白
    BOOL ok = applyHardwareGamma((CGFloat)temp);
    if (!ok) {
        applyOverlayGamma((CGFloat)temp);
    }
}

static void CWNotify(CFNotificationCenterRef c, void *o, CFStringRef n,
                     const void *obj, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{ CWApply(); });
}

%ctor {
    initHardwareGamma();

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL, CWNotify, CFSTR("com.chatgpt.coldwhite/reload"), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ CWApply(); });
}
