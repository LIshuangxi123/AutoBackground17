#import "AutoBGConfig.h"

static NSString *const AutoBGPrefsDomain = @"com.autobg.autobackground17";

static id AutoBGPrefsValue(NSString *key, id fallback) {
    CFTypeRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)AutoBGPrefsDomain);
    if (!value) {
        return fallback;
    }
    return (__bridge_transfer id)value;
}

@implementation AutoBGConfig

+ (instancetype)shared {
    static AutoBGConfig *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AutoBGConfig alloc] init];
    });
    return shared;
}

- (BOOL)enabled {
    return [AutoBGPrefsValue(@"Enabled", @YES) boolValue];
}

- (BOOL)keepAllApps {
    return [AutoBGPrefsValue(@"KeepAllApps", @YES) boolValue];
}

- (BOOL)audioFallback {
    return [AutoBGPrefsValue(@"AudioFallback", @NO) boolValue];
}

- (BOOL)preventManualKill {
    return [AutoBGPrefsValue(@"PreventManualKill", @NO) boolValue];
}

- (BOOL)shouldKeepAliveBundle:(NSString *)bundleID {
    if (!self.enabled || bundleID.length == 0) {
        return NO;
    }

    id rawOverrides = AutoBGPrefsValue(@"AppOverrides", @{});
    NSDictionary *overrides = [rawOverrides isKindOfClass:[NSDictionary class]] ? rawOverrides : @{};
    NSNumber *override = overrides[bundleID];
    if (override) {
        return [override boolValue];
    }

    return self.keepAllApps;
}

@end