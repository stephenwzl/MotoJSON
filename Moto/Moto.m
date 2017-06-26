//
//  MotoCreator.m
//  Moto
//
//  Created by stephenw on 2017/6/19.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "Moto.h"
#import "MotoClassInfo.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

#define BUFFER_SIZE 64
#define MT_BRIDGE_CAST (void *)
#define MT_PUSH(__x__) void *temp = __x__;
#define MT_POP(__x__) __x__ = temp;

struct MTParserState
{
  CFStringRef source; //points to NSString
  int BOMLength;
  NSStringEncoding encoding;
  void (*updateBuffer)(struct MTParserState *);
  unichar buffer[BUFFER_SIZE];
  NSUInteger bufferIndex;
  NSUInteger bufferLength;
  NSInteger sourceIndex;
  BOOL mutableStrings;
  BOOL mutableContainers;
  MotoClassInfoRef targetClassInfo;
  MotoClassInfoRef currentClassInfo;
  void *error;  //points to NSError
} ;

typedef struct MTParserState* MTParserStateRef;

#pragma mark - pre definition
static inline id parseValue(MTParserStateRef state);

static inline MotoPropertyInfoRef propertyInfoForKey(MTParserStateRef state, NSString *key) {
  NSDictionary *info = (__bridge NSDictionary *)state->currentClassInfo->propertyInfo;
  return (__bridge void *)[info objectForKey:key];
}

static inline void
updateStringBuffer(MTParserStateRef state) {
  CFRange r = CFRangeMake(state->sourceIndex, BUFFER_SIZE);
  NSUInteger end = CFStringGetLength(state->source);
  
  if (end - state->sourceIndex < BUFFER_SIZE) {
    r.length = end - state->sourceIndex;
  }
  CFStringGetCharacters(state->source, r, state->buffer);
  state->sourceIndex = r.location;
  state->bufferIndex = 0;
  state->bufferLength = r.length;
  if (r.length == 0) {
    state->buffer[0] = 0;
  }
}


/**
 * Returns the current character.
 */
static inline unichar
currentChar(MTParserStateRef state)
{
  if (state->bufferIndex >= state->bufferLength) {
    state->updateBuffer(state);
  }
  return state->buffer[state->bufferIndex];
}

/**
 * Consumes a character.
 */
static inline unichar
consumeChar(MTParserStateRef state)
{
  state->sourceIndex++;
  state->bufferIndex++;
  if (state->bufferIndex >= state->bufferLength) {
    state->updateBuffer(state);
  }
  return currentChar(state);
}

/**
 * Consumes all whitespace characters and returns the first non-space
 * character.  Returns 0 if we're past the end of the input.
 */
static inline unichar
consumeSpace(MTParserStateRef state)
{
  while (isspace(currentChar(state)))
  {
    consumeChar(state);
  }
  return currentChar(state);
}

/**
 * Sets an error state.
 */
static void
parseError(MTParserStateRef state)
{
  /* TODO: Work out what stuff should go in this and probably add them to
   * parameters for this function.
   */
  NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                            @"JSON Parse error", NSLocalizedDescriptionKey,
                            ([NSString stringWithFormat: @"Unexpected character %c at index %"PRIdPTR,
                              (char)currentChar(state), state->sourceIndex]),
                            NSLocalizedFailureReasonErrorKey,
                            nil];
  state->error = (__bridge void *)([NSError errorWithDomain: NSCocoaErrorDomain
                                                       code: 0
                                                   userInfo: userInfo]);
}

