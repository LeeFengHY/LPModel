//
//  NSObject+LLModel.m
//  LPModel
//
//  Created by QFWangLP on 2016/11/8.
//  Copyright © 2016年 LeeFengHY. All rights reserved.
//

#import "NSObject+LLModel.h"
#import "LLClassInfo.h"
#import <objc/message.h>

//内联函数,提升效率
#define force_inline __inline__ __attribute__((always_inline))

//Foundation class type
typedef NS_ENUM(NSUInteger, LLEncodingNSType) {
    LLEncodingNSTypeNSUnknow = 0,
    LLEncodingNSTypeNSString,
    LLEncodingNSTypeNSMutableString,
    LLEncodingNSTypeNSValue,
    LLEncodingNSTypeNSNumber,
    LLEncodingNSTypeNSDecimalNumber,
    LLEncodingNSTypeNSData,
    LLEncodingNSTypeNSMutableData,
    LLEncodingNSTypeNSDate,
    LLEncodingNSTypeNSURL,
    LLEncodingNSTypeNSArray,
    LLEncodingNSTypeNSMutableArray,
    LLEncodingNSTypeNSDictionary,
    LLEncodingNSTypeNSMutableDictionary,
    LLEncodingNSTypeNSSet,
    LLEncodingNSTypeNSMutableSet,
};
// Get the Foundation class type from property info.
static force_inline LLEncodingNSType LLClassGetNSType(Class cls) {
    if (!cls) return LLEncodingNSTypeNSUnknow;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return LLEncodingNSTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return LLEncodingNSTypeNSString;
    if ([cls isSubclassOfClass:[NSValue class]]) return LLEncodingNSTypeNSValue;
    if ([cls isSubclassOfClass:[NSNumber class]]) return LLEncodingNSTypeNSNumber;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return LLEncodingNSTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSData class]]) return LLEncodingNSTypeNSData;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return LLEncodingNSTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSDate class]]) return LLEncodingNSTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return LLEncodingNSTypeNSURL;
    if ([cls isSubclassOfClass:[NSArray class]]) return LLEncodingNSTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return LLEncodingNSTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return LLEncodingNSTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return LLEncodingNSTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSSet class]]) return LLEncodingNSTypeNSSet;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return LLEncodingNSTypeNSMutableSet;
    return LLEncodingNSTypeNSUnknow;
}
static force_inline BOOL LLEncodingTypeIsCNumber(LLEncodingType type) {
    switch (type & LLEncodingTypeMask) {
        case LLEncodingTypeBool:
        case LLEncodingTypeInt8:
        case LLEncodingTypeInt16:
        case LLEncodingTypeUInt16:
        case LLEncodingTypeInt32:
        case LLEncodingTypeUInt32:
        case LLEncodingTypeInt64:
        case LLEncodingTypeUInt64:
        case LLEncodingTypeFloat:
        case LLEncodingTypeDouble:
        case LLEncodingTypeLongDouble:
            return YES;
        default:
            return NO;
    }
}
// Parse a number value from 'id'.
static force_inline NSNumber *LLNSNumberCreateFromID(__unsafe_unretained id value) {
    static NSCharacterSet *dot;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        
        dic = @{@"TRUE" :    @(YES),
                           @"True" :  @(YES),
                           @"true" :  @(YES),
                           @"FALSE" : @(NO),
                           @"False" : @(NO),
                           @"false" : @(NO),
                           @"YES" :   @(YES),
                           @"Yes" :   @(YES),
                           @"yes" :   @(YES),
                           @"NO" :    @(NO),
                           @"No" :    @(NO),
                           @"no" :    @(NO),
                           @"NIL" : (id)kCFNull,
                           @"Nil" : (id)kCFNull,
                           @"nil" : (id)kCFNull,
                           @"NULL" : (id)kCFNull,
                           @"Null" : (id)kCFNull,
                           @"null" : (id)kCFNull,
                           @"(NULL)" : (id)kCFNull,
                           @"(Null)" : (id)kCFNull,
                           @"(null)" : (id)kCFNull,
                           @"<NULL>" : (id)kCFNull,
                           @"<Null>" : (id)kCFNull,
                           @"<null>" : (id)kCFNull
                         };
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSNumber *num = dic[value];
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            double num = atof(cstring);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }else {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            return @(atoll(cstring));
        }
    }
    return nil;
}
// Parse string to date
static force_inline NSDate * LLNSDateFromString(__unsafe_unretained NSString *string) {
    typedef NSDate * (^LLNSDateParseBlock)(NSString *string);
    #define kParseNum 34
    static LLNSDateParseBlock blocks[kParseNum + 1] = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
    
            /*
             2014-01-20  // Google
             */
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = @"yyyy-MM-dd";
            blocks[10] = ^(NSString *string) {
                return [formatter dateFromString:string];
            };

        }
        {
            /*
             2014-01-20 12:24:48
             2014-01-20T12:24:48   // Google
             2014-01-20 12:24:48.000
             2014-01-20T12:24:48.000
             */
            NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
            formatter1.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter1.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
            NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter2.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            
            NSDateFormatter *formatter3 = [[NSDateFormatter alloc] init];
            formatter3.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter3.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter3.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
            
            NSDateFormatter *formatter4 = [[NSDateFormatter alloc] init];
            formatter4.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter4.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter4.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
            
            blocks[19] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter1 dateFromString:string];
                }else {
                    return [formatter2 dateFromString:string];
                }
            };
            
            blocks[23] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter3 dateFromString:string];
                }else {
                    return [formatter4 dateFromString:string];
                }
            };
        }
        
        {
            /*
             2014-01-20T12:24:48Z        // Github, Apple
             2014-01-20T12:24:48+0800    // Facebook
             2014-01-20T12:24:48+12:00   // Google
             2014-01-20T12:24:48.000Z
             2014-01-20T12:24:48.000+0800
             2014-01-20T12:24:48.000+12:00
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssSSSZ";
            
            blocks[20] = ^(NSString *string) {return [formatter dateFromString:string]; };
            blocks[24] = ^(NSString *string) {return [formatter dateFromString:string]?: [formatter2 dateFromString:string]; };
            blocks[25] = ^(NSString *string) {return [formatter dateFromString:string]; };
            blocks[28] = ^(NSString *string) {return [formatter2 dateFromString:string]; };
            blocks[29] = ^(NSString *string) {return [formatter2 dateFromString:string]; };
        }
        
        {
            /*
             Fri Sep 04 00:12:21 +0800 2015 // Weibo, Twitter
             Fri Sep 04 00:12:21.000 +0800 2015
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";
            
            NSDateFormatter *formatter2 = [NSDateFormatter new];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.dateFormat = @"EEE MMM dd HH:mm:ss.SSS Z yyyy";
            
            blocks[30] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[34] = ^(NSString *string) { return [formatter2 dateFromString:string]; };

        }
    });
    
    if (!string) return nil;
    if (string.length > kParseNum) return nil;
    LLNSDateParseBlock parser = blocks[string.length];
    if (!parser) return nil;
    return parser(string);
}
// Get the 'NSBlock' class.
static force_inline Class LLNSBlockClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = ((NSObject *)block).class;
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls;
}
/**
 Get the ISO date formatter.
 
 ISO8601 format example:
 2010-07-09T16:13:30+12:00
 2011-01-11T11:11:11+0000
 2011-01-26T19:06:43Z
 
 length: 20/24/25
 */
static force_inline NSDateFormatter *LLISODateFormatter() {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}
// Get the value with key paths from dictionary
// The dic should be NSDictionary, and the keyPath should not be nil.
static force_inline id LLValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = nil;
    for (NSUInteger i = 0,max = keyPaths.count; i < max; i++) {
        value = dic[keyPaths[i]];
        if (i + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            }else {
                return nil;
            }
        }
    }
    return value;
}
// Get the value with multi key (or key path) from dictionary
// The dic should be NSDictionary
static force_inline id LLValueForMultikeys(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *multiKeys) {
    id value = nil;
    for (NSString *key in multiKeys) {
        if ([key isKindOfClass:[NSString class]]) {
            value = dic[key];
            if (value) break;
        }else {
            value = LLValueForKeyPath(dic, (NSArray *)key);
            if (value) break;
        }
    }
    return value;
}

