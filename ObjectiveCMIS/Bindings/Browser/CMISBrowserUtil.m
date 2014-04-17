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

#import "CMISBrowserUtil.h"
#import "CMISConstants.h"
#import "CMISBrowserConstants.h"
#import "CMISRepositoryInfo.h"
#import "CMISPropertyDefinition.h"
#import "CMISRenditionData.h"
#import "CMISDocumentTypeDefinition.h"
#import "CMISFolderTypeDefinition.h"
#import "CMISRelationshipTypeDefinition.h"
#import "CMISItemTypeDefinition.h"
#import "CMISSecondaryTypeDefinition.h"
#import "CMISErrors.h"
#import "CMISNSDictionary+CMISUtil.h"

@implementation CMISBrowserUtil

+ (NSDictionary *)repositoryInfoDictionaryFromJSONData:(NSData *)jsonData bindingSession:(CMISBindingSession *)bindingSession error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    NSMutableDictionary *repositories = nil;
    if (!serialisationError) {
        repositories = [NSMutableDictionary dictionary];
        
        // parse the json into CMISRepositoryInfo objects and store in self.repositories
        NSArray *repos = [jsonDictionary allValues];
        for (NSDictionary *repo in repos) {
            CMISRepositoryInfo *repoInfo = [CMISRepositoryInfo new];
            repoInfo.identifier = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONRepositoryId];
            repoInfo.name = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONRepositoryName];
            repoInfo.desc = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONRepositoryDescription];
            repoInfo.vendorName = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONVendorName];
            repoInfo.productName = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONProductName];
            repoInfo.productVersion = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONProductVersion];
            repoInfo.rootFolderId = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONRootFolderId];
            repoInfo.repositoryUrl = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONRepositoryUrl];
            repoInfo.rootFolderUrl = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONRootFolderUrl];
            
            repoInfo.repositoryCapabilities = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONCapabilities]; //TODO should be own type instead of dictionary
            //TOOD aclCapabilities
            repoInfo.latestChangeLogToken = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONLatestChangeLogToken];
            
            repoInfo.cmisVersionSupported = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONCMISVersionSupported];
            repoInfo.thinClientUri = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONThinClientUri];

            //TODO repoInfo.changesIncomplete = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONChangesIncomplete);
            //TODO changesOnType

            repoInfo.principalIdAnonymous = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONPrincipalIdAnonymous];
            repoInfo.principalIdAnyone = [repo cmis_objectForKeyNotNull:kCMISBrowserJSONPrincipalIdAnyone];
            
            //handle extensions
            repoInfo.extensions = [CMISBrowserUtil convertExtensions:repo cmisKeys:[CMISBrowserConstants repositoryInfoKeys]];
            
            // store the repo and root folder URLs in the session (when the repoId matches)
            if ([repoInfo.identifier isEqualToString:bindingSession.repositoryId]) {
                [bindingSession setObject:repoInfo.rootFolderUrl forKey:kCMISBrowserBindingSessionKeyRootFolderUrl];
                [bindingSession setObject:repoInfo.repositoryUrl forKey:kCMISBrowserBindingSessionKeyRepositoryUrl];
            }
            
            [repositories setObject:repoInfo forKey:repoInfo.identifier];
        }
    }

    return repositories;
}

