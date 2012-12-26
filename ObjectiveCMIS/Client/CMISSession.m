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

#import "CMISSession.h"
#import "CMISConstants.h"
#import "CMISObjectConverter.h"
#import "CMISStandardAuthenticationProvider.h"
#import "CMISBindingFactory.h"
#import "CMISObjectList.h"
#import "CMISQueryResult.h"
#import "CMISErrors.h"
#import "CMISOperationContext.h"
#import "CMISPagedResult.h"
#import "CMISTypeDefinition.h"

@interface CMISSession ()
@property (nonatomic, strong, readwrite) CMISObjectConverter *objectConverter;
@property (nonatomic, assign, readwrite) BOOL isAuthenticated;
@property (nonatomic, strong, readwrite) id<CMISBinding> binding;
@property (nonatomic, strong, readwrite) CMISRepositoryInfo *repositoryInfo;
// Returns a CMISSession using the given session parameters.
- (id)initWithSessionParameters:(CMISSessionParameters *)sessionParameters;

// Authenticates using the CMISSessionParameters and returns if the authentication was succesful
- (void)authenticateWithCompletionBlock:(void (^)(CMISSession *session, NSError * error))completionBlock;
@end

@interface CMISSession (PrivateMethods)
- (BOOL)authenticateAndReturnError:(NSError **)error;
@end

@implementation CMISSession

@synthesize isAuthenticated = _isAuthenticated;
@synthesize binding = _binding;
@synthesize repositoryInfo = _repositoryInfo;
@synthesize sessionParameters = _sessionParameters;
@synthesize objectConverter = _objectConverter;

#pragma mark -
#pragma mark Setup

+ (void)arrayOfRepositories:(CMISSessionParameters *)sessionParameters completionBlock:(void (^)(NSArray *repositories, NSError *error))completionBlock
{
    CMISSession *session = [[CMISSession alloc] initWithSessionParameters:sessionParameters];
    
    // TODO: validate session parameters?
    
    // return list of repositories
    [session.binding.repositoryService retrieveRepositoriesWithCompletionBlock:completionBlock];
}

+ (void)connectWithSessionParameters:(CMISSessionParameters *)sessionParameters
                     completionBlock:(void (^)(CMISSession *session, NSError * error))completionBlock
{
    CMISSession *session = [[CMISSession alloc] initWithSessionParameters:sessionParameters];
    if (session)
    {
        [session authenticateWithCompletionBlock:completionBlock];
    }
    else
    {
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                         withDetailedDescription:@"Not enough session parameters to connect"]);
    }
}

#pragma internal authentication methods

- (id)initWithSessionParameters:(CMISSessionParameters *)sessionParameters
{
    self = [super init];
    if (self)
    {
        self.sessionParameters = sessionParameters;
        self.isAuthenticated = NO;
    
        // setup authentication provider if not present
        if (self.sessionParameters.authenticationProvider == nil)
        {
            NSString *username = self.sessionParameters.username;
            NSString *password = self.sessionParameters.password;
            if (username == nil || password == nil)
            {
                log(@"No username or password provided for standard authentication provider");
                return nil;
            }
            
            self.sessionParameters.authenticationProvider = [[CMISStandardAuthenticationProvider alloc] initWithUsername:username
                                                                                                             andPassword:password];
        }

        // create the binding the session will use
        CMISBindingFactory *bindingFactory = [[CMISBindingFactory alloc] init];
        self.binding = [bindingFactory bindingWithParameters:sessionParameters];

        id objectConverterClassValue = [self.sessionParameters objectForKey:kCMISSessionParameterObjectConverterClassName];
        if (objectConverterClassValue != nil && [objectConverterClassValue isKindOfClass:[NSString class]])
        {
            NSString *objectConverterClassName = (NSString *)objectConverterClassValue;
            log(@"Using a custom object converter class: %@", objectConverterClassName);
            self.objectConverter = [[NSClassFromString(objectConverterClassName) alloc] initWithSession:self];
        }
        else // default
        {
            self.objectConverter = [[CMISObjectConverter alloc] initWithSession:self];
        }
    
        // TODO: setup locale
        // TODO: setup default session parameters
        // TODO: setup caches
    }
    
    return self;
}

