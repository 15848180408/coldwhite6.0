#import <UIKit/UIKit.h>

@interface PSListController : UITableViewController {
    NSMutableArray *_specifiers;
}
- (id)specifiers;
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
@end

@interface PSSpecifier : NSObject
@property (nonatomic, retain) NSMutableDictionary *properties;
@end

@interface CWRootListController : PSListController
@end
