#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
static NSString * const kDomain = @"com.chatgpt.coldwhite";
static void CWApply(void){
 NSUserDefaults *d=[[NSUserDefaults alloc] initWithSuiteName:kDomain];
 BOOL en=[d objectForKey:@"Enabled"]?[d boolForKey:@"Enabled"]:YES;
 NSInteger v=[d objectForKey:@"Temperature"]?[d integerForKey:@"Temperature"]:0; v=MAX(0,MIN(100,v));
 CFStringRef app=CFSTR("com.apple.Accessibility");
 CFPreferencesSetAppValue(CFSTR("ColorFilterEnabled"),en&&v>0?kCFBooleanTrue:kCFBooleanFalse,app);
 CFPreferencesSetAppValue(CFSTR("ColorFilterType"),(__bridge CFPropertyListRef)@(4),app);
 CFPreferencesSetAppValue(CFSTR("ColorFilterIntensity"),(__bridge CFPropertyListRef)@(v),app);
 CFPreferencesSetAppValue(CFSTR("ColorFilterHue"),(__bridge CFPropertyListRef)@(205.0),app);
 CFPreferencesAppSynchronize(app);
 CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.apple.accessibility.cache.changed"),NULL,NULL,true);
 CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.apple.accessibility.settings.changed"),NULL,NULL,true);
}
static void CWNotify(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef ui){ dispatch_async(dispatch_get_main_queue(),^{CWApply();}); }
%ctor {
 CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,CWNotify,CFSTR("com.chatgpt.coldwhite/reload"),NULL,CFNotificationSuspensionBehaviorCoalesce);
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{CWApply();});
}
