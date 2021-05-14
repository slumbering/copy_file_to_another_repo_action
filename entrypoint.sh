#!/bin/sh

set -e
set -x

if [ -z "$GITHUB_REF"]
then
  CURRENT_REF=main
else
  CURRENT_REF=$( echo "$GITHUB_REF" |cut -d/ -f3)
fi

if [ -z "$INPUT_SOURCE_FILE" ]
then
  echo "Source file must be defined"
  return -1
fi

if [ -z "$INPUT_DESTINATION_BRANCH" ]
then
  INPUT_DESTINATION_BRANCH=main
fi
OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"

CLONE_DIR=$(mktemp -d)

echo "Retieve tag list"
ROOTDIR=$(pwd)
echo "[ {\"tag\": \"$(git tag -l "v*" | tr '\n' '|' | sed -e 's/|/"}, {\"tag\": "/g')main\"} ]" > tags.json 

echo "Cloning destination git repository"
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"
git clone --single-branch --branch $INPUT_DESTINATION_BRANCH "https://x-access-token:$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
cp -r "$INPUT_SOURCE_FILE" "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"
cd "$CLONE_DIR"
mkdir -p site/tags
cp "$ROOTDIR/tags.json" ./site/tags/tags.json

if [ ! -z "$INPUT_DESTINATION_BRANCH_CREATE" ]
then
  git checkout -b "$INPUT_DESTINATION_BRANCH_CREATE"
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH_CREATE"
fi

if [ -z "$INPUT_COMMIT_MESSAGE" ]
then
  INPUT_COMMIT_MESSAGE="Update from https://github.com/$%7BGITHUB_REPOSITORY%7D/commit/$%7BGITHUB_SHA%7D"
fi

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  if [[ $CURRENT_REF != main  ]]
  then
    git tag -a $CURRENT_REF -m "New Release for ${CURRENT_REF}"
    echo "Pushing git tag commit"
    git push --tags
  else
    git commit --message "$INPUT_COMMIT_MESSAGE"
    echo "Pushing git commit"
    git push -u origin HEAD:$OUTPUT_BRANCH
  fi
else
  echo "No changes detected"
fi
