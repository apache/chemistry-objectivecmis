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

#import "CMISAtomPubObjectService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISAtomEntryWriter.h"
#import "CMISAtomEntryParser.h"
#import "CMISConstants.h"
#import "CMISErrors.h"
#import "CMISStringInOutParameter.h"
#import "CMISURLUtil.h"
#import "CMISFileUtil.h"
#import "CMISRequest.h"

@implementation CMISAtomPubObjectService

- (void)retrieveObject:(NSString *)objectId
            withFilter:(NSString *)filter
andIncludeRelationShips:(CMISIncludeRelationship)includeRelationship
   andIncludePolicyIds:(BOOL)includePolicyIds
    andRenditionFilder:(NSString *)renditionFilter
         andIncludeACL:(BOOL)includeACL
andIncludeAllowableActions:(BOOL)includeAllowableActions
       completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectInternal:objectId
               withReturnVersion:NOT_PROVIDED
                      withFilter:filter
         andIncludeRelationShips:includeRelationship
             andIncludePolicyIds:includePolicyIds
              andRenditionFilder:renditionFilter
                   andIncludeACL:includeACL
      andIncludeAllowableActions:includeAllowableActions
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData, nil);
                     }
                 }];
}

- (void)retrieveObjectByPath:(NSString *)path
                  withFilter:(NSString *)filter
     andIncludeRelationShips:(CMISIncludeRelationship)includeRelationship
         andIncludePolicyIds:(BOOL)includePolicyIds
          andRenditionFilder:(NSString *)renditionFilter
               andIncludeACL:(BOOL)includeACL
  andIncludeAllowableActions:(BOOL)includeAllowableActions
             completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectByPathInternal:path
                            withFilter:filter
               andIncludeRelationShips:includeRelationship
                   andIncludePolicyIds:includePolicyIds
                    andRenditionFilder:renditionFilter
                         andIncludeACL:includeACL
            andIncludeAllowableActions:includeAllowableActions
                       completionBlock:completionBlock];
}

- (CMISRequest*)downloadContentOfObject:(NSString *)objectId
                           withStreamId:(NSString *)streamId
                                 toFile:(NSString *)filePath
                        completionBlock:(void (^)(NSError *error))completionBlock
                          progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock;
{
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    return [self downloadContentOfObject:objectId
                            withStreamId:streamId
                          toOutputStream:outputStream
                         completionBlock:completionBlock
                           progressBlock:progressBlock];
}

- (CMISRequest*)downloadContentOfObject:(NSString *)objectId
                           withStreamId:(NSString *)streamId
                         toOutputStream:(NSOutputStream *)outputStream
                        completionBlock:(void (^)(NSError *error))completionBlock
                          progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock;
{
    CMISRequest *request = [[CMISRequest alloc] init];
    
    [self retrieveObjectInternal:objectId completionBlock:^(CMISObjectData *objectData, NSError *error) {
        if (error) {
            log(@"Error while retrieving CMIS object for object id '%@' : %@", objectId, error.description);
            if (completionBlock) {
                completionBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
            }
        } else {
            NSURL *contentUrl = objectData.contentUrl;
            
            // This is not spec-compliant!! Took me half a day to find this in opencmis ...
            if (streamId != nil) {
                contentUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterStreamId withValue:streamId toUrl:contentUrl];
            }
            
            unsigned long long streamLength = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamLength] firstValue] unsignedLongLongValue];
            
            [HttpUtil invoke:contentUrl
              withHttpMethod:HTTP_GET
                 withSession:self.bindingSession
                outputStream:outputStream
               bytesExpected:streamLength
             completionBlock:^(CMISHttpResponse *httpResponse, NSError *error)
             {
                 if (completionBlock) {
                     completionBlock(error);
                 }
             }
               progressBlock:progressBlock
               requestObject:request];
        }
    }];
    
    return request;
}

