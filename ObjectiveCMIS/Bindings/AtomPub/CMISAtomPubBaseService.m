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

#import "CMISAtomPubBaseService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISServiceDocumentParser.h"
#import "CMISConstants.h"
#import "CMISAtomEntryParser.h"
#import "CMISWorkspace.h"
#import "CMISErrors.h"
#import "CMISObjectByPathUriBuilder.h"
#import "CMISTypeByIdUriBuilder.h"
#import "CMISLinkCache.h"

@interface CMISAtomPubBaseService ()

@property (nonatomic, strong, readwrite) CMISBindingSession *bindingSession;
@property (nonatomic, strong, readwrite) NSURL *atomPubUrl;

@end

@implementation CMISAtomPubBaseService

@synthesize bindingSession = _bindingSession;
@synthesize atomPubUrl = _atomPubUrl;

- (id)initWithBindingSession:(CMISBindingSession *)session
{
    self = [super init];
    if (self)
    {
        self.bindingSession = session;
        
        // pull out and cache all the useful objects for this binding
        self.atomPubUrl = [session objectForKey:kCMISBindingSessionKeyAtomPubUrl];
    }
    return self;
}


#pragma mark -
#pragma mark Protected methods

- (void)retrieveFromCache:(NSString *)cacheKey completionBlock:(void (^)(id object, NSError *error))completionBlock
{
    id object = [self.bindingSession objectForKey:cacheKey];

    if (object) {
        completionBlock(object, nil);
    } else {
         // if object is nil, first populate cache
        [self fetchRepositoryInfoWithCompletionBlock:^(NSError *error) {
            id object = [self.bindingSession objectForKey:cacheKey];
            if (!object && !error) {
                // TODO: proper error initialisation
                error = [[NSError alloc] init];
                log(@"Could not get object from cache with key '%@'", cacheKey);
            }
            completionBlock(object, error);
        }];
    }
}

- (void)fetchRepositoryInfoWithCompletionBlock:(void (^)(NSError *error))completionBlock
{
    [self retrieveCMISWorkspacesWithCompletionBlock:^(NSArray *cmisWorkSpaces, NSError *error) {
        if (!error) {
            BOOL repositoryFound = NO;
            for (CMISWorkspace *workspace in cmisWorkSpaces) {
                if ([workspace.repositoryInfo.identifier isEqualToString:self.bindingSession.repositoryId])
                {
                    repositoryFound = YES;
                    
                    // Cache collections
                    [self.bindingSession setObject:[workspace collectionHrefForCollectionType:kCMISAtomCollectionQuery] forKey:kCMISBindingSessionKeyQueryCollection];
                    
                    
                    // Cache uri's and uri templates
                    CMISObjectByIdUriBuilder *objectByIdUriBuilder = [[CMISObjectByIdUriBuilder alloc] initWithTemplateUrl:workspace.objectByIdUriTemplate];
                    [self.bindingSession setObject:objectByIdUriBuilder forKey:kCMISBindingSessionKeyObjectByIdUriBuilder];
                    
                    CMISObjectByPathUriBuilder *objectByPathUriBuilder = [[CMISObjectByPathUriBuilder alloc] initWithTemplateUrl:workspace.objectByPathUriTemplate];
                    [self.bindingSession setObject:objectByPathUriBuilder forKey:kCMISBindingSessionKeyObjectByPathUriBuilder];
                    
                    CMISTypeByIdUriBuilder *typeByIdUriBuilder = [[CMISTypeByIdUriBuilder alloc] initWithTemplateUrl:workspace.typeByIdUriTemplate];
                    [self.bindingSession setObject:typeByIdUriBuilder forKey:kCMISBindingSessionKeyTypeByIdUriBuilder];
                    
                    [self.bindingSession setObject:workspace.queryUriTemplate forKey:kCMISBindingSessionKeyQueryUri];

                    break;
                }
            }
            
            if (!repositoryFound) {
                log(@"No matching repository found for repository id %@", self.bindingSession.repositoryId);
                // TODO: populate error properly
                NSString *detailedDescription = [NSString stringWithFormat:@"No matching repository found for repository id %@", self.bindingSession.repositoryId];
                error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNoRepositoryFound withDetailedDescription:detailedDescription];
            }
        }
        completionBlock(error);
    }];
}

