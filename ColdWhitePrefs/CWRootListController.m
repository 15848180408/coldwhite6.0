#import "CWRootListController.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString * const kDomain = @"com.chatgpt.coldwhite";

@implementation CWRootListController

- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kDomain];
}

- (NSNumber *)getEnabled:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    return @([d objectForKey:@"Enabled"] ? [d boolForKey:@"Enabled"] : YES);
}

- (void)setEnabled:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setBool:value.boolValue forKey:@"Enabled"];
    [d synchronize];
    [self notify];
}

- (NSNumber *)getTemperature:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    return @([d objectForKey:@"Temperature"] ? [d integerForKey:@"Temperature"] : 0);
}

- (void)setTemperature:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setInteger:MAX(0, MIN(100, value.integerValue)) forKey:@"Temperature"];
    [d synchronize];
    [self notify];
}

- (void)reset:(PSSpecifier *)specifier {
    NSUserDefaults *d = [self defaults];
    [d setBool:NO forKey:@"Enabled"];
    [d setInteger:0 forKey:@"Temperature"];
    [d synchronize];
    [self notify];
    [self reloadSpecifiers];
}

- (void)notify {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.chatgpt.coldwhite/reload"),
        NULL, NULL, true
    );
}

@end
