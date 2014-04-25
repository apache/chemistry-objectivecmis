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

#import "CMISBrowserVersioningService.h"
#import "CMISRequest.h"
#import "CMISBrowserConstants.h"
#import "CMISHttpResponse.h"
#import "CMISBrowserUtil.h"
#import "CMISURLUtil.h"
#import "CMISConstants.h"

@implementation CMISBrowserVersioningService

- (CMISRequest*)retrieveObjectOfLatestVersion:(NSString *)objectId
                                        major:(BOOL)major
                                       filter:(NSString *)filter
                                relationships:(CMISIncludeRelationship)relationships
                             includePolicyIds:(BOOL)includePolicyIds
                              renditionFilter:(NSString *)renditionFilter
                                   includeACL:(BOOL)includeACL
                      includeAllowableActions:(BOOL)includeAllowableActions
                              completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    NSString *objectUrl = [self getObjectUrlObjectId:objectId selector:kCMISBrowserJSONSelectorObject];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter value:filter urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAllowableActions boolValue:includeAllowableActions urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeRelationships value:[CMISEnums stringForIncludeRelationShip:relationships] urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterRenditionFilter value:renditionFilter urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludePolicyIds boolValue:includePolicyIds urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAcl boolValue:includeACL urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterReturnVersion value:[CMISEnums stringForReturnVersion:major] urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISBrowserJSONParameterSuccinct value:kCMISParameterValueTrue urlString:objectUrl];
    
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    
    [self.bindingSession.networkProvider invokeGET:[NSURL URLWithString:objectUrl]
                                           session:self.bindingSession
                                       cmisRequest:cmisRequest
                                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if (httpResponse.statusCode == 200 && httpResponse.data) {
                                           CMISTypeCache *typeCache = [[CMISTypeCache alloc] initWithRepositoryId:self.bindingSession.repositoryId bindingService:self];
                                           NSError *parsingError = nil;
                                           [CMISBrowserUtil objectDataFromJSONData:httpResponse.data typeCache:typeCache completionBlock:^(CMISObjectData *objectData, NSError *error) {
                                               if (error) {
                                                   completionBlock(nil, parsingError);
                                               } else {
                                                   completionBlock(objectData, nil);
                                               }
                                           }];
                                          
                                       } else {
                                           completionBlock(nil, error);
                                       }
                                   }];
    
    return cmisRequest;
}

- (CMISRequest*)retrieveAllVersions:(NSString *)objectId
                             filter:(NSString *)filter
            includeAllowableActions:(BOOL)includeAllowableActions
                    completionBlock:(void (^)(NSArray *objects, NSError *error))completionBlock
{    
    NSString *objectUrl = [self getObjectUrlObjectId:objectId selector:kCMISBrowserJSONSelectorVersions];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter value:filter urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAllowableActions value:(includeAllowableActions ? @"true" : @"false") urlString:objectUrl];
    objectUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISBrowserJSONParameterSuccinct value:@"true" urlString:objectUrl];
    
    CMISRequest *cmisRequest = [[CMISRequest alloc] init];
    
    [self.bindingSession.networkProvider invokeGET:[NSURL URLWithString:objectUrl]
                                           session:self.bindingSession
                                       cmisRequest:cmisRequest
                                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                       if (httpResponse.statusCode == 200 && httpResponse.data) {
                                           CMISTypeCache *typeCache = [[CMISTypeCache alloc] initWithRepositoryId:self.bindingSession.repositoryId bindingService:self];
                                           [CMISBrowserUtil objectListFromJSONData:httpResponse.data typeCache:typeCache isQueryResult:NO completionBlock:^(CMISObjectList *objectList, NSError *error) {
                                               if (error) {
                                                   completionBlock(nil, error);
                                               } else {
                                                   completionBlock(objectList.objects, nil);
                                               }
                                           }];
                                       } else {
                                           completionBlock(nil, error);
                                       }
                                   }];
    
    return cmisRequest;
}

/**
 * Create a private working copy of a document given an object identifier.
 *
 * @param objectId
 * @param completionBlock returns PWC object data or nil
 */
- (CMISRequest*)checkOut:(NSString *)objectId
         completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    NSString * message = [NSString stringWithFormat:@"%s is not implemented yet", __PRETTY_FUNCTION__];
    NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:message userInfo:nil];
    @throw exception;
}

/**
 * Reverses the effect of a check-out.
 *
 * @param objectId
 * @param completionBlock returns object data or nil
 */
- (CMISRequest*)cancelCheckOut:(NSString *)objectId
               completionBlock:(void (^)(BOOL checkOutCancelled, NSError *error))completionBlock
{
    NSString * message = [NSString stringWithFormat:@"%s is not implemented yet", __PRETTY_FUNCTION__];
    NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:message userInfo:nil];
    @throw exception;
}

/**
 * Checks-in the private working copy (PWC) document from the given path.
 *
 * @param objectId the identifier for the PWC
 * @param asMajorVersion indicator if the new version should become a major (YES) or minor (NO) version
 * @param filePath (optional) Path to the file containing the content to be uploaded
 * @param mimeType (optional) Mime type of the content to be uploaded
 * @param properties (optional) the property values that must be applied to the checked-in document object
 * @param checkinComment (optional) a version comment
 * @param completionBlock returns object data or nil
 * @param progressBlock periodic file upload status
 */
- (CMISRequest*)checkIn:(NSString *)objectId
         asMajorVersion:(BOOL)asMajorVersion
               filePath:(NSString *)filePath
               mimeType:(NSString *)mimeType
             properties:(CMISProperties *)properties
         checkinComment:(NSString *)checkinComment
        completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
          progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSString * message = [NSString stringWithFormat:@"%s is not implemented yet", __PRETTY_FUNCTION__];
    NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:message userInfo:nil];
    @throw exception;
}

/**
 * Checks-in the private working copy (PWC) document from the given an input stream.
 *
 * @param objectId the identifier for the PWC
 * @param asMajorVersion indicator if the new version should become a major (YES) or minor (NO) version
 * @param inputStream (optional) Input stream containing the content to be uploaded
 * @param bytesExpected The size of content to be uploaded (must be provided if an inputStream is given)
 * @param mimeType (optional) Mime type of the content to be uploaded
 * @param properties (optional) the property values that must be applied to the checked-in document object
 * @param checkinComment (optional) a version comment
 * @param completionBlock returns object data or nil
 * @param progressBlock periodic file upload status
 */
- (CMISRequest*)checkIn:(NSString *)objectId
         asMajorVersion:(BOOL)asMajorVersion
            inputStream:(NSInputStream *)inputStream
          bytesExpected:(unsigned long long)bytesExpected
               mimeType:(NSString *)mimeType
             properties:(CMISProperties *)properties
         checkinComment:(NSString *)checkinComment
        completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
          progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSString * message = [NSString stringWithFormat:@"%s is not implemented yet", __PRETTY_FUNCTION__];
    NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:message userInfo:nil];
    @throw exception;
}

@end
