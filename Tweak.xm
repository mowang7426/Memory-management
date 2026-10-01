#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static CFStringRef const MMDomain = CFSTR("com.mowang.memorymanagement");
static CFStringRef const MMProbeKey = CFSTR("runtimeProbeSummary");
static CFStringRef const MMStatusKey = CFSTR("runtimeProbeStatus");

static BOOL MMSelectorLooksRelevant(NSString *name) {
    NSString *s = name.lowercaseString;
    NSArray *terms = @[@"launch", @"openapplication", @"activate", @"workspace", @"icon", @"application"];
    for (NSString *term in terms) if ([s containsString:term]) return YES;
    return NO;
}

static NSString *MMInspectClass(NSString *className) {
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) return [NSString stringWithFormat:@"%@：当前进程中不存在", className];
    NSMutableArray *matches = [NSMutableArray array];
    for (Class current = cls; current && current != [NSObject class]; current = class_getSuperclass(current)) {
        unsigned count = 0;
        Method *methods = class_copyMethodList(current, &count);
        for (unsigned i = 0; i < count; i++) {
            NSString *selector = NSStringFromSelector(method_getName(methods[i]));
            if (!MMSelectorLooksRelevant(selector)) continue;
            const char *encoding = method_getTypeEncoding(methods[i]);
            [matches addObject:[NSString stringWithFormat:@"%@ · %@ · %s", NSStringFromClass(current), selector, encoding ?: "?"]];
        }
        free(methods);
    }
    if (!matches.count) return [NSString stringWithFormat:@"%@：未发现匹配方法", className];
    return [NSString stringWithFormat:@"%@（%lu）\n%@", className, (unsigned long)matches.count,
            [[matches subarrayWithRange:NSMakeRange(0, MIN(matches.count, 80))] componentsJoinedByString:@"\n"]];
}

static void MMRunReadOnlyProbe(void) {
    @autoreleasepool {
        NSString *process = NSProcessInfo.processInfo.processName ?: @"unknown";
        NSString *os = NSProcessInfo.processInfo.operatingSystemVersionString ?: @"unknown";
        NSMutableArray *sections = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"只读探测 · %@ · %@", process, os]];
        NSArray *classes = @[@"SBMainWorkspace", @"SBIconController", @"SBIconManager", @"SBIconView", @"SBWorkspaceTransitionRequest", @"FBSSystemService"];
        for (NSString *name in classes) [sections addObject:MMInspectClass(name)];
        NSString *summary = [sections componentsJoinedByString:@"\n\n"];
        CFPreferencesSetAppValue(MMProbeKey, (__bridge CFStringRef)summary, MMDomain);
        CFPreferencesSetAppValue(MMStatusKey, CFSTR("已运行：只读枚举；没有 Hook 或拦截"), MMDomain);
        CFPreferencesAppSynchronize(MMDomain);
        NSLog(@"[MemoryManagement] Read-only runtime inspection finished for %@", process);
    }
}

%ctor {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try { MMRunReadOnlyProbe(); }
        @catch (NSException *exception) {
            CFPreferencesSetAppValue(MMStatusKey, (__bridge CFStringRef)[NSString stringWithFormat:@"探测异常：%@", exception.reason ?: @"unknown"], MMDomain);
            CFPreferencesAppSynchronize(MMDomain);
            NSLog(@"[MemoryManagement] Runtime inspection exception: %@", exception.reason ?: @"unknown");
        }
    });
}
