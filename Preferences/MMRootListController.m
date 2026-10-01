#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface MMRootListController : PSListController
@end

@implementation MMRootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];
        PSSpecifier *intro = [PSSpecifier preferenceSpecifierNamed:@"第一版开发中"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [intro setProperty:@"当前版本仅安装设置入口和安全框架；尚未启用任何后台启动拦截。" forKey:@"footerText"];
        [items addObject:intro];

        PSSpecifier *scope = [PSSpecifier preferenceSpecifierNamed:@"设计目标"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [scope setProperty:@"后续仅管理用户选择的第三方 App。用户主动打开必须放行；无法确认启动来源时默认放行。" forKey:@"footerText"];
        [items addObject:scope];

        PSSpecifier *safety = [PSSpecifier preferenceSpecifierNamed:@"系统保护"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [safety setProperty:@"不会限制 SpringBoard、backboardd、kernel_task 或系统关键服务，也不修改 Jetsam 策略。" forKey:@"footerText"];
        [items addObject:safety];

        PSSpecifier *note = [PSSpecifier preferenceSpecifierNamed:@"注意"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [note setProperty:@"iOS 不提供通用的每 App 自启动开关。拦截能力需按 iOS 版本验证，不能承诺长期保留固定空闲内存。" forKey:@"footerText"];
        [items addObject:note];
        _specifiers = [items copy];
    }
    return _specifiers;
}
@end
