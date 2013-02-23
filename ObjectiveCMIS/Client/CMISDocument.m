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

#import "CMISDocument.h"
#import "CMISConstants.h"
#import "CMISObjectConverter.h"
#import "CMISStringInOutParameter.h"
#import "CMISOperationContext.h"
#import "CMISFileUtil.h"
#import "CMISErrors.h"
#import "CMISRequest.h"
#import "CMISSession.h"
#import "CMISLog.h"

@interface CMISDocument()

@property (nonatomic, strong, readwrite) NSString *contentStreamId;
@property (nonatomic, strong, readwrite) NSString *contentStreamFileName;
@property (nonatomic, strong, readwrite) NSString *contentStreamMediaType;
@property (readwrite) unsigned long long contentStreamLength;

@property (nonatomic, strong, readwrite) NSString *versionLabel;
@property (nonatomic, assign, readwrite, getter = isLatestVersion) BOOL latestVersion;
@property (nonatomic, assign, readwrite, getter = isMajorVersion) BOOL majorVersion;
@property (nonatomic, assign, readwrite, getter = isLatestMajorVersion) BOOL latestMajorVersion;
@property (nonatomic, strong, readwrite) NSString *versionSeriesId;

@end

@implementation CMISDocument

- (id)initWithObjectData:(CMISObjectData *)objectData session:(CMISSession *)session
{
    self = [super initWithObjectData:objectData session:session];
    if (self){
        self.contentStreamId = [[objectData.properties.propertiesDictionary objectForKey:kCMISProperyContentStreamId] firstValue];
        self.contentStreamMediaType = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamMediaType] firstValue];
        self.contentStreamLength = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamLength] firstValue] unsignedLongLongValue];
        self.contentStreamFileName = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamFileName] firstValue];

        self.versionLabel = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyVersionLabel] firstValue];
        self.versionSeriesId = [[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyVersionSeriesId] firstValue];
        self.latestVersion = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyIsLatestVersion] firstValue] boolValue];
        self.latestMajorVersion = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyIsLatestMajorVersion] firstValue] boolValue];
        self.majorVersion = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyIsMajorVersion] firstValue] boolValue];
    }
    return self;
}

- (CMISRequest*)retrieveAllVersionsWithCompletionBlock:(void (^)(CMISCollection *allVersionsOfDocument, NSError *error))completionBlock
{
    return [self retrieveAllVersionsWithOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (CMISRequest*)retrieveAllVersionsWithOperationContext:(CMISOperationContext *)operationContext completionBlock:(void (^)(CMISCollection *collection, NSError *error))completionBlock
{
    return [self.binding.versioningService retrieveAllVersions:self.identifier
           filter:operationContext.filterString includeAllowableActions:operationContext.includeAllowableActions completionBlock:^(NSArray *objects, NSError *error) {
               if (error) {
                   CMISLogError(@"Error while retrieving all versions: %@", error.description);
                   completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
               } else {
                   completionBlock([self.session.objectConverter convertObjects:objects], nil);
               }
           }];
}

- (CMISRequest*)changeContentToContentOfFile:(NSString *)filePath
                                    mimeType:(NSString *)mimeType
                                   overwrite:(BOOL)overwrite
                             completionBlock:(void (^)(NSError *error))completionBlock
                               progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    return [self.binding.objectService changeContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:self.identifier]
                                             toContentOfFile:filePath
                                                    mimeType:mimeType
                                           overwriteExisting:overwrite
                                                 changeToken:[CMISStringInOutParameter inOutParameterUsingInParameter:self.changeToken]
                                             completionBlock:completionBlock
                                               progressBlock:progressBlock];
}

- (CMISRequest*)changeContentToContentOfInputStream:(NSInputStream *)inputStream
                                      bytesExpected:(unsigned long long)bytesExpected
                                           fileName:(NSString *)filename
                                           mimeType:(NSString *)mimeType
                                          overwrite:(BOOL)overwrite
                                    completionBlock:(void (^)(NSError *error))completionBlock
                                      progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    return [self.binding.objectService changeContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:self.identifier]
                                      toContentOfInputStream:inputStream
                                               bytesExpected:bytesExpected
                                                    filename:filename
                                                    mimeType:mimeType
                                           overwriteExisting:overwrite
                                                 changeToken:[CMISStringInOutParameter inOutParameterUsingInParameter:self.changeToken]
                                             completionBlock:completionBlock
                                               progressBlock:progressBlock];
}

- (CMISRequest*)deleteContentWithCompletionBlock:(void (^)(NSError *error))completionBlock
{
    return [self.binding.objectService deleteContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:self.identifier]
                                      changeToken:[CMISStringInOutParameter inOutParameterUsingInParameter:self.changeToken]
                                      completionBlock:completionBlock];
}

- (CMISRequest*)retrieveObjectOfLatestVersionWithMajorVersion:(BOOL)major completionBlock:(void (^)(CMISDocument *document, NSError *error))completionBlock
{
    return [self retrieveObjectOfLatestVersionWithMajorVersion:major operationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (CMISRequest*)retrieveObjectOfLatestVersionWithMajorVersion:(BOOL)major
                                             operationContext:(CMISOperationContext *)operationContext
                                              completionBlock:(void (^)(CMISDocument *document, NSError *error))completionBlock
{
    return [self.binding.versioningService retrieveObjectOfLatestVersion:self.identifier
                                                                   major:major filter:operationContext.filterString
                                                           relationships:operationContext.relationships
                                                        includePolicyIds:operationContext.includePolicies
                                                         renditionFilter:operationContext.renditionFilterString
                                                              includeACL:operationContext.includeACLs
                                                 includeAllowableActions:operationContext.includeAllowableActions
                                                         completionBlock:^(CMISObjectData *objectData, NSError *error) {
            if (error) {
                completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
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
                                                      streamId:nil
                                                toOutputStream:outputStream
                                               completionBlock:completionBlock
                                                 progressBlock:progressBlock];
}


- (CMISRequest*)downloadContentToOutputStream:(NSOutputStream *)outputStream
                              completionBlock:(void (^)(NSError *error))completionBlock
                                progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
{
    return [self.binding.objectService downloadContentOfObject:self.identifier
                                                      streamId:nil
                                                toOutputStream:outputStream
                                               completionBlock:completionBlock
                                                 progressBlock:progressBlock];
}


- (CMISRequest*)deleteAllVersionsWithCompletionBlock:(void (^)(BOOL documentDeleted, NSError *error))completionBlock
{
    return [self.binding.objectService deleteObject:self.identifier allVersions:YES completionBlock:completionBlock];
}

@end