- (void)retrieveCMISWorkspacesWithCompletionBlock:(void (^)(NSArray *workspaces, NSError *error))completionBlock
{
    if ([self.bindingSession objectForKey:kCMISSessionKeyWorkspaces]) {
        completionBlock([self.bindingSession objectForKey:kCMISSessionKeyWorkspaces], nil);
    } else {
        [HttpUtil invokeGET:self.atomPubUrl
                withSession:self.bindingSession
            completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                if (httpResponse) {
                    NSData *data = httpResponse.data;
                    // Uncomment to see the service document
                    //        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    //        log(@"Service document: %@", dataString);
                    
                    // Parse the cmis service document
                    if (data) {
                        CMISServiceDocumentParser *parser = [[CMISServiceDocumentParser alloc] initWithData:data];
                        NSError *error = nil;
                        if ([parser parseAndReturnError:&error]) {
                            [self.bindingSession setObject:parser.workspaces forKey:kCMISSessionKeyWorkspaces];
                        } else {
                            log(@"Error while parsing service document: %@", error.description);
                        }
                        completionBlock(parser.workspaces, error);
                    }
                } else {
                    completionBlock(nil, error);
                }
            }];
    }
}

- (void)retrieveObjectInternal:(NSString *)objectId completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectInternal:objectId withReturnVersion:NOT_PROVIDED withFilter:@"" andIncludeRelationShips:CMISIncludeRelationshipNone
             andIncludePolicyIds:NO andRenditionFilder:nil andIncludeACL:NO
      andIncludeAllowableActions:YES completionBlock:completionBlock];
}


- (void)retrieveObjectInternal:(NSString *)objectId
             withReturnVersion:(CMISReturnVersion)returnVersion
                    withFilter:(NSString *)filter
       andIncludeRelationShips:(CMISIncludeRelationship)includeRelationship
           andIncludePolicyIds:(BOOL)includePolicyIds
            andRenditionFilder:(NSString *)renditionFilter
                 andIncludeACL:(BOOL)includeACL
    andIncludeAllowableActions:(BOOL)includeAllowableActions
               completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveFromCache:kCMISBindingSessionKeyObjectByIdUriBuilder completionBlock:^(id object, NSError *error) {
        CMISObjectByIdUriBuilder *objectByIdUriBuilder = object;
        objectByIdUriBuilder.objectId = objectId;
        objectByIdUriBuilder.filter = filter;
        objectByIdUriBuilder.includeACL = includeACL;
        objectByIdUriBuilder.includeAllowableActions = includeAllowableActions;
        objectByIdUriBuilder.includePolicyIds = includePolicyIds;
        objectByIdUriBuilder.includeRelationships = includeRelationship;
        objectByIdUriBuilder.renditionFilter = renditionFilter;
        objectByIdUriBuilder.returnVersion = returnVersion;
        NSURL *objectIdUrl = [objectByIdUriBuilder buildUrl];
        
        // Execute actual call
        [HttpUtil invokeGET:objectIdUrl
                withSession:self.bindingSession
            completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                if (httpResponse) {
                    if (httpResponse.statusCode == 200 && httpResponse.data) {
                        CMISObjectData *objectData = nil;
                        NSError *error = nil;
                        CMISAtomEntryParser *parser = [[CMISAtomEntryParser alloc] initWithData:httpResponse.data];
                        if ([parser parseAndReturnError:&error]) {
                            objectData = parser.objectData;
                            
                            // Add links to link cache
                            CMISLinkCache *linkCache = [self linkCache];
                            [linkCache addLinks:objectData.linkRelations forObjectId:objectData.identifier];
                        }
                        completionBlock(objectData, error);
                    }
                } else {
                    completionBlock(nil, error);
                }
            }];
    }];
}

