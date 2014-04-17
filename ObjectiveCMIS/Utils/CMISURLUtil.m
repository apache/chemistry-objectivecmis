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
 
#import "CMISURLUtil.h"
#import "CMISConstants.h"


@implementation CMISURLUtil

+ (NSString *)urlStringByAppendingParameter:(NSString *)parameterName boolValue:(BOOL)parameterValue urlString:(NSString *)urlString
{
    return [CMISURLUtil urlStringByAppendingParameter:parameterName value:parameterValue ? kCMISParameterValueTrue : kCMISParameterValueFalse urlString:urlString];
}

+ (NSString *)urlStringByAppendingParameter:(NSString *)parameterName numberValue:(NSNumber *)parameterValue urlString:(NSString *)urlString
{
    return [CMISURLUtil urlStringByAppendingParameter:parameterName value:[parameterValue stringValue] urlString:urlString];
}

+ (NSString *)urlStringByAppendingParameter:(NSString *)parameterName value:(NSString *)parameterValue urlString:(NSString *)urlString
{
    if (parameterName == nil || parameterValue == nil) {
        return urlString;
    }

    NSMutableString *result = [NSMutableString stringWithString:urlString];

    // Append '?' if not yet in url, else append ampersand
    if ([result rangeOfString:@"?"].location == NSNotFound) {
        [result appendString:@"?"];
    } else {
        if([result rangeOfString:@"?"].location != result.length -1){ // Only add ampersand if there is already a parameter added
            [result appendString:@"&"];
        }
    }

    // Append param
    [result appendString:parameterName];
    [result appendString:@"="];
    [result appendString:[parameterValue stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    return result;
}

+ (NSString *)urlStringByAppendingPath:(NSString *)path urlString:(NSString *)urlString
{
    NSURL *url = [[NSURL URLWithString:urlString] URLByAppendingPathComponent:path];
    
    return [url absoluteString];
}

+ (NSURL *)urlStringByAppendingParameter:(NSString *)parameterName value:(NSString *)parameterValue url:(NSURL *)url
{
    return [NSURL URLWithString:[CMISURLUtil urlStringByAppendingParameter:parameterName value:parameterValue urlString:[url absoluteString]]];
}

@end