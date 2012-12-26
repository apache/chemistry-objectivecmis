/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

//
// CMISDateUtil
//
#import "CMISDateUtil.h"


@implementation CMISDateUtil

+ (NSDateFormatter *)CMISDateFormatter
{
    static dispatch_once_t predicate = 0;
      __strong static NSDateFormatter *dateFormatter = nil;
      dispatch_once(&predicate, ^
      {
          dateFormatter = [[NSDateFormatter alloc] init];
          dateFormatter.locale = [NSLocale systemLocale];
          dateFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar]; // ISO8601 calendar not available
          NSTimeZone *timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
          dateFormatter.calendar.timeZone = timeZone;
          dateFormatter.timeZone = timeZone;
          dateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";
      });
      return dateFormatter;
}


+ (NSString*)stringFromDate:(NSDate*)date {
    NSString *string = [[CMISDateUtil CMISDateFormatter] stringFromDate:date];
    return string;
}


+ (NSDate *)dateFromString:(NSString *)string {
    if (string == nil) {
        return nil;
    }
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    NSScanner *scanner = [NSScanner scannerWithString:string];
    NSInteger integer;
    
    // format 1: year
    if (![scanner scanInteger:&integer]) {
        log(@"No year found in time string '%@'", string);
        return nil;
    }
    components.year = integer;
    
    if ([scanner scanString:@"-" intoString:nil]) {
        // format 2: year and month
        if (![scanner scanInteger:&integer]) {
            log(@"No month found in time string '%@'", string);
            return nil;
        }
        components.month = integer;
        
        if ([scanner scanString:@"-" intoString:nil]) {
            // format 3: complete date
            if (![scanner scanInteger:&integer]) {
                log(@"No day found in time string '%@'", string);
                return nil;
            }
            components.day = integer;
        }
        
        if ([scanner scanString:@"T" intoString:nil]) {
            // format 4: complete date plus hours and minutes
            if (![scanner scanInteger:&integer]) {
                log(@"No hour found in time string '%@'", string);
                return nil;
            }
            components.hour = integer;
            
            if (![scanner scanString:@":" intoString:nil]) {
                log(@"No minute found in time string '%@'", string);
                return nil;
            }
            
            if (![scanner scanInteger:&integer]) {
                log(@"No minute found in time string '%@'", string);
                return nil;
            }
            components.minute = integer;
            
            if ([scanner scanString:@":" intoString:nil]) {
                // format 5: complete date plus hours, minutes and seconds
                if (![scanner scanInteger:&integer]) {
                    log(@"No second found in time string '%@'", string);
                    return nil;
                }
                components.second = integer;
                
                if ([scanner scanString:@"." intoString:nil]) {
                    // format 6: complete date plus hours, minutes, seconds and a decimal fraction of a	second
                    if (![scanner scanInteger:nil]) {
                        log(@"No fraction of a second found in time string '%@'", string);
                        return nil;
                    }
                    // ignore fraction of a second
                }
            }
            
            if ([scanner scanString:@"Z" intoString:nil]) {
                components.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            } else {
                NSInteger tzSign, tzHour, tzMinute;
                if ([scanner scanString:@"+" intoString:nil]) {
                    tzSign = +1;
                } else if ([scanner scanString:@"-" intoString:nil]) {
                    tzSign = -1;
                } else {
                    tzSign = 0;
                }
                
                if (tzSign != 0) {
                    if (![scanner scanInteger:&tzHour]) {
                        log(@"No timezone hour found in time string '%@'", string);
                        return nil;
                    }
                    
                    if (![scanner scanString:@":" intoString:nil]) {
                        log(@"No timezone minute found in time string '%@'", string);
                        return nil;
                    }
                    
                    if (![scanner scanInteger:&tzMinute]) {
                        log(@"No timezone minute found in time string '%@'", string);
                        return nil;
                    }
                    components.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:(tzSign * (tzHour * 3600 + tzMinute * 60))];
                } else { // no time zone specified, assume local time
                    components.timeZone = [NSTimeZone defaultTimeZone];
                }
            }
        }
    }
    
    if (![scanner isAtEnd]) {
        log(@"Unexpected characters found at end of time string '%@'", string);
        return nil;
    }
    
    static NSCalendar *gregorianCalendar = nil;
    if (gregorianCalendar == nil) {
        gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar]; // ISO8601 calendar not available
        gregorianCalendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0]; // default for formats without time
    }

    NSDate *date = [gregorianCalendar dateFromComponents:components];
    return date;
}


@end