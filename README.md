# DST Dedicated Server build script

This script will configure an ubuntu linux machine to run a Don't Starver Together dedicated server

Suggested use
```bash
wget https://raw.githubusercontent.com/trevorpeacock/DST-dedicated-server-build-script/main/build_server.sh
chmod +x build_server.sh
nano build_server.sh #set options at top of file
./build_server.sh
```

This is tested on an EC2 instance with the following options:
* Ubuntu Server 20.04 LTS (ami-0567f647e75c7bc05)
* t3a.medium (4GB RAM)
* 12GB disk
* Security group allowing SSH (TCP/22) DST (UDP/11000) and Ping (ICMP Echo Request)

It will install `steamcmd` and `DoNotStarveTogether`, generate a sample game configuration and start the server

It will optionally configure a script to shut down the server if left idle

If you modify  game config and add mods to `modoverrides.lua`, it will automatically add those mods to `dedicated_server_mods_setup.lua`

## Configuration

There are two mandatory parameters that must be set inside `build_server.sh`
 * CLUSTER_TOKEN: Token from [Klei](https://accounts.klei.com/account/game/servers?game=DontStarveTogether) to register the server 
 * GAME_NAME: The display name of your server
 
Optional parameters:
 * GAME_DESCRIPTION: Description displayed for the game
 * GAME_INTENTION: Intention displayed with the game (cooperative | social | competitive | madness)
 * GAME_MODE: The play mode (endless | survival | wilderness)
 * GAME_MAX_PLAYERS: maximum number of players allowed
 * GAME_PVP: if players are allowed to hurt each other
 * GAME_PASSWORD: add a password required to enter the game (leaving blank disables password)
 * ENABLE_AUTO_SHUTDOWN: Set the server to automatically turn off when idle
 * AUTO_SHUTDOWN_TIME: The number of minutes before the server turns off

## Command Line Parameters
```
Usage: build_server.sh [-o] [-d] [-l]

 build_server.sh will set up a DST service and start it

  Arguments:
    -o overwite game configuration if it exists
    -d don't start the dst service
    -l launch the server interactively (implies -d)
```

## Additional game configuration

Game configuration is stored in `/home/steam/.klei/DoNotStarveTogether/MyDediServer/`

The following files control server behaviour
 * cluster.ini
 * server.ini
 * server.ini

The following files control world generation
 * Master/worldgenoverride.lua
 * Caves/worldgenoverride.lua

To generate custom worlds:
 * delete current game and world (if you have already run the script)<br/>`sudo rm -dfr /home/steam/.klei/DoNotStarveTogether/MyDediServer/`
 * run `./build_server.sh -d` to configure server without starting the game
 * modify `worldgenoverride.lua` files
 * start server `sudo systemctl start dst`

To Add Mods, edit:
 * Master/modoverrides.lua
 * Caves/modoverrides.lua

To add game Admins:
* Add Klei User IDs to `adminlist.txt`, one per line

Klei User IDs are in the form KU_xxxxxxxx, and can be found by visiting https://accounts.klei.com/account/info
