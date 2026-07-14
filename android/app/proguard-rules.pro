# ── Android 平台缺失的可选依赖（R8 放行）──
# SSHD 2.10 / FTP 服务器在 Android 上引用了以下仅桌面/JDK 环境存在的可选类，
# 其调用点均被库内部 try-catch 保护，运行时不会触发；放行以避免 R8 报 Missing class 失败。
-dontwarn javax.management.**
-dontwarn net.i2p.crypto.eddsa.**
-dontwarn org.slf4j.impl.**
