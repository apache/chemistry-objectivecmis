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

#import "CMISAtomPubBaseService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISHttpResponse.h"
#import "CMISServiceDocumentParser.h"
#import "CMISConstants.h"
#import "CMISAtomEntryParser.h"
#import "CMISWorkspace.h"
#import "CMISErrors.h"
#import "CMISObjectByPathUriBuilder.h"
#import "CMISTypeByIdUriBuilder.h"
#import "CMISLinkCache.h"
#import "CMISLog.h"

@interface CMISAtomPubBaseService ()

@property (nonatomic, strong, readwrite) CMISBindingSession *bindingSession;
@property (nonatomic, strong, readwrite) NSURL *atomPubUrl;

@end

@implementation CMISAtomPubBaseService


- (id)initWithBindingSession:(CMISBindingSession *)session
{
    self = [super init];
    if (self) {
        self.bindingSession = session;
        self.atomPubUrl = [session objectForKey:kCMISBindingSessionKeyAtomPubUrl];
    }
    return self;
}


#pragma mark -
#pragma mark Protected methods

- (void)retrieveFromCache:(NSString *)cacheKey
              cmisRequest:(CMISRequest *)cmisRequest
          completionBlock:(void (^)(id object, NSError *error))completionBlock
{
    id object = [self.bindingSession objectForKey:cacheKey];

    if (object) {
        completionBlock(object, nil);
        return;
    } else {
         // if object is nil, first populate cache
        [self fetchRepositoryInfoWithCMISRequest:cmisRequest completionBlock:^(NSError *error) {
            id object = [self.bindingSession objectForKey:cacheKey];
            if (!object && !error) {
                // TODO: proper error initialisation
                error = [[NSError alloc] init];
                CMISLogDebug(@"Could not get object from cache with key '%@'", cacheKey);
            }
            completionBlock(object, error);
        }];        
    }
}

- (void)fetchRepositoryInfoWithCMISRequest:(CMISRequest *)cmisRequest
                           completionBlock:(void (^)(NSError *error))completionBlock
{
    [self retrieveCMISWorkspacesWithCMISRequest:cmisRequest completionBlock:^(NSArray *cmisWorkSpaces, NSError *error) {
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
                CMISLogError(@"No matching repository found for repository id %@", self.bindingSession.repositoryId);
                // TODO: populate error properly
                NSString *detailedDescription = [NSString stringWithFormat:@"No matching repository found for repository id %@", self.bindingSession.repositoryId];
                error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNoRepositoryFound detailedDescription:detailedDescription];
            }
        }
        completionBlock(error);
    }];
}

- (void)retrieveCMISWorkspacesWithCMISRequest:(CMISRequest *)cmisRequest
                              completionBlock:(void (^)(NSArray *workspaces, NSError *error))completionBlock
{
    if ([self.bindingSession objectForKey:kCMISSessionKeyWorkspaces]) {
        completionBlock([self.bindingSession objectForKey:kCMISSessionKeyWorkspaces], nil);
    } else {
        [self.bindingSession.networkProvider invokeGET:self.atomPubUrl
                                               session:self.bindingSession
                                           cmisRequest:cmisRequest
                                       completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                           if (httpResponse) {
                                               NSData *data = httpResponse.data;
                                               // Uncomment to see the service document
                                               //        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                               //        CMISLogDebug(@"Service document: %@", dataString);
                                               
                                               // Parse the cmis service document
                                               if (data) {
                                                   CMISServiceDocumentParser *parser = [[CMISServiceDocumentParser alloc] initWithData:data];
                                                   NSError *error = nil;
                                                   if ([parser parseAndReturnError:&error]) {
                                                       [self.bindingSession setObject:parser.workspaces forKey:kCMISSessionKeyWorkspaces];
                                                   } else {
                                                       CMISLogError(@"Error while parsing service document: %@", error.description);
                                                   }
                                                   completionBlock(parser.workspaces, error);
                                               }
                                           } else {
                                               completionBlock(nil, error);
                                           }
                                       }];
    }
}

- (void)retrieveObjectInternal:(NSString *)objectId
                   cmisRequest:(CMISRequest *)cmisRequest
               completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    return [self retrieveObjectInternal:objectId
                          returnVersion:NOT_PROVIDED
                                 filter:@""
                          relationships:CMISIncludeRelationshipNone
                       includePolicyIds:NO
                        renditionFilder:nil
                             includeACL:NO
                includeAllowableActions:YES
                            cmisRequest:cmisRequest
                        completionBlock:completionBlock];
}


