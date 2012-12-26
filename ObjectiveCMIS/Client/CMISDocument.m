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

#import "CMISDocument.h"
#import "CMISConstants.h"
#import "CMISHttpUtil.h"
#import "CMISObjectConverter.h"
#import "CMISStringInOutParameter.h"
#import "CMISOperationContext.h"
#import "CMISFileUtil.h"
#import "CMISErrors.h"
#import "CMISRequest.h"
#import "CMISSession.h"

@interface CMISDocument()

@property (nonatomic, strong, readwrite) NSString *contentStreamId;
@property (nonatomic, strong, readwrite) NSString *contentStreamFileName;
@property (nonatomic, strong, readwrite) NSString *contentStreamMediaType;
@property (readwrite) unsigned long long contentStreamLength;

@property (nonatomic, strong, readwrite) NSString *versionLabel;
@property (readwrite) BOOL isLatestVersion;
@property (readwrite) BOOL isMajorVersion;
@property (readwrite) BOOL isLatestMajorVersion;
@property (nonatomic, strong, readwrite) NSString *versionSeriesId;

@end

@implementation CMISDocument

@synthesize contentStreamId = _contentStreamId;
@synthesize contentStreamFileName = _contentStreamFileName;
@synthesize contentStreamMediaType = _contentStreamMediaType;
@synthesize contentStreamLength = _contentStreamLength;
@synthesize versionLabel = _versionLabel;
@synthesize isLatestVersion = _isLatestVersion;
@synthesize isMajorVersion = _isMajorVersion;
@synthesize versionSeriesId = _versionSeriesId;
@synthesize isLatestMajorVersion = _isLatestMajorVersion;

- (id)initWithObjectData:(CMISObjectData *)objectData withSession:(CMISSession *)session
{
    self = [super initWithObjectData:objectData withSession:session];
    if (self)
    {
        self.contentStreamId = [[objectData.properties.propertiesDictionary objectForKey:kCMISProperyContentStreamId] firstValue];
        self.contentStreamMediaType = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamMediaType] firstValue];
        self.contentStreamLength = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamLength] firstValue] unsignedLongLongValue];
        self.contentStreamFileName = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamFileName] firstValue];

        self.versionLabel = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyVersionLabel] firstValue];
        self.versionSeriesId = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyVersionSeriesId] firstValue];
        self.isLatestVersion = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyIsLatestVersion] firstValue] boolValue];
        self.isLatestMajorVersion = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyIsLatestMajorVersion] firstValue] boolValue];
        self.isMajorVersion = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyIsMajorVersion] firstValue] boolValue];
    }
    return self;
}

- (void)retrieveAllVersionsWithCompletionBlock:(void (^)(CMISCollection *allVersionsOfDocument, NSError *error))completionBlock
{
    [self retrieveAllVersionsWithOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (void)retrieveAllVersionsWithOperationContext:(CMISOperationContext *)operationContext completionBlock:(void (^)(CMISCollection *collection, NSError *error))completionBlock
{
    [self.binding.versioningService retrieveAllVersions:self.identifier
           filter:operationContext.filterString includeAllowableActions:operationContext.isIncludeAllowableActions completionBlock:^(NSArray *objects, NSError *error) {
               if (error) {
                   log(@"Error while retrieving all versions: %@", error.description);
                   completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
               } else {
                   completionBlock([self.session.objectConverter convertObjects:objects], nil);
               }
           }];
}

- (CMISRequest*)changeContentToContentOfFile:(NSString *)filePath withOverwriteExisting:(BOOL)overwrite
                             completionBlock:(void (^)(NSError *error))completionBlock
                               progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    return [self.binding.objectService changeContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:self.identifier]
                                             toContentOfFile:filePath
                                       withOverwriteExisting:overwrite
                                             withChangeToken:[CMISStringInOutParameter inOutParameterUsingInParameter:self.changeToken]
                                             completionBlock:completionBlock
                                               progressBlock:progressBlock];
}

- (CMISRequest*)changeContentToContentOfInputStream:(NSInputStream *)inputStream
                                      bytesExpected:(unsigned long long)bytesExpected
                                       withFileName:(NSString *)filename
                              withOverwriteExisting:(BOOL)overwrite
                                    completionBlock:(void (^)(NSError *error))completionBlock
                                      progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    return [self.binding.objectService changeContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:self.identifier]
                                      toContentOfInputStream:inputStream
                                               bytesExpected:bytesExpected
                                                withFilename:filename
                                       withOverwriteExisting:overwrite
                                             withChangeToken:[CMISStringInOutParameter inOutParameterUsingInParameter:self.changeToken]
                                             completionBlock:completionBlock
                                               progressBlock:progressBlock];
}

- (void)deleteContentWithCompletionBlock:(void (^)(NSError *error))completionBlock
{
    [self.binding.objectService deleteContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:self.identifier]
                                      withChangeToken:[CMISStringInOutParameter inOutParameterUsingInParameter:self.changeToken]
                                      completionBlock:completionBlock];
}

- (void)retrieveObjectOfLatestVersionWithMajorVersion:(BOOL)major completionBlock:(void (^)(CMISDocument *document, NSError *error))completionBlock
{
    [self retrieveObjectOfLatestVersionWithMajorVersion:major withOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (void)retrieveObjectOfLatestVersionWithMajorVersion:(BOOL)major
                                 withOperationContext:(CMISOperationContext *)operationContext
                                      completionBlock:(void (^)(CMISDocument *document, NSError *error))completionBlock
{
    [self.binding.versioningService retrieveObjectOfLatestVersion:self.identifier
                                                            major:major filter:operationContext.filterString
                                             includeRelationShips:operationContext.includeRelationShips
                                                 includePolicyIds:operationContext.isIncludePolicies
                                                  renditionFilter:operationContext.renditionFilterString
                                                       includeACL:operationContext.isIncluseACLs
                                          includeAllowableActions:operationContext.isIncludeAllowableActions
                                                  completionBlock:^(CMISObjectData *objectData, NSError *error) {
            if (error) {
                completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
            } else {
                completionBlock((CMISDocument *) [self.session.objectConverter convertObject:objectData], nil);
            }
        }];
}

- (CMISRequest*)downloadContentToFile:(NSString *)filePath
                      completionBlock:(void (^)(NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
{
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    return [self.binding.objectService downloadContentOfObject:self.identifier
                                                  withStreamId:nil
                                                toOutputStream:outputStream
                                               completionBlock:completionBlock
                                                 progressBlock:progressBlock];
}

- (void)deleteAllVersionsWithCompletionBlock:(void (^)(BOOL documentDeleted, NSError *error))completionBlock
{
    [self.binding.objectService deleteObject:self.identifier allVersions:YES completionBlock:completionBlock];
}

@end