+ (CMISTypeDefinition *)typeDefinitionFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    CMISTypeDefinition *typeDef = nil;
    if (!serialisationError) {
        //TODO check for valid baseTypeId (cmis:document, cmis:folder, cmis:relationship, cmis:policy, [cmis:item, cmis:secondary])
        CMISBaseType baseType = [CMISEnums enumForBaseId:[jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONBaseId]];
        switch (baseType) {
            case CMISBaseTypeDocument: {
                typeDef = [CMISDocumentTypeDefinition new];
                ((CMISDocumentTypeDefinition*)typeDef).contentStreamAllowed = [CMISEnums enumForContentStreamAllowed:
                                                                               [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONContentStreamAllowed]];
                ((CMISDocumentTypeDefinition*)typeDef).versionable = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONVersionable];
                break;
            }
            case CMISBaseTypeFolder:
                typeDef = [CMISFolderTypeDefinition new];
                break;
                
            case CMISBaseTypeRelationship: {
                typeDef = [CMISRelationshipTypeDefinition new];
                
                id allowedSourceTypes = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONAllowedSourceTypes];
                if([allowedSourceTypes isKindOfClass:NSArray.class]){
                    NSMutableArray *types = [[NSMutableArray alloc] init];
                    for (id type in allowedSourceTypes) {
                        if(type){
                            [types addObject:type];
                        }
                    }
                    ((CMISRelationshipTypeDefinition*)typeDef).allowedSourceTypes = types;
                }
                
                id allowedTargetTypes = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONAllowedTargetTypes];
                if([allowedTargetTypes isKindOfClass:NSArray.class]){
                    NSMutableArray *types = [[NSMutableArray alloc] init];
                    for (id type in allowedTargetTypes) {
                        if(type){
                            [types addObject:type];
                        }
                    }
                    ((CMISRelationshipTypeDefinition*)typeDef).allowedTargetTypes = types;
                }
                break;
            }
            case CMISBaseTypeItem:
                typeDef = [CMISItemTypeDefinition new];
                break;
            case CMISBaseTypeSecondary:
                typeDef = [CMISSecondaryTypeDefinition new];
                break;
            default:
                if (outError != NULL) *outError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument detailedDescription:[NSString stringWithFormat:@"Type '%@' does not match a base type!", [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONBaseId]]];
                return nil;
        }

        typeDef.baseTypeId = baseType;
        typeDef.description = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONDescription];
        typeDef.displayName = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONDisplayName];
        typeDef.id = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONId];
        typeDef.controllablePolicy = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONControllablePolicy];
        typeDef.controllableAcl = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONControllableAcl];
        typeDef.creatable = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONCreateable];
        typeDef.fileable = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONFileable];
        typeDef.fullTextIndexed = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONFullTextIndexed];
        typeDef.includedInSupertypeQuery = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONIncludedInSuperTypeQuery];
        typeDef.queryable = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONQueryable];
        typeDef.localName = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONLocalName];
        typeDef.localNameSpace = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONLocalNamespace];
        typeDef.parentTypeId = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONParentId];
        typeDef.queryName = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONQueryName];
        
        //TODO type mutability
        
        NSDictionary *propertyDefinitions = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONPropertyDefinitions];
        for (NSDictionary *propertyDefDictionary in [propertyDefinitions allValues]) {
            [typeDef addPropertyDefinition:[CMISBrowserUtil convertPropertyDefinition:propertyDefDictionary]];
        }
        
        // handle extensions
        typeDef.extensions = [CMISBrowserUtil convertExtensions:jsonDictionary cmisKeys:[CMISBrowserConstants typeKeys]];
    }
    
    return typeDef;
}

+ (CMISObjectData *)objectDataFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil

    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    CMISObjectData *objectData = nil;
    if (!serialisationError) {
        // parse the json into a CMISObjectData object
        objectData = [CMISBrowserUtil convertObject:jsonDictionary];
    }
    
    return objectData;
}

+ (CMISObjectList *)objectListFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    CMISObjectList *objectList = nil;
    if (!serialisationError) {
        // parse the json into a CMISObjectList object
        objectList = [CMISObjectList new];
        
        // parse the objects
        BOOL isArray = [jsonDictionary isKindOfClass:NSArray.class];
        NSArray *objectsArray;
        if(isArray){
            objectsArray = jsonDictionary;
            
            objectList.hasMoreItems = NO;
            objectList.numItems = (int)objectsArray.count;
        } else { // is NSDictionary
            objectsArray = [jsonDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONObjects];
            
            // retrieve the paging data
            objectList.hasMoreItems = [jsonDictionary cmis_boolForKey:kCMISBrowserJSONHasMoreItems];
            objectList.numItems = [jsonDictionary cmis_intForKey:kCMISBrowserJSONNumberItems];
        }
        if (objectsArray) {
            NSMutableArray *objects = [NSMutableArray arrayWithCapacity:objectsArray.count];
            for (NSDictionary *dictionary in objectsArray) {
                NSDictionary *objectDictionary;
                if(isArray){
                    objectDictionary = dictionary;
                } else {
                    objectDictionary = [dictionary cmis_objectForKeyNotNull:kCMISBrowserJSONObject];
                }
                CMISObjectData *objectData = [CMISBrowserUtil convertObject:objectDictionary];
                if(objectData){
                    [objects addObject:objectData];
                }
            }
            
            // pass objects to list
            objectList.objects = objects;
        }
    }
    
    return objectList;
}