- (void)retrieveObjectInternal:(NSString *)objectId
                 returnVersion:(CMISReturnVersion)returnVersion
                        filter:(NSString *)filter
                 relationships:(CMISIncludeRelationship)relationships
              includePolicyIds:(BOOL)includePolicyIds
               renditionFilder:(NSString *)renditionFilter
                    includeACL:(BOOL)includeACL
       includeAllowableActions:(BOOL)includeAllowableActions
                   cmisRequest:(CMISRequest *)cmisRequest
               completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveFromCache:kCMISBindingSessionKeyObjectByIdUriBuilder
                cmisRequest:cmisRequest
            completionBlock:^(id object, NSError *error) {
        CMISObjectByIdUriBuilder *objectByIdUriBuilder = object;
        objectByIdUriBuilder.objectId = objectId;
        objectByIdUriBuilder.filter = filter;
        objectByIdUriBuilder.includeACL = includeACL;
        objectByIdUriBuilder.includeAllowableActions = includeAllowableActions;
        objectByIdUriBuilder.includePolicyIds = includePolicyIds;
        objectByIdUriBuilder.relationships = relationships;
        objectByIdUriBuilder.renditionFilter = renditionFilter;
        objectByIdUriBuilder.returnVersion = returnVersion;
        NSURL *objectIdUrl = [objectByIdUriBuilder buildUrl];
        
        // Execute actual call
        [self.bindingSession.networkProvider invokeGET:objectIdUrl
                                               session:self.bindingSession
                                           cmisRequest:cmisRequest
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
                            [linkCache addLinks:objectData.linkRelations objectId:objectData.identifier];
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
                              filter:(NSString *)filter
                       relationships:(CMISIncludeRelationship)relationships
                    includePolicyIds:(BOOL)includePolicyIds
                     renditionFilder:(NSString *)renditionFilter
                          includeACL:(BOOL)includeACL
             includeAllowableActions:(BOOL)includeAllowableActions
                         cmisRequest:(CMISRequest *)cmisRequest
                     completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveFromCache:kCMISBindingSessionKeyObjectByPathUriBuilder
                cmisRequest:cmisRequest
            completionBlock:^(id object, NSError *error) {
        CMISObjectByPathUriBuilder *objectByPathUriBuilder = object;
        objectByPathUriBuilder.path = path;
        objectByPathUriBuilder.filter = filter;
        objectByPathUriBuilder.includeACL = includeACL;
        objectByPathUriBuilder.includeAllowableActions = includeAllowableActions;
        objectByPathUriBuilder.includePolicyIds = includePolicyIds;
        objectByPathUriBuilder.relationships = relationships;
        objectByPathUriBuilder.renditionFilter = renditionFilter;
        
        // Execute actual call
        [self.bindingSession.networkProvider invokeGET:[objectByPathUriBuilder buildUrl]
                                               session:self.bindingSession
                                           cmisRequest:cmisRequest
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
                            [linkCache addLinks:objectData.linkRelations objectId:objectData.identifier];
                        }
                        completionBlock(objectData, error);
                    }
                } else {
                    completionBlock(nil, error);
                }
            }];
    }];
}

- (CMISLinkCache *)linkCache
{
    CMISLinkCache *linkCache = [self.bindingSession objectForKey:kCMISBindingSessionKeyLinkCache];
    if (linkCache == nil) {
        linkCache = [[CMISLinkCache alloc] initWithBindingSession:self.bindingSession];
        [self.bindingSession setObject:linkCache forKey:kCMISBindingSessionKeyLinkCache];
    }
    return linkCache;
}

- (void)clearCacheFromService
{
    CMISLinkCache *linkCache = [self.bindingSession objectForKey:kCMISBindingSessionKeyLinkCache];
    if (linkCache != nil) {
        [linkCache removeAllLinks];
    }    
}


- (void)loadLinkForObjectId:(NSString *)objectId
                   relation:(NSString *)rel
                cmisRequest:(CMISRequest *)cmisRequest
            completionBlock:(void (^)(NSString *link, NSError *error))completionBlock
{
    [self loadLinkForObjectId:objectId relation:rel type:nil cmisRequest:cmisRequest completionBlock:completionBlock];
}

- (void)loadLinkForObjectId:(NSString *)objectId
                   relation:(NSString *)rel
                       type:(NSString *)type
                cmisRequest:(CMISRequest *)cmisRequest
            completionBlock:(void (^)(NSString *link, NSError *error))completionBlock
{
    CMISLinkCache *linkCache = [self linkCache];
    
    // Fetch link from cache
    NSString *link = [linkCache linkForObjectId:objectId relation:rel type:type];
    if (link) {
        completionBlock(link, nil);
        return;///shall we return nil here
    } else {
        // Fetch object, which will trigger the caching of the links
        [self retrieveObjectInternal:objectId
                                      cmisRequest:cmisRequest
                                  completionBlock:^(CMISObjectData *objectData, NSError *error) {
            if (error) {
                CMISLogDebug(@"Could not retrieve object with id %@", objectId);
                completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
            } else {
                NSString *link = [linkCache linkForObjectId:objectId relation:rel type:type];
                if (link == nil) {
                    completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound
                                                         detailedDescription:[NSString stringWithFormat:@"Could not find link '%@' for object with id %@", rel, objectId]]);
                } else {
                    completionBlock(link, nil);
                }
            }
        }];
    }
}

@end
