#Remote SignTool 

This tool can be used to automate EV Codesigning process on your build server.

Limitations of EV Codesignig with SafeNet token:
1. You must login locally to buildserver. Or if you logged to server via RDP, you must attach token to local machine, not server.
2. If you have more than one developer who want to sign files, you can't do it, because you cannot replicate your token.
3. Windows service applications cannot access to token to sign files.

To pass (partially) this limitations, I'm developed Client-Server application. You can run server at any machine where you can login locally and attach token.
On the client side, you call client which send file to server and place signed file back. Client can act as regular signtool.exe, so no modifications needed in your build scripts.

The only one limitation in my solution: You must login locally (No via RDP) to machine with token attached and start server application. Once started you must press "Test and start" button. This button will try to sign test file and if succeed will start HTTP server on port 8090 (default).
While test running, you will be prompted to enter password to your token (This is SafeNet toke password dialog). I'm specially not hardcoded any passwords, so nobody can stolen it.

*Requirements:*
1. You must set "Enable single logon" in the SafeNet Auth client Tools (Advanced View -> Client Settings -> Advanced)
2. Delphi XE8 Upd1 must be used to compile project

*Usage:*
1. Login to computer where you placed this tool (server side). This can be build server itself, if you have access to admin console.
2. Press "Test and start" button, and enter your token password when SafeNet dialog appears. Now server ready to accept connections.
3. Do not lock console. After Lock and Unlock, tool will be unable to sign files and you must restart it and enter token password again!