static inline NSString*
parseString(MTParserStateRef state)
{
  NSMutableString *val = nil;
  unichar buffer[BUFFER_SIZE];
  int bufferIndex = 0;
  unichar next;
  
  if (state->error)
  {
    return nil;
  }
  
  if (currentChar(state) != '"')
  {
    parseError(state);
    return nil;
  }
  
  next = consumeChar(state);
  while ((next != 0) && (next != '"'))
  {
    // Unexpected end of stream
    if (next == '\\')
    {
      next = consumeChar(state);
      switch (next)
      {
          // Simple escapes, just ignore the leading '
        case '"':
        case '\\':
        case '/':
          break;
          // Map to the unicode values specified in RFC4627
        case 'b': next = 0x0008; break;
        case 'f': next = 0x000c; break;
        case 'n': next = 0x000a; break;
        case 'r': next = 0x000d; break;
        case 't': next = 0x0009; break;
          // decode a unicode value from 4 hex digits
        case 'u':
        {
          char hex[5] = {0};
          unsigned i;
          for (i = 0 ; i < 4 ; i++)
          {
            next = consumeChar(state);
            if (!isxdigit(next))
            {
              [val release];
              parseError(state);
              return nil;
            }
            hex[i] = next;
          }
          // Parse 4 hex digits and a NULL terminator into a 16-bit
          // unicode character ID.
          next = (unichar)strtol(hex, 0, 16);
        }
      }
    }
    buffer[bufferIndex++] = next;
    if (bufferIndex >= BUFFER_SIZE)
    {
      NSMutableString *str;
      
      str = [[NSMutableString alloc] initWithCharacters: buffer
                                                 length: bufferIndex];
      bufferIndex = 0;
      if (nil == val)
      {
        val = str;
      }
      else
      {
        [val appendString: str];
        [str release];
      }
    }
    next = consumeChar(state);
  }
  
  if (currentChar(state) != '"')
  {
    [val release];
    parseError(state);
    return nil;
  }
  
  if (bufferIndex > 0)
  {
    NSMutableString *str;
    
    str = [[NSMutableString alloc] initWithCharacters: buffer
                                               length: bufferIndex];
    if (nil == val)
    {
      val = str;
    }
    else
    {
      [val appendString: str];
      [str release];
    }
  }
  else if (nil == val){
    val = [NSMutableString new];
  }
  if (!state->mutableStrings)
  {
    NSMutableString *oldPtr = val;
    val = [val copy];
    [oldPtr release];
  }
  // Consume the trailing "
  consumeChar(state);
  return val;
}

static NSArray*
parseArray(MTParserStateRef state)
{
  unichar c = consumeSpace(state);
  NSMutableArray *array;
  
  if (c != '[')
  {
    parseError(state);
    return nil;
  }
  // Eat the [
  consumeChar(state);
  array = [NSMutableArray new];
  c = consumeSpace(state);
  while (c != ']')
  {
    // If this fails, it will already set the error, so we don't have to.
    id obj = parseValue(state);
    if (nil == obj)
    {
      return nil;
    }
    [array addObject: obj];
    c = consumeSpace(state);
    if (c == ',')
    {
      consumeChar(state);
      c = consumeSpace(state);
    }
  }
  // Eat the trailing ]
  consumeChar(state);
  if (!state->mutableContainers)
  {
    //    if (NO == [array makeImmutable])
    //    {
    array = [array copy];
    //    }
  }
  return array;
}

static NSDictionary*
parseObject(MTParserStateRef state)
{
  unichar c = consumeSpace(state);
  id currentObject;
  if (c != '{') {
    parseError(state);
    return nil;
  }
  // Eat the {
  consumeChar(state);
  currentObject = class_createInstance(state->currentClassInfo->cls, 0);
  c = consumeSpace(state);
  while (c != '}') {
    id key = parseString(state);
    id obj;
    
    if (nil == key) {
      return nil;
    }
    c = consumeSpace(state);
    if (':' != c) {
      [key release];
      parseError(state);
      return nil;
    }
    // Eat the :
    consumeChar(state);
    MT_PUSH(state->currentClassInfo);
    MotoPropertyInfoRef info = propertyInfoForKey(state, key);
    if (info && info->isMotoModel) {
      state->currentClassInfo = classInfoWithClass(info->cls);
    }
    obj = parseValue(state);
    MT_POP(state->currentClassInfo);
    if (nil == obj) {
      [key release];
      currentObject = object_dispose(currentObject);
      return nil;
    }
    if (info) {
      [currentObject setValue:obj forKey:(__bridge NSString *)info->name];
    } else {
      // enter here means this parsed value not mapped
      [key release];
    }
    c = consumeSpace(state);
    if (c == ',') {
      consumeChar(state);
    }
    c = consumeSpace(state);
  }
  // Eat the trailing }
  consumeChar(state);
  return currentObject;
}

static NSNumber*
parseNumber(MTParserStateRef state) {
  unichar c = currentChar(state);
  char numberBuffer[128];
  char *number = numberBuffer;
  int bufferSize = 128;
  int parsedSize = 0;
  double num;
  
  // Define a macro to add a character to the buffer, because we'll need to do
  // it a lot.  This resizes the buffer if required.
#define BUFFER(x) do {\
if (parsedSize == bufferSize)\
{\
bufferSize *= 2;\
if (number == numberBuffer)\
  number = malloc(bufferSize);\
else\
  number = realloc(number, bufferSize);\
}\
number[parsedSize++] = (char)x; } while (0)
  // JSON numbers must start with a - or a digit
  if (!(c == '-' || isdigit(c)))
  {
    parseError(state);
    return nil;
  }
  // digit or -
  BUFFER(c);
  // Read as many digits as we see
  while (isdigit(c = consumeChar(state)))
  {
    BUFFER(c);
  }
  // Parse the fractional component, if there is one
  if ('.' == c)
  {
    BUFFER(c);
    while (isdigit(c = consumeChar(state)))
    {
      BUFFER(c);
    }
  }
  // parse the exponent if there is one
  if ('e' == tolower(c))
  {
    BUFFER(c);
    c = consumeChar(state);
    // The exponent must be a valid number
    if (!(c == '-' || c == '+' || isdigit(c))) {
      if (number != numberBuffer) {
        free(number);
      }
    }
    BUFFER(c);
    while (isdigit(c = consumeChar(state)))
    {
      BUFFER(c);
    }
  }
  // Add a null terminator on the buffer.
  BUFFER(0);
  num = strtod(number, 0);
  if (number != numberBuffer)
  {
    free(number);
  }
  return [[NSNumber alloc] initWithDouble: num];
