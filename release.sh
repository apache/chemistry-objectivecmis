#!/bin/sh

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

OBJECTIVECMIS_VERSION=0.1
OBJECTIVECMIS_PACK=chemistry-objectiveccmis-$OBJECTIVECMIS_VERSION.zip
OBJECTIVECMIS_RC=RC1

rm -R release-temp
mkdir release-temp

echo "Copying files..."

rm -R release-pack
mkdir release-pack
mkdir release-pack/src
mkdir release-pack/doc
mkdir release-pack/bin

cp NOTICE release-pack
cp LICENSE release-pack
cp README release-pack
cp -R ObjectiveCMIS release-pack/src
cp -R ObjectiveCMIS.xcodeproj release-pack/src
cp -R ObjectiveCMISTests release-pack/src


echo "Generating documentation ..."

mkdir release-temp

appledoc --output release-temp --project-name "Apache Chemistry ObjectiveCMIS" --project-company "Apache Software Foundation" --company-id org.apache.chemistry --keep-intermediate-files --exit-threshold 2 --keep-undocumented-objects --keep-undocumented-members --ignore .m --docset-install-path release-pack/doc ObjectiveCMIS

rm -R release-temp


echo "Building static library..."

BUILD_UNIVERSAL_LIB='TRUE'
export BUILD_UNIVERSAL_LIB
xcodebuild -project ObjectiveCMIS.xcodeproj -target ObjectiveCMIS -configuration Debug clean build

cp -R build/Debug-universal/* release-pack/bin


echo "Creating package..."

rm -R release
mkdir release

cd release-pack

zip -r ../release/$OBJECTIVECMIS_PACK *

cd ..


echo "Signing package ..."

cd release

gpg --armor --output $OBJECTIVECMIS_PACK.asc --detach-sig $OBJECTIVECMIS_PACK
gpg --print-md MD5 $OBJECTIVECMIS_PACK > $OBJECTIVECMIS_PACK.md5
gpg --print-md SHA1 $OBJECTIVECMIS_PACK > $OBJECTIVECMIS_PACK.sha
gpg --print-md MD5 $OBJECTIVECMIS_PACK.asc > $OBJECTIVECMIS_PACK.asc.md5
gpg --print-md SHA1 $OBJECTIVECMIS_PACK.asc > $OBJECTIVECMIS_PACK.asc.sha

cd ..


echo "Creating RC tag..."

# svn copy https://svn.apache.org/repos/asf/chemistry/objectivecmis/trunk https://svn.apache.org/repos/asf/chemistry/objectivecmis/tags/chemistry-objectivecmis-$OBJECTIVECMIS_VERSION-$OBJECTIVECMIS_RC


echo "Almost done..."

rm -R release-pack


echo "done!"