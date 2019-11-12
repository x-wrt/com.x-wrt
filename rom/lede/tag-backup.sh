#!/bin/sh

fail()
{
	echo $@
	exit 255
}

test -f .build_x/env && \
. .build_x/env

test -n "$TAG" && release=0

TAG=${TAG-$CONFIG_VERSION_NUMBER} &&
test -n "$TAG" || fail no TAG

[ "x$release" = "x0" ] || {
	sed -i "s/\(^src-git.*\.git$\)/\1;$TAG/" feeds.conf.default && \
	git commit --signoff -am "release: $TAG"
}

git tag $TAG && \
git push origin $TAG || exit 1

cd feeds/x
[ "x$release" = "x0" ] || {
	sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$TAG\"/" rom/lede/config.* && \
	git commit --signoff -am "release: $TAG" && \
	git push origin master
}

git tag $TAG && \
git push origin $TAG || exit 1
cd -

for d in feeds/packages feeds/luci feeds/routing feeds/telephony; do
	cd "$d" && {
		echo
		pwd
		git tag $TAG && \
		git push origin $TAG || exit 1
		cd -
	} || exit 1
done