- (void)authenticateWithCompletionBlock:(void (^)(CMISSession *session, NSError * error))completionBlock
{
    // TODO: validate session parameters, extract the checks below?
    
    // check repository id is present
    if (self.sessionParameters.repositoryId == nil)
    {
        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                     withDetailedDescription:@"Must provide repository id"];
        log(@"Error: %@", error.description);
        completionBlock(nil, error);
        return;
    }
    
    if (self.sessionParameters.authenticationProvider == nil) {
        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeUnauthorized withDetailedDescription:@"Must provide authentication provider"];
        log(@"Error: %@", error.description);
        completionBlock(nil, error);
        return;
    }
    
    // TODO: use authentication provider to make sure we have enough credentials, it may need to make another call to get a ticket or do handshake i.e. NTLM.
    
    // get repository info
    [self.binding.repositoryService retrieveRepositoryInfoForId:self.sessionParameters.repositoryId completionBlock:^(CMISRepositoryInfo *repositoryInfo, NSError *error) {
        self.repositoryInfo = repositoryInfo;
        if (self.repositoryInfo == nil)
        {
            if (error)
            {
                log(@"Error because repositoryInfo is nil: %@", error.description);
                completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeInvalidArgument]);
            }
            else
            {
                completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                 withDetailedDescription:@"Could not fetch repository information"]);
            }
        } else {
            // no errors have occurred so set authenticated flag and return success flag
            self.isAuthenticated = YES;
            completionBlock(self, nil);
        }
    }];
}


#pragma mark CMIS operations

- (void)retrieveRootFolderWithCompletionBlock:(void (^)(CMISFolder *folder, NSError *error))completionBlock
{
    [self retrieveFolderWithOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (void)retrieveFolderWithOperationContext:(CMISOperationContext *)operationContext completionBlock:(void (^)(CMISFolder *folder, NSError *error))completionBlock
{
    NSString *rootFolderId = self.repositoryInfo.rootFolderId;
    [self retrieveObject:rootFolderId withOperationContext:operationContext completionBlock:^(CMISObject *rootFolder, NSError *error) {
        if (rootFolder != nil && ![rootFolder isKindOfClass:[CMISFolder class]]) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime withDetailedDescription:@"Root folder object is not a folder!"]);
        } else {
            completionBlock((CMISFolder *)rootFolder, nil);
        }
    }];
}

