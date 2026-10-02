#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

static CFStringRef const MMDomain = CFSTR("com.mowang.memorymanagement");
static CFStringRef const MMChanged = CFSTR("com.mowang.memorymanagement/changed");

static id MMRead(CFStringRef key) {
    CFPreferencesAppSynchronize(MMDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, MMDomain);
    return value ? CFBridgingRelease(value) : nil;
}
static void MMWrite(CFStringRef key, id value) {
    CFPreferencesSetAppValue(key, value ? (__bridge CFPropertyListRef)value : NULL, MMDomain);
    CFPreferencesAppSynchronize(MMDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), MMChanged, NULL, NULL, true);
}

@interface MMAppsController : UITableViewController
@property(nonatomic,strong) NSArray<NSDictionary *> *apps;
@property(nonatomic,strong) NSMutableSet<NSString *> *selected;
@end

@implementation MMAppsController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择要限制的 App";
    NSArray *stored = MMRead(CFSTR("managedBundles"));
    self.selected = [NSMutableSet setWithArray:[stored isKindOfClass:NSArray.class] ? stored : @[]];
    [self loadApplications];
}
- (void)loadApplications {
    NSMutableArray *rows = [NSMutableArray array];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    SEL allSelector = NSSelectorFromString(@"allApplications");
    id workspace = workspaceClass && [workspaceClass respondsToSelector:defaultSelector]
        ? ((id(*)(id,SEL))objc_msgSend)(workspaceClass, defaultSelector) : nil;
    NSArray *proxies = workspace && [workspace respondsToSelector:allSelector]
        ? ((id(*)(id,SEL))objc_msgSend)(workspace, allSelector) : @[];
    for (id proxy in proxies) {
        NSString *bundle = nil, *name = nil, *type = nil;
        @try {
            bundle = [proxy valueForKey:@"applicationIdentifier"];
            name = [proxy valueForKey:@"localizedName"];
            type = [proxy valueForKey:@"applicationType"];
        } @catch (__unused NSException *exception) {}
        if (!bundle.length || [bundle hasPrefix:@"com.apple."]) continue;
        if (type.length && ![type isEqualToString:@"User"] && ![type isEqualToString:@"System"] ) continue;
        [rows addObject:@{ @"name": name.length ? name : bundle, @"bundle": bundle }];
    }
    [rows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    self.apps = rows;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.apps.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"勾选后，仅当 App 冷启动后 5 秒内始终没有进入前台时才自动退出。推送、后台刷新、定位或 VoIP 可能受影响。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"MMApp";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary *app = self.apps[indexPath.row];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text = app[@"bundle"];
    cell.accessoryType = [self.selected containsObject:app[@"bundle"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *bundle = self.apps[indexPath.row][@"bundle"];
    if ([self.selected containsObject:bundle]) [self.selected removeObject:bundle]; else [self.selected addObject:bundle];
    NSArray *saved = [[self.selected allObjects] sortedArrayUsingSelector:@selector(compare:)];
    MMWrite(CFSTR("managedBundles"), saved);
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}
@end

@interface MMRootListController : PSListController
@end
@implementation MMRootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];
        PSSpecifier *intro = [PSSpecifier preferenceSpecifierNamed:@"后台冷启动限制"
            target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [intro setProperty:@"直接功能版：限制用户选择的第三方 App。用户主动打开正常放行；App 未进入前台且持续处于后台 5 秒时自动退出。" forKey:@"footerText"];
        [items addObject:intro];

        PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"启用后台冷启动限制" target:self
            set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enabled setProperty:@"enabled" forKey:@"key"];
        [enabled setProperty:@NO forKey:@"default"];
        [enabled setProperty:@"com.mowang.memorymanagement" forKey:@"defaults"];
        [items addObject:enabled];

        PSSpecifier *apps = [PSSpecifier preferenceSpecifierNamed:@"选择第三方 App" target:self set:nil get:nil
            detail:MMAppsController.class cell:PSLinkCell edit:nil];
        [items addObject:apps];

        NSDictionary *event = MMRead(CFSTR("lastEvent"));
        NSString *eventText = @"暂无事件。";
        if ([event isKindOfClass:NSDictionary.class]) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[event[@"time"] doubleValue]];
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; formatter.dateFormat = @"MM-dd HH:mm:ss";
            eventText = [NSString stringWithFormat:@"%@ · %@ · %@", [formatter stringFromDate:date], event[@"bundle"] ?: @"?", event[@"result"] ?: @"?"];
        }
        PSSpecifier *last = [PSSpecifier preferenceSpecifierNamed:@"最近事件" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [last setProperty:eventText forKey:@"footerText"];
        [items addObject:last];

        PSSpecifier *warning = [PSSpecifier preferenceSpecifierNamed:@"重要影响" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [warning setProperty:@"被选 App 的后台推送处理、后台刷新、定位、音频或 VoIP 任务可能失败。普通通知是否显示由系统推送服务决定，但依赖 App 后台执行的功能会受影响。不要选择支付、电话、信息、身份验证或系统关键 App。" forKey:@"footerText"];
        [items addObject:warning];
        _specifiers = [items copy];
    }
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    id value = MMRead((__bridge CFStringRef)[specifier propertyForKey:@"key"]);
    return value ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    MMWrite((__bridge CFStringRef)[specifier propertyForKey:@"key"], value);
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; _specifiers=nil; [self reloadSpecifiers]; }
@end