+ (NSArray *)renditionsFromJSONData:(NSData *)jsonData error:(NSError **)outError
{
    // TODO: error handling i.e. if jsonData is nil, also handle outError being nil
    
    // parse the JSON response
    NSError *serialisationError = nil;
    id jsonDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&serialisationError];
    
    NSArray *renditions = nil;
    if (!serialisationError) {
        // parse the json into a CMISObjectData object
        renditions = [CMISBrowserUtil renditionsFromArray:jsonDictionary];
    }
    
    return renditions;
}

#pragma mark -
#pragma mark Private helper methods

+ (CMISObjectData *)convertObject:(NSDictionary *)dictionary
{
    if(!dictionary) {
        return nil;
    }
    
    CMISObjectData *objectData = [CMISObjectData new];
    NSDictionary *propertiesJson = [dictionary cmis_objectForKeyNotNull:kCMISBrowserJSONSuccinctProperties];
    objectData.identifier = [propertiesJson cmis_objectForKeyNotNull:kCMISPropertyObjectId];
    
    // determine the object type
    NSString *baseType = [propertiesJson cmis_objectForKeyNotNull:kCMISPropertyBaseTypeId];
    if ([baseType isEqualToString:kCMISPropertyObjectTypeIdValueDocument]) {
        objectData.baseType = CMISBaseTypeDocument;
    } else if ([baseType isEqualToString:kCMISPropertyObjectTypeIdValueFolder]) {
        objectData.baseType = CMISBaseTypeFolder;
    }
    
    // set the properties
    NSDictionary *propertiesExtension = [dictionary cmis_objectForKeyNotNull:kCMISBrowserJSONPropertiesExtension];
    objectData.properties = [CMISBrowserUtil convertSuccinctProperties:propertiesJson propertiesExtension:propertiesExtension];
    
    // relationships
    NSArray *relationshipsJson = [dictionary cmis_objectForKeyNotNull:kCMISBrowserJSONRelationships];
    objectData.relationships = [CMISBrowserUtil convertObjects:relationshipsJson];
    
    //renditions
    NSArray *renditionsJson = [dictionary cmis_objectForKeyNotNull:kCMISBrowserJSONRenditions];
    objectData.renditions = [self renditionsFromArray:renditionsJson];
    
    // handle extensions
    objectData.extensions = [CMISBrowserUtil convertExtensions:dictionary cmisKeys:[CMISBrowserConstants objectKeys]];
    
    return objectData;
}

