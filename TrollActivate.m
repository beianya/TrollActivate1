// TrollActivate.m
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *g_current_udid = nil;
#define FORGED_ENDTIME @"9999999999"

static IMP g_orig_ACPDS_kaiv = NULL;
static IMP g_orig_ACPDS_kiv = NULL;

static BOOL isUdidKey(NSString *key) {
    return [key isEqualToString:@"ICmCIVMIKNQfFXuT"];
}

static BOOL looksLikeUdid(NSString *s) {
    if (!s || s.length < 30 || s.length > 60) return NO;
    NSRange r = [s rangeOfString:@"-"];
    if (r.location != 32) return NO;
    return YES;
}

static id processResult(NSString *key, id result) {
    if (!result || ![result isKindOfClass:[NSString class]]) return result;
    NSString *pt = (NSString *)result;

    if (isUdidKey(key) && looksLikeUdid(pt)) {
        g_current_udid = [pt copy];
        NSLog(@"[TrollActivate] Captured device udid: %@", g_current_udid);
        return pt;
    }

    if ([pt rangeOfString:@"\"endtime\":"].location != NSNotFound &&
        [pt rangeOfString:@"\"udid\":"].location != NSNotFound) {
        NSError *err = nil;
        NSString *modified = pt;

        NSRegularExpression *reEnd = [NSRegularExpression
            regularExpressionWithPattern:@"\"endtime\":\"?\\d+\"?"
            options:0 error:&err];
        if (reEnd) {
            modified = [reEnd stringByReplacingMatchesInString:modified
                options:0 range:NSMakeRange(0, modified.length)
                withTemplate:[NSString stringWithFormat:@"\"endtime\":\"%@\"", FORGED_ENDTIME]];
        }

        if (g_current_udid) {
            NSRegularExpression *reUdid = [NSRegularExpression
                regularExpressionWithPattern:@"\"udid\":\"[^\"]+\""
                options:0 error:&err];
            if (reUdid) {
                modified = [reUdid stringByReplacingMatchesInString:modified
                    options:0 range:NSMakeRange(0, modified.length)
                    withTemplate:[NSString stringWithFormat:@"\"udid\":\"%@\"", g_current_udid]];
            }
        }

        NSRegularExpression *reState = [NSRegularExpression
            regularExpressionWithPattern:@"\"state\":\"[^\"]*\""
            options:0 error:&err];
        if (reState) {
            modified = [reState stringByReplacingMatchesInString:modified
                options:0 range:NSMakeRange(0, modified.length)
                withTemplate:@"\"state\":\"\\u6b63\\u5e38\""];
        }

        NSLog(@"[TrollActivate] Rewrote JSON");
        return modified;
    }

    return result;
}

static id new_ACPDS_kaiv(id self, SEL _cmd, id ct, id key) {
    id result = ((id (*)(id, SEL, id, id))g_orig_ACPDS_kaiv)(self, _cmd, ct, key);
    NSString *keyStr = (key && [key isKindOfClass:[NSString class]]) ? (NSString *)key : @"";
    return processResult(keyStr, result);
}

static id new_ACPDS_kiv(id self, SEL _cmd, id ct, id key, id iv) {
    id result = ((id (*)(id, SEL, id, id, id))g_orig_ACPDS_kiv)(self, _cmd, ct, key, iv);
    NSString *keyStr = (key && [key isKindOfClass:[NSString class]]) ? (NSString *)key : @"";
    return processResult(keyStr, result);
}

static IMP g_orig_UD_setObject = NULL;
static void new_UD_setObject(id self, SEL _cmd, id value, NSString *key) {
    if ([key isKindOfClass:[NSString class]] &&
        [key isEqualToString:@"tz0111endtime"] &&
        value && [value isKindOfClass:[NSString class]]) {
        value = @"2099-12-31 23:59:59";
        NSLog(@"[TrollActivate] Forced tz0111endtime");
    }
    ((void (*)(id, SEL, id, id))g_orig_UD_setObject)(self, _cmd, value, key);
}

__attribute__((constructor))
static void TrollActivateInit(void) {
    NSLog(@"[TrollActivate] loading...");

    SEL sel1 = sel_registerName("ACPDS:kaiv:");
    Method m1 = class_getClassMethod([NSString class], sel1);
    if (m1) {
        g_orig_ACPDS_kaiv = method_getImplementation(m1);
        method_setImplementation(m1, (IMP)new_ACPDS_kaiv);
        NSLog(@"[TrollActivate] hooked ACPDS:kaiv:");
    }

    SEL sel2 = sel_registerName("ACPDS:key:iv:");
    Method m2 = class_getClassMethod([NSString class], sel2);
    if (m2) {
        g_orig_ACPDS_kiv = method_getImplementation(m2);
        method_setImplementation(m2, (IMP)new_ACPDS_kiv);
        NSLog(@"[TrollActivate] hooked ACPDS:key:iv:");
    }

    Method udm = class_getInstanceMethod([NSUserDefaults class], @selector(setObject:forKey:));
    if (udm) {
        g_orig_UD_setObject = method_getImplementation(udm);
        method_setImplementation(udm, (IMP)new_UD_setObject);
        NSLog(@"[TrollActivate] hooked UD.setObject");
    }

    NSLog(@"[TrollActivate] init done");
}
