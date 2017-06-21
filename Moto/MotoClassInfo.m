//
//  MotoClassInfo.m
//  Moto
//
//  Created by stephenw on 2017/6/20.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "MotoClassInfo.h"
#import "Moto.h"
#include <string.h>

static MotoEncodingType MotoEncodingGetType(const char *typeEncoding) {
  char *type = (char *)typeEncoding;
  if (!type) return MotoEncodingUnknown;
  size_t len = strlen(type);
  if (len == 0) return MotoEncodingUnknown
    ;
  
  MotoEncodingType qualifier = 0;
  bool prefix = true;
  while (prefix) {
    switch (*type) {
      case 'r': {
        qualifier |= MotoEncodingQualifierConst;
        type++;
      } break;
      case 'n': {
        qualifier |= MotoEncodingQualifierIn;
        type++;
      } break;
      case 'N': {
        qualifier |= MotoEncodingQualifierInOut;
        type++;
      } break;
      case 'o': {
        qualifier |= MotoEncodingQualifierOut;
        type++;
      } break;
      case 'O': {
        qualifier |= MotoEncodingQualifierBycopy;
        type++;
      } break;
      case 'R': {
        qualifier |= MotoEncodingQualifierByref;
        type++;
      } break;
      case 'V': {
        qualifier |= MotoEncodingQualifierOneway;
        type++;
      } break;
      default: { prefix = false; } break;
    }
  }
  
  len = strlen(type);
  if (len == 0) return MotoEncodingUnknown | qualifier;
  
  switch (*type) {
    case 'v': return MotoEncodingVoid | qualifier;
    case 'B': return MotoEncodingBool | qualifier;
    case 'c': return MotoEncodingInt8 | qualifier;
    case 'C': return MotoEncodingUInt8 | qualifier;
    case 's': return MotoEncodingInt16 | qualifier;
    case 'S': return MotoEncodingUInt16 | qualifier;
    case 'i': return MotoEncodingInt32 | qualifier;
    case 'I': return MotoEncodingUInt32 | qualifier;
    case 'l': return MotoEncodingInt32 | qualifier;
    case 'L': return MotoEncodingUInt32 | qualifier;
    case 'q': return MotoEncodingInt64 | qualifier;
    case 'Q': return MotoEncodingUInt64 | qualifier;
    case 'f': return MotoEncodingFloat | qualifier;
    case 'd': return MotoEncodingDouble | qualifier;
    case 'D': return MotoEncodingLongDouble | qualifier;
    case '#': return MotoEncodingClass | qualifier;
    case ':': return MotoEncodingSEL | qualifier;
    case '*': return MotoEncodingCString | qualifier;
    case '^': return MotoEncodingPointer | qualifier;
    case '[': return MotoEncodingCArray | qualifier;
    case '(': return MotoEncodingUnion | qualifier;
    case '{': return MotoEncodingStruct | qualifier;
    case '@': {
      if (len == 2 && *(type + 1) == '?')
        return MotoEncodingBlock | qualifier;
      else
        return MotoEncodingObject | qualifier;
    }
    default: return MotoEncodingUnknown | qualifier;
  }
}

static MotoClassInfoRef allocClassInfoWithClass(Class cls) {
  if (!cls || ![cls conformsToProtocol:@protocol(MTJSONSerializationHelper)]) return NULL;
  MotoClassInfoRef slf = (MotoClassInfoRef)malloc(sizeof(struct MotoModelClassInfo));
  slf->cls = cls;
  slf->propertyKeyPath = (__bridge CFDictionaryRef)[cls JSONKeyPathForProperty];
  slf->name = (__bridge CFStringRef)NSStringFromClass(cls);
  slf->isMetaClass = class_isMetaClass(cls);
  slf->superClass = class_getSuperclass(cls);
  slf->superClassInfo = classInfoWithClass(slf->superClass);
  unsigned int propertyCount;
  objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
  if (properties) {
    CFMutableDictionaryRef infos = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, NULL, NULL);
    slf->propertyInfo = infos;
    for (unsigned int i = 0; i < propertyCount; ++i) {
      MotoPropertyInfoRef info = propertyInfoWithProperty(properties[i], slf->propertyKeyPath);
      if (info && info->mappedValue) {
        CFDictionarySetValue(infos,info->name, info);
      }
      if (info->cls && [info->cls conformsToProtocol:@protocol(MTJSONSerializationHelper)]) {
        classInfoWithClass(info->cls);
      }
    }
    free(properties);
  } else {
    slf->propertyInfo = NULL;
  }
  return slf;
}

