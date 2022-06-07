## fakemesh 使用

### 组网成功后统一的访问设备的地址格式如下:

访问控制器的地址: `http://controller.fakemesh/`

访问AP得地址: `http://{mac}.ap.fakemesh/` 或者 `http://N.ap.fakemesh/`

其中`{mac}`是AP的MAC地址，比如`{mac}=1122334455AB`，`N`是AP的自动编号，比如 N=1, N=2, N=3, ...

例子:
```
http://1.ap.fakemesh/
http://1122334455AB.ap.fakemesh/
```

### 故障处理:

AP离线3分钟左右进入故障模式，这个模式开启默认SSID，可以提供接入管理重新配置。
故障模式的默认SSID和密码是:
```
SSID: X-WRT_XXXX
PASSWD: 88888888
```

故障模式下AP的管理IP地址是DHCP的网关地址，比如电脑获取到`192.168.1.x`的IP，那么AP的管理IP就是`192.168.1.1`

## fakemesh 基本组成

组网由一个`控制器(controller)`和一个或者多个`AP`组成

AP包括: `卫星(Agent)`和`有线AP(Wired AP)`两种

**控制器(Controller)**:  作为AC和出口路由器，提供网络出口上网，统一管理下挂的卫星和有线AP，统一管理无线

**卫星(Agent)**:  通过Wi-Fi组网接入的AP

**有线AP(Wired AP)**:  通过网线组网接入的AP

## fakemesh 配置参数

### 1. Mesh ID

   这个参数是fakemesh网络组网的统一ID，控制器、卫星、有线AP都要设置相同的Mesh ID。

### 2. 密钥(Key)

   这是组网的统一密钥，组网加密需要，如果不需要加密可以留空白。

### 3. 带宽(Band)

   这是组网使用的无线频段，要设置相同，5G或者2G。

### 4. 角色(Role)

   可以是控制器、卫星、有线AP。

### 5. 同步配置(Sync Config)

   是否统一管理Wi-Fi配置等，Wi-Fi配置由控制器统一配置管理。

### 6. 访问 IP 地址(Access IP address)

   设置一个特定的IP地址给控制器，可以通过这个IP访问控制器的管理界面。

## 无线管理(Wireless Management)

   可以在控制器界面上统一管理无线，包括增删SSID，设置SSID的加密方式，频宽。
