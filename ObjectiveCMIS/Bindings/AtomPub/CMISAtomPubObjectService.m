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

#import "CMISAtomPubObjectService.h"
#import "CMISAtomPubBaseService+Protected.h"
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
                filter:(NSString *)filter
         relationShips:(CMISIncludeRelationship)includeRelationship
      includePolicyIds:(BOOL)includePolicyIds
       renditionFilder:(NSString *)renditionFilter
            includeACL:(BOOL)includeACL
    includeAllowableActions:(BOOL)includeAllowableActions
       completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectInternal:objectId
                   returnVersion:NOT_PROVIDED
                          filter:filter
                   relationShips:includeRelationship
                includePolicyIds:includePolicyIds
                 renditionFilder:renditionFilter
                      includeACL:includeACL
         includeAllowableActions:includeAllowableActions
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData, nil);
                     }
                 }];
}

- (void)retrieveObjectByPath:(NSString *)path
                      filter:(NSString *)filter
               relationShips:(CMISIncludeRelationship)includeRelationship
            includePolicyIds:(BOOL)includePolicyIds
             renditionFilder:(NSString *)renditionFilter
                  includeACL:(BOOL)includeACL
     includeAllowableActions:(BOOL)includeAllowableActions
             completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectByPathInternal:path
                                filter:filter
                         relationShips:includeRelationship
                      includePolicyIds:includePolicyIds
                       renditionFilder:renditionFilter
                            includeACL:includeACL
               includeAllowableActions:includeAllowableActions
                       completionBlock:completionBlock];
}

- (CMISRequest*)downloadContentOfObject:(NSString *)objectId
                               streamId:(NSString *)streamId
                                 toFile:(NSString *)filePath
                        completionBlock:(void (^)(NSError *error))completionBlock
                          progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock;
{
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    return [self downloadContentOfObject:objectId
                                streamId:streamId
                          toOutputStream:outputStream
                         completionBlock:completionBlock
                           progressBlock:progressBlock];
}

- (CMISRequest*)downloadContentOfObject:(NSString *)objectId
                               streamId:(NSString *)streamId
                         toOutputStream:(NSOutputStream *)outputStream
                        completionBlock:(void (^)(NSError *error))completionBlock
                          progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock;
{
    CMISRequest *request = [[CMISRequest alloc] init];
    
    [self retrieveObjectInternal:objectId completionBlock:^(CMISObjectData *objectData, NSError *error) {
        if (error) {
            log(@"Error while retrieving CMIS object for object id '%@' : %@", objectId, error.description);
            if (completionBlock) {
                completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
            }
        } else {
            NSURL *contentUrl = objectData.contentUrl;
            
            if (contentUrl) {
                // This is not spec-compliant!! Took me half a day to find this in opencmis ...
                if (streamId != nil) {
                    contentUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterStreamId value:streamId url:contentUrl];
                }
                
                unsigned long long streamLength = [[[objectData.properties.propertiesDictionary objectForKey:kCMISPropertyContentStreamLength] firstValue] unsignedLongLongValue];
                
                [self.bindingSession.networkProvider invoke:contentUrl
                                                 httpMethod:HTTP_GET
                                                    session:self.bindingSession
                                               outputStream:outputStream
                                              bytesExpected:streamLength
                                            completionBlock:^(CMISHttpResponse *httpResponse, NSError *error)
                 {
                     if (completionBlock) {
                         completionBlock(error);
                     }
                 }progressBlock:progressBlock
                requestObject:request];
            } else { // it is spec-compliant to have no content stream set and in this case there is nothing to download
                if (completionBlock) {
                    completionBlock(nil);
                }
            }
        }
    }];
    
    return request;
}

