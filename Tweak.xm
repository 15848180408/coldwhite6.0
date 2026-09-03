#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <mach/mach.h>

static NSString * const kDomain = @"com.chatgpt.coldwhite";

// ========== IOMobileFramebuffer 正确的类型和函数签名 ==========
typedef struct __IOMobileFramebuffer *IOMobileFramebufferRef;
typedef int IOMobileFramebufferReturn;

// Gamma table 结构体（关键！）
typedef struct {
    uint32_t channelCount;  // 3 = RGB
    uint32_t dataCount;     // 256
    uint32_t dataWidth;     // 32 = float
    void *data;             // 指向实际数据
} IOMobileFramebufferGammaTable;

typedef IOMobileFramebufferReturn (*IOFBOpenFunc)(
    mach_port_t servicePort,
    task_port_t owningTask,
    unsigned int type,
    IOMobileFramebufferRef *connection
);

typedef IOMobileFramebufferReturn (*IOFBSetGammaTableFunc)(
    IOMobileFramebufferRef connection,
    const IOMobileFramebufferGammaTable *table
);

typedef mach_port_t (*IOServiceGetMatchingServiceFunc)(
    mach_port_t mainPort,
    CFDictionaryRef matching
);

typedef CFDictionaryRef (*IOServiceMatchingFunc)(const char *name);

static IOFBOpenFunc                  s_openFB = NULL;
static IOFBSetGammaTableFunc         s_setGammaTable = NULL;
static IOServiceGetMatchingServiceFunc s_getService = NULL;
static IOServiceMatchingFunc          s_matching = NULL;
static IOMobileFramebufferRef         s_connection = NULL;
static BOOL                           s_hwAvailable = NO;

// ========== 全屏窗口降级 ==========
static UIWindow *g_overlayWindow = nil;

static CGFloat clampv(CGFloat x, CGFloat a, CGFloat b) {
    return MIN(MAX(x, a), b);
}

// ========== 初始化（正确方式：IOServiceGetMatchingService + IOMobileFramebufferOpen） ==========
static void initHardwareGamma(void) {
    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer",
        RTLD_LAZY
    );
    if (!handle) return;

    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!iokit) return;

    s_openFB        = (IOFBOpenFunc)dlsym(handle, "IOMobileFramebufferOpen");
    s_setGammaTable = (IOFBSetGammaTableFunc)dlsym(handle, "IOMobileFramebufferSetGammaTable");
    s_getService    = (IOServiceGetMatchingServiceFunc)dlsym(iokit, "IOServiceGetMatchingService");
    s_matching      = (IOServiceMatchingFunc)dlsym(iokit, "IOServiceMatching");

    if (!s_openFB || !s_setGammaTable || !s_getService || !s_matching) return;

    // 找到 AppleCLCD 显示服务
    mach_port_t service = s_getService(0, s_matching("AppleCLCD"));
    if (!service) return;

    // 打开 connection
    IOMobileFramebufferReturn kr = s_openFB(service, mach_task_self(), 0, &s_connection);
    if (kr != 0 || !s_connection) return;

    s_hwAvailable = YES;
}

// ========== 硬件 Gamma（正确调用方式） ==========
static BOOL applyHardwareGamma(CGFloat intensity) {
    if (!s_hwAvailable) return NO;

    CGFloat k = clampv(intensity, 0, 100) / 100.0;

    // 冷白参数：降红、微提蓝、绿不动
    CGFloat redScale   = 1.0 - 0.20 * k;
    CGFloat greenScale = 1.0;
    CGFloat blueScale  = 1.0 + 0.10 * k;

    // 构造 gamma 数据：256 个条目，每个条目是 RGB 三个 float（交错）
    static float data[256 * 3];
    for (int i = 0; i < 256; i++) {
        CGFloat val = (CGFloat)i / 255.0;
        data[i * 3 + 0] = clampv(val * redScale,   0, 1);
        data[i * 3 + 1] = clampv(val * greenScale, 0, 1);
        data[i * 3 + 2] = clampv(val * blueScale,  0, 1);
    }

    IOMobileFramebufferGammaTable table;
    table.channelCount = 3;
    table.dataCount = 256;
    table.dataWidth = 32;  // float = 32 bit
    table.data = data;

    IOMobileFramebufferReturn kr = s_setGammaTable(s_connection, &table);
    return (kr == 0);
}

static BOOL restoreHardwareGamma(void) {
    if (!s_hwAvailable) return NO;

    static float data[256 * 3];
    for (int i = 0; i < 256; i++) {
        CGFloat val = (CGFloat)i / 255.0;
        data[i * 3 + 0] = val;
        data[i * 3 + 1] = val;
        data[i * 3 + 2] = val;
    }

    IOMobileFramebufferGammaTable table;
    table.channelCount = 3;
    table.dataCount = 256;
    table.dataWidth = 32;
    table.data = data;

    IOMobileFramebufferReturn kr = s_setGammaTable(s_connection, &table);
    return (kr == 0);
}

// ========== 窗口降级 ==========
static void applyOverlayGamma(CGFloat intensity) {
    CGFloat k = clampv(intensity, 0, 100) / 100.0;

    if (!g_overlayWindow) {
        g_overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_overlayWindow.windowLevel = UIWindowLevelAlert + 1000;
        g_overlayWindow.userInteractionEnabled = NO;
        g_overlayWindow.rootViewController = [UIViewController new];
        g_overlayWindow.hidden = YES;
    }

    if (k < 0.01) {
        g_overlayWindow.hidden = YES;
        return;
    }

    g_overlayWindow.hidden = NO;
    CGFloat alpha = k * 0.12;
    g_overlayWindow.backgroundColor = [UIColor colorWithRed:0.88 green:0.93 blue:1.0 alpha:alpha];
}

// ========== 主入口 ==========
static void CWApply(void) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:kDomain];
    BOOL enabled = [d objectForKey:@"Enabled"] ? [d boolForKey:@"Enabled"] : YES;
    NSInteger temp = [d objectForKey:@"Temperature"] ? [d integerForKey:@"Temperature"] : 0;
    temp = MAX(0, MIN(100, temp));

    if (!enabled || temp == 0) {
        BOOL ok = restoreHardwareGamma();
        if (!ok) applyOverlayGamma(0);
        return;
    }

    BOOL ok = applyHardwareGamma((CGFloat)temp);
    if (!ok) applyOverlayGamma((CGFloat)temp);
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

    // 延迟 5 秒，等 SpringBoard 完全启动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ CWApply(); });
}