- (void)deleteContentOfObject:(CMISStringInOutParameter *)objectIdParam
              withChangeToken:(CMISStringInOutParameter *)changeTokenParam
              completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil)
    {
        log(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return;
    }
    
    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter andRelation:kCMISLinkEditMedia completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            log(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            completionBlock(error);
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             withValue:changeTokenParam.inParameter toUrlString:editMediaLink];
        }
        
        [HttpUtil invokeDELETE:[NSURL URLWithString:editMediaLink]
                   withSession:self.bindingSession
               completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                   if (httpResponse) {
                       // Atompub DOES NOT SUPPORT returning the new object id and change token
                       // See http://docs.oasis-open.org/cmis/CMIS/v1.0/cs01/cmis-spec-v1.0.html#_Toc243905498
                       objectIdParam.outParameter = nil;
                       changeTokenParam.outParameter = nil;
                       completionBlock(nil);
                   } else {
                       completionBlock(error);
                   }
               }];
    }];
}

- (CMISRequest*)changeContentOfObject:(CMISStringInOutParameter *)objectIdParam
                      toContentOfFile:(NSString *)filePath
                withOverwriteExisting:(BOOL)overwrite
                      withChangeToken:(CMISStringInOutParameter *)changeTokenParam
                      completionBlock:(void (^)(NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    if (inputStream == nil) {
        log(@"Could not find file %@", filePath);
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return nil;
    }
    
    NSError *fileError = nil;
    unsigned long long fileSize = [FileUtil fileSizeForFileAtPath:filePath error:&fileError];
    if (fileError) {
        log(@"Could not determine size of file %@: %@", filePath, [fileError description]);
    }
    
    return [self changeContentOfObject:objectIdParam
                toContentOfInputStream:inputStream
                         bytesExpected:fileSize
                          withFilename:[filePath lastPathComponent]
                 withOverwriteExisting:overwrite
                       withChangeToken:changeTokenParam
                       completionBlock:completionBlock
                         progressBlock:progressBlock];
}

- (CMISRequest*)changeContentOfObject:(CMISStringInOutParameter *)objectIdParam
               toContentOfInputStream:(NSInputStream *)inputStream
                        bytesExpected:(unsigned long long)bytesExpected
                         withFilename:(NSString*)filename
                withOverwriteExisting:(BOOL)overwrite
                      withChangeToken:(CMISStringInOutParameter *)changeTokenParam
                      completionBlock:(void (^)(NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil)
    {
        log(@"Object id is nil or inParameter of objectId is nil");
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Must provide object id"]);
        }
        return nil;
    }
    
    if (inputStream == nil) {
        log(@"Invalid input stream");
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Invalid input stream"]);
        }
        return nil;
    }
    
    // Atompub DOES NOT SUPPORT returning the new object id and change token
    // See http://docs.oasis-open.org/cmis/CMIS/v1.0/cs01/cmis-spec-v1.0.html#_Toc243905498
    objectIdParam.outParameter = nil;
    changeTokenParam.outParameter = nil;
    
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter andRelation:kCMISLinkEditMedia completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            log(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            if (completionBlock) {
                completionBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
            }
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             withValue:changeTokenParam.inParameter toUrlString:editMediaLink];
        }
        
        // Append overwrite flag
        editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterOverwriteFlag
                                                         withValue:(overwrite ? @"true" : @"false") toUrlString:editMediaLink];
        
        // Execute HTTP call on edit media link, passing the a stream to the file
        NSDictionary *additionalHeader = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"attachment; filename=%@",
                                                                             filename] forKey:@"Content-Disposition"];
        
        [HttpUtil invoke:[NSURL URLWithString:editMediaLink]
          withHttpMethod:HTTP_PUT
             withSession:self.bindingSession
             inputStream:inputStream
                 headers:additionalHeader
           bytesExpected:bytesExpected
         completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
             // Check response status
             if (httpResponse) {
                 if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 204) {
                     error = nil;
                 } else {
                     log(@"Invalid http response status code when updating content: %d", httpResponse.statusCode);
                     error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                         withDetailedDescription:[NSString stringWithFormat:@"Could not update content: http status code %d", httpResponse.statusCode]];
                 }
             }
             if (completionBlock) {
                 completionBlock(error);
             }
         }
           progressBlock:progressBlock
           requestObject:request];
    }];
    
    return request;
}