- (void)deleteContentOfObject:(CMISStringInOutParameter *)objectIdParam
                  changeToken:(CMISStringInOutParameter *)changeTokenParam
              completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil) {
        log(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return;
    }
    
    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter relation:kCMISLinkEditMedia completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            log(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            completionBlock(error);
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             value:changeTokenParam.inParameter urlString:editMediaLink];
        }
        
        [self.bindingSession.networkProvider invokeDELETE:[NSURL URLWithString:editMediaLink]
                   session:self.bindingSession
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
                    overwriteExisting:(BOOL)overwrite
                          changeToken:(CMISStringInOutParameter *)changeTokenParam
                      completionBlock:(void (^)(NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    if (inputStream == nil) {
        log(@"Could not find file %@", filePath);
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
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
                              filename:[filePath lastPathComponent]
                     overwriteExisting:overwrite
                           changeToken:changeTokenParam
                       completionBlock:completionBlock
                         progressBlock:progressBlock];
}

- (CMISRequest*)changeContentOfObject:(CMISStringInOutParameter *)objectIdParam
               toContentOfInputStream:(NSInputStream *)inputStream
                        bytesExpected:(unsigned long long)bytesExpected
                             filename:(NSString*)filename
                    overwriteExisting:(BOOL)overwrite
                          changeToken:(CMISStringInOutParameter *)changeTokenParam
                      completionBlock:(void (^)(NSError *error))completionBlock
                        progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil) {
        log(@"Object id is nil or inParameter of objectId is nil");
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:@"Must provide object id"]);
        }
        return nil;
    }
    
    if (inputStream == nil) {
        log(@"Invalid input stream");
        if (completionBlock) {
            completionBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:@"Invalid input stream"]);
        }
        return nil;
    }
    
    // Atompub DOES NOT SUPPORT returning the new object id and change token
    // See http://docs.oasis-open.org/cmis/CMIS/v1.0/cs01/cmis-spec-v1.0.html#_Toc243905498
    objectIdParam.outParameter = nil;
    changeTokenParam.outParameter = nil;
    
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter relation:kCMISLinkEditMedia completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            log(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            if (completionBlock) {
                completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
            }
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             value:changeTokenParam.inParameter urlString:editMediaLink];
        }
        
        // Append overwrite flag
        editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterOverwriteFlag
                                                         value:(overwrite ? @"true" : @"false") urlString:editMediaLink];
        
        // Execute HTTP call on edit media link, passing the a stream to the file
        NSDictionary *additionalHeader = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"attachment; filename=%@",
                                                                             filename] forKey:@"Content-Disposition"];
        
        [self.bindingSession.networkProvider invoke:[NSURL URLWithString:editMediaLink]
                                         httpMethod:HTTP_PUT
                                            session:self.bindingSession
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
                                             detailedDescription:[NSString stringWithFormat:@"Could not update content: http status code %d", httpResponse.statusCode]];
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
                                  mimeType:(NSString *)mimeType
                                properties:(CMISProperties *)properties
                                  inFolder:(NSString *)folderObjectId
                           completionBlock:(void (^)(NSString *objectId, NSError *Error))completionBlock
                             progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    if (inputStream == nil) {
        log(@"Could not find file %@", filePath);
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                 detailedDescription:@"Invalid file"]);
        }
        return nil;
    }
    
    NSError *fileError = nil;
    unsigned long long bytesExpected = [FileUtil fileSizeForFileAtPath:filePath error:&fileError];
    if (fileError) {
        log(@"Could not determine size of file %@: %@", filePath, [fileError description]);
    }
    
    return [self createDocumentFromInputStream:inputStream
                                      mimeType:mimeType
                                    properties:properties
                                      inFolder:folderObjectId
                                 bytesExpected:bytesExpected
                               completionBlock:completionBlock
                                 progressBlock:progressBlock];
}

- (CMISRequest*)createDocumentFromInputStream:(NSInputStream *)inputStream // may be nil if you do not want to set content
                                     mimeType:(NSString *)mimeType
                                   properties:(CMISProperties *)properties
                                     inFolder:(NSString *)folderObjectId
                                bytesExpected:(unsigned long long)bytesExpected // optional
                              completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                                progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
{
    // Validate properties
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil) {
        log(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return nil;
    }
    
    // Validate mimetype
    if (inputStream && !mimeType) {
        log(@"Must provide a mimetype when creating a cmis document");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return nil;
    }
    
    CMISRequest *request = [[CMISRequest alloc] init];
    // Get Down link
    [self loadLinkForObjectId:folderObjectId
                     relation:kCMISLinkRelationDown
                         type:kCMISMediaTypeChildren
              completionBlock:^(NSString *downLink, NSError *error) {
                          if (error) {
                              log(@"Could not retrieve down link: %@", error.description);
                              if (completionBlock) {
                                  completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
                              }
                          } else {
                              
                          }
                          [self sendAtomEntryXmlToLink:downLink
                                     httpRequestMethod:HTTP_POST
                                            properties:properties
                                    contentInputStream:inputStream
                                       contentMimeType:mimeType
                                         bytesExpected:bytesExpected
                                       completionBlock:completionBlock
                                         progressBlock:progressBlock
                                         requestObject:request];
                      }];
    return request;
}


