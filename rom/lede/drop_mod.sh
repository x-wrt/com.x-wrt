

for cfg in rom/lede/config.*; do

git diff HEAD^ $cfg | grep "^+CONFIG.*=m" | grep -v CONFIG_PACKAGE_.*-support=m | sed 's/+//;s/=m//' | while read m; do

echo $cfg $m
sed -i "s/$m=m/# $m is not set/g" $cfg

done
done
