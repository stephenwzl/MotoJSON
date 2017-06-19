//
//  MotoCreator.m
//  Moto
//
//  Created by stephenw on 2017/6/19.
//  Copyright © 2017年 stephenw.cc. All rights reserved.
//

#import "Moto.h"
#import <CoreFoundation/CoreFoundation.h>

#define BUFFER_SIZE 64

@interface MTParserState : NSObject
{
  @public
  NSString *source;
  int BOMLength;
  NSStringEncoding encoding;
  void (*updateBuffer)(MTParserState *);
  unichar buffer[BUFFER_SIZE];
  NSUInteger bufferIndex;
  NSUInteger bufferLength;
  NSInteger sourceIndex;
  BOOL mutableStrings;
  BOOL mutableContainers;
  NSError *error;
}
@end
@implementation MTParserState

@end

typedef struct ParserStateStruct
{
  /**
   * The data source.  This is either an NSString or an NSStream, depending on
   * the source.
   */
  void* source;
  /**
   * The length of the byte order mark in the source.  0 if there is no BOM.
   */
  int BOMLength;
  /**
   * The string encoding used in the source.
   */
  NSStringEncoding enc;
  /**
   * Function used to pull the next BUFFER_SIZE characters from the string.
   */
  void (*updateBuffer)(struct ParserStateStruct*);
  /**
   * Buffer used to store the next data from the input stream.
   */
  unichar buffer[BUFFER_SIZE];
  /**
   * The index of the parser within the buffer.
   */
  NSUInteger bufferIndex;
  /**
   * The number of bytes stored within the buffer.
   */
  NSUInteger bufferLength;
  /**
   * The index of the parser within the source.
   */
  NSInteger sourceIndex;
  /**
   * Should the parser construct mutable string objects?
   */
  BOOL mutableStrings;
  /**
   * Should the parser construct mutable containers?
   */
  BOOL mutableContainers;
  /**
   * Error value, if this parser is currently in an error state, nil otherwise.
   */
  void *error;
} ParserState;

#pragma mark - pre definition
static id parseValue(MTParserState *state);

static void
getEncoding(const uint8_t BOM[4], MTParserState *state)
{
  NSStringEncoding enc = NSUTF8StringEncoding;
  int BOMLength = 0;
  
  if ((BOM[0] == 0xEF) && (BOM[1] == 0xBB) && (BOM[2] == 0xBF))
  {
    BOMLength = 3;
  }
  else if ((BOM[0] == 0xFE) && (BOM[1] == 0xFF))
  {
    BOMLength = 2;
    enc = NSUTF16BigEndianStringEncoding;
  }
  else if ((BOM[0] == 0xFF) && (BOM[1] == 0xFE))
  {
    if ((BOM[2] == 0) && (BOM[3] == 0))
    {
      BOMLength = 4;
      enc = NSUTF32LittleEndianStringEncoding;
    }
    else
    {
      BOMLength = 2;
      enc = NSUTF16LittleEndianStringEncoding;
    }
  }
  else if ((BOM[0] == 0)
           && (BOM[1] == 0)
           && (BOM[2] == 0xFE)
           && (BOM[3] == 0xFF))
  {
    BOMLength = 4;
    enc = NSUTF32BigEndianStringEncoding;
  }
  else if (BOM[0] == 0)
  {
    // TODO: Throw an error if this doesn't match one of the patterns
    // described in section 3 of RFC4627
    if (BOM[1] == 0)
    {
      enc = NSUTF32BigEndianStringEncoding;
    }
    else
    {
      enc = NSUTF16BigEndianStringEncoding;
    }
  }
  else if (BOM[1] == 0)
  {
    if (BOM[2] == 0)
    {
      enc = NSUTF32LittleEndianStringEncoding;
    }
    else
    {
      enc = NSUTF16LittleEndianStringEncoding;
    }
  }
  state->encoding = enc;
  state->BOMLength = BOMLength;
}

static inline void
updateStringBuffer(MTParserState* state)
{
  NSRange r = {state->sourceIndex, BUFFER_SIZE};
  NSUInteger end = [state->source length];
  
  if (end - state->sourceIndex < BUFFER_SIZE)
  {
    r.length = end - state->sourceIndex;
  }
  [state->source getCharacters: state->buffer range: r];
  state->sourceIndex = r.location;
  state->bufferIndex = 0;
  state->bufferLength = r.length;
  if (r.length == 0)
  {
    state->buffer[0] = 0;
  }
}


/**
 * Returns the current character.
 */
static inline unichar
currentChar(MTParserState *state)
{
  if (state->bufferIndex >= state->bufferLength)
  {
    state->updateBuffer(state);
  }
  return state->buffer[state->bufferIndex];
}

/**
 * Consumes a character.
 */
static inline unichar
consumeChar(MTParserState *state)
{
  state->sourceIndex++;
  state->bufferIndex++;
  if (state->bufferIndex >= state->bufferLength)
  {
    state->updateBuffer(state);
  }
  return currentChar(state);
}