@interface _LLModelPropertyMeta : NSObject {
    @package
    NSString *_name;                           //property name
    LLEncodingType _type;                      //property type
    LLEncodingNSType _nsType;
    BOOL _isCNumber;
    Class _cls;
    Class _genericCls;
    SEL _getter;
    SEL _setter;
    BOOL _isKVCCompatible;
    BOOL _isStructAvailableForKeyedArchiver;
    BOOL _hasCustomClassFromDictionary;
    
    NSString *_mappedToKey;
    NSArray *_mappedToKeyPath;
    NSArray  *_mappedToKeyArray;
    LLClassPropertyInfo *_info;
    _LLModelPropertyMeta *_next;
}
@end
@implementation _LLModelPropertyMeta
+ (instancetype)metaWithClassInfo:(LLClassInfo *)classInfo propertyInfo:(LLClassPropertyInfo *)propertyInfo generic:(Class)generic
{
    _LLModelPropertyMeta *meta = [self new];
    meta->_name = propertyInfo.name;
    meta->_type = propertyInfo.type;
    meta->_info = propertyInfo;
    meta->_genericCls = generic;
    
    if ((meta->_type & LLEncodingTypeMask) == LLEncodingTypeObject) {
        meta->_nsType = LLClassGetNSType(propertyInfo.cls);
    }else {
        meta->_isCNumber = LLEncodingTypeIsCNumber(meta->_type);
    }
    
    if ((meta->_type & LLEncodingTypeMask) == LLEncodingTypeStruct) {
        /*
         It seems that NSKeyedUnarchiver cannot decode NSValue except these structs:
         */
        static NSSet *types = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableSet *set = [NSMutableSet new];
            // 32 bit
            [set addObject:@"{CGSize=ff}"];
            [set addObject:@"{CGPoint=ff}"];
            [set addObject:@"{CGRect={CGPoint=ff}{CGSize=ff}}"];
            [set addObject:@"{CGAffineTransform=ffffff}"];
            [set addObject:@"{UIEdgeInsets=ffff}"];
            [set addObject:@"{UIOffset=ff}"];
            // 64 bit
            [set addObject:@"{CGSize=dd}"];
            [set addObject:@"{CGPoint=dd}"];
            [set addObject:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
            [set addObject:@"{CGAffineTransform=dddddd}"];
            [set addObject:@"{UIEdgeInsets=dddd}"];
            [set addObject:@"{UIOffset=dd}"];
            types = set;
        });
        if ([types containsObject:propertyInfo.typeEncoding]) {
            meta->_isStructAvailableForKeyedArchiver = YES;
        }
    }
    
    meta->_cls = propertyInfo.cls;
    
    if (generic) {
        meta->_hasCustomClassFromDictionary = [generic respondsToSelector:@selector(modelCustomClassForDictionary:)];
    } else if (meta->_cls && meta->_nsType == LLEncodingNSTypeNSUnknow) {
        meta->_hasCustomClassFromDictionary = [meta->_cls respondsToSelector:@selector(modelCustomClassForDictionary:)];
    }
    
    if (propertyInfo.getter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.getter]) {
            meta->_getter = propertyInfo.getter;
        }
    }
    if (propertyInfo.setter) {
        if ([classInfo.cls instancesRespondToSelector:propertyInfo.setter]) {
            meta->_setter = propertyInfo.setter;
        }
    }

    
    if (meta->_getter && meta->_setter) {
        /*
         KVC invalid type:
         long double
         pointer (such as SEL/CoreFoundation object)
         */
        switch (meta->_type & LLEncodingTypeMask) {
            case LLEncodingTypeBool:
            case LLEncodingTypeInt8:
            case LLEncodingTypeUInt8:
            case LLEncodingTypeInt16:
            case LLEncodingTypeUInt16:
            case LLEncodingTypeInt32:
            case LLEncodingTypeUInt32:
            case LLEncodingTypeInt64:
            case LLEncodingTypeUInt64:
            case LLEncodingTypeFloat:
            case LLEncodingTypeDouble:
            case LLEncodingTypeObject:
            case LLEncodingTypeClass:
            case LLEncodingTypeBlock:
            case LLEncodingTypeStruct:
            case LLEncodingTypeUnion:
            {
               meta->_isKVCCompatible = YES;
            }break;
            default: break;
        }
    }
    return meta;
}
@end

// A class info in object model.
@interface _LLModelMeta : NSObject {
    @package
    LLClassInfo *_classInfo;
    NSDictionary *_mapper;
    NSArray *_allPropertyMetas;
    NSArray *_keyPathPropertyMetas;
    NSArray *_multiKeysPropertyMetas;
    NSUInteger _keyMappedCount;
    LLEncodingNSType _nsType;
    
