#!/bin/sh

TAG=${TAG-x-b`date +%Y%m%d%H%M`}

sed -i "s/\(^src-git.*\.git$\)/\1;$TAG/" feeds.conf.default && \
git commit --signoff -am "release: $TAG" && \
git tag $TAG && \
git push origin $TAG

cd feeds/x && \
sed -i "s/CONFIG_VERSION_NUMBER=\".*\"/CONFIG_VERSION_NUMBER=\"$TAG\"/" rom/lede/config.* && \
git commit --signoff -am "release: $TAG" && \
git tag $TAG && \
git push origin $TAG && \
git push origin master && \
cd -

exit 0

for d in feeds/packages feeds/luci feeds/routing feeds/telephony; do
	cd "$d" && {
		echo
		pwd
		git tag $TAG && \
		git push origin $TAG
		cd -
	}
done