+ (NSArray *)convertObjects:(NSArray *)json
{
    if (!json){
        return nil;
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (id obj in json) {
        //TODO check if obj is NSDictionary or else abort with error
        CMISObjectData *relationship = [CMISBrowserUtil convertObject:obj];
        if(relationship){
            [result addObject:relationship];
        }
    }
    
    return result;
}

+ (CMISProperties *)convertSuccinctProperties:(NSDictionary *)propertiesJson propertiesExtension:(NSDictionary *)extJson
{
    if(!propertiesJson) {
        return nil;
    }
    
    // TODO convert properties according to typeDefinition
    
    // create properties
    CMISProperties *properties = [CMISProperties new];
    NSArray *propNames = [propertiesJson allKeys];
    for (NSString *propName in propNames) {
        CMISPropertyData *propertyData;
        id propValue = [propertiesJson cmis_objectForKeyNotNull:propName];
        if ([propValue isKindOfClass:[NSArray class]]) {
            propertyData = [CMISPropertyData createPropertyForId:propName arrayValue:propValue type:CMISPropertyTypeString];
        }
        else {
            if(propValue){
                propertyData = [CMISPropertyData createPropertyForId:propName stringValue:propValue];
            } else {
                //TODO create convenient method for nil values?
                propertyData = [CMISPropertyData createPropertyForId:propName arrayValue:[NSArray array] type:CMISPropertyTypeString];
            }
        }
        
        [properties addProperty:propertyData];
    }
    
    if(extJson){
        properties.extensions = [CMISBrowserUtil convertExtensions:extJson cmisKeys:[NSSet set]];
    }
    
    return properties;
}

+ (NSArray *)renditionsFromArray:(NSArray *)array
{
    if(!array) {
        return nil;
    }
    NSMutableArray *renditions = [[NSMutableArray alloc] initWithCapacity:array.count];
    for(NSDictionary *renditionJson in array){
        CMISRenditionData *renditionData = [CMISRenditionData new];
        renditionData.height = [NSNumber numberWithLongLong:[[renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionHeight] longLongValue]];
        renditionData.kind = [renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionKind];
        renditionData.length = [NSNumber numberWithLongLong:[[renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionLength] longLongValue]];
        renditionData.mimeType = [renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionMimeType];
        renditionData.renditionDocumentId = [renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionDocumentId];
        renditionData.streamId = [renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionStreamId];
        renditionData.title = [renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionTitle];
        renditionData.width = [NSNumber numberWithLongLong:[[renditionJson cmis_objectForKeyNotNull:kCMISBrowserJSONRenditionWidth] longLongValue]];
        
        // handle extensions
        renditionData.extensions = [CMISBrowserUtil convertExtensions:renditionJson cmisKeys:[CMISBrowserConstants renditionKeys]];
        
        [renditions addObject:renditionData];
    }
    
    return renditions;
}

+ (CMISPropertyDefinition *)convertPropertyDefinition:(NSDictionary *)propertyDictionary
{
    if(!propertyDictionary){
        return nil;
    }
    
    // create property definition and add to type definition
    CMISPropertyDefinition *propDef = [CMISPropertyDefinition new];
    propDef.id = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONId];
    propDef.localName = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONLocalName];
    propDef.localNamespace = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONLocalNamespace];
    propDef.queryName = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONQueryName];
    propDef.description = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONDescription];
    propDef.displayName = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONDisplayName];
    propDef.inherited = [propertyDictionary cmis_boolForKey:kCMISBrowserJSONInherited];
    propDef.openChoice = [propertyDictionary cmis_boolForKey:kCMISBrowserJSONOpenChoice];
    propDef.orderable = [propertyDictionary cmis_boolForKey:kCMISBrowserJSONOrderable];
    propDef.queryable = [propertyDictionary cmis_boolForKey:kCMISBrowserJSONQueryable];
    propDef.required = [propertyDictionary cmis_boolForKey:kCMISBrowserJSONRequired];
    
    // determine property type
    NSString *typeString = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONPropertyType];
    if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueString]) {
        propDef.propertyType = CMISPropertyTypeString;
    } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueId]) {
        propDef.propertyType = CMISPropertyTypeId;
    } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueInteger]) {
        propDef.propertyType = CMISPropertyTypeInteger;
    } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueDecimal]) {
        propDef.propertyType = CMISPropertyTypeDecimal;
    } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueBoolean]) {
        propDef.propertyType = CMISPropertyTypeBoolean;
    } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueDateTime]) {
        propDef.propertyType = CMISPropertyTypeDateTime;
    } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueHtml]) {
        propDef.propertyType = CMISPropertyTypeHtml;
    } else if ([typeString isEqualToString:kCMISBrowserJSONPropertyTypeValueUri]) {
        propDef.propertyType = CMISPropertyTypeUri;
    }
    
    // determine cardinality
    NSString *cardinalityString = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONCardinality];
    if ([cardinalityString isEqualToString:kCMISBrowserJSONCardinalityValueSingle]) {
        propDef.cardinality = CMISCardinalitySingle;
    } else if ([cardinalityString isEqualToString:kCMISBrowserJSONCardinalityValueMultiple]) {
        propDef.cardinality = CMISCardinalityMulti;
    }
    
    // determine updatability
    NSString *updatabilityString = [propertyDictionary cmis_objectForKeyNotNull:kCMISBrowserJSONUpdateability];
    if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueReadOnly]) {
        propDef.updatability = CMISUpdatabilityReadOnly;
    } else if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueReadWrite]) {
        propDef.updatability = CMISUpdatabilityReadWrite;
    } else if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueOnCreate]) {
        propDef.updatability = CMISUpdatabilityOnCreate;
    } else if ([updatabilityString isEqualToString:kCMISBrowserJSONUpdateabilityValueWhenCheckedOut]) {
        propDef.updatability = CMISUpdatabilityWhenCheckedOut;
    }
    
    // TODO default value
    
    // handle extensions
    propDef.extensions = [CMISBrowserUtil convertExtensions:propertyDictionary cmisKeys:[CMISBrowserConstants propertyTypeKeys]];
    
    return propDef;
}