- (void)deleteObject:(NSString *)objectId
         allVersions:(BOOL)allVersions
     completionBlock:(void (^)(BOOL objectDeleted, NSError *error))completionBlock
{
    [self loadLinkForObjectId:objectId relation:kCMISLinkRelationSelf completionBlock:^(NSString *selfLink, NSError *error) {
        if (!selfLink) {
            completionBlock(NO, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        } else {
            NSURL *selfUrl = [NSURL URLWithString:selfLink];
            [self.bindingSession.networkProvider invokeDELETE:selfUrl
                                                      session:self.bindingSession
                                              completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                       if (httpResponse) {
                           completionBlock(YES, nil);
                       } else {
                           completionBlock(NO, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeUpdateConflict]);
                       }
                   }];
        }
    }];
}

- (void)createFolderInParentFolder:(NSString *)folderObjectId
                        properties:(CMISProperties *)properties
                   completionBlock:(void (^)(NSString *, NSError *))completionBlock
{
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil) {
        log(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        completionBlock(nil,  [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        return;
    }
    
    // Validate parent folder id
    if (!folderObjectId) {
        log(@"Must provide a parent folder object id when creating a new folder");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound detailedDescription:nil]);
        return;
    }
    
    // Get Down link
    [self loadLinkForObjectId:folderObjectId
                     relation:kCMISLinkRelationDown
                         type:kCMISMediaTypeChildren
              completionBlock:^(NSString *downLink, NSError *error) {
                          if (error) {
                              log(@"Could not retrieve down link: %@", error.description);
                              completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
                          } else {
                              [self sendAtomEntryXmlToLink:downLink
                                         httpRequestMethod:HTTP_POST
                                                properties:properties
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
    if (!folderObjectId) {
        log(@"Must provide a folder object id when deleting a folder tree");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound detailedDescription:nil]);
        return;
    }
    
    [self loadLinkForObjectId:folderObjectId
                     relation:kCMISLinkRelationDown
                         type:kCMISMediaTypeDescendants
              completionBlock:^(NSString *link, NSError *error) {
        if (error) {
            log(@"Error while fetching %@ link : %@", kCMISLinkRelationDown, error.description);
            completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
            return;
        }
        
        void (^continueWithLink)(NSString *) = ^(NSString *link) {
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterAllVersions value:(allVersions ? @"true" : @"false") urlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterUnfileObjects value:[CMISEnums stringForUnfileObject:unfileObjects] urlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterContinueOnFailure value:(continueOnFailure ? @"true" : @"false") urlString:link];
            
            [self.bindingSession.networkProvider invokeDELETE:[NSURL URLWithString:link]
                       session:self.bindingSession
                   completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                       if (httpResponse) {
                           // TODO: retrieve failed folders and files and return
                           completionBlock([NSArray array], nil);
                       } else {
                           completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
                       }
                   }];
        };
        
        if (link == nil) {
            [self loadLinkForObjectId:folderObjectId
                             relation:kCMISLinkRelationFolderTree
                      completionBlock:^(NSString *link, NSError *error) {
                if (error) {
                    log(@"Error while fetching %@ link : %@", kCMISLinkRelationFolderTree, error.description);
                    completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
                } else if (link == nil) {
                    log(@"Could not retrieve %@ nor %@ link", kCMISLinkRelationDown, kCMISLinkRelationFolderTree);
                    completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeRuntime]);
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
                       properties:(CMISProperties *)properties
                      changeToken:(CMISStringInOutParameter *)changeTokenParam
                  completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate params
    if (objectIdParam == nil || objectIdParam.inParameter == nil) {
        log(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return;
    }
    
    // Get self link
    [self loadLinkForObjectId:objectIdParam.inParameter
                     relation:kCMISLinkRelationSelf
              completionBlock:^(NSString *selfLink, NSError *error) {
        if (selfLink == nil) {
            log(@"Could not retrieve %@ link", kCMISLinkRelationSelf);
            completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
            return;
        }
        
        // Append optional params
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            selfLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                        value:changeTokenParam.inParameter urlString:selfLink];
        }
        
        // Execute request
        [self sendAtomEntryXmlToLink:selfLink
                   httpRequestMethod:HTTP_PUT
                          properties:properties
                     completionBlock:^(CMISObjectData *objectData, NSError *error) {
                         // Create XML needed as body of html
                         
                         CMISAtomEntryWriter *xmlWriter = [[CMISAtomEntryWriter alloc] init];
                         xmlWriter.cmisProperties = properties;
                         xmlWriter.generateXmlInMemory = YES;
                         
                         [self.bindingSession.networkProvider invokePUT:[NSURL URLWithString:selfLink]
                                                                session:self.bindingSession
                                        body:[xmlWriter.generateAtomEntryXml dataUsingEncoding:NSUTF8StringEncoding]
                                     headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                             completionBlock:^(CMISHttpResponse *httpResponse, NSError *error) {
                                 if (httpResponse) {
                                     // Object id and changeToken might have changed because of this operation
                                     CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:httpResponse.data];
                                     NSError *error = nil;
                                     if ([atomEntryParser parseAndReturnError:&error]) {
                                         objectIdParam.outParameter = [[atomEntryParser.objectData.properties propertyForId:kCMISPropertyObjectId] firstValue];
                                         
                                         if (changeTokenParam != nil) {
                                             changeTokenParam.outParameter = [[atomEntryParser.objectData.properties propertyForId:kCMISPropertyChangeToken] firstValue];
                                         }
                                     }
                                     completionBlock(nil);
                                 } else {
                                     completionBlock([CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
                                 }
                             }];
                     }];
    }];
}


- (void)retrieveRenditions:(NSString *)objectId
           renditionFilter:(NSString *)renditionFilter
                  maxItems:(NSNumber *)maxItems
                 skipCount:(NSNumber *)skipCount
           completionBlock:(void (^)(NSArray *renditions, NSError *error))completionBlock
{
    // Only fetching the bare minimum
    [self retrieveObjectInternal:objectId returnVersion:LATEST filter:kCMISPropertyObjectId
         relationShips:CMISIncludeRelationshipNone includePolicyIds:NO
              renditionFilder:renditionFilter includeACL:NO includeAllowableActions:NO
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData.renditions, nil);
                     }
                 }];
}

#pragma mark Helper methods

- (void)sendAtomEntryXmlToLink:(NSString *)link
             httpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                    properties:(CMISProperties *)properties
               completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    // Validate params
    if (link == nil) {
        log(@"Could not retrieve link from object to do creation or update");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
        }
        return;
    }
    
    // Generate XML
    NSString *writeResult = [self createAtomEntryWriter:properties
                                        contentFilePath:nil
                                        contentMimeType:nil
                                    isXmlStoredInMemory:YES];
    
    // Execute call
    [self.bindingSession.networkProvider invoke:[NSURL URLWithString:link]
                                     httpMethod:httpRequestMethod
                                        session:self.bindingSession
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
                     completionBlock(nil, [CMISErrors cmisError:parseError cmisErrorCode:kCMISErrorCodeUpdateConflict]);
                 }
             }
         } else {
             log(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
             log(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
             if (completionBlock) {
                 completionBlock(nil, [CMISErrors cmisError:error cmisErrorCode:kCMISErrorCodeConnection]);
             }
         }
     }];
}


- (void)sendAtomEntryXmlToLink:(NSString *)link
             httpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                    properties:(CMISProperties *)properties
            contentInputStream:(NSInputStream *)contentInputStream
               contentMimeType:(NSString *)contentMimeType
                 bytesExpected:(unsigned long long)bytesExpected
               completionBlock:(void (^)(NSString *objectId, NSError *error))completionBlock
                 progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock
                 requestObject:(CMISRequest*)request
{
    // Validate param
    if (link == nil) {
        log(@"Could not retrieve link from object to do creation or update");
        if (completionBlock) {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:nil]);
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
    
    [self.bindingSession.networkProvider invoke:[NSURL URLWithString:link]
                                     httpMethod:HTTP_POST
                                        session:self.bindingSession
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
                     completionBlock(nil, [CMISErrors cmisError:parseError cmisErrorCode:kCMISErrorCodeUpdateConflict]);
                 }
             }
         } else {
             log(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
             log(@"Error content: %@", [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
             if (completionBlock) {
                 completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                                  detailedDescription:[NSString stringWithFormat:@"Could not create content: http status code %d", response.statusCode]]);
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
