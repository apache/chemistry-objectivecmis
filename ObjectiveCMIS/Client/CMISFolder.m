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

#import "CMISFolder.h"
#import "CMISObjectConverter.h"
#import "CMISConstants.h"
#import "CMISErrors.h"
#import "CMISPagedResult.h"
#import "CMISOperationContext.h"
#import "CMISObjectList.h"
#import "CMISSession.h"

@interface CMISFolder ()

@property (nonatomic, strong, readwrite) NSString *path;
@property (nonatomic, strong, readwrite) CMISCollection *children;
@end

@implementation CMISFolder

@synthesize path = _path;
@synthesize children = _children;

- (id)initWithObjectData:(CMISObjectData *)objectData withSession:(CMISSession *)session
{
    self = [super initWithObjectData:objectData withSession:session];
    if (self)
    {
        self.path = [[objectData.properties propertyForId:kCMISPropertyPath] firstValue];
    }
    return self;
}

- (void)retrieveChildrenWithCompletionBlock:(void (^)(CMISPagedResult *result, NSError *error))completionBlock
{
    [self retrieveChildrenWithOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (BOOL)isRootFolder
{
    return [self.identifier isEqualToString:self.session.repositoryInfo.rootFolderId];
}

- (void)retrieveFolderParentWithCompletionBlock:(void (^)(CMISFolder *folder, NSError *error))completionBlock
{
    if ([self isRootFolder])
    {
        completionBlock(nil, nil);
    } else {
        [self retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
            if (parentFolders.count > 0) {
                completionBlock([parentFolders objectAtIndex:0], error);
            } else {
                completionBlock(nil, error);
            }
        }];
    }
}

- (void)retrieveChildrenWithOperationContext:(CMISOperationContext *)operationContext completionBlock:(void (^)(CMISPagedResult *result, NSError *error))completionBlock
{
    CMISFetchNextPageBlock fetchNextPageBlock = ^(int skipCount, int maxItems, CMISFetchNextPageBlockCompletionBlock pageBlockCompletionBlock)
    {
        // Fetch results through navigationService
        [self.binding.navigationService retrieveChildren:self.identifier
                                                 orderBy:operationContext.orderBy
                                                  filter:operationContext.filterString
                                    includeRelationShips:operationContext.includeRelationShips
                                         renditionFilter:operationContext.renditionFilterString
                                 includeAllowableActions:operationContext.isIncludeAllowableActions
                                      includePathSegment:operationContext.isIncludePathSegments
                                               skipCount:[NSNumber numberWithInt:skipCount]
                                                maxItems:[NSNumber numberWithInt:maxItems]
                                         completionBlock:^(CMISObjectList *objectList, NSError *error) {
                                             if (error) {
                                                 pageBlockCompletionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
                                             } else {
                                                 CMISFetchNextPageBlockResult *result = [[CMISFetchNextPageBlockResult alloc] init];
                                                 result.hasMoreItems = objectList.hasMoreItems;
                                                 result.numItems = objectList.numItems;
                                             
                                                 result.resultArray = [self.session.objectConverter convertObjects:objectList.objects].items;
                                                 pageBlockCompletionBlock(result, nil);
                                             }
                                         }];
    };

    [CMISPagedResult pagedResultUsingFetchBlock:fetchNextPageBlock
                             andLimitToMaxItems:operationContext.maxItemsPerPage
                          andStartFromSkipCount:operationContext.skipCount
                          completionBlock:^(CMISPagedResult *result, NSError *error) {
                              if (error) {
                                  completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                              } else {
                                  completionBlock(result, nil);
                              }
                          }];
}

- (void)createFolder:(NSDictionary *)properties completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
{
    [self.session.objectConverter convertProperties:properties
                                    forObjectTypeId:[properties objectForKey:kCMISPropertyObjectTypeId]
                                    completionBlock:^(CMISProperties *properties, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                     } else {
                         [self.binding.objectService createFolderInParentFolder:self.identifier
                                                                 withProperties:properties
                                                                completionBlock:^(NSString *objectId, NSError *error) {
                                                                    completionBlock(objectId, error);
                                                                }];
                     }
                 }];
}

- (void)createDocumentFromFilePath:(NSString *)filePath
                      withMimeType:(NSString *)mimeType
                    withProperties:(NSDictionary *)properties
                   completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                     progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    [self.session.objectConverter convertProperties:properties
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
                                                          inFolder:self.identifier
                                                   completionBlock:completionBlock
                                                     progressBlock:progressBlock];
        }
    }];
}

- (void)deleteTreeWithDeleteAllVersions:(BOOL)deleteAllversions
                           withUnfileObjects:(CMISUnfileObject)unfileObjects
                       withContinueOnFailure:(BOOL)continueOnFailure
                             completionBlock:(void (^)(NSArray *failedObjects, NSError *error))completionBlock
{
    [self.binding.objectService deleteTree:self.identifier allVersion:deleteAllversions
                                    unfileObjects:unfileObjects continueOnFailure:continueOnFailure completionBlock:completionBlock];
}

@end
