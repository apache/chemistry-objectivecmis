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

#import "CMISBrowserDiscoveryService.h"

@implementation CMISBrowserDiscoveryService

- (CMISRequest*)query:(NSString *)statement searchAllVersions:(BOOL)searchAllVersions
        relationships:(CMISIncludeRelationship)relationships
      renditionFilter:(NSString *)renditionFilter
includeAllowableActions:(BOOL)includeAllowableActions
             maxItems:(NSNumber *)maxItems
            skipCount:(NSNumber *)skipCount
      completionBlock:(void (^)(CMISObjectList *objectList, NSError *error))completionBlock
{
    NSString * message = [NSString stringWithFormat:@"%s is not implemented yet", __PRETTY_FUNCTION__];
    NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:message userInfo:nil];
    @throw exception;
}

@end
