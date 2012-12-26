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

#import "CMISObject.h"
#import "CMISConstants.h"
#import "CMISErrors.h"
#import "CMISObjectConverter.h"
#import "CMISStringInOutParameter.h"
#import "CMISSession.h"
#import "CMISRenditionData.h"
#import "CMISRendition.h"

@interface CMISObject ()

@property (nonatomic, strong, readwrite) CMISSession *session;
@property (nonatomic, strong, readwrite) id<CMISBinding> binding;

@property (nonatomic, strong, readwrite) NSString *identifier;
@property (nonatomic, strong, readwrite) NSString *name;
@property (nonatomic, strong, readwrite) NSString *createdBy;
@property (nonatomic, strong, readwrite) NSDate *creationDate;
@property (nonatomic, strong, readwrite) NSString *lastModifiedBy;
@property (nonatomic, strong, readwrite) NSDate *lastModificationDate;
@property (nonatomic, strong, readwrite) NSString *objectType;
@property (nonatomic, strong, readwrite) NSString *changeToken;

@property (nonatomic, strong, readwrite) CMISProperties *properties;
@property (nonatomic, strong, readwrite) CMISAllowableActions *allowableActions;
@property (nonatomic, strong, readwrite) NSArray *renditions;

@property (nonatomic, strong) NSMutableDictionary *extensionsDict;

// returns a non-nil NSArray
- (NSArray *)nonNilArray:(NSArray *)aArray;
@end

@implementation CMISObject

@synthesize session = _session;
@synthesize binding = _binding;
@synthesize identifier = _identifier;
@synthesize name = _name;
@synthesize createdBy = _createdBy;
@synthesize creationDate = _creationDate;
@synthesize lastModifiedBy = _lastModifiedBy;
@synthesize lastModificationDate = _lastModificationDate;
@synthesize objectType = _objectType;
@synthesize changeToken = _changeToken;
@synthesize properties = _properties;
@synthesize allowableActions = _allowableActions;
@synthesize renditions = _renditions;
@synthesize extensionsDict = _extensionsDict;

- (id)initWithObjectData:(CMISObjectData *)objectData withSession:(CMISSession *)session
{
    self =  [super initWithString:objectData.identifier];
    if (self)
    {
        self.session = session;
        self.binding = session.binding;

        self.properties = objectData.properties;
        self.name = [[self.properties propertyForId:kCMISPropertyName] firstValue];
        self.createdBy = [[self.properties propertyForId:kCMISPropertyCreatedBy] firstValue];
        self.lastModifiedBy = [[self.properties propertyForId:kCMISPropertyModifiedBy] firstValue];
        self.creationDate = [[self.properties propertyForId:kCMISPropertyCreationDate] firstValue];
        self.lastModificationDate = [[self.properties propertyForId:kCMISPropertyModificationDate] firstValue];
        self.objectType = [[self.properties propertyForId:kCMISPropertyObjectTypeId] firstValue];
        self.changeToken = [[self.properties propertyForId:kCMISPropertyChangeToken] firstValue];

        self.allowableActions = objectData.allowableActions;

        // Extract Extensions and store in the extensionsDict
        self.extensionsDict = [[NSMutableDictionary alloc] init];
        [self.extensionsDict setObject:[self nonNilArray:objectData.extensions] forKey:[NSNumber numberWithInt:CMISExtensionLevelObject]];
        [self.extensionsDict setObject:[self nonNilArray:self.properties.extensions] forKey:[NSNumber numberWithInt:CMISExtensionLevelProperties]];
        [self.extensionsDict setObject:[self nonNilArray:self.allowableActions.extensions] forKey:[NSNumber numberWithInt:CMISExtensionLevelAllowableActions]];        

        // Renditions must be converted here, because they need access to the session
        if (objectData.renditions != nil)
        {
            NSMutableArray *renditions = [NSMutableArray array];
            for (CMISRenditionData *renditionData in objectData.renditions)
            {
                [renditions addObject:[[CMISRendition alloc] initWithRenditionData:renditionData andObjectId:self.identifier andSession:session]];
            }
            self.renditions = renditions;
        }
    }
    
    return self;
}

- (NSArray *)nonNilArray:(NSArray *)aArray
{   // Move to category on NSArray?
    return ((aArray == nil) ? [NSArray array] : aArray);
}

- (void)updateProperties:(NSDictionary *)properties completionBlock:(void (^)(CMISObject *object, NSError *error))completionBlock
{
    // Validate properties param
        if (!properties || properties.count == 0)
    {
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Properties cannot be nil or empty"]);
        return;
    }

    // Convert properties to an understandable format for the service
    [self.session.objectConverter convertProperties:properties forObjectTypeId:self.objectType completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
        if (convertedProperties)
        {
            CMISStringInOutParameter *objectIdInOutParam = [CMISStringInOutParameter inOutParameterUsingInParameter:self.identifier];
            CMISStringInOutParameter *changeTokenInOutParam = [CMISStringInOutParameter inOutParameterUsingInParameter:self.changeToken];
            [self.binding.objectService
             updatePropertiesForObject:objectIdInOutParam
             withProperties:convertedProperties
             withChangeToken:changeTokenInOutParam
             completionBlock:^(NSError *error) {
                 if (objectIdInOutParam.outParameter) {
                     [self.session retrieveObject:objectIdInOutParam.outParameter
                                  completionBlock:^(CMISObject *object, NSError *error) {
                                      completionBlock(object, error);
                                  }];
                 }
                 else
                 {
                     completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                 }
             }];
        }
        else
        {
            completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
        }
    }];
}

- (NSArray *)extensionsForExtensionLevel:(CMISExtensionLevel)extensionLevel
{
    // TODO Need to implement the following extension levels CMISExtensionLevelAcl, CMISExtensionLevelPolicies, CMISExtensionLevelChangeEvent
    
    return [self.extensionsDict objectForKey:[NSNumber numberWithInt:extensionLevel]];
}

@end
