#import <Foundation/Foundation.h>
#import <math.h>

static inline NSArray<NSString *> *MMValidBundles(id raw) {
    NSMutableOrderedSet *items = [NSMutableOrderedSet orderedSet];
    if ([raw isKindOfClass:NSArray.class]) for (id item in raw) {
        if ([item isKindOfClass:NSString.class] && [item length] && ![item hasPrefix:@"com.apple."]) [items addObject:item];
    }
    return items.array;
}
static inline NSDictionary *MMValidEvent(id raw) {
    if (![raw isKindOfClass:NSDictionary.class]) return nil;
    id bundle=raw[@"bundle"], result=raw[@"result"], time=raw[@"time"];
    if (![bundle isKindOfClass:NSString.class] || ![result isKindOfClass:NSString.class] ||
        ![time isKindOfClass:NSNumber.class] || !isfinite([time doubleValue]) ||
        [time doubleValue] < 0 || [time doubleValue] > 4102444800.0) return nil;
    return @{@"bundle":bundle, @"result":result, @"time":time};
}
static inline NSArray<NSDictionary *> *MMValidEvents(id raw) {
    NSMutableArray *events=[NSMutableArray array];
    if ([raw isKindOfClass:NSArray.class]) for (id item in raw) {
        NSDictionary *event=MMValidEvent(item);
        if (event) [events addObject:event];
        if (events.count==100) break;
    }
    return events;
}
