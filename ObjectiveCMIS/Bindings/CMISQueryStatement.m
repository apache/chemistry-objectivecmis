/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CMISQueryStatement.h"

@interface CMISQueryStatement ()

@property (nonatomic, strong) NSString* statement;
@property (nonatomic, strong) NSMutableDictionary *parametersDictionary;

@end

@implementation CMISQueryStatement

- (id)initWithStatement:(NSString*)statement {
    self = [super init];
    if (self) {
        self.statement = statement;
        self.parametersDictionary = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)setTypeAtIndex:(NSUInteger)parameterIndex type:(NSString*)type {
    if (type && type.length > 0) {
        [self.parametersDictionary setObject:[CMISQueryStatement escapeString:type withSurroundingQuotes:NO] forKey:[NSNumber numberWithInteger:parameterIndex]];
    }
}

- (void)setPropertyAtIndex:(NSUInteger)parameterIndex property:(NSString*)property {
    if (property && property.length > 0) {
        [self.parametersDictionary setObject:[CMISQueryStatement escapeString:property withSurroundingQuotes:NO] forKey:[NSNumber numberWithInteger:parameterIndex]];
    }
}

- (void)setNumberAtIndex:(NSUInteger)parameterIndex number:(NSNumber*)number {
    if (number) {
        [self.parametersDictionary setObject:number forKey:[NSNumber numberWithInteger:parameterIndex]];
    }
}

- (void)setStringAtIndex:(NSUInteger)parameterIndex string:(NSString*)string {
    if (string && string.length > 0) {
        [self.parametersDictionary setObject:[CMISQueryStatement escapeString:string withSurroundingQuotes:YES] forKey:[NSNumber numberWithInteger:parameterIndex]];
    }
}

- (void)setStringLikeAtIndex:(NSUInteger)parameterIndex string:(NSString*)string {
    if (string && string.length > 0) {
        [self.parametersDictionary setObject:[CMISQueryStatement escapeLike:string] forKey:[NSNumber numberWithInteger:parameterIndex]];
    }
}

- (void)setStringContainsAtIndex:(NSUInteger)parameterIndex string:(NSString*)string {
    if (string && string.length > 0) {
        [self.parametersDictionary setObject:[CMISQueryStatement escapeContains:string] forKey:[NSNumber numberWithInteger:parameterIndex]];
    }
}

- (void)setUrlAtIndex:(NSUInteger)parameterIndex url:(NSURL*)url {
    if (url) {
        NSError *error;
        NSString *urlString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (!error && urlString && urlString.length >0) {
            [self.parametersDictionary setObject:[CMISQueryStatement escapeString:urlString withSurroundingQuotes:YES] forKey:[NSNumber numberWithInteger:parameterIndex]];
        }
    }
}

- (void)setBooleanAtIndex:(NSUInteger)parameterIndex boolean:(BOOL)boolean {
    NSString *booleanString;
    if (boolean) {
        booleanString = @"YES";
    } else {
        booleanString = @"NO";
    }
    [self.parametersDictionary setObject:booleanString forKey:[NSNumber numberWithInteger:parameterIndex]];
}

- (void)setDateTimeAtIndex:(NSUInteger)parameterIndex date:(NSDate*)date {
    if (date) {
        [self.parametersDictionary setObject:[NSString stringWithFormat:@"TIMESTAMP '%@'", [CMISQueryStatement convert:date]] forKey:[NSNumber numberWithInteger:parameterIndex]];
    }
}


- (NSString*)queryString {
    BOOL inStr = false;
    NSUInteger parameterIndex = 0;
    
    NSMutableString *retStr = [NSMutableString string];
    
    for (NSUInteger i = 0; i < self.statement.length; i++) {
        unichar c = [self.statement characterAtIndex:i];
        
        if (c == '\'') {
            if (inStr && [retStr characterAtIndex:i - 1] == '\\') {
                inStr = true;
            } else {
                inStr = !inStr;
            }
            [retStr appendString:[NSString stringWithCharacters:&c length:1]];
        } else if (c == '?' && !inStr) {
            parameterIndex++;
            NSObject *parameter = [self.parametersDictionary objectForKey:[NSNumber numberWithInteger:parameterIndex]];
            NSString *paramValue = nil;
            if ([parameter isKindOfClass:NSString.class]) {
                paramValue = (NSString*)parameter;
            } else if ([parameter isKindOfClass:NSNumber.class]) {
                paramValue = [(NSNumber*)parameter stringValue];
            }
            if (paramValue) {
                // Replace placeholder
                [retStr appendString:paramValue];
            }
        } else {
            [retStr appendString:[NSString stringWithCharacters:&c length:1]];
        }
    }
    
    return retStr;
}

#pragma mark - Escaping methods

+ (NSString*)escapeString:(NSString*)string withSurroundingQuotes:(BOOL)quotes {
    NSMutableString *escapedString = [NSMutableString string];
    [escapedString appendString:quotes ? @"'" : @"" ];
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        
        if (c == '\'' || c == '\\') {
            [escapedString appendString:@"\\"];
        }
        
        [escapedString appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    if (quotes) {
        [escapedString appendString:@"\'"];
    }
    
    return escapedString;
}

+ (NSString*)escapeLike:(NSString*)string {
    NSMutableString *escapedString = [NSMutableString stringWithString:@"'"];
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        
        if (c == '\'') {
            [escapedString appendString:@"\\"];
        } else if (c == '\\') {
            if (i + 1 < string.length && ([string characterAtIndex:(i + 1)] == '%' || [string characterAtIndex:(i + 1)] == '_')) {
                // no additional back slash
            } else {
                [escapedString appendString:@"\\"];
            }
        }
        
        [escapedString appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    [escapedString appendString:@"\'"];
    return escapedString;
}

+ (NSString*)escapeContains:(NSString*)string {
    NSMutableString *escapedString = [NSMutableString stringWithString:@"'"];
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        
        if (c == '\\') {
            [escapedString appendString:@"\\"];
        } else if (c == '\'' || c == '\"') {
            [escapedString appendString:@"\\\\\\"];
        }
        
        [escapedString appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    [escapedString appendString:@"\'"];
    return escapedString;
}

+ (NSString*)convert:(NSDate*)date {
    NSDateFormatter* timeStampFormatter = [[NSDateFormatter alloc] init];
    timeStampFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    timeStampFormatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    timeStampFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    
    return [timeStampFormatter stringFromDate:date];
}

@end
