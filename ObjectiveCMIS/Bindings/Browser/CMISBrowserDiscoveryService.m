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
#import "CMISRequest.h"
#import "CMISHttpResponse.h"
#import "CMISBrowserTypeCache.h"
#import "CMISBrowserUtil.h"
#import "CMISBroswerFormDataWriter.h"
#import "CMISBrowserConstants.h"
#import "CMISConstants.h"
#import "CMISEnums.h"
#import "CMISURLUtil.h"
#import "CMISStringInOutParameter.h"

@implementation CMISBrowserDiscoveryService

- (CMISRequest*)query:(NSString *)statement
    searchAllVersions:(BOOL)searchAllVersions
        relationships:(CMISIncludeRelationship)relationships
      renditionFilter:(NSString *)renditionFilter
includeAllowableActions:(BOOL)includeAllowableActions
             maxItems:(NSNumber *)maxItems
            skipCount:(NSNumber *)skipCount
      completionBlock:(void (^)(CMISObjectList *objectList, NSError *error))completionBlock
{
    NSString *url = [self retrieveRepositoryUrl];

    // prepare form data
    CMISBroswerFormDataWriter *formData = [[CMISBroswerFormDataWriter alloc] initWithAction:kCMISBrowserJSONActionQuery];
    [formData addParameter:kCMISParameterStatement value:statement];
    [formData addParameter:kCMISParameterSearchAllVersions boolValue:searchAllVersions];
    [formData addParameter:kCMISParameterIncludeAllowableActions boolValue:includeAllowableActions];
    [formData addParameter:kCMISParameterIncludeRelationships value:[CMISEnums stringForIncludeRelationShip:relationships]];
    [formData addParameter:kCMISParameterRenditionFilter value:renditionFilter];
    [formData addParameter:kCMISParameterMaxItems value:maxItems];
    [formData addParameter:kCMISParameterSkipCount value:skipCount];
    // Important: No succinct flag here!!!
    
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    
    [self.bindingSession.networkProvider invokePOST:[NSURL URLWithString:url]
                                            session:self.bindingSession
                                               body:formData.body
                                            headers:formData.headers
                                        cmisRequest:cmisRequest
                                    completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if ((httpResponse.statusCode == 200 || httpResponse.statusCode == 201) && httpResponse.data) {
                                           CMISBrowserTypeCache *typeCache = [[CMISBrowserTypeCache alloc] initWithRepositoryId:self.bindingSession.repositoryId bindingService:self];
                                           [CMISBrowserUtil objectListFromJSONData:httpResponse.data typeCache:typeCache isQueryResult:YES completionBlock:^(CMISObjectList *objectList, NSError *error) {
                                               if (error) {
                                                   completionBlock(nil, error);
                                               } else {
                                                   completionBlock(objectList, nil);
                                               }
                                           }];
                                       } else {
                                           completionBlock(nil, error);
                                       }
                                   }];
    return cmisRequest;
}

- (CMISRequest *)retrieveContentChanges:(CMISStringInOutParameter *)changeLogTokenParam
                     includeProperties:(BOOL)includeProperties
                                filter:(NSString *)filter
                      includePolicyIds:(BOOL)includePolicyIds
                            includeAcl:(BOOL)includeAcl
                              maxItems:(NSNumber *)maxItems
                       completionBlock:(void (^)(CMISObjectList *, NSError *))completionBlock
{
    // build url
    NSString *url = [self retrieveRepositoryUrlWithSelector:kCMISBrowserJSONSelectorContentChanges];
    url = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeLogToken value:changeLogTokenParam.inParameter urlString:url];
    url = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeProperties boolValue:includeProperties urlString:url];
    url = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter value:filter urlString:url];
    url = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludePolicyIds boolValue:includePolicyIds urlString:url];
    url = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAcl boolValue:includeAcl urlString:url];
    url = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterMaxItems numberValue:maxItems urlString:url];
    url = [CMISURLUtil urlStringByAppendingParameter:kCMISBrowserJSONParameterSuccinct value:kCMISParameterValueTrue urlString:url];
    
    // read and parse
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    [self.bindingSession.networkProvider invokeGET:[NSURL URLWithString:url]
                                           session:self.bindingSession
                                       cmisRequest:cmisRequest
                                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if (httpResponse.statusCode == 200 && httpResponse.data) {
                                           NSError *parsingError = nil;
                                           NSString *token = [CMISBrowserUtil objectListChangeLogTokenFromJSONData:httpResponse.data error:&parsingError];
                                           if (parsingError) {
                                               completionBlock(nil, parsingError);
                                           } else {
                                               changeLogTokenParam.outParameter = token;
                                               
                                               CMISBrowserTypeCache *typeCache = [[CMISBrowserTypeCache alloc] initWithRepositoryId:self.bindingSession.repositoryId bindingService:self];
                                               [CMISBrowserUtil objectListFromJSONData:httpResponse.data typeCache:typeCache isQueryResult:NO completionBlock:^(CMISObjectList *objectList, NSError *objectListParseError) {
                                                   if (objectListParseError) {
                                                       completionBlock(nil, objectListParseError);
                                                   } else {
                                                       completionBlock(objectList, nil);
                                                   }
                                               }];
                                           }
                                       } else {
                                           completionBlock(nil, error);
                                       }
                                   }];
    return cmisRequest;
}

@end