- (CMISRequest*)createDocumentFromFilePath:(NSString *)filePath
                              withMimeType:(NSString *)mimeType
                            withProperties:(CMISProperties *)properties
                                  inFolder:(NSString *)folderObjectId
                           completionBlock:(void (^)(NSString *objectId, NSError *Error))completionBlock
                             progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    if (inputStream == nil) {
        log(@"Could not find file %@", filePath);
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Invalid file"]);
        }
        return nil;
    }
    
    NSError *fileError = nil;
    unsigned long long bytesExpected = [FileUtil fileSizeForFileAtPath:filePath error:&fileError];
    if (fileError) {
        log(@"Could not determine size of file %@: %@", filePath, [fileError description]);
    }
    
    return [self createDocumentFromInputStream:inputStream
                                  withMimeType:mimeType withProperties:properties
                                      inFolder:folderObjectId
                                 bytesExpected:bytesExpected
                               completionBlock:completionBlock
                                 progressBlock:progressBlock];
}

- (CMISRequest*)createDocumentFromInputStream:(NSInputStream *)inputStream // may be nil if you do not want to set content
                                 withMimeType:(NSString *)mimeType
                               withProperties:(CMISProperties *)properties
                                     inFolder:(NSString *)folderObjectId
                                bytesExpected:(unsigned long long)bytesExpected // optional
                              completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                                progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    // Validate properties
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil)
    {
        log(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return nil;
    }
    
    // Validate mimetype
    if (inputStream && !mimeType)
    {
        log(@"Must provide a mimetype when creating a cmis document");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return nil;
    }
    
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get Down link
    [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationDown
                      andType:kCMISMediaTypeChildren completionBlock:^(NSString *downLink, NSError *error) {
                          if (error) {
                              log(@"Could not retrieve down link: %@", error.description);
                              if (completionBlock) {
                                  completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
                              }
                          } else {
                              
                          }
                          [self sendAtomEntryXmlToLink:downLink
                                 withHttpRequestMethod:HTTP_POST
                                        withProperties:properties
                                withContentInputStream:inputStream
                                   withContentMimeType:mimeType
                                         bytesExpected:bytesExpected
                                       completionBlock:completionBlock
                                         progressBlock:progressBlock
                                         requestObject:request];
                      }];
    return request;
}


- (void)deleteObject:(NSString *)objectId allVersions:(BOOL)allVersions completionBlock:(void (^)(BOOL objectDeleted, NSError *error))completionBlock
{
    [self loadLinkForObjectId:objectId andRelation:kCMISLinkRelationSelf completionBlock:^(NSString *selfLink, NSError *error) {
        if (!selfLink) {
            completionBlock(NO, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        } else {
            NSURL *selfUrl = [NSURL URLWithString:selfLink];
            [HttpUtil invokeDELETE:selfUrl
                       withSession:self.bindingSession
                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                       if (httpResponse) {
                           completionBlock(YES, nil);
                       } else {
                           completionBlock(NO, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeUpdateConflict]);
                       }
                   }];
        }
    }];
}

