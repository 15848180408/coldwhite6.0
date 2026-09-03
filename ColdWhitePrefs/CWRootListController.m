#import "CWRootListController.h"
#import <CoreFoundation/CoreFoundation.h>
static NSString * const kDomain=@"com.chatgpt.coldwhite";
@interface CWRootListController:PSListController @end
@implementation CWRootListController
- (id)specifiers { if(!_specifiers){ NSMutableArray *a=[NSMutableArray array]; PSSpecifier *e=[PSSpecifier preferenceSpecifierNamed:@"启用冷白" target:self set:@selector(setEnabled:specifier:) get:@selector(getEnabled:) detail:nil cell:6 edit:nil]; [e.properties setObject:@"Enabled" forKey:@"key"]; [e.properties setObject:kDomain forKey:@"defaults"]; [a addObject:e]; PSSpecifier *s=[PSSpecifier preferenceSpecifierNamed:@"冷白强度" target:self set:@selector(setTemperature:specifier:) get:@selector(getTemperature:) detail:nil cell:5 edit:nil]; [s.properties setObject:@"Temperature" forKey:@"key"]; [s.properties setObject:kDomain forKey:@"defaults"]; [s.properties setObject:@0 forKey:@"min"]; [s.properties setObject:@100 forKey:@"max"]; [s.properties setObject:@YES forKey:@"showValue"]; [a addObject:s]; PSSpecifier *n=[PSSpecifier preferenceSpecifierNamed:@"0 = 原厂，数值越高越冷" target:nil set:nil get:nil detail:nil cell:13 edit:nil]; [a addObject:n]; PSSpecifier *r=[PSSpecifier preferenceSpecifierNamed:@"恢复原厂" target:self set:@selector(reset:) get:nil detail:nil cell:13 edit:nil]; [a addObject:r]; _specifiers=[a copy]; } return _specifiers; }
- (NSUserDefaults*)defaults{return [[NSUserDefaults alloc]initWithSuiteName:kDomain];}
- (NSNumber*)getEnabled:(PSSpecifier*)s{NSUserDefaults*d=[self defaults];return @([d objectForKey:@"Enabled"]?[d boolForKey:@"Enabled"]:YES);}
- (void)setEnabled:(NSNumber*)v specifier:(PSSpecifier*)s{NSUserDefaults*d=[self defaults];[d setBool:v.boolValue forKey:@"Enabled"];[d synchronize];[self notify];}
- (NSNumber*)getTemperature:(PSSpecifier*)s{NSUserDefaults*d=[self defaults];return @([d objectForKey:@"Temperature"]?[d integerForKey:@"Temperature"]:0);}
- (void)setTemperature:(NSNumber*)v specifier:(PSSpecifier*)s{NSUserDefaults*d=[self defaults];[d setInteger:MAX(0,MIN(100,v.integerValue)) forKey:@"Temperature"];[d synchronize];[self notify];}
- (void)reset:(PSSpecifier*)s{NSUserDefaults*d=[self defaults];[d setBool:NO forKey:@"Enabled"];[d setInteger:0 forKey:@"Temperature"];[d synchronize];[self notify];}
- (void)notify{CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.chatgpt.coldwhite/reload"),NULL,NULL,true);}
@end
