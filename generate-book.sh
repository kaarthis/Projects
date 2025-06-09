#!/usr/bin/env bash

set -e

rm -r src || true
mkdir src
cp -a {design,rfd,prd,api} src/
cp -a README.md src/README.md

pushd src
trap 'popd > /dev/null 2>&1 || true' EXIT INT KILL


printf -- '[Introduction](./README.md)\n\n' > SUMMARY.md


printf -- '- [PRD](./prd/README.md)\n' >> SUMMARY.md
find ./prd ! -type d ! -name README.md -name '*.md' -print0 \
  | sort -z \
  | while read -r -d '' file;
do
    printf -- '  - [%s](%s)\n' "$(basename "$file" ".md")" "$file";
done >> SUMMARY.md


printf -- '- [API Change Proposal](./api/README.md)\n' >> SUMMARY.md
find ./api ! -type d ! -name README.md -name '*.md' -print0 \
  | sort -z \
  | while read -r -d '' file;
do
    printf -- '  - [%s](%s)\n' "$(basename "$file" ".md")" "$file";
done >> SUMMARY.md

# TODO(ace): remove head -n1
printf -- '- [Design](./design/README.md)\n' >> SUMMARY.md
find ./design ! -type d ! -name README.md -name '*.md' \
  | sort  \
  | head -n 1 \
  | while read -r file;
do
    printf -- '  - [%s](%s)\n' "$(basename "$file" ".md")" "$file";
done >> SUMMARY.md


printf -- '- [RFD](./rfd/README.md)\n' >> SUMMARY.md
find ./rfd ! -type d ! -name README.md -name '*.md' -print0 \
  | sort -z \
  | while read -r -d '' file;
do
    printf -- '  - [%s](%s)\n' "$(basename "$file" ".md")" "$file";
done >> SUMMARY.md

# mbdook expects to be in dir with src/, but we were inside src/
# results in:
# 2023-01-22 16:12:27 [ERROR] (mdbook::utils): Error: Couldn't open SUMMARY.md in "/root/code/aks-docs/src/src" directory
popd
mdbook build
