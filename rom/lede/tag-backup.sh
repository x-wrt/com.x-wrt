#!/bin/sh

fail()
{
	echo $@
	exit 255
}

release=1

test -f .build_x/env && \
. .build_x/env

test -n "$TAG" && release=0

TAG=${TAG-$CONFIG_VERSION_NUMBER} &&
test -n "$TAG" || fail no TAG

for d in feeds/packages feeds/luci feeds/routing feeds/telephony; do
	echo CD: $d
	cd "$d" && {
		echo
		pwd
		git tag | grep "^$TAG$" || {
			git tag $TAG
		}
		git push origin $TAG || exit 1
		cd -
	} || exit 1
done

if git tag | grep "^$TAG$"; then
	if [ "x$release" = "x1" ]; then
	echo CD: feeds/x
	cd feeds/x && \
	sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$TAG\"/" rom/lede/config.* && \
	git commit --signoff -am "release: $TAG" && \
	git tag $TAG && \
	git push origin $TAG || exit 1
	cd -
	else
	echo CD: feeds/x
	cd feeds/x && \
	git tag $TAG && \
	git push origin $TAG || exit 1
	cd -
	fi
else
if [ "x$release" = "x1" ]; then
	echo CD: feeds/x
	cd feeds/x && \
	sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$TAG\"/" rom/lede/config.* && \
	git commit --signoff -am "release: $TAG" && \
	git tag $TAG && \
	git push origin $TAG || exit 1
	cd -

	sed -i "s/\(^src-git.*\.git$\)/\1;$TAG/" feeds.conf.default && \
	git commit --signoff -am "release: $TAG" && \
	git tag $TAG && \
	git push origin $TAG || exit 1
else
	echo CD: feeds/x
	cd feeds/x && \
	git tag $TAG && \
	git push origin $TAG || exit 1
	cd -

	git tag $TAG && \
	git push origin $TAG || exit 1
fi
fi
