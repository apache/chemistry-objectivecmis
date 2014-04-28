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

#import "CMISFormDataWriter.h"
#import "CMISConstants.h"
#import "CMISBrowserConstants.h"
#import "CMISEnums.h"
#import "CMISLog.h"

NSString * const kCMISFormDataContentTypeUrlEncoded = @"application/x-www-form-urlencoded;charset=utf-8";

@interface CMISFormDataWriter ()

@property (nonatomic, strong) NSMutableDictionary *parameters;
@property (nonatomic, strong) NSString *boundary;

@end

@implementation CMISFormDataWriter



- (id)initWithAction:(NSString *)action
{
    self = [super init];
    if (self) {
        self.parameters = [[NSMutableDictionary alloc] init];
        
        [self addParameter:kCMISBrowserJSONControlCmisAction value:action];
        //self.contentStream = contentStream;
        self.boundary = [NSString stringWithFormat:@"aPacHeCheMIStryoBjECtivEcmiS%x%a%x", (unsigned int) action.hash, CFAbsoluteTimeGetCurrent(), (unsigned int) self.hash];
        
    }
    return self;
}

- (void)addParameter:(NSString *)name value:(id)value
{
    if(!name || !value) {
        return;
    }
    
    [self.parameters setValue:[value description] forKey:name];
}

- (void)addParameter:(NSString *)name boolValue:(BOOL)value
{
    [self addParameter:name value:(value? kCMISParameterValueTrue : kCMISParameterValueFalse)];
}

- (void)addSuccinctFlag:(BOOL)succinct
{
    if (succinct) {
        [self addParameter:kCMISBrowserJSONParameterSuccinct value:kCMISParameterValueTrue];
    }
}

- (void)addPropertiesParameters:(CMISProperties *)properties
{
    if (!properties) {
        return;
    }
    
    int idx = 0;
    
    for (CMISPropertyData *prop in properties.propertyList) {
        
        NSString *idxStr = [NSString stringWithFormat:@"[%d]", idx];
        
        
        [self addParameter:[NSString stringWithFormat:@"%@%@", kCMISBrowserJSONControlPropertyId, idxStr] value:prop.identifier];
        
        if (prop.values && prop.values.count > 0) {
            if (prop.values.count == 1) {
                NSString *value = [self convertPropertyValue:prop.firstValue forPropertyType:prop.type];
                [self addParameter:[NSString stringWithFormat:@"%@%@", kCMISBrowserJSONControlPropertyValue, idxStr] value:value];
            } else {
                int vidx = 0;
                for (id obj in prop.values) {
                    NSString *vidxStr = [NSString stringWithFormat:@"[%d]", vidx];
                    NSString *value = [self convertPropertyValue:obj forPropertyType:prop.type];
                    [self addParameter:[NSString stringWithFormat:@"%@%@%@", kCMISBrowserJSONControlPropertyValue, idxStr, vidxStr] value:value];
                    vidx++;
                }
            }
        }
        
        idx++;
    }
}

// TODO should this method be part of CMISPropertyData class (as class method?)
- (NSString *)convertPropertyValue:(id)value forPropertyType:(CMISPropertyType)type
{
    if (!value) {
        return nil;
    }
    
    if (type == CMISPropertyTypeBoolean) {
        return [value boolValue] ? kCMISParameterValueTrue : kCMISParameterValueFalse;
    } else if (type == CMISPropertyTypeDateTime) {
        if ([value isKindOfClass:NSDate.class]) {
            return [NSNumber numberWithDouble:[(NSDate *)value timeIntervalSinceReferenceDate]].description;
        } else {
            CMISLogWarning(@"value is not a date!");
        }
    }
    return value;
}

- (NSDictionary *)headers
{
    return @{@"Content-Type" : kCMISFormDataContentTypeUrlEncoded};
}

- (NSData *)body
{
    BOOL first = YES;
    NSData *amp = [@"&" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *data = [[NSMutableData alloc] init];
    
    for (NSString *parameterKey in self.parameters) {
        if (first) {
            first = NO;
        } else {
            [data appendData:amp];
        }
        NSString *parameterValue = [self.parameters[parameterKey] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *parameter = [NSString stringWithFormat:@"%@=%@", parameterKey, parameterValue];
        [data appendData:[parameter dataUsingEncoding:NSUTF8StringEncoding]];
    }

    return data;
}

@end
