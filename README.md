# OpenWrt for Amlogic S9XXX

## Firmware information

| Name | Value |
| ---- | ---- |
| Default IP | 192.168.2.1 |
| Default username | root |
| Default password | password |
| Default WIFI name | OpenWrt |
| Default WIFI password | none |

## Bypass gateway settings

If used as a bypass gateway, you can add custom firewall rules as needed (Network → Firewall → Custom Rules):

```yaml
iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE        #If the interface is eth0.
iptables -t nat -I POSTROUTING -o br-lan -j MASQUERADE      #If the interface is br-lan bridged.
```

## Acknowledgments

- [openwrt](https://github.com/openwrt/openwrt)
- [lede](https://github.com/coolsnowwolf/lede)
- [unifreq](https://github.com/unifreq/openwrt_packit)
- [ophub](https://github.com/ophub)

## License

[LICENSE](https://github.com/lasthinker/amlogic-s9xxx-openwrt/blob/main/LICENSE) © lasthinker

