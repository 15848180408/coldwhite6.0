#import <UIKit/UIKit.h>
@interface PSListController : UITableViewController { NSMutableArray *_specifiers; } - (id)specifiers; @end
@interface PSSpecifier : NSObject + (instancetype)preferenceSpecifierNamed:(NSString*)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cellType edit:(id)edit; @property(nonatomic,retain) NSMutableDictionary *properties; @end