    BOOL _hasCustomWillTransformFromDictionary;
    BOOL _hasCustomTransformFromDictionary;
    BOOL _hasCustomTransformToDictionary;
    BOOL _hasCustomClassFromDictionary;
}
@end

@implementation _LLModelMeta
- (instancetype)initWithClass:(Class)cls {
    LLClassInfo *classInfo = [LLClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    self = [super init];
    
    // Get black list
    NSSet *blacklist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyBlacklist)]) {
        NSArray *properties = [(id<LLModel>)cls modelPropertyBlacklist];
        if (properties) {
            blacklist = [NSSet setWithArray:properties];
        }
    }
    // Get White list
    NSSet *whitelist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyWhitelist)]) {
        NSArray *properties = [(id<LLModel>)cls modelPropertyWhitelist];
        if (properties) {
            whitelist = [NSSet setWithArray:properties];
        }
    }
    // Get container property's generic class
    NSDictionary *genericMapper = nil;
    if ([cls respondsToSelector:@selector(modelContainerPropertyGenericClass)]) {
        genericMapper = [(id<LLModel>)cls modelContainerPropertyGenericClass];
        if (genericMapper) {
            NSMutableDictionary *tmp = [NSMutableDictionary new];
            [genericMapper enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if (![key isKindOfClass:[NSString class]]) return;
                Class meta = object_getClass(obj);
                if (!meta) return;
                if (class_isMetaClass(meta)) {
                    tmp[key] = obj;
                }else if ([obj isKindOfClass:[NSString class]]) {
                    Class cls = NSClassFromString(obj);
                    if (cls) {
                        tmp[key] = cls;
                    }
                }
            }];
            genericMapper = tmp;
        }
    }
    // Create all property metas.
    NSMutableDictionary *allPropertyMetas = [NSMutableDictionary new];
    LLClassInfo *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.superCls != nil) {
        for (LLClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name) continue;
            if (blacklist && [blacklist containsObject:propertyInfo.name]) continue;
            if (whitelist && [whitelist containsObject:propertyInfo.name]) continue;
            _LLModelPropertyMeta *meta = [_LLModelPropertyMeta metaWithClassInfo:classInfo
                                                                    propertyInfo:propertyInfo
                                                                         generic:genericMapper[propertyInfo.name]];
            if (!meta || !meta->_name) continue;
            if (!meta->_getter || !meta->_setter) continue;
            if (allPropertyMetas[meta->_name]) continue;
            allPropertyMetas[meta->_name] = meta;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    if (allPropertyMetas.count) _allPropertyMetas = allPropertyMetas.allValues.copy;
    
    // create mapper
    NSMutableDictionary *mapper = [NSMutableDictionary new];
    NSMutableArray *keyPathPropertyMetas = [NSMutableArray new];
    NSMutableArray *multiKeysPropertyMetas = [NSMutableArray new];
    
    if ([cls respondsToSelector:@selector(modelCustomPropertyMapper)]) {
        NSDictionary *customMapper = [(id<LLModel>)cls modelCustomPropertyMapper];
        [customMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *mappedToKey, BOOL *stop) {
            _LLModelPropertyMeta *propertyMeta = allPropertyMetas[propertyName];
            if (!propertyMeta) return;
            [allPropertyMetas removeObjectForKey:propertyName];
            
            if ([mappedToKey isKindOfClass:[NSString class]]) {
                if (mappedToKey.length == 0) return;
                propertyMeta->_mappedToKey = mappedToKey;
                NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."];
                if (keyPath.count > 1) {
                    propertyMeta->_mappedToKeyPath = keyPath;
                    [keyPathPropertyMetas addObject:propertyMeta];
                }
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
                
            }else if ([mappedToKey isKindOfClass:[NSArray class]]) {
                
                NSMutableArray *mappedToKeyArray = [NSMutableArray new];
                for (NSString *oneKey in (NSArray *)mappedToKey) {
                    if (![oneKey isKindOfClass:[NSString class]]) continue;
                    if (oneKey.length == 0) continue;
                    NSArray *keyPath = [oneKey componentsSeparatedByString:@"."];
                    if (keyPath.count > 1) {
                        [mappedToKeyArray addObject:keyPath];
                    }else {
                        [mappedToKeyArray addObject:oneKey];
                    }
                    if (!propertyMeta-> _mappedToKey) {
                    propertyMeta->_mappedToKey = oneKey;
                    propertyMeta->_mappedToKeyPath = keyPath.count > 1 ?keyPath : nil;
                        
                    }
                }
                if (!propertyMeta->_mappedToKey) return;
                
                propertyMeta->_mappedToKeyArray = mappedToKeyArray;
                [multiKeysPropertyMetas addObject:propertyMeta];
                
                propertyMeta->_next = mapper[mappedToKey] ?: nil;
                mapper[mappedToKey] = propertyMeta;
            }
        }];
    }
    
    [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString *name, _LLModelPropertyMeta *propertyMeta, BOOL * _Nonnull stop) {
        propertyMeta->_mappedToKey = name;
        propertyMeta->_next = mapper[name] ?: nil;
        mapper[name] = propertyMeta;
    }];
    
    if (mapper.count) _mapper = mapper;
    if (keyPathPropertyMetas) _keyPathPropertyMetas = keyPathPropertyMetas;
    if (multiKeysPropertyMetas) _multiKeysPropertyMetas = multiKeysPropertyMetas;
    
    _classInfo = classInfo;
    _keyMappedCount = _allPropertyMetas.count;
    _nsType = LLClassGetNSType(cls);
    _hasCustomWillTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomWillTransformFromDictionary:)]);
    _hasCustomTransformFromDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformFromDictionary:)]);
    _hasCustomTransformToDictionary = ([cls instancesRespondToSelector:@selector(modelCustomTransformToDictionary:)]);
    _hasCustomClassFromDictionary = ([cls respondsToSelector:@selector(modelCustomClassForDictionary:)]);
    
    return self;
}
// Returns the cached model class meta
+ (instancetype)metaWithClass:(Class)cls {
    if (!cls) return nil;
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    _LLModelMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    dispatch_semaphore_signal(lock);
    if (!meta || meta->_classInfo.needUpdate) {
        meta = [[_LLModelMeta alloc] initWithClass:cls];
        if (meta) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            dispatch_semaphore_signal(lock);
        }
    }
    return meta;

}
@end

/**
 Get number from property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.getter should not be nil.
 @return A number object, or nil if failed.
 */