- (void)retrieveObject:(NSString *)objectId completionBlock:(void (^)(CMISObject *object, NSError *error))completionBlock
{
    [self retrieveObject:objectId withOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (void)retrieveObject:(NSString *)objectId withOperationContext:(CMISOperationContext *)operationContext completionBlock:(void (^)(CMISObject *object, NSError *error))completionBlock
{
    if (objectId == nil)
    {
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Must provide object id"]);
        return;
    }

    // TODO: cache the object

    [self.binding.objectService retrieveObject:objectId
                                    withFilter:operationContext.filterString
                       andIncludeRelationShips:operationContext.includeRelationShips
                           andIncludePolicyIds:operationContext.isIncludePolicies
                            andRenditionFilder:operationContext.renditionFilterString
                                 andIncludeACL:operationContext.isIncluseACLs
                    andIncludeAllowableActions:operationContext.isIncludeAllowableActions
                               completionBlock:^(CMISObjectData *objectData, NSError *error) {
                                            if (error) {
                                                completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
                                            } else {
                                                CMISObject *object = nil;
                                                if (objectData) {
                                                    object = [self.objectConverter convertObject:objectData];
                                                }
                                                completionBlock(object, nil);
                                            }
                                        }];
}

- (void)retrieveObjectByPath:(NSString *)path completionBlock:(void (^)(CMISObject *object, NSError *error))completionBlock
{
    [self retrieveObjectByPath:path withOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (void)retrieveObjectByPath:(NSString *)path withOperationContext:(CMISOperationContext *)operationContext completionBlock:(void (^)(CMISObject *object, NSError *error))completionBlock
{
    [self.binding.objectService retrieveObjectByPath:path
                                          withFilter:operationContext.filterString
                             andIncludeRelationShips:operationContext.includeRelationShips
                                 andIncludePolicyIds:operationContext.isIncludePolicies
                                  andRenditionFilder:operationContext.renditionFilterString
                                       andIncludeACL:operationContext.isIncluseACLs
                          andIncludeAllowableActions:operationContext.isIncludeAllowableActions
                                     completionBlock:^(CMISObjectData *objectData, NSError *error) {
                                         if (objectData != nil && error == nil) {
                                             completionBlock([self.objectConverter convertObject:objectData], nil);
                                         } else {
                                             if (error == nil) {
                                                 error = [[NSError alloc] init]; // TODO: create a proper error object
                                             }
                                             completionBlock(nil, error);
                                         }
                                     }];
}

- (void)retrieveTypeDefinition:(NSString *)typeId completionBlock:(void (^)(CMISTypeDefinition *typeDefinition, NSError *error))completionBlock
{
    return [self.binding.repositoryService retrieveTypeDefinition:typeId completionBlock:completionBlock];
}

- (void)query:(NSString *)statement searchAllVersions:(BOOL)searchAllVersion completionBlock:(void (^)(CMISPagedResult *pagedResult, NSError *error))completionBlock
{
    [self query:statement searchAllVersions:searchAllVersion operationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (void)query:(NSString *)statement searchAllVersions:(BOOL)searchAllVersion
                                     operationContext:(CMISOperationContext *)operationContext
                                      completionBlock:(void (^)(CMISPagedResult *pagedResult, NSError *error))completionBlock
{
    CMISFetchNextPageBlock fetchNextPageBlock = ^(int skipCount, int maxItems, CMISFetchNextPageBlockCompletionBlock pageBlockCompletionBlock)
    {
        // Fetch results through discovery service
        [self.binding.discoveryService query:statement
                                                  searchAllVersions:searchAllVersion
                                                  includeRelationShips:operationContext.includeRelationShips
                                                  renditionFilter:operationContext.renditionFilterString
                                                  includeAllowableActions:operationContext.isIncludeAllowableActions
                                                  maxItems:[NSNumber numberWithInt:maxItems]
                                                  skipCount:[NSNumber numberWithInt:skipCount]
                                                  completionBlock:^(CMISObjectList *objectList, NSError *error) {
                                                      if (error) {
                                                          pageBlockCompletionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                                                      } else {
                                                          // Fill up return result
                                                          CMISFetchNextPageBlockResult *result = [[CMISFetchNextPageBlockResult alloc] init];
                                                          result.hasMoreItems = objectList.hasMoreItems;
                                                          result.numItems = objectList.numItems;
                                                          
                                                          NSMutableArray *resultArray = [[NSMutableArray alloc] init];
                                                          result.resultArray = resultArray;
                                                          for (CMISObjectData *objectData in objectList.objects)
                                                          {
                                                              [resultArray addObject:[CMISQueryResult queryResultUsingCmisObjectData:objectData andWithSession:self]];
                                                          }
                                                          pageBlockCompletionBlock(result, nil);
                                                      }
                                                  }];
    };

    [CMISPagedResult pagedResultUsingFetchBlock:fetchNextPageBlock
                             andLimitToMaxItems:operationContext.maxItemsPerPage
                          andStartFromSkipCount:operationContext.skipCount
                                completionBlock:^(CMISPagedResult *result, NSError *error) {
                                    // Return nil and populate error in case something went wrong
                                    if (error) {
                                        completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                                    } else {
                                        completionBlock(result, nil);
                                    }
                                }];
}

- (void)queryObjectsWithTypeDefinition:(CMISTypeDefinition *)typeDefinition
                       withWhereClause:(NSString *)whereClause
                     searchAllVersions:(BOOL)searchAllVersion
                      operationContext:(CMISOperationContext *)operationContext
                       completionBlock:(void (^)(CMISPagedResult *result, NSError *error))completionBlock
{
    // Creating the cmis query using the input params
    NSMutableString *statement = [[NSMutableString alloc] init];
    
    // Filter
    [statement appendFormat:@"SELECT %@", (operationContext.filterString != nil ? operationContext.filterString : @"*")];
    
    // Type
    [statement appendFormat:@" FROM %@", typeDefinition.queryName];
    
    // Where
    if (whereClause != nil)
    {
        [statement appendFormat:@" WHERE %@", whereClause];
    }
    
    // Order by
    if (operationContext.orderBy != nil)
    {
        [statement appendFormat:@" ORDER BY %@", operationContext.orderBy];
    }
    
    // Fetch block for paged results
    CMISFetchNextPageBlock fetchNextPageBlock = ^(int skipCount, int maxItems, CMISFetchNextPageBlockCompletionBlock pageBlockCompletionBlock)
    {
        // Fetch results through discovery service
        [self.binding.discoveryService query:statement
                           searchAllVersions:searchAllVersion
                        includeRelationShips:operationContext.includeRelationShips
                             renditionFilter:operationContext.renditionFilterString
                     includeAllowableActions:operationContext.isIncludeAllowableActions
                                    maxItems:[NSNumber numberWithInt:maxItems]
                                   skipCount:[NSNumber numberWithInt:skipCount]
                             completionBlock:^(CMISObjectList *objectList, NSError *error) {
                                 if (error) {
                                     pageBlockCompletionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                                 } else {
                                     // Fill up return result
                                     CMISFetchNextPageBlockResult *result = [[CMISFetchNextPageBlockResult alloc] init];
                                     result.hasMoreItems = objectList.hasMoreItems;
                                     result.numItems = objectList.numItems;
                                     
                                     NSMutableArray *resultArray = [[NSMutableArray alloc] init];
                                     result.resultArray = resultArray;
                                     for (CMISObjectData *objectData in objectList.objects)
                                     {
                                         [resultArray addObject:[self.objectConverter convertObject:objectData]];
                                     }
                                     pageBlockCompletionBlock(result, nil);
                                 }
                             }];
    };
    
    [CMISPagedResult pagedResultUsingFetchBlock:fetchNextPageBlock
                             andLimitToMaxItems:operationContext.maxItemsPerPage
                          andStartFromSkipCount:operationContext.skipCount
                                completionBlock:^(CMISPagedResult *result, NSError *error) {
                                    // Return nil and populate error in case something went wrong
                                    if (error) {
                                        completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                                    } else {
                                        completionBlock(result, nil);
                                    }
                                }];
}

- (void)queryObjectsWithTypeid:(NSString *)typeId
               withWhereClause:(NSString *)whereClause
             searchAllVersions:(BOOL)searchAllVersion
              operationContext:(CMISOperationContext *)operationContext
               completionBlock:(void (^)(CMISPagedResult *result, NSError *error))completionBlock
{
    [self retrieveTypeDefinition:typeId
                 completionBlock:^(CMISTypeDefinition *typeDefinition, NSError *internalError) {
                     if (internalError != nil) {
                         NSError *error = [CMISErrors cmisError:internalError withCMISErrorCode:kCMISErrorCodeRuntime];
                         completionBlock(nil, error);
                     } else {
                         [self queryObjectsWithTypeDefinition:typeDefinition
                                              withWhereClause:whereClause
                                            searchAllVersions:searchAllVersion
                                             operationContext:operationContext
                                              completionBlock:completionBlock];
                     }
                 }];
}

- (void)createFolder:(NSDictionary *)properties
            inFolder:(NSString *)folderObjectId
     completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
{
    [self.objectConverter convertProperties:properties
                            forObjectTypeId:[properties objectForKey:kCMISPropertyObjectTypeId]
                            completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                               if (error) {
                                   completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                               } else {
                                   [self.binding.objectService createFolderInParentFolder:folderObjectId
                                                                           withProperties:convertedProperties
                                                                          completionBlock:^(NSString *objectId, NSError *error) {
                                                                              completionBlock(objectId, error);
                                                                          }];
                               }
                           }];
}

- (CMISRequest*)downloadContentOfCMISObject:(NSString *)objectId
                                     toFile:(NSString *)filePath
                            completionBlock:(void (^)(NSError *error))completionBlock
                              progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
{
    return [self.binding.objectService downloadContentOfObject:objectId
                                                  withStreamId:nil
                                                        toFile:filePath
                                               completionBlock:completionBlock
                                                 progressBlock:progressBlock];
}

- (CMISRequest*)downloadContentOfCMISObject:(NSString *)objectId
                             toOutputStream:(NSOutputStream *)outputStream
                            completionBlock:(void (^)(NSError *error))completionBlock
                              progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
{
    return [self.binding.objectService downloadContentOfObject:objectId
                                                  withStreamId:nil
                                                toOutputStream:outputStream
                                               completionBlock:completionBlock
                                                 progressBlock:progressBlock];
}


- (void)createDocumentFromFilePath:(NSString *)filePath withMimeType:(NSString *)mimeType
                    withProperties:(NSDictionary *)properties inFolder:(NSString *)folderObjectId
                   completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                     progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    [self.objectConverter convertProperties:properties
                            forObjectTypeId:[properties objectForKey:kCMISPropertyObjectTypeId]
                            completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
        if (error) {
            log(@"Could not convert properties: %@", error.description);
            if (completionBlock) {
                completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
            }
        } else {
            [self.binding.objectService createDocumentFromFilePath:filePath
                                                      withMimeType:mimeType
                                                    withProperties:convertedProperties
                                                      inFolder:folderObjectId
                                                   completionBlock:completionBlock
                                                     progressBlock:progressBlock];
        }
    }];
}

- (void)createDocumentFromInputStream:(NSInputStream *)inputStream
                         withMimeType:(NSString *)mimeType
                       withProperties:(NSDictionary *)properties
                             inFolder:(NSString *)folderObjectId
                        bytesExpected:(unsigned long long)bytesExpected
                      completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    [self.objectConverter convertProperties:properties
                            forObjectTypeId:[properties objectForKey:kCMISPropertyObjectTypeId]
                            completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
        if (error) {
            log(@"Could not convert properties: %@", error.description);
            if (completionBlock) {
                completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
            }
        } else {
            [self.binding.objectService createDocumentFromInputStream:inputStream
                                                         withMimeType:mimeType
                                                       withProperties:convertedProperties
                                                             inFolder:folderObjectId
                                                        bytesExpected:bytesExpected
                                                      completionBlock:completionBlock
                                                        progressBlock:progressBlock];
        }
    }];
}

@end
