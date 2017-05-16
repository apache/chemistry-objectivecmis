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

#import "CMISOAuthHttpResponse.h"
#import "CMISErrors.h"

@implementation CMISOAuthHttpResponse

- (NSString*)exception
{
    NSString *exception = [self responseValueForKey:@"error"];
    return exception;
}


- (NSString*)errorMessage
{
    NSString *message = [self responseValueForKey:@"error_description"];
    return message;
}

+ (NSDictionary *)parseResponse:(CMISHttpResponse *)httpResponse error:(NSError **)outError
{
    NSDictionary *jsonDictionary = nil;
    
    NSError *serialisationError = nil;
    id jsonResponse = [NSJSONSerialization JSONObjectWithData:httpResponse.data options:0 error:&serialisationError];
    
    if (!serialisationError) {
        if ([jsonResponse isKindOfClass:NSDictionary.class]) {
            jsonDictionary = (NSDictionary *)jsonResponse;
        } else {
            if (outError != NULL) *outError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime detailedDescription:@"Invalid response!"];
        }
    } else {
        if (outError != NULL) *outError = [CMISErrors cmisError:serialisationError cmisErrorCode:kCMISErrorCodeRuntime];
    }
    
    return jsonDictionary;
}

@end