static force_inline NSNumber *ModelCreateNumberFromProperty(__unsafe_unretained id model, __unsafe_unretained _LLModelPropertyMeta *meta)
{
    switch (meta->_type & LLEncodingTypeMask) {
        case LLEncodingTypeBool:
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeInt8:
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeUInt8:
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeInt16:
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeUInt16:
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeInt32:
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeUInt32:
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeInt64:
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeUInt64:
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        case LLEncodingTypeFloat:
        {
            float num =((float (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case LLEncodingTypeDouble:
        {
            double num =((double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        case LLEncodingTypeLongDouble:
        {
            double num =((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        }
        default:
            return nil;
    }
}
/**
 Set number to property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param num   Can be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.setter should not be nil.
 */
static force_inline void ModelSetNumberToProperty(__unsafe_unretained id model,
                                                  __unsafe_unretained NSNumber *num,
                                                  __unsafe_unretained _LLModelPropertyMeta *meta)
{
    
    switch (meta->_type & LLEncodingTypeMask) {
        case LLEncodingTypeBool:
        {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        }break;
        case LLEncodingTypeInt8:
        {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        }break;
        case LLEncodingTypeUInt8:
        {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        }break;
            
        case LLEncodingTypeInt16:
        {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        }break;
        case LLEncodingTypeUInt16:
        {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        }break;
           
        case LLEncodingTypeInt32:
        {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }break;
        case LLEncodingTypeUInt32:
        {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        }break;
        case LLEncodingTypeInt64:
        {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.longLongValue);
            }
        }break;
        case LLEncodingTypeUInt64:
        {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
            }
        }break;
        case LLEncodingTypeFloat:
        {
            float d = num.floatValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        }break;
        case LLEncodingTypeDouble:
        {
            double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        }break;
        case LLEncodingTypeLongDouble:
        {
            long double d = num.doubleValue;
            if (isnan(d) || isinf(d))  d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        }break;
        default: break;
    }
}
/**
 Set value to model with a property meta.
 
 @discussion Caller should hold strong reference to the parameters before this function returns.
 
 @param model Should not be nil.
 @param value Should not be nil, but can be NSNull.
 @param meta  Should not be nil, and meta->_setter should not be nil.
 */
static void ModelSetValueForProperty(__unsafe_unretained id model,
                                     __unsafe_unretained id value,
                                     __unsafe_unretained _LLModelPropertyMeta *meta)
{
    if (meta->_isCNumber) {
        NSNumber *num = LLNSNumberCreateFromID(value);
        ModelSetNumberToProperty(model, num, meta);
        if (num) [num class]; //hold the number
    }else if (meta->_nsType) {
        if (value == (id)kCFNull) {
            ((void (*)(id, SEL, id)) (void *)objc_msgSend)((id)model,meta->_setter,(id)nil);
        }else{
            switch (meta->_nsType) {
                case LLEncodingNSTypeNSString:
                case LLEncodingNSTypeNSMutableString:
                {
                    if ([value isKindOfClass:[NSString class]]) {
                        if (meta->_nsType == LLEncodingNSTypeNSString) {
                            ((void (*)(id, SEL, id))(void *)objc_msgSend)((id)model,meta->_setter,value);
                        }else {
                            ((void (*)(id, SEL, id))(void *)objc_msgSend)((id)model,meta->_setter,((NSString *)value).mutableCopy);
                        }
                    }else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       meta->_nsType == LLEncodingNSTypeNSString?
                                                                       [(NSNumber *)value stringValue] :
                                                                       ((NSNumber *)value).stringValue.mutableCopy);
                    }else if ([value isKindOfClass:[NSData class]]) {
                        NSMutableString *string = [[NSMutableString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        ((void (*)(id, SEL, id))(void *)objc_msgSend)((id)model,meta->_setter,string);
                    }else if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       meta->_nsType == LLEncodingNSTypeNSString?
                                                                       [(NSURL *)value absoluteString] :
                                                                       ((NSURL *)value).absoluteString.mutableCopy);
                    }else if ([value isKindOfClass:[NSAttributedString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       meta->_nsType == LLEncodingNSTypeNSString?
                                                                       ((NSAttributedString *)value).string :
                                                                       ((NSAttributedString *)value).string.mutableCopy);
                    }
                }break;
                case LLEncodingNSTypeNSValue:
                case LLEncodingNSTypeNSNumber:
                case LLEncodingNSTypeNSDecimalNumber:
                {
                    if (meta->_nsType == LLEncodingNSTypeNSNumber) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)(model,meta->_setter,LLNSNumberCreateFromID(value));
                    }else if (meta->_nsType == LLEncodingNSTypeNSDecimalNumber) {
                        if ([value isKindOfClass:[NSDecimalNumber class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)(model, meta->_setter, value);
                        }else if ([value isKindOfClass:[NSNumber class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithDecimal:[(NSNumber *)value decimalValue]];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)(model, meta->_setter, decNum);
                            
                        }else if ([value isKindOfClass:[NSString class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithString:value];
                            NSDecimal dec = decNum.decimalValue;
                            if (dec._length == 0 && dec._isNegative) {
                                decNum = nil; //NaN,非数字的特殊值
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)(model, meta->_setter, decNum);
                        }
                    }else {
                        //LLEncodingNSTypeNSValue
                        if ([value isKindOfClass:[NSValue class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)(model, meta->_setter, value);
                        }
                    }
                }break;
                case LLEncodingNSTypeNSData:
                case LLEncodingNSTypeNSMutableData:
                {
                    if ([value isKindOfClass:[NSData class]]) {
                        if (meta->_nsType == LLEncodingNSTypeNSData) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)(model, meta->_setter, value);
                        }else {
                            NSMutableData *data = [(NSData *)value mutableCopy];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)(model, meta->_setter, data);
                        }
                    }else if ([value isKindOfClass:[NSString class]]) {
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (meta->_nsType == LLEncodingNSTypeNSMutableData) {
                            data = [data mutableCopy];
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)(model, meta->_setter, data);
                    }
                }break;
                case LLEncodingNSTypeNSDate:
                {
                    if ([value isKindOfClass:[NSDate class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    }else if ([value isKindOfClass:[NSString class]]) {
                        NSDate *date = LLNSDateFromString(value);
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, date);
                    }
                }break;
                case LLEncodingNSTypeNSURL:
                {
                    if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    }else if ([value isKindOfClass:[NSString class]]) {
                        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        NSString *str = [value stringByTrimmingCharactersInSet:set];
                        if (str.length == 0) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, nil);
                        }else {
                            NSURL *url = [[NSURL alloc]initWithString:str];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, url);
                        }
                    }
                }break;
                case LLEncodingNSTypeNSArray:
                case LLEncodingNSTypeNSMutableArray:
                {
                    if (meta->_genericCls) {
                        NSArray *valueArr = nil;
                        if ([value isKindOfClass:[NSArray class]]) valueArr = value;
                        else if ([value isKindOfClass:[NSSet class]]) valueArr = [(NSSet *)value allObjects];
                        if (valueArr) {
                            NSMutableArray *objectArr = [NSMutableArray new];
                            for (id one in valueArr) {
                                if ([one isKindOfClass:meta->_genericCls]) {
                                    [objectArr addObject:one];
                                }else if ([one isKindOfClass:[NSDictionary class]]) {
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) {
                                        cls = [cls modelCustomClassForDictionary:one];
                                        if (!cls) cls = meta->_genericCls; //for xcode code coverage
                                    }
                                    NSObject *newOne = [cls new];
                                    [newOne ll_modelSetWithDictiionary:one];
                                    if (newOne) [objectArr addObject:newOne];
                                }
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
                        }
                    }else {
                        if ([value isKindOfClass:[NSArray class]]) {
                            if (meta->_nsType == LLEncodingNSTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            }else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [(NSArray *)value mutableCopy]);
                            }
                        }else if ([value isKindOfClass:[NSSet class]]) {
                            if (meta->_nsType == LLEncodingNSTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [(NSSet *)value allObjects]);
                            }else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [(NSSet *)value allObjects].mutableCopy);
                            }
                        }
                    }
                }break;
                case LLEncodingNSTypeNSDictionary:
                case LLEncodingNSTypeNSMutableDictionary:
                {
                    if ([value isKindOfClass:[NSDictionary class]]) {
                        if (meta->_genericCls) {
                            NSMutableDictionary *dic = [NSMutableDictionary new];
                            [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, id oneValue, BOOL *stop) {
                                if ([oneValue isKindOfClass:[NSDictionary class]]) {
                                    Class cls = meta->_genericCls;
                                    if (meta->_hasCustomClassFromDictionary) {
                                        cls = [cls modelCustomClassForDictionary:oneValue];
                                        if (!cls) cls = meta->_genericCls; //for xcode code coverage
                                    }
                                    NSObject *newOne = [cls new];
                                    [newOne ll_modelSetWithDictiionary:oneValue];
                                    if (newOne) dic[oneKey] = newOne;
                                }
                            }];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                        }
                    }else {
                        if (meta->_nsType == LLEncodingNSTypeNSDictionary) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        }else{
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [(NSDictionary *)value mutableCopy]);
                        }
                    }
                }break;
                case LLEncodingNSTypeNSSet:
                case LLEncodingNSTypeNSMutableSet:
                {
                    NSSet *valueSet = nil;
                    if ([value isKindOfClass:[NSArray class]]) valueSet = [NSMutableSet setWithArray:value];
                    else if ([value isKindOfClass:[NSSet class]]) valueSet = (NSSet *)value;
                    
                    if (meta->_genericCls) {
                        NSMutableSet *set = [NSMutableSet new];
                        for ( id one in valueSet) {
                            if ([one isKindOfClass:meta->_genericCls]) {
                                [set addObject:one];
                            }else if ([one isKindOfClass:[NSDictionary class]]) {
                                Class cls = meta->_genericCls;
                                if (meta->_hasCustomClassFromDictionary) {
                                    cls = [cls modelCustomClassForDictionary:one];
                                    if (!cls) cls = meta->_genericCls; //for xcode code coverage
                                }
                                NSObject *newOne = [cls new];
                                [newOne ll_modelSetWithDictiionary:one];
                                if (newOne) [set addObject:newOne];
                            }
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, set);
                    }else {
                        if (meta->_nsType == LLEncodingNSTypeNSSet) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueSet);
                        }else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [(NSSet *)valueSet mutableCopy]);
                        }
                    }
                }
                default: break;
            }
        }
    }else {
        BOOL isNull = (value == (id)kCFNull);
        switch (meta->_type & LLEncodingTypeMask) {
            case LLEncodingTypeObject:
            {
                if (isNull) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
                }else if ([value isKindOfClass:meta->_cls]) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)value);
                }else if ([value isKindOfClass:[NSDictionary class]]) {
                    NSObject *one = nil;
                    if (meta->_getter) {
                        one = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
                    }
                    if (one) {
                        [one ll_modelSetWithDictiionary:value];
                    }else {
                        Class cls = meta->_cls;
                        if (meta->_hasCustomClassFromDictionary) {
                            cls = [cls modelCustomClassForDictionary:value];
                            if (!cls) cls = meta->_genericCls; // for xcode code coverage
                        }
                        one = [cls new];
                        [one ll_modelSetWithDictiionary:value];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)one);
                    }
                }
            }break;
            case LLEncodingTypeClass:
            {
                if (isNull) {
                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)NULL);
                }else{
                    Class cls = nil;
                    if ([value isKindOfClass:[NSString class]]) {
                        cls = NSClassFromString(value);
                        if (cls) {
                            ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)cls);
                        }
                    }else {
                        cls = object_getClass(value);
                        if (cls) {
                            if (class_isMetaClass(cls)) {
                                ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)value);
                            }
                        }
                    }
                }
            }break;
            case LLEncodingTypeSEL:
            {
                if (isNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)NULL);
                }else if ([value isKindOfClass:[NSString class]]) {
                    SEL sel = NSSelectorFromString(value);
                    if (sel) {
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)sel);
                    }
                }
            }break;
            case LLEncodingTypeBlock:
            {
                if (isNull) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())NULL);
                }else if ([value isKindOfClass:LLNSBlockClass()]) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())value);
                }
            }break;
            case LLEncodingTypeStruct:
            case LLEncodingTypeUnion:
            case LLEncodingTypeCArray:
            {
                if ([value isKindOfClass:[NSValue class]]) {
                    const char *valueType = ((NSValue *)value).objCType;
                    const char *metaType = meta->_info.typeEncoding.UTF8String;
                    if (valueType && metaType && strcmp(valueType, metaType) == 0) {
                        [model setValue:value forKey:meta->_name];
                    }
                }
            }break;
            case LLEncodingTypePointer:
            case LLEncodingTypeCString:
            {
                if (isNull) {
                   ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())NULL);
                }else if ([value isKindOfClass:[NSValue class]]) {
                    NSValue *nsValue = value;
                    if (nsValue.objCType && strcmp(nsValue.objCType, "^v") == 0) {
                        ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, nsValue.pointerValue);
                    }
                }
            }
            default:
                break;
        }
        
    }
}

