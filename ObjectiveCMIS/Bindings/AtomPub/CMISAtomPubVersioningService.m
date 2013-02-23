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

#import "CMISAtomPubVersioningService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISAtomPubConstants.h"
#import "CMISHttpResponse.h"
#import "CMISAtomFeedParser.h"
#import "CMISErrors.h"
#import "CMISURLUtil.h"
#import "CMISLog.h"

@implementation CMISAtomPubVersioningService

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
    CMISRequest *request = [[CMISRequest alloc] init];
    [self retrieveObjectInternal:objectId
                   returnVersion:(major ? LATEST_MAJOR : LATEST)
                          filter:filter
                   relationships:relationships
                includePolicyIds:includePolicyIds
                 renditionFilder:renditionFilter
                      includeACL:includeACL
         includeAllowableActions:includeAllowableActions
                     cmisRequest:request
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     completionBlock(objectData, error);
                 }];
    return request;
}

- (CMISRequest*)retrieveAllVersions:(NSString *)objectId
                             filter:(NSString *)filter
            includeAllowableActions:(BOOL)includeAllowableActions
                    completionBlock:(void (^)(NSArray *objects, NSError *error))completionBlock
{
    // Validate params
    if (!objectId) {
        CMISLogError(@"Must provide an objectId when retrieving all versions");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound detailedDescription:nil]);
        return nil;
    }
    CMISRequest *request = [[CMISRequest alloc] init];
    
    // Fetch version history link
    [self loadLinkForObjectId:objectId
                     relation:kCMISLinkVersionHistory
                  cmisRequest:request
              completionBlock:^(NSString *versionHistoryLink, NSError *error) {
        if (error) {
            completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
            return;
        }
        
        if (filter) {
            versionHistoryLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter value:filter urlString:versionHistoryLink];
        }
        versionHistoryLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAllowableActions
                                                              value:(includeAllowableActions ? @"true" : @"false") urlString:versionHistoryLink];
        
        // Execute call
        [self.bindingSession.networkProvider invokeGET:[NSURL URLWithString:versionHistoryLink]
                                               session:self.bindingSession
                                           cmisRequest:request
                                       completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                if (httpResponse) {
                    NSData *data = httpResponse.data;
                    CMISAtomFeedParser *feedParser = [[CMISAtomFeedParser alloc] initWithData:data];
                    NSError *error;
                    if (![feedParser parseAndReturnError:&error]) {
                        completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeVersioning]);
                    } else {
                        completionBlock(feedParser.entries, nil);
                    }
                } else {
                    completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
                }
            }];
    }];
    return request;
}

@end