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

#import "CMISBrowserNavigationService.h"
#import "CMISRequest.h"
#import "CMISHttpResponse.h"
#import "CMISConstants.h"
#import "CMISBrowserUtil.h"
#import "CMISBrowserConstants.h"
#import "CMISURLUtil.h"

@implementation CMISBrowserNavigationService

- (CMISRequest*)retrieveChildren:(NSString *)objectId
                         orderBy:(NSString *)orderBy
                          filter:(NSString *)filter
                   relationships:(CMISIncludeRelationship)relationships
                 renditionFilter:(NSString *)renditionFilter
         includeAllowableActions:(BOOL)includeAllowableActions
              includePathSegment:(BOOL)includePathSegment
                       skipCount:(NSNumber *)skipCount
                        maxItems:(NSNumber *)maxItems
                 completionBlock:(void (^)(CMISObjectList *objectList, NSError *error))completionBlock
{
    NSString *objectUrl = [self getObjectUrlObjectId:objectId selector:kCMISBrowserJSONSelectorChildren];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter value:filter urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterOrderBy value:orderBy urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAllowableActions boolValue:includeAllowableActions urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeRelationships value:[CMISEnums stringForIncludeRelationShip:relationships] urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterRenditionFilter value:renditionFilter urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludePathSegment boolValue:includePathSegment urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterMaxItems numberValue:maxItems urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterSkipCount numberValue:skipCount urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterSuccinct value:kCMISParameterValueTrue urlString:objectUrl];
    
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    
    [self.bindingSession.networkProvider invokeGET:[NSURL URLWithString:objectUrl]
                                           session:self.bindingSession
                                       cmisRequest:cmisRequest
                                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if (httpResponse) {
                                           NSData *data = httpResponse.data;
                                           if (data) {
                                               NSError *parsingError = nil;
                                               CMISObjectList *objectList = [CMISBrowserUtil objectListFromJSONData:data error:&parsingError];
                                               if (parsingError)
                                               {
                                                   completionBlock(nil, parsingError);
                                               } else {
                                                   completionBlock(objectList, nil);
                                               }
                                           }
                                       } else {
                                           completionBlock(nil, error);
                                       }
                                   }];
    
    return cmisRequest;
}


- (CMISRequest*)retrieveParentsForObject:(NSString *)objectId
                                  filter:(NSString *)filter
                           relationships:(CMISIncludeRelationship)relationships
                         renditionFilter:(NSString *)renditionFilter
                 includeAllowableActions:(BOOL)includeAllowableActions
              includeRelativePathSegment:(BOOL)includeRelativePathSegment
                         completionBlock:(void (^)(NSArray *parents, NSError *error))completionBlock
{
    NSString * message = [NSString stringWithFormat:@"%s is not implemented yet", __PRETTY_FUNCTION__];
    NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:message userInfo:nil];
    @throw exception;
}

@end