/**
 * Consumes all whitespace characters and returns the first non-space
 * character.  Returns 0 if we're past the end of the input.
 */
static inline unichar
consumeSpace(MTParserState *state)
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
parseError(MTParserState *state)
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
  state->error = [NSError errorWithDomain: NSCocoaErrorDomain
                                                       code: 0
                                                   userInfo: userInfo];
}

static NSString*
parseString(MTParserState *state)
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
//              [val release];
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
//        [str release];
      }
    }
    next = consumeChar(state);
  }
  
  if (currentChar(state) != '"')
  {
//    [val release];
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
//      [str release];
    }
  }
  else if (nil == val)
  {
    val = [NSMutableString new];
  }
  if (!state->mutableStrings)
  {
//    if (NO == [val makeImmutable])
//    {
      val = [val copy];
//    }
  }
  // Consume the trailing "
  consumeChar(state);
  return val;
}

static NSArray*
parseArray(MTParserState *state)
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
parseObject(MTParserState *state)
{
  unichar c = consumeSpace(state);
  NSMutableDictionary *dict;
  
  if (c != '{')
  {
    parseError(state);
    return nil;
  }
  // Eat the {
  consumeChar(state);
  dict = [NSMutableDictionary new];
  c = consumeSpace(state);
  while (c != '}')
  {
    id key = parseString(state);
    id obj;
    
    if (nil == key)
    {
//      [dict release];
      return nil;
    }
    c = consumeSpace(state);
    if (':' != c)
    {
//      [key release];
//      [dict release];
      parseError(state);
      return nil;
    }
    // Eat the :
    consumeChar(state);
    obj = parseValue(state);
    if (nil == obj)
    {
//      [key release];
//      [dict release];
      return nil;
    }
    [dict setObject: obj forKey: key];
//    [key release];
//    [obj release];
    c = consumeSpace(state);
    if (c == ',')
    {
      consumeChar(state);
    }
    c = consumeSpace(state);
  }
  // Eat the trailing }
  consumeChar(state);
  if (!state->mutableContainers)
  {
//    if (NO == [dict makeImmutable])
//    {
      dict = [dict copy];
//    }
  }
  return dict;
  
}

static NSNumber*
parseNumber(MTParserState *state)
{
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
    if (!(c == '-' || c == '+' || isdigit(c)))
    {
      if (number != numberBuffer)
      {
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




static id
parseValue(MTParserState *state)
{
  unichar c;
  
  if (state->error) { return nil; };
  c = consumeSpace(state);
  //   2.1: A JSON value MUST be an object, array, number, or string, or one of the
  //   following three literal names:
  //            false null true
  switch (c)
  {
    case (unichar)'"':
      return parseString(state);
    case (unichar)'[':
      return parseArray(state);
    case (unichar)'{':
      return parseObject(state);
    case (unichar)'-':
    case (unichar)'0' ... (unichar)'9':
      return parseNumber(state);
      // Literal null
    case 'n':
    {
      if ((consumeChar(state) == 'u')
          && (consumeChar(state) == 'l')
          && (consumeChar(state) == 'l'))
      {
        consumeChar(state);
        return [NSNull null];
      }
      break;
    }
      // literal
    case 't':
    {
      if ((consumeChar(state) == 'r')
          && (consumeChar(state) == 'u')
          && (consumeChar(state) == 'e'))
      {
        consumeChar(state);
        return [NSNumber numberWithBool:YES];
      }
      break;
    }
    case 'f':
    {
      if ((consumeChar(state) == 'a')
          && (consumeChar(state) == 'l')
          && (consumeChar(state) == 's')
          && (consumeChar(state) == 'e'))
      {
        consumeChar(state);
        return [NSNumber numberWithBool:NO];
      }
      break;
    }
  }
  parseError(state);
  return nil;
}


@implementation MTJSONSerialization

+ (id)JSONObjectWithString:(NSString *)string options:(MTJSONReadingOptions)opt error:(NSError *__autoreleasing *)error {
  return [self JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:opt error:error];
}

+ (id)JSONObjectWithData:(NSData *)data options:(MTJSONReadingOptions)opt error:(NSError *__autoreleasing *)error {
  uint8_t BOM[4];
  MTParserState *p = [MTParserState new];
  id obj;
  [data getBytes:BOM length:4];
  getEncoding(BOM, p);
  
  p->source = [[NSString alloc] initWithData:data encoding:p->encoding];
  p->updateBuffer = updateStringBuffer;
  p->mutableContainers = (opt & NSJSONReadingMutableContainers) == NSJSONReadingMutableContainers;
  p->mutableStrings = (opt & NSJSONReadingMutableLeaves) == NSJSONReadingMutableLeaves;
  
  obj = parseValue(p);
  
  if (NULL != error) {
    *error = p->error;
  }
  return obj;
}

@end