#undef BUFFER
}


static inline id
parseValue(MTParserStateRef state) {
  unichar c;
  
  if (state->error) { return nil; };
  c = consumeSpace(state);
/*
 * A JSON value MUST be an object, array, number, or string, of one of these three literal names: false/true/null
 */
  switch (c) {
    case (unichar)'"':
      return parseString(state);
    case (unichar)'[':
      return parseArray(state);
    case (unichar)'{':
      return parseObject(state);
    case (unichar)'-':
    case (unichar)'0' ... (unichar)'9':
      return parseNumber(state);
//following three literal names:
    case 'n':
    {
      if ((consumeChar(state) == 'u')
          && (consumeChar(state) == 'l')
          && (consumeChar(state) == 'l')) {
        consumeChar(state);
        return [[NSNull null] retain];
      }
      break;
    }
    case 't':
    {
      if ((consumeChar(state) == 'r')
          && (consumeChar(state) == 'u')
          && (consumeChar(state) == 'e')) {
        consumeChar(state);
        return [(__bridge NSNumber *)kCFBooleanTrue retain];
      }
      break;
    }
    case 'f':
    {
      if ((consumeChar(state) == 'a')
          && (consumeChar(state) == 'l')
          && (consumeChar(state) == 's')
          && (consumeChar(state) == 'e')) {
        consumeChar(state);
        return [(__bridge NSNumber *)kCFBooleanFalse retain];
      }
      break;
    }
  }
  parseError(state);
  return nil;
}

@interface MTJSONSerialization : NSObject

+ (id)JSONObjectWithData:(NSData *)data
                 options:(MTJSONReadingOptions)opt
             targetClass:(Class)cls
                   error:(NSError * _Nullable __autoreleasing *)error;
+ (id)JSONObjectWithString:(NSString *)string
                   options:(MTJSONReadingOptions)opt
               targetClass:(Class)cls
                     error:(NSError *__autoreleasing  _Nullable *)error;

@end

@implementation MTJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data
                 options:(MTJSONReadingOptions)opt
             targetClass:(Class)cls
                   error:(NSError * _Nullable __autoreleasing *)error {
  return [self JSONObjectWithString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                            options:opt
                        targetClass:cls
                              error:error];
}

+ (id)JSONObjectWithString:(NSString *)string
                   options:(MTJSONReadingOptions)opt
               targetClass:(Class)cls
                     error:(NSError * _Nullable __autoreleasing *)error {
  if (!cls || !string) {
    return nil;
  }
  MTParserStateRef p = (MTParserStateRef)malloc(sizeof(struct MTParserState));
  id obj;
  
  p->source = (__bridge CFStringRef)string;
  p->updateBuffer = updateStringBuffer;
  p->mutableStrings = NO;
  p->mutableContainers = NO;
  p->targetClassInfo = classInfoWithClass(cls);
  p->currentClassInfo = p->targetClassInfo;
  obj = parseValue(p);
  
  if (NULL != error) {
    *error = p->error;
  }
  free(p);
  return obj;
}

@end

@implementation NSObject (MTJSONModel)

+ (instancetype)instanceFromJSONData:(NSData *)jsonData {
  return [[MTJSONSerialization JSONObjectWithData:jsonData options:kNilOptions targetClass:[self class] error:NULL] autorelease];
}

+ (instancetype)instanceFromJSONString:(NSString *)jsonString {
  return [[MTJSONSerialization JSONObjectWithString:jsonString options:kNilOptions targetClass:[self class] error:NULL] autorelease];
}

@end

#if defined(DEBUG)
void motoDebugPrint(CFDictionaryRef dict) {
  NSDictionary *ns_dict = (__bridge NSDictionary *)dict;
  for (NSString *key in ns_dict) {
    NSLog(@"%@, %@", key, (void *)ns_dict[key]);
  }
}

#endif