- (void)createFolderInParentFolder:(NSString *)folderObjectId withProperties:(CMISProperties *)properties completionBlock:(void (^)(NSString *, NSError *))completionBlock
{
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil)
    {
        log(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        completionBlock(nil,  [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        return;
    }
    
    // Validate parent folder id
    if (!folderObjectId)
    {
        log(@"Must provide a parent folder object id when creating a new folder");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound withDetailedDescription:nil]);
        return;
    }
    
    // Get Down link
    [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationDown
                      andType:kCMISMediaTypeChildren completionBlock:^(NSString *downLink, NSError *error) {
                          if (error) {
                              log(@"Could not retrieve down link: %@", error.description);
                              completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
                          } else {
                              [self sendAtomEntryXmlToLink:downLink
                                     withHttpRequestMethod:HTTP_POST
                                            withProperties:properties
                                           completionBlock:^(CMISObjectData *objectData, NSError *error) {
                                               completionBlock(objectData.identifier, error);
                                           }];
                          }
                      }];
}

- (void)deleteTree:(NSString *)folderObjectId
        allVersion:(BOOL)allVersions
     unfileObjects:(CMISUnfileObject)unfileObjects
 continueOnFailure:(BOOL)continueOnFailure
   completionBlock:(void (^)(NSArray *failedObjects, NSError *error))completionBlock
{
    // Validate params
    if (!folderObjectId)
    {
        log(@"Must provide a folder object id when deleting a folder tree");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound withDetailedDescription:nil]);
        return;
    }
    
    [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationDown andType:kCMISMediaTypeDescendants completionBlock:^(NSString *link, NSError *error) {
        if (error) {
            log(@"Error while fetching %@ link : %@", kCMISLinkRelationDown, error.description);
            completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
            return;
        }
        
        void (^continueWithLink)(NSString *) = ^(NSString *link) {
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterAllVersions withValue:(allVersions ? @"true" : @"false") toUrlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterUnfileObjects withValue:[CMISEnums stringForUnfileObject:unfileObjects] toUrlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterContinueOnFailure withValue:(continueOnFailure ? @"true" : @"false") toUrlString:link];
            
            [HttpUtil invokeDELETE:[NSURL URLWithString:link]
                       withSession:self.bindingSession
                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                       if (httpResponse) {
                           // TODO: retrieve failed folders and files and return
                           completionBlock([NSArray array], nil);
                       } else {
                           completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
                       }
                   }];
        };
        
        if (link == nil) {
            [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationFolderTree completionBlock:^(NSString *link, NSError *error) {
                if (error) {
                    log(@"Error while fetching %@ link : %@", kCMISLinkRelationFolderTree, error.description);
                    completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                } else if (link == nil) {
                    log(@"Could not retrieve %@ nor %@ link", kCMISLinkRelationDown, kCMISLinkRelationFolderTree);
                    completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                } else {
                    continueWithLink(link);
                }
            }];
        } else {
            continueWithLink(link);
        }
    }];
}

- (void)updatePropertiesForObject:(CMISStringInOutParameter *)objectIdParam
                   withProperties:(CMISProperties *)properties
                  withChangeToken:(CMISStringInOutParameter *)changeTokenParam
                  completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate params
    if (objectIdParam == nil || objectIdParam.inParameter == nil)
    {
        log(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return;
    }
    
    // Get self link
    [self loadLinkForObjectId:objectIdParam.inParameter andRelation:kCMISLinkRelationSelf completionBlock:^(NSString *selfLink, NSError *error) {
        if (selfLink == nil)
        {
            log(@"Could not retrieve %@ link", kCMISLinkRelationSelf);
            completionBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
            return;
        }
        
        // Append optional params
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil)
        {
            selfLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                        withValue:changeTokenParam.inParameter toUrlString:selfLink];
        }
        
        // Execute request
        [self sendAtomEntryXmlToLink:selfLink
               withHttpRequestMethod:HTTP_PUT
                      withProperties:properties
                     completionBlock:^(CMISObjectData *objectData, NSError *error) {
                         // Create XML needed as body of html
                         
                         CMISAtomEntryWriter *xmlWriter = [[CMISAtomEntryWriter alloc] init];
                         xmlWriter.cmisProperties = properties;
                         xmlWriter.generateXmlInMemory = YES;
                         
                         [HttpUtil invokePUT:[NSURL URLWithString:selfLink]
                                 withSession:self.bindingSession
                                        body:[xmlWriter.generateAtomEntryXml dataUsingEncoding:NSUTF8StringEncoding]
                                     headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                             completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                 if (httpResponse) {
                                     // Object id and changeToken might have changed because of this operation
                                     CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:httpResponse.data];
                                     NSError *error = nil;
                                     if ([atomEntryParser parseAndReturnError:&error])
                                     {
                                         objectIdParam.outParameter = [[atomEntryParser.objectData.properties propertyForId:kCMISPropertyObjectId] firstValue];
                                         
                                         if (changeTokenParam != nil)
                                         {
                                             changeTokenParam.outParameter = [[atomEntryParser.objectData.properties propertyForId:kCMISPropertyChangeToken] firstValue];
                                         }
                                     }
                                     completionBlock(nil);
                                 } else {
                                     completionBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
                                 }
                             }];
                     }];
    }];
}


