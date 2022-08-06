## fakemesh简介

fakemesh是由一个`控制器（AC）`和一个或者多个`有线AP（Wired AP）`和`卫星（Agent）`组成的网络，是混合了`无线Mesh`和`AC+AP`两种组网模式的混合网络，`有线AP`通过网线和AC相连，`卫星`则通过无线STA方式接入，共同组成一个无线（包括有线）覆盖网络。

fakemesh在部署上非常方便，只需要设置好节点设备的角色，Mesh ID等信息，就可以轻松接入。

目前[X-WRT](https://github.com/x-wrt/x-wrt)默认集成了fakemesh功能

## fakemesh 使用

### 组网成功后统一的访问设备的地址格式如下:

访问控制器的地址: `http://controller.fakemesh/`或者`http://ac.fakemesh/`

访问AP的地址: `http://{mac}.ap.fakemesh/` 或者 `http://N.ap.fakemesh/`

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

故障模式下AP的管理IP地址是DHCP的网关地址，比如电脑获取到`192.168.16.x`的IP，那么AP的管理IP就是`192.168.16.1`

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

### 7. 关闭前传(Fronthaul Disabled)
   这个节点关闭前传无线信号，也就是不允许其他AP节点通过这个节点Wi-Fi接入。

### 8. 漫游组件(Band Steer Helper)
   目前可以选择[DAWN](https://github.com/fakemesh/dawn)或者[usteer](https://github.com/fakemesh/usteer)作为漫游辅助控件。

## 无线管理(Wireless Management)

   可以在控制器界面上统一管理无线，包括增删SSID，设置SSID的加密方式，频宽。

## 控制器(Controller)旁路部署

   有时候可以让控制器旁路部署，这种情况，控制器可以选择不作为网关出口，可以不提供dhcp服务，这个时候用户需要根据自己的需要，自行关闭控制器lan口的DHCP服务，如果需要，也可以自行设置lan口的IP地址和网关IP和DNS。

   需要注意的是，通常会设置lan口dhcp自动上网，自动从第三方网关获取IP和网关，也可以设置静态IP，但是要保证和第三方网关ping通，如果不通/不在一个网段，就无法和其他AP同步配置了。
