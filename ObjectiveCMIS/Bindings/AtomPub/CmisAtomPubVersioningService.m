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

#import "CMISAtomPubVersioningService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISAtomPubConstants.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISAtomFeedParser.h"
#import "CMISErrors.h"
#import "CMISURLUtil.h"

@implementation CMISAtomPubVersioningService

- (void)retrieveObjectOfLatestVersion:(NSString *)objectId
                                major:(BOOL)major
                               filter:(NSString *)filter
                 includeRelationShips:(CMISIncludeRelationship)includeRelationships
                     includePolicyIds:(BOOL)includePolicyIds
                      renditionFilter:(NSString *)renditionFilter
                           includeACL:(BOOL)includeACL
              includeAllowableActions:(BOOL)includeAllowableActions
                      completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectInternal:objectId withReturnVersion:(major ? LATEST_MAJOR : LATEST)
                      withFilter:filter andIncludeRelationShips:includeRelationships
             andIncludePolicyIds:includePolicyIds andRenditionFilder:renditionFilter
                   andIncludeACL:includeACL andIncludeAllowableActions:includeAllowableActions
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     completionBlock(objectData, error);
                 }];
}

- (void)retrieveAllVersions:(NSString *)objectId
                     filter:(NSString *)filter
    includeAllowableActions:(BOOL)includeAllowableActions
            completionBlock:(void (^)(NSArray *objects, NSError *error))completionBlock
{
    // Validate params
    if (!objectId)
    {
        log(@"Must provide an objectId when retrieving all versions");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound withDetailedDescription:nil]);
        return;
    }
    
    // Fetch version history link
    [self loadLinkForObjectId:objectId andRelation:kCMISLinkVersionHistory completionBlock:^(NSString *versionHistoryLink, NSError *error) {
        if (error) {
            completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
            return;
        }
        
        if (filter) {
            versionHistoryLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter withValue:filter toUrlString:versionHistoryLink];
        }
        versionHistoryLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAllowableActions
                                                              withValue:(includeAllowableActions ? @"true" : @"false") toUrlString:versionHistoryLink];
        
        // Execute call
        [HttpUtil invokeGET:[NSURL URLWithString:versionHistoryLink]
                withSession:self.bindingSession
            completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                if (httpResponse) {
                    NSData *data = httpResponse.data;
                    CMISAtomFeedParser *feedParser = [[CMISAtomFeedParser alloc] initWithData:data];
                    NSError *error;
                    if (![feedParser parseAndReturnError:&error]) {
                        completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeVersioning]);
                    } else {
                        completionBlock(feedParser.entries, nil);
                    }
                } else {
                    completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
                }
            }];
    }];
}

@end