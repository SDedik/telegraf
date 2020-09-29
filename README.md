# Telegraf
PowerShell DSC Module for managing Telegraf Agent on Windows nodes

@all feel free to download, copy and use this code as you like. I am genuinly interested in wider adoption of PowerShell DSC.

The main idea is that Telegraf executable is downloaded by each Windows node from some internal http web-server. In the company where I implemented this, we specifically wanted to avoid downloads from Internet. MD5 hash is used by the module if telegraf version is already at what is requested by configuration, or new executable has to be downloaded.

Entire module is in the **Telegraf** folder along with usage examples, ready for download and use on your Windows machines.

This module has not been published to powershell gallery yet. Perhaps I will do so in the future.