- (void)retrieveObjectByPathInternal:(NSString *)path
                          withFilter:(NSString *)filter
             andIncludeRelationShips:(CMISIncludeRelationship)includeRelationship
                 andIncludePolicyIds:(BOOL)includePolicyIds
                  andRenditionFilder:(NSString *)renditionFilter
                       andIncludeACL:(BOOL)includeACL
          andIncludeAllowableActions:(BOOL)includeAllowableActions
                     completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveFromCache:kCMISBindingSessionKeyObjectByPathUriBuilder completionBlock:^(id object, NSError *error) {
        CMISObjectByPathUriBuilder *objectByPathUriBuilder = object;
        objectByPathUriBuilder.path = path;
        objectByPathUriBuilder.filter = filter;
        objectByPathUriBuilder.includeACL = includeACL;
        objectByPathUriBuilder.includeAllowableActions = includeAllowableActions;
        objectByPathUriBuilder.includePolicyIds = includePolicyIds;
        objectByPathUriBuilder.includeRelationships = includeRelationship;
        objectByPathUriBuilder.renditionFilter = renditionFilter;
        
        // Execute actual call
        [HttpUtil invokeGET:[objectByPathUriBuilder buildUrl]
                withSession:self.bindingSession
            completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                if (httpResponse) {
                    if (httpResponse.statusCode == 200 && httpResponse.data != nil) {
                        CMISObjectData *objectData = nil;
                        NSError *error = nil;
                        CMISAtomEntryParser *parser = [[CMISAtomEntryParser alloc] initWithData:httpResponse.data];
                        if ([parser parseAndReturnError:&error]) {
                            objectData = parser.objectData;
                            
                            // Add links to link cache
                            CMISLinkCache *linkCache = [self linkCache];
                            [linkCache addLinks:objectData.linkRelations forObjectId:objectData.identifier];
                        }
                        completionBlock(objectData, error);
                    }
                } else {
                    completionBlock(nil, error);
                }
            }];
    }];
}

- (CMISLinkCache *)linkCache{
    CMISLinkCache *linkCache = [self.bindingSession objectForKey:kCMISBindingSessionKeyLinkCache];
    if (linkCache == nil)
    {
        linkCache = [[CMISLinkCache alloc] initWithBindingSession:self.bindingSession];
        [self.bindingSession setObject:linkCache forKey:kCMISBindingSessionKeyLinkCache];
    }
    return linkCache;
}

- (void)clearCacheFromService
{
    CMISLinkCache *linkCache = [self.bindingSession objectForKey:kCMISBindingSessionKeyLinkCache];
    if (linkCache != nil)
    {
        [linkCache removeAllLinks];
    }    
}


- (void)loadLinkForObjectId:(NSString *)objectId
                andRelation:(NSString *)rel
            completionBlock:(void (^)(NSString *link, NSError *error))completionBlock
{
    [self loadLinkForObjectId:objectId andRelation:rel andType:nil completionBlock:completionBlock];
}


- (void)loadLinkForObjectId:(NSString *)objectId andRelation:(NSString *)rel andType:(NSString *)type completionBlock:(void (^)(NSString *link, NSError *error))completionBlock
{
    CMISLinkCache *linkCache = [self linkCache];
    
    // Fetch link from cache
    NSString *link = [linkCache linkForObjectId:objectId andRelation:rel andType:type];
    if (link) {
        completionBlock(link, nil);
    } else {
        // Fetch object, which will trigger the caching of the links
        [self retrieveObjectInternal:objectId completionBlock:^(CMISObjectData *objectData, NSError *error) {
            if (error) {
                log(@"Could not retrieve object with id %@", objectId);
                completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
            } else {
                NSString *link = [linkCache linkForObjectId:objectId andRelation:rel andType:type];
                if (link == nil) {
                    completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound
                                                     withDetailedDescription:[NSString stringWithFormat:@"Could not find link '%@' for object with id %@", rel, objectId]]);
                } else {
                    completionBlock(link, nil);
                }
            }
        }];
    }
}

@end
