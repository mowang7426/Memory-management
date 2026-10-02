#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdatomic.h>
#import <unistd.h>

static CFStringRef const MMDomain = CFSTR("com.mowang.memorymanagement");
static _Atomic(bool) MMHasBeenActive = false;
static _Atomic(bool) MMTerminationScheduled = false;

static id MMPreference(CFStringRef key) {
    CFPreferencesAppSynchronize(MMDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, MMDomain);
    return value ? CFBridgingRelease(value) : nil;
}

static BOOL MMIsManagedBundle(NSString *bundleID) {
    if (!bundleID.length || [bundleID hasPrefix:@"com.apple."]) return NO;
    NSNumber *enabled = MMPreference(CFSTR("enabled"));
    if (![enabled isKindOfClass:NSNumber.class] || !enabled.boolValue) return NO;
    NSArray *managed = MMPreference(CFSTR("managedBundles"));
    return [managed isKindOfClass:NSArray.class] && [managed containsObject:bundleID];
}

static void MMRecordEvent(NSString *bundleID, NSString *result) {
    if (!bundleID.length || !result.length) return;
    NSDictionary *event = @{ @"bundle": bundleID,
                             @"result": result,
                             @"time": @([[NSDate date] timeIntervalSince1970]) };
    CFPreferencesAppSynchronize(MMDomain);
    CFPropertyListRef existingValue = CFPreferencesCopyAppValue(CFSTR("eventLog"), MMDomain);
    NSArray *existing = existingValue ? CFBridgingRelease(existingValue) : nil;
    NSMutableArray *events = [NSMutableArray arrayWithObject:event];
    if ([existing isKindOfClass:NSArray.class]) {
        NSUInteger keep = MIN(existing.count, 99);
        if (keep) [events addObjectsFromArray:[existing subarrayWithRange:NSMakeRange(0, keep)]];
    }
    CFPreferencesSetAppValue(CFSTR("lastEvent"), (__bridge CFDictionaryRef)event, MMDomain);
    CFPreferencesSetAppValue(CFSTR("eventLog"), (__bridge CFArrayRef)events, MMDomain);
    CFPreferencesAppSynchronize(MMDomain);
}

static void MMCancelTermination(void) {
    atomic_store(&MMHasBeenActive, true);
    atomic_store(&MMTerminationScheduled, false);
}

static void MMScheduleBackgroundLaunchCheck(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (!MMIsManagedBundle(bundleID) || atomic_load(&MMHasBeenActive)) return;
    bool expected = false;
    if (!atomic_compare_exchange_strong(&MMTerminationScheduled, &expected, true)) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        atomic_store(&MMTerminationScheduled, false);
        if (atomic_load(&MMHasBeenActive)) return;
        UIApplication *application = UIApplication.sharedApplication;
        if (application.applicationState != UIApplicationStateBackground) return;
        if (!MMIsManagedBundle(bundleID)) return;
        MMRecordEvent(bundleID, @"已阻止后台冷启动");
        NSLog(@"[MemoryManagement] terminating selected background-only launch: %@", bundleID);
        _exit(0);
    });
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        if (!bundleID.length || [bundleID hasPrefix:@"com.apple."] ||
            [bundleID isEqualToString:@"com.apple.springboard"] ||
            !NSClassFromString(@"UIApplication")) return;

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            MMCancelTermination();
            if (MMIsManagedBundle(bundleID)) MMRecordEvent(bundleID, @"用户前台启动，已放行");
        }];
        [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            MMScheduleBackgroundLaunchCheck();
        }];
        [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            UIApplication *application = UIApplication.sharedApplication;
            if (application.applicationState == UIApplicationStateActive) MMCancelTermination();
            else MMScheduleBackgroundLaunchCheck();
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIApplication *application = UIApplication.sharedApplication;
            if (application.applicationState == UIApplicationStateActive) MMCancelTermination();
            else MMScheduleBackgroundLaunchCheck();
        });
    }
}
