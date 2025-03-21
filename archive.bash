#!/usr/bin/env bash
# Copyright 2025 xeraph. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

REMOTE="origin"
BRANCH="main"
OWNER="$1"
IGNORED_FILES=("$(basename "$0")" .git '.' '..')

cleanup() {
    if [[ -z "$repo" ]]; then
        exit 1
    fi

    echo "[$repo] restoring previous state"

    echo "[$repo] resetting changes"
    git reset --hard

    echo "[$repo] changing to $BRANCH branch"
    git switch "$BRANCH"

    echo "[$repo] removing remote"
    git remote remove "$repo"

    echo "[$repo] removing branch"
    git branch -D "$repo"

    echo "[$repo] cleaning up the repository"
    for file in * .*; do
        if ! [[ " ${IGNORED_FILES[*]} " =~ [[:space:]]${file}[[:space:]] ]]; then
            git rm -rf "$file"
            rm -rf "$file"
        fi
    done

    echo "[$repo] resetting changes from $BRANCH"
    git reset --hard

    exit 1
}

trap cleanup SIGINT

shift
for repo in "$@"; do
    echo "[$repo] adding remote"
    if ! git remote add "$repo" git@github.com:"$OWNER"/"$repo"; then
        exit 1
    fi

    echo "[$repo] fetching branches"
    if ! git fetch "$repo"; then
        exit 1
    fi

    echo "[$repo] finding root branch"
    for _branch in master main; do
        if git branch --list --remote | grep "$repo/$_branch"; then
            echo "[$repo] using branch $_branch"
            branch="$_branch"
            break
        fi
    done

    if [[ -z "$branch" ]]; then
        echo "[$repo] could not find root branch"
        exit 1
    fi

    echo "[$repo] cleaning up the repository"
    for file in * .*; do
        if ! [[ " ${IGNORED_FILES[*]} " =~ [[:space:]]${file}[[:space:]] ]]; then
            if ! git rm -rf "$file"; then
                exit 1
            fi
        fi
    done

    echo "[$repo] changing to an orphan branch"
    if ! git checkout --orphan "$repo"; then
        exit 1
    fi

    echo "[$repo] pulling source code"
    if ! git pull "$repo" "$branch"; then
        exit 1
    fi

    echo "[$repo] moving files and directories"
    if ! mkdir "$repo"; then
        exit 1
    fi
    for file in * .*; do
        if ! [[ " ${IGNORED_FILES[*]} " =~ [[:space:]]"${file}"[[:space:]] ]]; then
            if [[ "$file" = "$repo" ]]; then
                continue
            fi
            if ! mv "$file" "$repo"; then
                exit 1
            fi
        fi
    done

    echo "[$repo] adding files"
    if ! git add "$repo"; then
        exit 1
    fi

    echo "[$repo] committing"
    if ! git commit --message "archive $repo"; then
        exit 1
    fi

    commit=$(git rev-parse HEAD)
    if [[ -z "$commit" ]]; then
        echo "[$repo] missing HEAD commit"
        exit 1
    fi

    echo "[$repo] switching to $BRANCH branch"
    if ! git switch "$BRANCH"; then
        exit 1
    fi

    echo "[$repo] cherry picking archive commit"
    if ! git cherry-pick "$commit"; then
        exit 1
    fi

    echo "[$repo] removing remote"
    if ! git remote remove "$repo"; then
        exit 1
    fi

    echo "[$repo] removing branch"
    if ! git branch -D "$repo"; then
        exit 1
    fi
done
