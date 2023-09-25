#!/bin/bash
set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
  echo "Set the GITHUB_REPOSITORY env variable."
  exit 1
fi

if [[ -z "$GITHUB_EVENT_PATH" ]]; then
  echo "Set the GITHUB_EVENT_PATH env variable."
  exit 1
fi

addLabel=$ADD_LABEL
if [[ -n "$LABEL_NAME" ]]; then
  echo "Warning: Please define the ADD_LABEL variable instead of the deprecated LABEL_NAME."
  addLabel=$LABEL_NAME
fi

if [[ -z "$addLabel" ]]; then
  echo "Set the ADD_LABEL or the LABEL_NAME env variable."
  exit 1
fi

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

action=$(jq --raw-output .action "$GITHUB_EVENT_PATH")
state=$(jq --raw-output .review.state "$GITHUB_EVENT_PATH")
number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

remove_label() {
  if [[ -n "$REMOVE_LABEL" ]]; then
      curl -sSL \
        -H "${AUTH_HEADER}" \
        -H "${API_HEADER}" \
        -X DELETE \
        "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels/${REMOVE_LABEL}"
  fi
}

add_removeLabel() {
  if [[ -n "$REMOVE_LABEL" ]]; then
    curl -sSL \
      -H "${AUTH_HEADER}" \
      -H "${API_HEADER}" \
      -X POST \
      -H "Content-Type: application/json" \
      -d "{\"labels\":[\"${REMOVE_LABEL}\"]}" \
      "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels"
  fi
}

add_label() {
  curl -sSL \
      -H "${AUTH_HEADER}" \
      -H "${API_HEADER}" \
      -X POST \
      -H "Content-Type: application/json" \
      -d "{\"labels\":[\"${addLabel}\"]}" \
      "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels"
}

remove_addLabel() {
  curl -sSL \
    -H "${AUTH_HEADER}" \
    -H "${API_HEADER}" \
    -X DELETE \
    "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels/${addLabel}"
}

remove_change() {
  if [[ -n "$CHANGE_LABEL" ]]; then
      curl -sSL \
        -H "${AUTH_HEADER}" \
        -H "${API_HEADER}" \
        -X DELETE \
        "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels/${CHANGE_LABEL}"
  fi
}

add_change() {
  if [[ -n "$CHANGE_LABEL" ]]; then
    curl -sSL \
      -H "${AUTH_HEADER}" \
      -H "${API_HEADER}" \
      -X POST \
      -H "Content-Type: application/json" \
      -d "{\"labels\":[\"${CHANGE_LABEL}\"]}" \
      "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels"
  fi
}

label_when_approved() {
  # https://developer.github.com/v3/pulls/reviews/#list-reviews-on-a-pull-request
  body=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}/pulls/${number}/reviews?per_page=100")
  reviews=$(echo "$body" | jq --raw-output '.[] | {state: .state, user: .user.login} | @base64')

  approvals=0
  changes_requested=0
  
  declare -A reviewsByReviewer
  for r in $reviews; do
    review="$(echo "$r" | base64 -d)"
    rState=$(echo "$review" | jq --raw-output '.state')
    if [[ "$rState" == "CHANGES_REQUESTED" || "$rState" == "APPROVED" ]]; then
      user=$(echo "$review" | jq --raw-output '.user')
      reviewsByReviewer["$user"]="$review"
    fi
  done
  
  for review in ${reviewsByReviewer[@]}; do
    rState=$(echo "$review" | jq --raw-output '.state')
    
    if [[ "$rState" == "CHANGES_REQUESTED" ]]; then
      changes_requested=$((changes_requested+1))
    elif [[ "$rState" == "APPROVED" ]]; then
      approvals=$((approvals+1))
    fi
    
    user=$(echo "$review" | jq --raw-output '.user')
    echo "${user}: ${rState}"
    echo "${changes_requested} change requested"
    echo "${approvals}/${APPROVALS} approvals"
    
  done
  
  totalReviews=$((approvals+changes_requested))
  if [[ "$totalReviews" -ge "$APPROVALS" ]]; then
    remove_label
  else
    add_removeLabel
  fi
  
  if [[ "$changes_requested" -ge "1" ]]; then
    remove_addLabel
    add_change
    
    exit 0
  else
    remove_change
  fi
  
  if [[ "$approvals" -ge "$APPROVALS" ]]; then
    add_label

    exit 0
  fi
}

label_when_approved