typedef struct {
    void *modelMeta;  //_LLModelMeta
    void *model;      // id (self)
    void *dictionary;  // NSDictionary (json)
}ModelSetContext;

/**
 Apply function for dictionary, to set the key-value pair to model.
 
 @param _key     should not be nil, NSString.
 @param _value   should not be nil.
 @param _context _context.modelMeta and _context.model should not be nil.
 */
static void ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained _LLModelMeta *meta = (__bridge _LLModelMeta *)context->modelMeta;
    __unsafe_unretained _LLModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)_key];
    __unsafe_unretained id model = (__bridge id)context->model;
    while (propertyMeta) {
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    }
}
/**
 Apply function for model property meta, to set dictionary to model.
 
 @param _propertyMeta should not be nil, _YYModelPropertyMeta.
 @param _context      _context.model and _context.dictionary should not be nil.
 */
static void ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context)
{
    ModelSetContext *context = _context;
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    __unsafe_unretained _LLModelPropertyMeta *propertyMeta = (__bridge _LLModelPropertyMeta *)_propertyMeta;
    if (!propertyMeta->_setter) return;
    id value = nil;
    if (propertyMeta->_mappedToKeyArray) {
        value = LLValueForMultikeys(dictionary, propertyMeta->_mappedToKeyArray);
    }else if (propertyMeta->_mappedToKeyPath) {
        value = LLValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath);
    }else {
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    if (value) {
        __unsafe_unretained id model = (__bridge id)context->model;
        ModelSetValueForProperty(model, value, propertyMeta);
    }
}
/**
 Returns a valid JSON object (NSArray/NSDictionary/NSString/NSNumber/NSNull),
 or nil if an error occurs.
 
 @param model Model, can be nil.
 @return JSON object, nil if an error occurs.--递归循环
 */
