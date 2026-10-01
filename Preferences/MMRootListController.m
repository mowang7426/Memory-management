#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

static CFStringRef const MMDomain = CFSTR("com.mowang.memorymanagement");
static NSString *MMPreferenceString(CFStringRef key, NSString *fallback) {
    CFPreferencesAppSynchronize(MMDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, MMDomain);
    if (!value) return fallback;
    id object = CFBridgingRelease(value);
    return [object isKindOfClass:NSString.class] ? object : fallback;
}

@interface MMRootListController : PSListController
@end

@implementation MMRootListController
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSString *status = MMPreferenceString(CFSTR("runtimeProbeStatus"), @"等待 SpringBoard 探测；如刚安装，请重载 SpringBoard 后返回此页。未显示“已运行”不代表拦截功能可用。 ");
        NSString *summary = MMPreferenceString(CFSTR("runtimeProbeSummary"), @"尚无运行时结果。该探测不会更改系统行为，也不会阻止任何 App 启动。");
        if (summary.length > 6500) summary = [[summary substringToIndex:6500] stringByAppendingString:@"\n\n（结果过长，已截断）"];

        NSMutableArray *items = [NSMutableArray array];
        PSSpecifier *state = [PSSpecifier preferenceSpecifierNamed:@"iOS 17.0 只读观察状态"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [state setProperty:status forKey:@"footerText"];
        [items addObject:state];

        PSSpecifier *results = [PSSpecifier preferenceSpecifierNamed:@"候选启动相关方法（设备侧枚举）"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [results setProperty:summary forKey:@"footerText"];
        [items addObject:results];

        PSSpecifier *boundary = [PSSpecifier preferenceSpecifierNamed:@"当前能力边界"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [boundary setProperty:@"目前只在 SpringBoard 进程中枚举运行时方法名与类型编码，结果直接显示于此页；没有方法 Hook、启动来源判定或拦截逻辑。请不要据此认为后台自启动已被限制。" forKey:@"footerText"];
        [items addObject:boundary];

        PSSpecifier *safety = [PSSpecifier preferenceSpecifierNamed:@"安全策略"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [safety setProperty:@"不修改 SpringBoard 启动流程，不限制系统服务，不改变 Jetsam。后续实现必须对用户主动启动放行；来源未知时 fail-open。" forKey:@"footerText"];
        [items addObject:safety];
        _specifiers = [items copy];
    }
    return _specifiers;
}
@end
