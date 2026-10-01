#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static NSString *const MMProbePath = @"/var/mobile/Library/Logs/MemoryManagement/RuntimeProbe.txt";

static void MMAppendClassMethods(NSMutableString *out, NSString *className) {
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) {
        [out appendFormat:@"\n[%@] unavailable\n", className];
        return;
    }
    [out appendFormat:@"\n[%@] class=%p\n", className, cls];
    unsigned depth = 0;
    for (Class current = cls; current && current != [NSObject class] && depth < 8; current = class_getSuperclass(current), depth++) {
        unsigned count = 0;
        Method *methods = class_copyMethodList(current, &count);
        [out appendFormat:@"  -- %@ (%u methods) --\n", NSStringFromClass(current), count];
        for (unsigned i = 0; i < count; i++) {
            SEL sel = method_getName(methods[i]);
            const char *encoding = method_getTypeEncoding(methods[i]);
            [out appendFormat:@"  %@ %s\n", NSStringFromSelector(sel), encoding ?: "?"];
        }
        free(methods);
    }
}

static void MMRunRuntimeProbe(void) {
    @autoreleasepool {
        NSMutableString *report = [NSMutableString stringWithFormat:
            @"MemoryManagement iOS 17.0 runtime probe\nOS: %@\nProcess: %@\nThis diagnostic is read-only: no methods are hooked and no launch requests are changed.\n",
            NSProcessInfo.processInfo.operatingSystemVersionString,
            NSProcessInfo.processInfo.processName];
        NSArray<NSString *> *names = @[
            @"SBMainWorkspace", @"SBIconController", @"SBIconManager",
            @"SBIconView", @"SBWorkspaceTransitionRequest", @"FBSSystemService"
        ];
        for (NSString *name in names) MMAppendClassMethods(report, name);

        NSError *error = nil;
        NSString *directory = [MMProbePath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                  withIntermediateDirectories:YES attributes:nil error:&error];
        if (!error && [report writeToFile:MMProbePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            NSLog(@"[MemoryManagement] Read-only runtime probe saved: %@", MMProbePath);
        } else {
            NSLog(@"[MemoryManagement] Runtime probe write failed: %@", error.localizedDescription ?: @"unknown error");
        }
    }
}

%ctor {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try { MMRunRuntimeProbe(); }
        @catch (NSException *exception) {
            NSLog(@"[MemoryManagement] Runtime probe exception: %@", exception.reason ?: @"unknown");
        }
    });
}
