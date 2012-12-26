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

#import "CMISAtomPubDiscoveryService.h"
#import "CMISQueryAtomEntryWriter.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISAtomPubConstants.h"
#import "CMISAtomFeedParser.h"
#import "CMISObjectList.h"
#import "CMISErrors.h"

@implementation CMISAtomPubDiscoveryService


- (void)query:(NSString *)statement searchAllVersions:(BOOL)searchAllVersions
                                 includeRelationShips:(CMISIncludeRelationship)includeRelationships
                                      renditionFilter:(NSString *)renditionFilter
                            includeAllowableActions:(BOOL)includeAllowableActions
                                           maxItems:(NSNumber *)maxItems
                                          skipCount:(NSNumber *)skipCount
                                    completionBlock:(void (^)(CMISObjectList *objectList, NSError *error))completionBlock;
{
    // Validate params
    if (statement == nil)
    {
        log(@"Must provide 'statement' parameter when executing a cmis query");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        return;
    }
    
    // Validate query uri
    NSString *queryUrlString = [self.bindingSession objectForKey:kCMISBindingSessionKeyQueryCollection];
    if (queryUrlString == nil)
    {
        log(@"Unknown repository or query not supported!");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound withDetailedDescription:nil]);
        return;
    }
    
    NSURL *queryURL = [NSURL URLWithString:queryUrlString];
    // Build XML for query
    CMISQueryAtomEntryWriter *atomEntryWriter = [[CMISQueryAtomEntryWriter alloc] init];
    atomEntryWriter.statement = statement;
    atomEntryWriter.searchAllVersions = searchAllVersions;
    atomEntryWriter.includeAllowableActions = includeAllowableActions;
    atomEntryWriter.includeRelationships = includeRelationships;
    atomEntryWriter.renditionFilter = renditionFilter;
    atomEntryWriter.maxItems = maxItems;
    atomEntryWriter.skipCount = skipCount;
    
    // Execute HTTP call
    [HttpUtil invokePOST:queryURL
             withSession:self.bindingSession
                    body:[[atomEntryWriter generateAtomEntryXML] dataUsingEncoding:NSUTF8StringEncoding]
                 headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeQuery forKey:@"Content-type"]
         completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
             if (httpResponse) {
                 CMISAtomFeedParser *feedParser = [[CMISAtomFeedParser alloc] initWithData:httpResponse.data];
                 NSError *error = nil;
                 if ([feedParser parseAndReturnError:&error]) {
                     NSString *nextLink = [feedParser.linkRelations linkHrefForRel:kCMISLinkRelationNext];
                     
                     CMISObjectList *objectList = [[CMISObjectList alloc] init];
                     objectList.hasMoreItems = (nextLink != nil);
                     objectList.numItems = feedParser.numItems;
                     objectList.objects = feedParser.entries;
                     completionBlock(objectList, nil);
                 } else {
                     completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                 }
             } else {
                 completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
             }
         }];
}

@end