static id ModelToJSONObjectRecursive(NSObject *model)
{
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [(NSDictionary *)model enumerateKeysAndObjectsUsingBlock:^(NSString *key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            id jsonObj = ModelToJSONObjectRecursive(obj);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray *array =[(NSSet *)model allObjects];
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in array) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            }else{
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSURL class]]) return [(NSURL *)model absoluteString];
    if ([model isKindOfClass:[NSAttributedString class]]) return [(NSAttributedString *)model string];
    if ([model isKindOfClass:[NSDate class]]) return [LLISODateFormatter() stringFromDate:(NSDate *)model];
    if ([model isKindOfClass:[NSData class]]) return nil;
    
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:model.class];
    if (!modelMeta || modelMeta->_keyMappedCount == 0) return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:64];
    __unsafe_unretained NSMutableDictionary *dic = result; // avoid retain and release in block
    [modelMeta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyMappedKey, _LLModelPropertyMeta *propertyMeta, BOOL *stop) {
        if (!propertyMeta->_getter) return;
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        }else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = ModelToJSONObjectRecursive(v);
        }else {
            switch (propertyMeta->_type & LLEncodingTypeMask) {
                case LLEncodingTypeObject:
                {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = ModelToJSONObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                }break;
                case LLEncodingTypeClass:
                {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                }break;
                case LLEncodingTypeSEL:
                {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                }break;
                default: break;
            }
        }
        if (!value) return;
        
        if (propertyMeta->_mappedToKeyPath) {
            NSMutableDictionary *superDic = dic;
            NSMutableDictionary *subDic = nil;
            for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
                NSString *key = propertyMeta->_mappedToKeyPath[i];
                if (i + 1 == max) {
                    //end
                    if (!superDic[key]) superDic[key] = value;
                    break;
                }
                
                subDic = subDic[key];
                if (subDic) {
                    if ([subDic isKindOfClass:[NSDictionary class]]) {
                        subDic = subDic.mutableCopy;
                        superDic[key] = subDic;
                    }else{
                        break;
                    }
                }else{
                    subDic = [NSMutableDictionary new];
                    superDic[key] = subDic;
                }
                superDic = subDic;
                subDic = nil;
            }
        }else{
            if (!dic[propertyMeta->_mappedToKey]) {
                dic[propertyMeta->_mappedToKey] = value;
            }
        }
    }];
    if (modelMeta->_hasCustomTransformToDictionary) {
        BOOL success = [((id<LLModel>)model) modelCustomTransformToDictionary:dic];
        if (!success) return nil;
    }
    return result;
}
/// Add indent to string (exclude first line)
static NSMutableString *ModelDescriptionAddIndent(NSMutableString *desc, NSUInteger indent)
{
    for (NSUInteger i = 0, max = desc.length; i < max; i++) {
        unichar c = [desc characterAtIndex:i];
        if (c == '\n') {
            for (NSUInteger j = 0; j < indent; j++) {
                [desc insertString:@"    " atIndex:i+1];
            }
            i += indent * 4;
            max += indent * 4;
        }
    }
    return desc;
}
/// Generaate a description string
static NSString *ModelDescription(NSObject *model)
{
    static const int kDescMaxLength = 100;
    if (!model) return @"<nil>";
    if (model == (id)kCFNull) return @"<null>";
    if (![model isKindOfClass:[NSObject class]]) return [NSString stringWithFormat:@"%@",model];
    
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:model.class];
    switch (modelMeta->_nsType) {
        case LLEncodingNSTypeNSString:
        case LLEncodingNSTypeNSMutableString:
        {
            NSString *tmp = model.description;
            if (tmp.length > kDescMaxLength) {
                tmp = [tmp substringToIndex:kDescMaxLength];
                tmp = [tmp stringByAppendingString:@"..."];
            }
            return tmp;
        }
        case LLEncodingNSTypeNSNumber:
        case LLEncodingNSTypeNSDecimalNumber:
        case LLEncodingNSTypeNSDate:
        case LLEncodingNSTypeNSURL:
        {
            return [NSString stringWithFormat:@"%@",model];
        }
        case LLEncodingNSTypeNSSet:
        case LLEncodingNSTypeNSMutableSet:
        {
            model = [(NSSet *)model allObjects];
        }
        case LLEncodingNSTypeNSArray:
        case LLEncodingNSTypeNSMutableArray:
        {
            NSArray *array = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (array.count == 0) {
                return [desc stringByAppendingString:@"[]"];
            }else {
                [desc appendString:@"[\n"];
                for (NSUInteger i = 0, max = array.count; i < max ; i++) {
                    NSObject *obj = array[i];
                    [desc appendString:@"    "];
                    [desc appendString:ModelDescriptionAddIndent(ModelDescription(obj).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @",\n"];
                }
                [desc appendString:@"]"];
                return desc;
            }
        }
        case LLEncodingNSTypeNSDictionary:
        case LLEncodingNSTypeNSMutableDictionary:
        {
            NSDictionary *dic = (id)model;
            NSMutableString *desc = [NSMutableString new];
            if (dic.count == 0) {
                return [desc stringByAppendingString:@"{}"];
            }else {
                NSArray *keys = dic.allKeys;
                [desc appendFormat:@"{\n"];
                for (NSUInteger i = 0, max = keys.count; i < max ; i++) {
                    NSString *key = keys[i];
                    NSObject *value = dic[key];
                    [desc appendString:@"    "];
                    [desc appendFormat:@"%@ = %@",key, ModelDescriptionAddIndent(ModelDescription(value).mutableCopy, 1)];
                    [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                }
                [desc appendFormat:@"}"];
            }
            return desc;
        }
        default:
        {
            NSMutableString *desc = [NSMutableString new];
            [desc appendFormat:@"<%@: %p>",model.class, model];
            if (modelMeta->_allPropertyMetas.count == 0) {
                return desc;
            }
            // sort property names
            NSArray *properties = [modelMeta->_allPropertyMetas sortedArrayUsingComparator:^NSComparisonResult(_LLModelPropertyMeta *p1, _LLModelPropertyMeta *p2) {
                return [p1->_name compare:p2->_name];
            }];
            [desc appendString:@" {\n"];
            for (NSUInteger i = 0, max = properties.count; i < max; i++) {
                _LLModelPropertyMeta *property = properties[i];
                NSString *propertyDesc;
                if (property->_isCNumber) {
                    NSNumber *num = ModelCreateNumberFromProperty(model, property);
                    propertyDesc = num.description;
                }else {
                    switch (property->_type & LLEncodingTypeMask) {
                        case LLEncodingTypeObject:
                        {
                            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = ModelDescription(v);
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        }break;
                        case LLEncodingTypeClass:
                        {
                            id v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = [(NSObject *)v description];
                            if (!propertyDesc) propertyDesc = @"<nil>";
                        }break;
                        case LLEncodingTypeSEL:
                        {
                            SEL sel = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            if (sel) propertyDesc = NSStringFromSelector(sel);
                            else propertyDesc = @"<NULL>";
                        }break;
                        case LLEncodingTypeBlock:
                        {
                            id block = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = block ? [(NSObject *)block description] : @"<nil>";
                        }break;
                        case LLEncodingTypeCArray:
                        case LLEncodingTypeCString:
                        case LLEncodingTypePointer:
                        {
                            void *pointer = ((void* (*)(id, SEL))(void *) objc_msgSend)((id)model, property->_getter);
                            propertyDesc = [NSString stringWithFormat:@"%p",pointer];
                        }break;
                        case LLEncodingTypeStruct:
                        case LLEncodingTypeUnion:
                        {
                            NSValue *value = [model valueForKey:property->_name];
                            propertyDesc = value ? value.description : @"{unknown}";
                        }
                        default: propertyDesc = @"unknown";
                    }
                }
                
                propertyDesc = ModelDescriptionAddIndent(propertyDesc.mutableCopy, 1);
                [desc appendFormat:@"      %@ = %@",property->_name, propertyDesc];
                [desc appendString:(i + 1 == max) ? @"\n" : @";\n"];
                
            }
            [desc appendString:@"}"];
            return desc;
        }
    }
}
@implementation NSObject (LLModel)

+ (NSDictionary *)_ll_dictionaryWithJSON:(id)json
{
    if (!json || json == (id)kCFNull) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    }else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    }else if ([json isKindOfClass:[NSData class]]) {
        jsonData = (NSData *)json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return dic;
}

