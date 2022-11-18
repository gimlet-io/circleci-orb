#!/usr/bin/env bash

set -e

git version

echo "Creating artifact.."

COMMIT_MESSAGE=$(git log -1 --pretty=%B)
COMMIT_AUTHOR=$(git log -1 --pretty=format:'%an')
COMMIT_AUTHOR_EMAIL=$(git log -1 --pretty=format:'%ae')
COMMIT_COMITTER=$(git log -1 --pretty=format:'%cn')
COMMIT_COMITTER_EMAIL=$(git log -1 --pretty=format:'%ce')
COMMIT_CREATED=$(git log -1 --format=%cI)

EVENT="push"
URL="https://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/commit/$CIRCLE_SHA1"
if [[ -v CIRCLE_PULL_REQUEST ]];
then
    EVENT="pr"
    SOURCE_BRANCH=$CIRCLE_BRANCH
    TARGET_BRANCH=todo
    URL=$CIRCLE_PULL_REQUESTS
fi

if [[ -v CIRCLE_TAG ]];
then
    EVENT="tag"
fi

gimlet artifact create \
  --repository "$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME" \
  --sha "$CIRCLE_SHA1" \
  --created "$COMMIT_CREATED" \
  --branch "$CIRCLE_BRANCH" \
  --event "$EVENT" \
  --sourceBranch "$SOURCE_BRANCH" \
  --targetBranch "$TARGET_BRANCH" \
  --tag "$CIRCLE_TAG" \
  --authorName "$COMMIT_AUTHOR" \
  --authorEmail "$COMMIT_AUTHOR_EMAIL" \
  --committerName "$COMMIT_COMITTER" \
  --committerEmail "$COMMIT_COMITTER_EMAIL" \
  --message "$COMMIT_MESSAGE" \
  --url "$URL" \
  > artifact.json

echo "Attaching CI run URL.."
gimlet artifact add \
  -f artifact.json \
  --field "name=CI" \
  --field "url=$CIRCLE_BUILD_URL"

echo "Attaching Gimlet manifests.."
for file in .gimlet/*
do
    if [[ -f $file ]]; then
      gimlet artifact add -f artifact.json --envFile $file
    fi
done

echo "Attaching environment variable context.."
VARS=$(printenv | grep CIRCLE | awk '$0="--var "$0')
gimlet artifact add -f artifact.json $VARS

echo "Attaching common Gimlet variables.."
gimlet artifact add \
-f artifact.json \
--var "REPO=$CIRCLE_PROJECT_REPONAME" \
--var "OWNER=$CIRCLE_PROJECT_USERNAME" \
--var "BRANCH=$CIRCLE_BRANCH" \
--var "TAG=$CIRCLE_TAG" \
--var "SHA=$CIRCLE_SHA1" \
--var "ACTOR=$CIRCLE_USERNAME" \
--var "EVENT=$EVENT" \
--var "JOB=$CIRCLE_JOB"

if [[ "$DEBUG" == "true" ]]; then
    cat artifact.json
    exit 0
fi

echo "Shipping artifact.."
gimlet artifact push -f artifact.json --output json | jq -r '.id'
ARTIFACT_ID=$(gimlet artifact push -f artifact.json --output json | jq -r '.id' )
if [ $? -ne 0 ]; then
    echo $ARTIFACT_ID
    exit 1
fi

echo "Shipped artifact ID is: $ARTIFACT_ID"

if [[ "$WAIT" == "true" || "$DEPLOY" == "true" ]]; then
    gimlet artifact track --wait --timeout $TIMEOUT $ARTIFACT_ID
else
    gimlet artifact track $ARTIFACT_ID
fi

if [[ "$DEPLOY" == "true" ]]; then
    echo "Deploying.."
    RELEASE_ID=$(gimlet release make --artifact $ARTIFACT_ID --env $ENV --app $APP --output json | jq -r '.id')
    echo "Deployment ID is: $RELEASE_ID"
    gimlet release track --wait --timeout $TIMEOUT $RELEASE_ID
fi