#pragma mark - implement
MotoClassInfoRef classInfoWithClass(Class cls) {
  if (!cls) return NULL;
  static CFMutableDictionaryRef classCache;
  static dispatch_once_t onceToken;
  static dispatch_semaphore_t lock;
  dispatch_once(&onceToken, ^{
    classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    lock = dispatch_semaphore_create(1);
  });
  dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
  MotoClassInfoRef info = (MotoClassInfoRef)CFDictionaryGetValue(classCache, (__bridge void *)cls);
  dispatch_semaphore_signal(lock);
  if (info) {
    return info;
  }
  info = allocClassInfoWithClass(cls);
  if (info) {
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    CFDictionarySetValue(classCache, (__bridge void *)cls, info);
    dispatch_semaphore_signal(lock);
  }
  return info;
}

MotoPropertyInfoRef propertyInfoWithProperty(objc_property_t property, CFDictionaryRef propertyKeyPath) {
  if (!property) return NULL;
  MotoPropertyInfoRef slf = (MotoPropertyInfoRef)malloc(sizeof(struct MotoModelPropertyInfo));
  slf->name = CFStringCreateWithCString(CFAllocatorGetDefault(), property_getName(property), kCFStringEncodingUTF8);
  slf->property_t = property;
  MotoEncodingType type = 0;
  unsigned int propertyAttrCount;
  objc_property_attribute_t *p_attrbutes = property_copyAttributeList(property, &propertyAttrCount);
  for (unsigned int i = 0; i < propertyAttrCount; ++i) {
    switch (p_attrbutes[i].name[0]) {
      case 'T': {//type encoding
        if (p_attrbutes[i].value) {
          const char* typeEncCString = p_attrbutes[i].value;
          slf->typeEncoding = CFStringCreateWithCString(CFAllocatorGetDefault(), typeEncCString, kCFStringEncodingUTF8);
          type = MotoEncodingGetType(typeEncCString);
          size_t typeEncLen = strlen(typeEncCString);
          if ((type & MotoEncodingMask) == MotoEncodingObject && typeEncLen) {
            if (typeEncCString[0] == '@' && typeEncCString[1] == '"' && typeEncCString[typeEncLen - 1] == '"' && typeEncLen > 3) {
              char *className = (char *)malloc(typeEncLen - 2);
              strncpy(className, &typeEncCString[2], typeEncLen - 3);
              CFStringRef classNameNS = CFStringCreateWithCString(CFAllocatorGetDefault(), className, kCFStringEncodingUTF8);
              slf->cls = NSClassFromString((__bridge NSString *)classNameNS);
              slf->isMotoModel = [slf->cls conformsToProtocol:@protocol(MTJSONSerializationHelper)];
              CFBridgingRelease(classNameNS);
              free(className);
              continue;
            }
          }
          slf->cls = NULL;
          slf->isMotoModel = NO;
        }
        break;
      }
      case 'V': { //instance variable
        if (p_attrbutes[i].value) slf->iVarName = CFStringCreateWithCString(CFAllocatorGetDefault(), p_attrbutes[i].value, kCFStringEncodingUTF8);
        break;
      }
      case 'R': { //read only
        type |= MotoEncodingPropertyReadOnly;
        break;
      }
      case 'C': { //copy
        type |= MotoEncodingPropertyCopy;
        break;
      }
      case '&': { //strong
        type |= MotoEncodingPropertyRetain;
        break;
      }
      case 'N': //nonatomic
      {
        type |= MotoEncodingPropertyNonatomic;
        break;
      }
      case 'D': //@dynamic
      {
        type |= MotoEncodingPropertyDynamic;
        break;
      }
      case 'W': //weak
      {
        type |= MotoEncodingPropertyWeak;
        break;
      }
      case 'G': //getter=
      {
        type |= MotoEncodingPropertyCustomGetter;
        if (p_attrbutes[i].value) {
          slf->getter = NSSelectorFromString([NSString stringWithUTF8String:p_attrbutes[i].value]);
        }
        break;
      }
      case 'S': //setter=
      {
        type |= MotoEncodingPropertyCustomSetter;
        if (p_attrbutes[i].value) {
          slf->setter = NSSelectorFromString([NSString stringWithUTF8String:p_attrbutes[i].value]);
        }
        break;
      }
      default:
        break;
    }
  }
  slf->type = type;
  if (p_attrbutes) {
    free(p_attrbutes);
    p_attrbutes = NULL;
  }
  if (CFStringGetLength(slf->name)) {
    NSString *name = (__bridge NSString *)slf->name;
    if (!slf->getter) {
      slf->getter = NSSelectorFromString(name);
    }
    if (!slf->setter) {
      slf->setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@", [name substringToIndex:1].uppercaseString, [name substringFromIndex:1]]);
    }
  }
  if (propertyKeyPath) {
    CFStringRef valueName = CFDictionaryGetValue(propertyKeyPath, slf->name);
    if (valueName) {
      slf->mappedValue = valueName;
    } else {
      slf->mappedValue = NULL;
    }
  }
  return slf;
}
