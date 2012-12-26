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

#import "CMISAtomPubRepositoryService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISWorkspace.h"
#import "CMISErrors.h"
#import "CMISTypeByIdUriBuilder.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISTypeDefinitionAtomEntryParser.h"

@interface CMISAtomPubRepositoryService ()
@property (nonatomic, strong) NSMutableDictionary *repositories;
@end

@interface CMISAtomPubRepositoryService (PrivateMethods)
- (void)internalRetrieveRepositoriesWithCompletionBlock:(void (^)(NSError *error))completionBlock;
@end


@implementation CMISAtomPubRepositoryService

@synthesize repositories = _repositories;

- (void)retrieveRepositoriesWithCompletionBlock:(void (^)(NSArray *repositories, NSError *error))completionBlock
{
    [self internalRetrieveRepositoriesWithCompletionBlock:^(NSError *error) {
        if (error) {
            completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
        } else {
            completionBlock([self.repositories allValues], nil);
        }
    }];
}

- (void)retrieveRepositoryInfoForId:(NSString *)repositoryId completionBlock:(void (^)(CMISRepositoryInfo *repositoryInfo, NSError *error))completionBlock
{
    [self internalRetrieveRepositoriesWithCompletionBlock:^(NSError *error) {
        if (error) {
            completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeInvalidArgument]);
        } else {
            completionBlock([self.repositories objectForKey:repositoryId], nil);
        }
    }];
}

- (void)internalRetrieveRepositoriesWithCompletionBlock:(void (^)(NSError *error))completionBlock
{
    self.repositories = [NSMutableDictionary dictionary];
    [self retrieveCMISWorkspacesWithCompletionBlock:^(NSArray *cmisWorkSpaces, NSError *error) {
        if (cmisWorkSpaces != nil)
        {
            for (CMISWorkspace *workspace in cmisWorkSpaces)
            {
                [self.repositories setObject:workspace.repositoryInfo forKey:workspace.repositoryInfo.identifier];
            }
        }
        completionBlock(error);
    }];
}

- (void)retrieveTypeDefinition:(NSString *)typeId completionBlock:(void (^)(CMISTypeDefinition *typeDefinition, NSError *error))completionBlock
{
    if (typeId == nil)
    {
        log(@"Parameter typeId is required");
        NSError *error = [[NSError alloc] init]; // TODO: proper error init
        completionBlock(nil, error);
        return;
    }
    
    [self retrieveFromCache:kCMISBindingSessionKeyTypeByIdUriBuilder completionBlock:^(id object, NSError *error) {
        CMISTypeByIdUriBuilder *typeByIdUriBuilder = object;
        typeByIdUriBuilder.id = typeId;
        
        [HttpUtil invokeGET:[typeByIdUriBuilder buildUrl] withSession:self.bindingSession completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
            if (httpResponse) {
                if (httpResponse.data != nil) {
                    CMISTypeDefinitionAtomEntryParser *parser = [[CMISTypeDefinitionAtomEntryParser alloc] initWithData:httpResponse.data];
                    NSError *error;
                    if ([parser parseAndReturnError:&error]) {
                        completionBlock(parser.typeDefinition, nil);
                    } else {
                        completionBlock(nil, error);
                    }
                } else {
                    NSError *error = [[NSError alloc] init]; // TODO: proper error init
                    completionBlock(nil, error);
                }
            } else {
                completionBlock(nil, error);
            }
        }];
    }];
}

@end