- (void)retrieveRenditions:(NSString *)objectId withRenditionFilter:(NSString *)renditionFilter
              withMaxItems:(NSNumber *)maxItems withSkipCount:(NSNumber *)skipCount
           completionBlock:(void (^)(NSArray *renditions, NSError *error))completionBlock
{
    // Only fetching the bare minimum
    [self retrieveObjectInternal:objectId withReturnVersion:LATEST withFilter:kCMISPropertyObjectId
         andIncludeRelationShips:CMISIncludeRelationshipNone andIncludePolicyIds:NO
              andRenditionFilder:renditionFilter andIncludeACL:NO andIncludeAllowableActions:NO
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData.renditions, nil);
                     }
                 }];
}

#pragma mark Helper methods

- (void)sendAtomEntryXmlToLink:(NSString *)link
         withHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                withProperties:(CMISProperties *)properties
               completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    // Validate params
    if (link == nil) {
        log(@"Could not retrieve link from object to do creation or update");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return;
    }
    
    // Generate XML
    NSString *writeResult = [self createAtomEntryWriter:properties
                                        contentFilePath:nil
                                        contentMimeType:nil
                                    isXmlStoredInMemory:YES];
    
    // Execute call
    [HttpUtil invoke:[NSURL URLWithString:link]
      withHttpMethod:httpRequestMethod
         withSession:self.bindingSession
                body:[writeResult dataUsingEncoding:NSUTF8StringEncoding]
             headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
     completionBlock:^(CMISHttpResponse *response, NSError *error) {
         if (error) {
             log(@"HTTP error when creating/uploading content: %@", error);
             if (completionBlock) {
                 completionBlock(nil, error);
             }
         } else if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
             if (completionBlock) {
                 CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:response.data];
                 NSError *parseError = nil;
                 [atomEntryParser parseAndReturnError:&parseError];
                 if (parseError == nil) {
                     completionBlock(atomEntryParser.objectData, nil);
                 } else {
                     log(@"Error while parsing response: %@", [parseError description]);
                     completionBlock(nil, [CMISErrors cmisError:parseError withCMISErrorCode:kCMISErrorCodeUpdateConflict]);
                 }
             }
         } else {
             log(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
             log(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
             if (completionBlock) {
                 completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
             }
         }
     }];
}


