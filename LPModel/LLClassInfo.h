//
//  LLClassInfo.h
//  LPModel
//
//  Created by QFWangLP on 2016/11/7.
//  Copyright © 2016年 LeeFengHY. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/*
 类型编码
 */
typedef NS_OPTIONS(NSUInteger, LLEncodingType) {
    LLEncodingTypeMask             = 0xFF,
    LLEncodingTypeUnknown          = 0,
    LLEncodingTypeVoid             = 1,
    LLEncodingTypeBool             = 2,
    LLEncodingTypeInt8             = 3,
    LLEncodingTypeUInt8            = 4,
    LLEncodingTypeInt16            = 5,
    LLEncodingTypeUInt16           = 6,
    LLEncodingTypeInt32            = 7,
    LLEncodingTypeUInt32           = 8,
    LLEncodingTypeInt64            = 9,
    LLEncodingTypeUInt64           = 10,
    LLEncodingTypeFloat            = 11,
    LLEncodingTypeDouble           = 12,
    LLEncodingTypeLongDouble       = 13,
    LLEncodingTypeObject           = 14,
    LLEncodingTypeClass            = 15,
    LLEncodingTypeSEL              = 16,
    LLEncodingTypeBlock            = 17,
    LLEncodingTypePointer          = 18,
    LLEncodingTypeStruct           = 19,
    LLEncodingTypeUnion            = 20,
    LLEncodingTypeCString          = 21,
    LLEncodingTypeCArray           = 22,
    
    LLEncodingTypeQualifierMask    = 0xFF00,
    LLEncodingTypeQualifierConst   = 1 << 8,
    LLEncodingTypeQualifierIn      = 1 << 9,
    LLEncodingTypeQualifierInout   = 1 << 10,
    LLEncodingTypeQualifierOut     = 1 << 11,
    LLEncodingTypeQualifierBycopy  = 1 << 12,
    LLEncodingTypeQualifierByref   = 1 << 13,
    LLEncodingTypeQualifierOneway  = 1 << 14,
    
    LLEncodingTypePropertyMask         = 0xFF0000,
    LLEncodingTypePropertyReadonly     = 1 << 16,
    LLEncodingTypePropertyCopy         = 1 << 17,
    LLEncodingTypePropertyRetain       = 1 << 18,
    LLEncodingTypePropertyNonatomic    = 1 << 19,
    LLEncodingTypePropertyWeak         = 1 << 20,
    LLEncodingTypePropertyCustomGetter = 1 << 21,
    LLEncodingTypePropertyCustomSetter = 1 << 22,
    LLEncodingTypePropertyDynamic      = 1 << 23,
    
};


/**
 根据编码字符得到一个类型
 参考资料:
 https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html

 @param typeEncoding 一个类型编码字符

 @return encoding type
 */
LLEncodingType LLEncodingGetType(const char *typeEncoding);

@interface LLClassIvarInfo : NSObject
@property (nonatomic, assign, readonly) Ivar ivar;              //Ivar opaque struct
@property (nonatomic, strong, readonly) NSString *name;         //Ivar's name
@property (nonatomic, assign, readonly) ptrdiff_t offset;       //Ivar's offset
@property (nonatomic, strong, readonly) NSString *typeEncoding; //Ivar's type encoding
@property (nonatomic, assign, readonly) LLEncodingType type;    //Ivar's type

/**
 Creates and returns an ivar info object.

 @param ivar ivar opaque struct

 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithIvar:(Ivar)ivar;
@end

@interface LLClassMethodInfo : NSObject
@property (nonatomic, assign, readonly) Method method;                                //method opaque struct
@property (nonatomic, strong, readonly) NSString *name;                               //method name
@property (nonatomic, assign, readonly) SEL sel;                                      //method's selector
@property (nonatomic, assign, readonly) IMP imp;                                      //method's implementation
@property (nonatomic, strong, readonly) NSString *typeEncoding;                       //method's parameter and return types
@property (nonatomic, assign, readonly) NSString *returnTypeEncoding;                 //return value's type
@property (nonatomic, strong, readonly, nullable) NSArray<NSString *> *argumentTypeEncodings; //array of argument's type

/**
 Creates and returns a method info object.
 
 @param method method opaque struct
 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithMethod:(Method)method;
@end

@interface LLClassPropertyInfo : NSObject
@property (nonatomic, assign, readonly) objc_property_t property;    //property's opaque struct
@property (nonatomic, strong, readonly) NSString *name;              //property's name
@property (nonatomic, assign, readonly) LLEncodingType type;         //property's type
@property (nonatomic, strong, readonly) NSString *typeEncoding;      //property's encoding value
@property (nonatomic, strong, readonly) NSString *ivarName;          //property's ivar name
@property (nonatomic, assign, readonly, nullable) Class cls;         //may be nil
@property (nonatomic, assign, readonly) SEL getter;                  //getter (nonnull)
@property (nonatomic, assign, readonly) SEL setter;                  //settter (nonnull)

/**
 Creates and returns a property info object

 @param property property opaque struct

 @return A new object, or nil if an error occurs
 */
- (instancetype)initWithProperty:(objc_property_t)property;
@end

/**
 Class information for a class
 */
@interface LLClassInfo : NSObject
@property (nonatomic, assign, readonly) Class cls;                  //class object
@property (nullable, nonatomic, assign, readonly) Class superCls;   //super class object
@property (nullable, nonatomic, assign, readonly) Class metaCls;    //class's meta class
@property (nonatomic, readonly, assign) BOOL isMeta;                //whether this class is meta class
@property (nonatomic, strong, readonly) NSString *name;             //class name
@property (nullable, nonatomic, strong, readonly) LLClassInfo *superClassInfo;  //super class's class info
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, LLClassIvarInfo *> *ivarInfos;   //ivars
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, LLClassMethodInfo*> *methodInfos; //methods
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, LLClassPropertyInfo*> *propertyInfos;    //propertyInfos

/**
 If the class is changed (for example: you add a method to this class with
 'class_addMethod()'), you should call this method to refresh the class info cache.
 
 After called this method, `needUpdate` will returns `YES`, and you should call
 'classInfoWithClass' or 'classInfoWithClassName' to get the updated class info.
 */

- (void)setNeedUpdate;

/**
 If this method returns `YES`, you should stop using this instance and call
 `classInfoWithClass` or `classInfoWithClassName` to get the updated class info.
 
 @return Whether this class info need update.
 */
- (BOOL)needUpdate;

/**
 Get the class info of a specified Class.
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 @param cls A class.
 @return A class info, or nil if an error occurs.
 */
+ (nullable instancetype)classInfoWithClass:(Class)cls;

/**
 Get the class info of a specified Class.
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 @param className A class name.
 @return A class info, or nil if an error occurs.
 */
+ (nullable instancetype)classInfoWithClassName:(NSString *)className;

@end

NS_ASSUME_NONNULL_END