+ (NSArray *)convertExtensions:(NSDictionary *)source cmisKeys:(NSSet *)cmisKeys
{
    if (!source) {
        return nil;
    }
    
    NSMutableArray *extensions = nil; // array of CMISExtensionElement's
    
    for (NSString *key in source.keyEnumerator) {
        if ([cmisKeys containsObject:key]) {
            continue;
        }
        
        if (!extensions) {
            extensions = [[NSMutableArray alloc] init];
        }
        
        id value = [source cmis_objectForKeyNotNull:key];
        if ([value isKindOfClass:NSDictionary.class]) {
            [extensions addObject:[[CMISExtensionElement alloc] initNodeWithName:key namespaceUri:nil attributes:nil children:[CMISBrowserUtil convertExtension:value]]];
        } else if ([value isKindOfClass:NSArray.class]) {
            [extensions addObjectsFromArray:[CMISBrowserUtil convertExtension: key fromArray:value]];
        } else {
            [extensions addObject:[[CMISExtensionElement alloc] initLeafWithName:key namespaceUri:nil attributes:nil value:value]];
        }
    }
    return extensions;
}

+ (NSArray *)convertExtension:(NSDictionary *)dictionary
{
    if (!dictionary) {
        return nil;
    }
    
    NSMutableArray *extensions = [[NSMutableArray alloc] init]; // array of CMISExtensionElement's
    
    for (NSString *key in dictionary.keyEnumerator) {
        id value = [dictionary cmis_objectForKeyNotNull:key];
        if ([value isKindOfClass:NSDictionary.class]) {
            [extensions addObject:[[CMISExtensionElement alloc] initNodeWithName:key namespaceUri:nil attributes:nil children:[CMISBrowserUtil convertExtension:value]]];
        } else if ([value isKindOfClass:NSArray.class]) {
            [extensions addObjectsFromArray:[CMISBrowserUtil convertExtension: key fromArray:value]];
        } else {
            [extensions addObject:[[CMISExtensionElement alloc] initLeafWithName:key namespaceUri:nil attributes:nil value:value]];
        }
    }
    
    return extensions;
}

+ (NSArray *)convertExtension:(NSString *)key fromArray:(NSArray *)array
{
    if (!array) {
        return nil;
    }
    
    NSMutableArray *extensions = [[NSMutableArray alloc] init]; // array of CMISExtensionElement's
    
    for (id element in array) {
        if ([element isKindOfClass:NSDictionary.class]) {
            [extensions addObject:[[CMISExtensionElement alloc] initNodeWithName:key namespaceUri:nil attributes:nil children:[CMISBrowserUtil convertExtension:element]]];
        } else if ([element isKindOfClass:NSArray.class]) {
            [extensions addObjectsFromArray:[CMISBrowserUtil convertExtension: key fromArray:element]];
        } else {
            [extensions addObject:[[CMISExtensionElement alloc] initLeafWithName:key namespaceUri:nil attributes:nil value:element]];
        }
    }
    
    return extensions;
}

@end
