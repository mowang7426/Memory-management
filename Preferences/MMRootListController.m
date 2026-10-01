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
        [intro setProperty:@"当前版本为 iOS 17.0 只读运行时探针：只枚举候选类的方法签名并写入诊断文件；不 Hook 方法、不修改启动请求、不拦截 App。" forKey:@"footerText"];
        [items addObject:intro];

        PSSpecifier *path = [PSSpecifier preferenceSpecifierNamed:@"诊断文件"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [path setProperty:@"SpringBoard 加载插件后生成：/var/mobile/Library/Logs/MemoryManagement/RuntimeProbe.txt。文件仅含系统版本、进程名、候选类方法名与 Objective-C 类型编码。" forKey:@"footerText"];
        [items addObject:path];

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