- (void)sendAtomEntryXmlToLink:(NSString *)link
         withHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                withProperties:(CMISProperties *)properties
        withContentInputStream:(NSInputStream *)contentInputStream
           withContentMimeType:(NSString *)contentMimeType
                 bytesExpected:(unsigned long long)bytesExpected
               completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                 progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
                 requestObject:(CMISRequest*)request
{
    // Validate param
    if (link == nil) {
        log(@"Could not retrieve link from object to do creation or update");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return;
    }
    
    // Generate XML
    NSString *writeResult = [self createAtomEntryWriter:properties
                                     contentInputStream:contentInputStream
                                        contentMimeType:contentMimeType
                                    isXmlStoredInMemory:NO];
    
    // Start the asynchronous POST http call
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:writeResult];
    
    NSError *fileSizeError = nil;
    unsigned long long fileSize = [FileUtil fileSizeForFileAtPath:writeResult error:&fileSizeError];
    if (fileSizeError) {
        log(@"Could not determine file size of %@ : %@", writeResult, [fileSizeError description]);
    }
    
    [HttpUtil invoke:[NSURL URLWithString:link]
      withHttpMethod:HTTP_POST
         withSession:self.bindingSession
         inputStream:inputStream
             headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
       bytesExpected:fileSize
     completionBlock:^(CMISHttpResponse *response, NSError *error) {
         // close stream to and delete temporary file
         [inputStream close];
         NSError *fileError = nil;
         [[NSFileManager defaultManager] removeItemAtPath:writeResult error:&fileError];
         if (fileError) {
             // the upload itself is not impacted by this error, so do not report it in the completion block
             log(@"Could not delete temporary file %@: %@", writeResult, [fileError description]);
         }
         
         if (error) {
             log(@"HTTP error when creating/uploading content: %@", error);
             if (completionBlock) {
                 completionBlock(nil, error);
             }
         } else if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
             if (completionBlock) {
                 NSError *parseError = nil;
                 CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:response.data];
                 [atomEntryParser parseAndReturnError:&parseError];
                 if (parseError == nil) {
                     completionBlock(atomEntryParser.objectData.identifier, nil);
                 } else {
                     log(@"Error while parsing response: %@", [parseError description]);
                     completionBlock(nil, [CMISErrors cmisError:parseError withCMISErrorCode:kCMISErrorCodeUpdateConflict]);
                 }
             }
         } else {
             log(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
             log(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
             if (completionBlock) {
                 completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                                  withDetailedDescription:[NSString stringWithFormat:@"Could not create content: http status code %d", response.statusCode]]);
             }
         }
     }
       progressBlock:progressBlock
       requestObject:request];
}


/**
 * Helper method: creates a writer for the xml needed to upload a file.
 * The atom entry XML can become huge, as the whole file is stored as base64 in the XML itself
 * Hence, we're allowing to store the atom entry xml in a temporary file and stream the body of the http post
 */
- (NSString *)createAtomEntryWriter:(CMISProperties *)properties
                    contentFilePath:(NSString *)contentFilePath
                    contentMimeType:(NSString *)contentMimeType
                isXmlStoredInMemory:(BOOL)isXmlStoredInMemory
{
    
    CMISAtomEntryWriter *atomEntryWriter = [[CMISAtomEntryWriter alloc] init];
    atomEntryWriter.contentFilePath = contentFilePath;
    atomEntryWriter.mimeType = contentMimeType;
    atomEntryWriter.cmisProperties = properties;
    atomEntryWriter.generateXmlInMemory = isXmlStoredInMemory;
    NSString *writeResult = [atomEntryWriter generateAtomEntryXml];
    return writeResult;
}

- (NSString *)createAtomEntryWriter:(CMISProperties *)properties
                 contentInputStream:(NSInputStream *)contentInputStream
                    contentMimeType:(NSString *)contentMimeType
                isXmlStoredInMemory:(BOOL)isXmlStoredInMemory
{
    
    CMISAtomEntryWriter *atomEntryWriter = [[CMISAtomEntryWriter alloc] init];
    atomEntryWriter.inputStream= contentInputStream;
    atomEntryWriter.mimeType = contentMimeType;
    atomEntryWriter.cmisProperties = properties;
    atomEntryWriter.generateXmlInMemory = isXmlStoredInMemory;
    NSString *writeResult = [atomEntryWriter generateAtomEntryXml];
    return writeResult;
}

@end
