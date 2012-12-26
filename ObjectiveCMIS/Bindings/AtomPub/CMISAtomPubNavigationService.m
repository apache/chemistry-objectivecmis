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

#import "CMISAtomPubNavigationService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISAtomFeedParser.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISErrors.h"
#import "CMISURLUtil.h"
#import "CMISObjectList.h"

@implementation CMISAtomPubNavigationService


- (void)retrieveChildren:(NSString *)objectId orderBy:(NSString *)orderBy
                  filter:(NSString *)filter includeRelationShips:(CMISIncludeRelationship)includeRelationship
         renditionFilter:(NSString *)renditionFilter includeAllowableActions:(BOOL)includeAllowableActions
      includePathSegment:(BOOL)includePathSegment skipCount:(NSNumber *)skipCount
                maxItems:(NSNumber *)maxItems
         completionBlock:(void (^)(CMISObjectList *objectList, NSError *error))completionBlock
{
    // Get Down link
    [self loadLinkForObjectId:objectId andRelation:kCMISLinkRelationDown
                      andType:kCMISMediaTypeChildren completionBlock:^(NSString *downLink, NSError *error) {
                          if (error)
                          {
                              log(@"Could not retrieve down link: %@", error.description);
                              completionBlock(nil, error);
                              return;
                          }
                          
                          // Add optional params (CMISUrlUtil will not append if the param name or value is nil)
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter withValue:filter toUrlString:downLink];
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterOrderBy withValue:orderBy toUrlString:downLink];
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAllowableActions withValue:(includeAllowableActions ? @"true" : @"false") toUrlString:downLink];
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeRelationships withValue:[CMISEnums stringForIncludeRelationShip:includeRelationship] toUrlString:downLink];
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterRenditionFilter withValue:renditionFilter toUrlString:downLink];
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludePathSegment withValue:(includePathSegment ? @"true" : @"false") toUrlString:downLink];
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterMaxItems withValue:[maxItems stringValue] toUrlString:downLink];
                          downLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterSkipCount withValue:[skipCount stringValue] toUrlString:downLink];
                          
                          // execute the request
                          [HttpUtil invokeGET:[NSURL URLWithString:downLink]
                                  withSession:self.bindingSession
                              completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                  if (httpResponse) {
                                      if (httpResponse.data == nil) {
                                          NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection withDetailedDescription:nil];
                                          completionBlock(nil, error);
                                          return;
                                      }
                                      
                                      // Parse the feed (containing entries for the children) you get back
                                      CMISAtomFeedParser *parser = [[CMISAtomFeedParser alloc] initWithData:httpResponse.data];
                                      NSError *internalError = nil;
                                      if ([parser parseAndReturnError:&internalError])
                                      {
                                          NSString *nextLink = [parser.linkRelations linkHrefForRel:kCMISLinkRelationNext];
                                          
                                          CMISObjectList *objectList = [[CMISObjectList alloc] init];
                                          objectList.hasMoreItems = (nextLink != nil);
                                          objectList.numItems = parser.numItems;
                                          objectList.objects = parser.entries;
                                          completionBlock(objectList, nil);
                                      }
                                      else
                                      {
                                          NSError *error = [CMISErrors cmisError:internalError withCMISErrorCode:kCMISErrorCodeRuntime];
                                          completionBlock(nil, error);
                                      }
                                  } else {
                                      completionBlock(nil, error);
                                  }
                              }];
                      }];
}

- (void)retrieveParentsForObject:(NSString *)objectId
                           withFilter:(NSString *)filter
             withIncludeRelationships:(CMISIncludeRelationship)includeRelationship
                  withRenditionFilter:(NSString *)renditionFilter
          withIncludeAllowableActions:(BOOL)includeAllowableActions
       withIncludeRelativePathSegment:(BOOL)includeRelativePathSegment
                      completionBlock:(void (^)(NSArray *parents, NSError *error))completionBlock
{
    // Get up link
    [self loadLinkForObjectId:objectId andRelation:kCMISLinkRelationUp completionBlock:^(NSString *upLink, NSError *error) {
        if (upLink == nil) {
            log(@"Failing because the NSString upLink is nil");
            completionBlock([NSArray array], nil); // TODO: shouldn't this return an error if the log talks about 'failing'?
            return;
        }
        
        // Add optional parameters
        if (filter != nil)
        {
            upLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterFilter withValue:filter toUrlString:upLink];
        }
        upLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeAllowableActions withValue:(includeAllowableActions ? @"true" : @"false") toUrlString:upLink];
        upLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterIncludeRelationships withValue:[CMISEnums stringForIncludeRelationShip:includeRelationship] toUrlString:upLink];
        
        if (renditionFilter != nil)
        {
            upLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterRenditionFilter withValue:renditionFilter toUrlString:upLink];
        }
        
        upLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterRelativePathSegment withValue:(includeRelativePathSegment ? @"true" : @"false") toUrlString:upLink];
        
        [HttpUtil invokeGET:[NSURL URLWithString:upLink]
                withSession:self.bindingSession
            completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                if (httpResponse) {
                    CMISAtomFeedParser *parser = [[CMISAtomFeedParser alloc] initWithData:httpResponse.data];
                    NSError *internalError;
                    if (![parser parseAndReturnError:&internalError])
                    {
                        NSError *error = [CMISErrors cmisError:internalError withCMISErrorCode:kCMISErrorCodeRuntime];
                        log(@"Failing because parsing the Atom Feed XML returns an error");
                        completionBlock([NSArray array], error);
                    } else {
                        completionBlock(parser.entries, nil);
                    }
                } else {
                    log(@"Failing because the invokeGET returns an error");
                    completionBlock([NSArray array], error);
                }
            }];
    }];
}

@end
