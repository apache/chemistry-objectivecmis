#!/bin/bash

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

OBJECTIVECMIS_VERSION=`sed -ne '/^OBJECTIVECMIS_VERSION=/s/.*=\([\^]*\)/\1/p' ObjectiveCMIS/ObjectiveCMIS.xcconfig`
echo Library Version detected: $OBJECTIVECMIS_VERSION

OBJECTIVECMIS_PACK_SRC=chemistry-objectivecmis-$OBJECTIVECMIS_VERSION-src.zip
OBJECTIVECMIS_PACK_BIN=chemistry-objectivecmis-$OBJECTIVECMIS_VERSION-bin.zip
OBJECTIVECMIS_RC=RC1

if [ -d release ]
then
  rm -R release
fi
mkdir release

if [ -d release-temp ]
then
  rm -R release-temp
fi
mkdir release-temp


echo "Creating source package..."
if [ -d release-pack ]
then
  rm -R release-pack
fi
mkdir release-pack
mkdir release-pack/src

cp NOTICE release-pack
cp LICENSE release-pack
cp README release-pack
rsync -a --exclude='.*' ObjectiveCMIS release-pack/src
rsync -a --exclude='.*' ObjectiveCMIS.xcodeproj release-pack/src
rsync -a --exclude='.*' ObjectiveCMISTests release-pack/src

cd release-pack

zip -r ../release/$OBJECTIVECMIS_PACK_SRC *

cd ..


echo "Preparing binary package..."

rm -R -f release-pack
mkdir release-pack
mkdir release-pack/doc
mkdir release-pack/bin

cp NOTICE release-pack
cp LICENSE release-pack
cp README release-pack


echo "Generating documentation ..."

mkdir release-temp

appledoc --output release-temp --project-name "Apache Chemistry ObjectiveCMIS" --project-company "Apache Software Foundation" --company-id org.apache.chemistry --keep-intermediate-files --exit-threshold 2 --keep-undocumented-objects --keep-undocumented-members --ignore .m --docset-install-path release-pack/doc ObjectiveCMIS

rm -R release-temp


echo "Building static library..."

BUILD_UNIVERSAL_LIB='TRUE'
export BUILD_UNIVERSAL_LIB
xcodebuild -project ObjectiveCMIS.xcodeproj -target ObjectiveCMIS -configuration Debug clean build
xcodebuild -project ObjectiveCMIS.xcodeproj -target ObjectiveCMIS -configuration Release clean build

cp -R build/Debug-universal/* release-pack/bin
cp build/Release-universal/*.a release-pack/bin

echo "Creating package..."

cd release-pack

zip -r ../release/$OBJECTIVECMIS_PACK_BIN *

cd ..


echo "Signing packages ..."

cd release

gpg --armor --output $OBJECTIVECMIS_PACK_SRC.asc --detach-sig $OBJECTIVECMIS_PACK_SRC
gpg --print-md MD5 $OBJECTIVECMIS_PACK_SRC > $OBJECTIVECMIS_PACK_SRC.md5
gpg --print-md SHA512 $OBJECTIVECMIS_PACK_SRC > $OBJECTIVECMIS_PACK_SRC.sha

gpg --armor --output $OBJECTIVECMIS_PACK_BIN.asc --detach-sig $OBJECTIVECMIS_PACK_BIN
gpg --print-md MD5 $OBJECTIVECMIS_PACK_BIN > $OBJECTIVECMIS_PACK_BIN.md5
gpg --print-md SHA512 $OBJECTIVECMIS_PACK_BIN > $OBJECTIVECMIS_PACK_BIN.sha


cd ..


echo "Creating RC tag..."

# svn copy https://svn.apache.org/repos/asf/chemistry/objectivecmis/trunk https://svn.apache.org/repos/asf/chemistry/objectivecmis/tags/chemistry-objectivecmis-$OBJECTIVECMIS_VERSION-$OBJECTIVECMIS_RC


echo "Almost done..."

rm -R release-pack


echo "done!"