+ (instancetype)ll_modelWithJSON:(id)json
{
    NSDictionary *dic = [self _ll_dictionaryWithJSON:json];
    return [self ll_modelWithDictionary:dic];
}
+ (instancetype)ll_modelWithDictionary:(NSDictionary *)dictionary
{
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    
    Class cls = [self class];
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:cls];
    if (modelMeta->_hasCustomClassFromDictionary) {
        cls = [cls modelCustomClassForDictionary:dictionary] ?: cls;
    }
    
    NSObject *one = [cls new];
    if ([one ll_modelSetWithDictiionary:dictionary]) return one;
    return nil;
}
- (BOOL)ll_modelSetWithJSON:(id)json
{
    NSDictionary *dic = [NSObject _ll_dictionaryWithJSON:json];
    return [self ll_modelSetWithDictiionary:dic];
}
- (BOOL)ll_modelSetWithDictiionary:(NSDictionary *)dictionary
{
    if (!dictionary || dictionary == (id)kCFNull) return NO;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return NO;
    
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:object_getClass(self)];
    if (modelMeta->_keyMappedCount == 0) return NO;
    if (modelMeta->_hasCustomWillTransformFromDictionary) {
        dictionary = [((id<LLModel>)self) modelCustomWillTransformFromDictionary:dictionary];
        if (![dictionary isKindOfClass:[NSDictionary class]]) return NO;
    }
    
    ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    context.dictionary = (__bridge void *)(dictionary);

    
    if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dictionary)) {
        CFDictionaryApplyFunction((CFDictionaryRef)dictionary, ModelSetWithDictionaryFunction, &context);
        if (modelMeta->_keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
        
        if (modelMeta->_multiKeysPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_multiKeysPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_multiKeysPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
    }else {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_allPropertyMetas,
                             CFRangeMake(0, modelMeta->_keyMappedCount),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);

    }
    if (modelMeta->_hasCustomTransformFromDictionary) {
        return [((id<LLModel>)self) modelCustomTransformFromDictionary:dictionary];
    }
    return YES;
    
}
- (id)ll_modelToJSONObject
{
    id jsonObject = ModelToJSONObjectRecursive(self);
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
    
}
- (NSData *)ll_modelToJSONData
{
    id jsonObject = [self ll_modelToJSONObject];
    if (!jsonObject) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
}
- (NSString *)ll_modelToJSONString
{
    NSData *jsonData = [self ll_modelToJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
- (id)ll_modelCopy
{
    if (self == (id)kCFNull) return self;
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self copy];
    
    NSObject *one = [self.class new];
    for (_LLModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter || !propertyMeta->_setter) continue;
        if (propertyMeta->_isCNumber) {
            switch (propertyMeta->_type & LLEncodingTypeMask) {
                case LLEncodingTypeBool:
                {
                    bool num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                }break;
                case LLEncodingTypeInt8:
                case LLEncodingTypeUInt8:
                {
                    uint8_t num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                }break;
                case LLEncodingTypeInt16:
                case LLEncodingTypeUInt16:
                {
                    uint16_t num = ((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);

                }break;
                case LLEncodingTypeInt32:
                case LLEncodingTypeUInt32:
                {
                    uint32_t num = ((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                }break;
                case LLEncodingTypeInt64:
                case LLEncodingTypeUInt64:
                {
                    uint64_t num = ((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                }break;
                case LLEncodingTypeFloat:
                {
                    float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                }break;
                case LLEncodingTypeDouble:
                {
                    double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                }break;
                case LLEncodingTypeLongDouble:
                {
                    long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                }
                default: break;
            }
        }else{
            switch (propertyMeta->_type & LLEncodingTypeMask) {
                case LLEncodingTypeObject:
                case LLEncodingTypeClass:
                case LLEncodingTypeBlock:
                {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                }break;
                case LLEncodingTypeStruct:
                case LLEncodingTypeUnion:
                {
                    @try {
                        NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                        if (value) {
                            [one setValue:value forKey:propertyMeta->_name];
                        }

                    } @catch (NSException *exception) {
                        
                    } @finally {
                        
                    }
                }
                default: break;
            }
        }
    }
    return one;
}
- (void)ll_modelEncodeWithCoder:(NSCoder *)aCoder
{
    if (!aCoder) return;
    if (self == (id)kCFNull) {
        [((id<NSCoding>)self) encodeWithCoder:aCoder];
        return;
    }
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) {
        [((id<NSCoding>)self) encodeWithCoder:aCoder];
        return;
    }
    
    for (_LLModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) return;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = ModelCreateNumberFromProperty(self, propertyMeta);
            if (value) [aCoder encodeObject:value forKey:propertyMeta->_name];
        }else {
            switch (propertyMeta->_type & LLEncodingTypeMask) {
                case LLEncodingTypeObject:
                {
                    id value = ((id (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value && (propertyMeta->_nsType || [value respondsToSelector:@selector(encodeWithCoder:)])) {
                        if ([value isKindOfClass:[NSValue class]]) {
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        }
                    }else {
                        [aCoder encodeObject:value forKey:propertyMeta->_name];
                    }
                }break;
                case LLEncodingTypeSEL:
                {
                    SEL value = ((SEL (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value) {
                        NSString *str = NSStringFromSelector(value);
                        [aCoder encodeObject:str forKey:propertyMeta->_name];
                    }
                }break;
                case LLEncodingTypeStruct:
                case LLEncodingTypeUnion:
                {
                    if (propertyMeta->_isKVCCompatible && propertyMeta->_isStructAvailableForKeyedArchiver) {
                        @try {
                            NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                            [aCoder encodeObject:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {
                            
                        } @finally {
                            
                        }
                    }
                }break;
                    
                default:
                    break;
            }
        }
    }
}
- (id)ll_modelInitWithCoder:(NSCoder *)aDecoder
{
    if (!aDecoder) return self;
    if (self == (id)kCFNull) return self;
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return self;
    
    for (_LLModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_setter) continue;
        if (propertyMeta->_isCNumber) {
            NSNumber *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
            if ([value isKindOfClass:[NSNumber class]]) {
                ModelSetNumberToProperty(self, value, propertyMeta);
                [value class];
            }
        }else {
            LLEncodingType type = propertyMeta->_type & LLEncodingTypeMask;
            switch (type) {
                case LLEncodingTypeObject:
                {
                    id value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyMeta->_setter, value);
                }break;
                case LLEncodingTypeSEL:
                {
                    NSString *str = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    if ([str isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(str);
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_setter, sel);
                    }
                }break;
                case LLEncodingTypeStruct:
                case LLEncodingTypeUnion:
                {
                    if (propertyMeta->_isKVCCompatible) {
                        @try {
                            NSValue *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                            if (value) [self setValue:value forKey:propertyMeta->_name];
                        } @catch (NSException *exception) {
                            
                        } @finally {
                            
                        }
                    }
                }break;
                    
                default:
                    break;
            }
        }
    }
    return self;
}

- (NSUInteger)ll_modelHash
{
    if (self == (id)kCFNull)  return [self hash];
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self hash];
    
    NSUInteger value = 0;
    NSUInteger count = 0;
    for (_LLModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        value ^= [[self valueForKey:NSStringFromSelector(propertyMeta->_getter)] hash];
        count++;
    }
    if (count == 0) value = (long)(__bridge void*)self;
    return value;
}

- (BOOL)ll_modelIsEqual:(id)model
{
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    _LLModelMeta *modelMeta = [_LLModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (_LLModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_isKVCCompatible) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        id that = [model valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if (![this isEqual:that]) return NO;
    }
    return YES;
}
- (NSString *)ll_modelDescription
{
    return ModelDescription(self);
}
@end

@implementation NSArray (LLModel)

+ (NSArray *)ll_modelArrayWithClass:(Class)cls json:(id)json
{
    if (!json) return nil;
    NSArray *arr = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSString class]]) {
        jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    }else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![arr isKindOfClass:[NSArray class]]) return nil;
    }
    return [self ll_modelArrayWithClass:cls array:arr];
}
+ (NSArray *)ll_modelArrayWithClass:(Class)cls array:(NSArray *)array
{
    if (!cls || !array) return nil;
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *dic in array) {
        if (![dic isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSObject *obj = [cls ll_modelWithDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return result;
}
@end
@implementation NSDictionary (LLModel)

+ (NSDictionary *)ll_modelDictionaryWithClass:(Class)cls json:(id)json
{
    if (!json) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    }else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding:NSUTF8StringEncoding];
    }else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return [self ll_modelDictionaryWithClass:cls dictionary:dic];
}
+ (NSDictionary *)ll_modelDictionaryWithClass:(Class)cls dictionary:(NSDictionary *)dic
{
    if (!cls || !dic) return nil;
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *key in dic.allKeys) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        NSObject *obj = [cls ll_modelWithDictionary:dic[key]];
        if (obj) result[key] = obj;
    }
    return result;
}
@end
