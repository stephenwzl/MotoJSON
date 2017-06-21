//
//  MotoClassInfo.h
//  Moto
//
//  Created by stephenw on 2017/6/20.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NS_OPTIONS(NSUInteger, MotoEncodingType) {
  //encoding type
  MotoEncodingMask        = 0xFF,
  MotoEncodingUnknown     = 0,    //unknown type
  MotoEncodingVoid        = 1,    //void
  MotoEncodingBool        = 2,    //BOOL
  MotoEncodingInt8        = 3,    //char / BOOL
  MotoEncodingUInt8       = 4,    //unsigned char
  MotoEncodingInt16       = 5,    //short
  MotoEncodingUInt16      = 6,    //unsigned short
  MotoEncodingInt32       = 7,    //int
  MotoEncodingUInt32      = 8,    //unsigned int
  MotoEncodingInt64       = 9,    //long long
  MotoEncodingUInt64      = 10,   //unsigned long long
  MotoEncodingFloat       = 11,   //float
  MotoEncodingDouble      = 12,   //double
  MotoEncodingLongDouble  = 13,   //long double
  MotoEncodingObject      = 14,   //id
  MotoEncodingClass       = 15,   //Class
  MotoEncodingSEL         = 16,   //SEL
  MotoEncodingBlock       = 17,   //block
  MotoEncodingPointer     = 18,   //void *
  MotoEncodingStruct      = 19,   //struct
  MotoEncodingUnion       = 20,   //union
  MotoEncodingCString     = 21,   //char*
  MotoEncodingCArray      = 22,   //type[length]
  
  MotoEncodingQualifierMask     = 0xFF00,
  MotoEncodingQualifierConst    = 1 << 8,
  MotoEncodingQualifierIn       = 1 << 9,
  MotoEncodingQualifierInOut    = 1 << 10,
  MotoEncodingQualifierOut      = 1 << 11,
  MotoEncodingQualifierBycopy   = 1 << 12,
  MotoEncodingQualifierByref    = 1 << 13,
  MotoEncodingQualifierOneway   = 1 << 14,
  
  //property type
  MotoEncodingPropertyMask          = 0xFF0000,
  MotoEncodingPropertyReadOnly      = 1 << 16,    //readonly
  MotoEncodingPropertyCopy          = 1 << 17,    //copy
  MotoEncodingPropertyRetain        = 1 << 18,    //retain
  MotoEncodingPropertyNonatomic     = 1 << 19,    //nonatomic
  MotoEncodingPropertyWeak          = 1 << 20,    //weak
  MotoEncodingPropertyCustomGetter  = 1 << 21,    //getter=
  MotoEncodingPropertyCustomSetter  = 1 << 22,    //setter=
  MotoEncodingPropertyDynamic       = 1 << 23     //@dynamic
  
  
};

typedef struct MotoModelClassInfo* MotoClassInfoRef;
typedef struct MotoModelPropertyInfo* MotoPropertyInfoRef;

extern MotoClassInfoRef classInfoWithClass(Class cls);
extern MotoPropertyInfoRef propertyInfoWithProperty(objc_property_t property, CFDictionaryRef propertyKeyPath);

struct MotoModelClassInfo {
  Class cls;
  Class superClass;
  BOOL isMetaClass;
  struct MotoModelClassInfo *superClassInfo;
  CFStringRef name;
  CFDictionaryRef propertyInfo;
  CFDictionaryRef propertyKeyPath;
};

struct MotoModelPropertyInfo {
  objc_property_t property_t;
  CFStringRef name;
  MotoEncodingType type;
  CFStringRef typeEncoding;
  CFStringRef iVarName;
  Class cls;
  BOOL isMotoModel;
  SEL getter;
  SEL setter;
  CFStringRef mappedValue; //may be null
};
